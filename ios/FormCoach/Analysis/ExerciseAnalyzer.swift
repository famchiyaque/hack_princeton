import Foundation
import os

private let log = Logger(subsystem: "com.formcoach", category: "ExerciseAnalyzer")

// MARK: - Classification state

enum ClassificationState: Equatable, CustomStringConvertible {
    case unknown
    case candidate(ExerciseType)
    case locked(ExerciseType)

    var exercise: ExerciseType {
        switch self {
        case .unknown: return .unknown
        case .candidate(let e), .locked(let e): return e
        }
    }

    var isLocked: Bool {
        if case .locked = self { return true }
        return false
    }

    var description: String {
        switch self {
        case .unknown: return "unknown"
        case .candidate(let e): return "candidate(\(e.rawValue))"
        case .locked(let e): return "locked(\(e.rawValue))"
        }
    }
}

// MARK: - Analyzer output (read by SessionView)

struct AnalyzerSnapshot {
    let state: ClassificationState
    let squatEvidence: Double
    let curlEvidence: Double
    let repCount: Int
    let currentPhase: String
    let formIssues: [FormIssue]
    let formResult: FormResult
    let debugReason: String
}

// MARK: - ExerciseAnalyzer

/// Sits between raw pose keypoints and UI/feedback.
/// Handles classification (with evidence + decay), rep counting,
/// phase detection, and form feedback in one unified pipeline.
final class ExerciseAnalyzer: ObservableObject {

    // MARK: - Configuration

    struct Config {
        // Evidence
        var evidencePerFrame: Double = 1.0
        var evidenceDecay: Double = 0.98
        var lockMargin: Double = 1.3       // winner must be N× the loser
        var lockMinEvidence: Double = 10.0
        var lockMinReps: Int = 1
        var lockMinConfidence: Float = 0.3
        var unlockContradictionFrames: Int = 150  // ~5 seconds of contradictory data

        // Classification signals
        var movementFloor: Double = 3.0
        var squatKneeThreshold: Double = 5.0
        var squatHipThreshold: Double = 5.0
        var curlElbowThreshold: Double = 15.0
        var curlLegStillThreshold: Double = 15.0

        // Rep detection hysteresis (degrees)
        var squatCycleHysteresis: Double = 20.0
        var curlCycleHysteresis: Double = 25.0

        // Cycle detection on hip center Y (body-relative units)
        var hipYCycleHysteresis: Double = 0.15
    }

    let config: Config

    // MARK: - Published state

    @Published private(set) var state: ClassificationState = .unknown
    @Published private(set) var repCount: Int = 0

    // MARK: - Internal state

    private var window = MotionWindow()
    private var squatEvidence: Double = 0
    private var curlEvidence: Double = 0
    private var squatReps: Int = 0
    private var curlReps: Int = 0
    private var contradictionCounter: Int = 0
    private var framesSinceLock: Int = 0
    private var debugReason: String = "waiting for movement"

    // Rep counting (post-lock)
    private var repCounter: RepCounter?
    private var currentPhase: String = "top"

    // Form feedback
    private let formEngine: FormFeedbackEngine
    private let comparator = FormComparator()
    private(set) var profile = CalibrationProfile()

    // Rep-level angle tracking for calibration
    private var repMinAngles: BodyAngles?
    private var repMaxAngles: BodyAngles?
    private var repSpineAccum: [Double] = []

    // Tick counter for logging throttle
    private var tickCount: Int = 0

    // MARK: - Init

    init(config: Config = Config()) {
        self.config = config
        self.formEngine = FormFeedbackEngine()
    }

    // MARK: - Public API

    /// Feed a new pose frame. Call every frame from SessionView.
    func update(pose: BodyPose) -> AnalyzerSnapshot {
        let features = PoseFeatures.extract(from: pose)
        window.append(features)

        // Update body proportions early.
        profile.updateBodyProportions(torso: features.torsoLength, shoulders: features.shoulderWidth)

        tickCount += 1

        switch state {
        case .unknown, .candidate:
            updateClassification(features: features)
        case .locked(let exercise):
            framesSinceLock += 1
            updateLockedExercise(features: features, exercise: exercise)
        }

        let formIssues = formEngine.activeIssues
        let formResult = buildFormResult(features: features)

        return AnalyzerSnapshot(
            state: state,
            squatEvidence: squatEvidence,
            curlEvidence: curlEvidence,
            repCount: repCount,
            currentPhase: currentPhase,
            formIssues: formIssues,
            formResult: formResult,
            debugReason: debugReason
        )
    }

    func reset() {
        state = .unknown
        repCount = 0
        squatEvidence = 0
        curlEvidence = 0
        squatReps = 0
        curlReps = 0
        contradictionCounter = 0
        framesSinceLock = 0
        window.clear()
        repCounter = nil
        currentPhase = "top"
        formEngine.reset()
        profile = CalibrationProfile()
        repMinAngles = nil
        repMaxAngles = nil
        repSpineAccum = []
        debugReason = "waiting for movement"
        tickCount = 0
    }

    // MARK: - Classification (unknown/candidate states)

    private func updateClassification(features: PoseFeatures) {
        guard window.isReady else {
            debugReason = "accumulating frames (\(window.frames.count)/\(window.config.minFrames))"
            return
        }
        guard window.avgConfidence >= config.lockMinConfidence else {
            debugReason = "low confidence (\(String(format: "%.2f", window.avgConfidence)))"
            return
        }

        // Compute motion signals
        let kneeRange = window.kneeRange ?? 0
        let hipRange = window.hipRange ?? 0
        let elbowRange = window.elbowRange ?? 0
        let hipYRange = window.hipCenterYRange ?? 0
        let wristYRange = window.wristYRange ?? 0
        let spineMean = window.spineMean ?? 180

        let lowerBodyMotion = kneeRange + hipRange
        let upperBodyMotion = elbowRange

        // Movement floor
        guard lowerBodyMotion > config.movementFloor || upperBodyMotion > config.movementFloor else {
            debugReason = "insufficient movement (lower=\(f(lowerBodyMotion)) upper=\(f(upperBodyMotion)))"
            // Decay evidence while still
            squatEvidence *= config.evidenceDecay
            curlEvidence *= config.evidenceDecay
            return
        }

        // Squat signals — hip Y (vertical movement) is the strongest front-camera signal
        let squatSignal: Double = {
            var score = 0.0
            if hipYRange > config.hipYCycleHysteresis * 0.5 { score += 2.0 }
            if hipYRange > config.hipYCycleHysteresis { score += 1.0 }
            if kneeRange > config.squatKneeThreshold { score += 1.0 }
            if hipRange > config.squatHipThreshold { score += 1.0 }
            if elbowRange < config.curlElbowThreshold { score += 0.5 }
            // Penalty if elbow motion dominates with no vertical movement
            if upperBodyMotion > lowerBodyMotion * 1.5 && hipYRange < config.hipYCycleHysteresis * 0.3 { score -= 1.5 }
            return max(0, score)
        }()

        // Curl signals — must have big elbow range AND minimal vertical hip movement
        let curlSignal: Double = {
            var score = 0.0
            if elbowRange > config.curlElbowThreshold { score += 1.5 }
            if wristYRange > 0.05 { score += 0.5 }
            if kneeRange < config.curlLegStillThreshold { score += 0.3 }
            if hipRange < config.curlLegStillThreshold { score += 0.3 }
            if spineMean > 140 { score += 0.3 }
            // Hard penalty: if body is moving up and down, it's not a curl
            if hipYRange > config.hipYCycleHysteresis * 0.5 { score -= 2.0 }
            // Penalty if lower body motion dominates
            if lowerBodyMotion > upperBodyMotion * 1.5 { score -= 1.0 }
            return max(0, score)
        }()

        // Accumulate evidence with decay
        squatEvidence = squatEvidence * config.evidenceDecay + squatSignal * config.evidencePerFrame
        curlEvidence = curlEvidence * config.evidenceDecay + curlSignal * config.evidencePerFrame

        // Count exercise-like cycles (use best of knee angle or hip Y for squats)
        let squatKneeCycles = window.countCycles(
            of: { $0.angles.kneeAngle },
            hysteresis: config.squatCycleHysteresis
        )
        let squatHipYCycles = window.countCycles(
            of: { $0.hipCenterY },
            hysteresis: config.hipYCycleHysteresis
        )
        squatReps = max(squatKneeCycles, squatHipYCycles)
        curlReps = window.countCycles(
            of: { $0.angles.elbowAngle },
            hysteresis: config.curlCycleHysteresis
        )

        // Log every ~10 ticks
        if tickCount % 10 == 0 {
            log.debug("""
                classify: sqEvidence=\(self.f(self.squatEvidence)) curlEvidence=\(self.f(self.curlEvidence)) \
                sqReps=\(self.squatReps) curlReps=\(self.curlReps) \
                knee=\(self.f(kneeRange)) hip=\(self.f(hipRange)) elbow=\(self.f(elbowRange)) \
                spine=\(self.f(spineMean)) hipY=\(self.f(hipYRange))
                """)
        }

        // Determine candidate
        let leadingExercise: ExerciseType?
        let leadingEvidence: Double
        let leadingReps: Int
        let trailingEvidence: Double

        if squatEvidence > curlEvidence {
            leadingExercise = .squat
            leadingEvidence = squatEvidence
            leadingReps = squatReps
            trailingEvidence = curlEvidence
        } else if curlEvidence > squatEvidence {
            leadingExercise = .curl
            leadingEvidence = curlEvidence
            leadingReps = curlReps
            trailingEvidence = squatEvidence
        } else {
            leadingExercise = nil
            leadingEvidence = 0
            leadingReps = 0
            trailingEvidence = 0
        }

        // State transitions
        if let exercise = leadingExercise {
            let margin = trailingEvidence > 0.1 ? leadingEvidence / trailingEvidence : leadingEvidence
            let hasEnoughReps = leadingReps >= config.lockMinReps
            let hasEnoughEvidence = leadingEvidence >= config.lockMinEvidence
            let hasClearMargin = margin >= config.lockMargin

            if hasEnoughReps && hasEnoughEvidence && hasClearMargin {
                // Lock!
                log.info("Locking \(exercise.rawValue): evidence=\(self.f(leadingEvidence)) margin=\(self.f(margin)) reps=\(leadingReps)")
                state = .locked(exercise)
                debugReason = "locked \(exercise.rawValue) (evidence=\(f(leadingEvidence)), reps=\(leadingReps))"
                repCounter = RepCounter(exercise: exercise)
                repCount = 0
                framesSinceLock = 0
                contradictionCounter = 0
                formEngine.reset()
                profile.captureStandingBaseline(features.angles)
            } else {
                state = .candidate(exercise)
                debugReason = "candidate \(exercise.rawValue): evidence=\(f(leadingEvidence)) margin=\(f(margin)) reps=\(leadingReps)"
                    + (!hasEnoughReps ? " (need \(config.lockMinReps) reps)" : "")
                    + (!hasEnoughEvidence ? " (need \(f(config.lockMinEvidence)) evidence)" : "")
                    + (!hasClearMargin ? " (need \(f(config.lockMargin))× margin)" : "")
            }
        } else {
            state = .unknown
            debugReason = "no clear leader"
        }
    }

    // MARK: - Locked exercise processing

    private func updateLockedExercise(features: PoseFeatures, exercise: ExerciseType) {
        let angles = features.angles

        // Phase detection
        currentPhase = detectPhase(angles: angles, exercise: exercise)

        // Rep counting
        if let counter = repCounter, let primaryAngle = primaryAngle(angles: angles, exercise: exercise) {
            let completed = counter.update(primaryAngle: primaryAngle)
            if completed {
                repCount = counter.repCount
                updateCalibrationFromRep()
                resetRepTracking()

                log.debug("Rep \(self.repCount) completed (phase: \(self.currentPhase))")
            }
        }

        // Track angles during rep for calibration
        trackRepAngles(angles)

        // Form feedback (only with sufficient confidence)
        formEngine.evaluate(
            features: features,
            exercise: exercise,
            phase: currentPhase,
            profile: profile
        )

        // Contradiction detection: if the OTHER exercise's signal dominates
        // for a long time, we might need to unlock.
        if framesSinceLock > 60 { // don't check for first 2 seconds
            checkForContradiction(features: features, lockedExercise: exercise)
        }
    }

    // MARK: - Phase detection

    private func detectPhase(angles: BodyAngles, exercise: ExerciseType) -> String {
        switch exercise {
        case .squat:
            let knee = angles.kneeAngle ?? 180
            if knee < 120 { return "bottom" }
            return "top"
        case .curl:
            let elbow = angles.elbowAngle ?? 180
            if elbow < 90 { return "top" }
            return "bottom"
        default:
            return "top"
        }
    }

    private func primaryAngle(angles: BodyAngles, exercise: ExerciseType) -> Double? {
        switch exercise {
        case .squat: return angles.kneeAngle
        case .curl: return angles.elbowAngle
        default: return nil
        }
    }

    // MARK: - Calibration

    private func trackRepAngles(_ angles: BodyAngles) {
        if let spine = angles.spine { repSpineAccum.append(spine) }

        if repMinAngles == nil {
            repMinAngles = angles
            repMaxAngles = angles
        } else {
            repMinAngles = minAngles(repMinAngles!, angles)
            repMaxAngles = maxAngles(repMaxAngles!, angles)
        }
    }

    private func updateCalibrationFromRep() {
        guard let minA = repMinAngles, let maxA = repMaxAngles else { return }
        let meanSpine = repSpineAccum.isEmpty ? nil : repSpineAccum.reduce(0, +) / Double(repSpineAccum.count)
        profile.updateFromRep(
            exercise: state.exercise,
            minAngles: minA,
            maxAngles: maxA,
            meanSpine: meanSpine
        )
    }

    private func resetRepTracking() {
        repMinAngles = nil
        repMaxAngles = nil
        repSpineAccum = []
    }

    private func minAngles(_ a: BodyAngles, _ b: BodyAngles) -> BodyAngles {
        BodyAngles(
            leftElbow: optMin(a.leftElbow, b.leftElbow),
            rightElbow: optMin(a.rightElbow, b.rightElbow),
            leftKnee: optMin(a.leftKnee, b.leftKnee),
            rightKnee: optMin(a.rightKnee, b.rightKnee),
            leftHip: optMin(a.leftHip, b.leftHip),
            rightHip: optMin(a.rightHip, b.rightHip),
            leftShoulder: optMin(a.leftShoulder, b.leftShoulder),
            rightShoulder: optMin(a.rightShoulder, b.rightShoulder),
            spine: optMin(a.spine, b.spine)
        )
    }

    private func maxAngles(_ a: BodyAngles, _ b: BodyAngles) -> BodyAngles {
        BodyAngles(
            leftElbow: optMax(a.leftElbow, b.leftElbow),
            rightElbow: optMax(a.rightElbow, b.rightElbow),
            leftKnee: optMax(a.leftKnee, b.leftKnee),
            rightKnee: optMax(a.rightKnee, b.rightKnee),
            leftHip: optMax(a.leftHip, b.leftHip),
            rightHip: optMax(a.rightHip, b.rightHip),
            leftShoulder: optMax(a.leftShoulder, b.leftShoulder),
            rightShoulder: optMax(a.rightShoulder, b.rightShoulder),
            spine: optMax(a.spine, b.spine)
        )
    }

    private func optMin(_ a: Double?, _ b: Double?) -> Double? {
        switch (a, b) {
        case let (a?, b?): return min(a, b)
        case let (a?, nil): return a
        case let (nil, b?): return b
        default: return nil
        }
    }

    private func optMax(_ a: Double?, _ b: Double?) -> Double? {
        switch (a, b) {
        case let (a?, b?): return max(a, b)
        case let (a?, nil): return a
        case let (nil, b?): return b
        default: return nil
        }
    }

    // MARK: - Contradiction detection (hysteresis for unlock)

    private func checkForContradiction(features: PoseFeatures, lockedExercise: ExerciseType) {
        let angles = features.angles
        let elbowRange = window.elbowRange ?? 0
        let kneeRange = window.kneeRange ?? 0
        let hipRange = window.hipRange ?? 0

        let isContradictory: Bool
        switch lockedExercise {
        case .squat:
            // Contradiction: elbow clearly dominates, legs are still
            isContradictory = elbowRange > 30 && kneeRange < 10 && hipRange < 10
        case .curl:
            // Contradiction: lower body clearly dominates
            isContradictory = (kneeRange + hipRange) > 30 && elbowRange < 10
        default:
            isContradictory = false
        }

        if isContradictory {
            contradictionCounter += 1
            if contradictionCounter >= config.unlockContradictionFrames {
                log.info("Unlocking \(lockedExercise.rawValue) after \(self.contradictionCounter) contradictory frames")
                reset()
            }
        } else {
            contradictionCounter = max(0, contradictionCounter - 2)
        }
    }

    // MARK: - Form result (compatibility with existing FeedbackScheduler)

    private func buildFormResult(features: PoseFeatures) -> FormResult {
        guard state.isLocked else { return .empty }

        // Use existing FormComparator for scoring (maintains compatibility with FeedbackScheduler).
        let result = comparator.evaluate(
            angles: features.angles,
            exercise: state.exercise,
            phase: currentPhase
        )

        // Merge FormFeedbackEngine issues into corrections if they add new info.
        var corrections = result.corrections
        for issue in formEngine.activeIssues {
            if !corrections.contains(where: { $0.message == issue.message }) {
                corrections.append(FormCorrection(
                    joint: issue.type,
                    message: issue.message,
                    severity: issue.severity
                ))
            }
        }

        return FormResult(
            score: result.score,
            corrections: corrections.sorted { $0.severity > $1.severity },
            phase: currentPhase
        )
    }

    // MARK: - Helpers

    private func f(_ v: Double) -> String { String(format: "%.1f", v) }
}
