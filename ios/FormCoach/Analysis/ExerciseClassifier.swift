import Vision
import CoreGraphics

enum ExerciseType: String, CaseIterable, Identifiable, Codable {
    case pushup, squat, deadlift, plank, lunge, jumpingJacks = "jumping_jacks", curl, unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pushup:       "Push-Up"
        case .squat:        "Squat"
        case .deadlift:     "Deadlift"
        case .plank:        "Plank"
        case .lunge:        "Lunge"
        case .jumpingJacks: "Jumping Jacks"
        case .curl:         "Bicep Curl"
        case .unknown:      "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .pushup:       "figure.strengthtraining.traditional"
        case .squat:        "figure.cooldown"
        case .deadlift:     "figure.strengthtraining.functional"
        case .plank:        "figure.core.training"
        case .lunge:        "figure.step.training"
        case .jumpingJacks: "figure.mixed.cardio"
        case .curl:         "dumbbell.fill"
        case .unknown:      "questionmark"
        }
    }

    var assetName: String? {
        switch self {
        case .squat:    "squat"
        case .deadlift: "deadlift"
        case .curl:     "bicep_curl"
        default:        nil
        }
    }

    /// Thresholds used by the RepCounter for this exercise.
    var downThreshold: Double {
        switch self {
        case .pushup:       100  // elbow
        case .squat, .lunge: 100 // knee
        case .deadlift:     110  // hip
        case .curl:         60   // elbow (top of curl)
        case .jumpingJacks: 40   // shoulder (closed)
        case .plank, .unknown: 90
        }
    }

    var upThreshold: Double {
        switch self {
        case .pushup, .squat, .lunge, .deadlift: 155
        case .curl:         150
        case .jumpingJacks: 150
        case .plank, .unknown: 90
        }
    }
}

/// Real-time classifier for squat, deadlift, and bicep curl.
///
/// Strategy:
///  - Rolling window of ~0.5 s of pose samples.
///  - Each tick, extract biomechanical signatures for each exercise.
///  - Curl check runs first (wrist travel + stable elbows beats everything).
///  - Squat vs deadlift uses a multi-feature confidence score: hip hinge ratio,
///    spine forward-lean, hip vertical travel, and wrist bar-path travel.
///  - `stickyWindows` consecutive matching results required before confirming.
///  - `suspendRecognition()` halts classification once an exercise is locked.
final class ExerciseClassifier: ObservableObject {
    @Published var detectedExercise: ExerciseType = .unknown
    @Published var isStable: Bool = false
    /// Set after the first lock; `update()` becomes a no-op until `reset()`.
    @Published private(set) var recognitionSuspended: Bool = false

    // MARK: - Tunables

    private let windowSize    = 15   // ~0.5 s at 30 fps
    private let classifyEvery = 5
    private let stickyWindows = 2

    // MARK: - State

    private struct Sample {
        let angles: BodyAngles
        let wristY: CGFloat?   // mean wrist y (Vision 0-1, 0 = bottom)
        let elbowY: CGFloat?   // mean elbow y — stable during curl
        let elbowX: CGFloat?   // mean elbow x — stable during curl (no lateral drift)
        let hipY:   CGFloat?   // mean hip y — travels during deadlift
    }

    private var samples: [Sample] = []
    private var frameCount = 0
    private var candidateLabel: ExerciseType = .unknown
    private var candidateStreak: Int = 0

    // MARK: - Public API

    func suspendRecognition() {
        DispatchQueue.main.async { self.recognitionSuspended = true }
    }

    func update(angles: BodyAngles, pose: BodyPose) {
        guard !recognitionSuspended else { return }

        func meanY(_ a: CGPoint?, _ b: CGPoint?) -> CGFloat? {
            switch (a, b) {
            case let (l?, r?): return (l.y + r.y) / 2
            case let (l?, nil): return l.y
            case let (nil, r?): return r.y
            default: return nil
            }
        }
        func meanX(_ a: CGPoint?, _ b: CGPoint?) -> CGFloat? {
            switch (a, b) {
            case let (l?, r?): return (l.x + r.x) / 2
            case let (l?, nil): return l.x
            case let (nil, r?): return r.x
            default: return nil
            }
        }

        samples.append(Sample(
            angles: angles,
            wristY: meanY(pose.point(for: .leftWrist),  pose.point(for: .rightWrist)),
            elbowY: meanY(pose.point(for: .leftElbow),  pose.point(for: .rightElbow)),
            elbowX: meanX(pose.point(for: .leftElbow),  pose.point(for: .rightElbow)),
            hipY:   meanY(pose.point(for: .leftHip),    pose.point(for: .rightHip))
        ))
        if samples.count > windowSize { samples.removeFirst(samples.count - windowSize) }

        frameCount += 1
        guard frameCount % classifyEvery == 0, samples.count >= windowSize else { return }

        let raw = classifyWindow()
        if raw == candidateLabel {
            candidateStreak += 1
        } else {
            candidateLabel = raw
            candidateStreak = 1
        }

        guard candidateStreak >= stickyWindows else { return }

        if candidateLabel != detectedExercise {
            DispatchQueue.main.async {
                self.detectedExercise = self.candidateLabel
                self.isStable = true
            }
        } else if !isStable {
            DispatchQueue.main.async { self.isStable = true }
        }
    }

    func reset() {
        samples.removeAll()
        frameCount = 0
        candidateLabel = .unknown
        candidateStreak = 0
        DispatchQueue.main.async {
            self.detectedExercise = .unknown
            self.isStable = false
            self.recognitionSuspended = false
        }
    }

    // MARK: - Feature extraction

    private func classifyWindow() -> ExerciseType {
        let spineVals = samples.compactMap { $0.angles.spine }
        let kneeVals  = samples.compactMap { $0.angles.kneeAngle }
        let hipVals   = samples.compactMap { $0.angles.hipAngle }
        let elbowVals = samples.compactMap { $0.angles.elbowAngle }
        let wristYs   = samples.compactMap { $0.wristY }
        let elbowYs   = samples.compactMap { $0.elbowY }
        let elbowXs   = samples.compactMap { $0.elbowX }
        let hipYs     = samples.compactMap { $0.hipY }

        guard kneeVals.count >= windowSize / 3,
              hipVals.count  >= windowSize / 3 else { return .unknown }

        // ── Derived features ──────────────────────────────────────────────────

        let spineMean  = spineVals.isEmpty ? 180.0 : spineVals.reduce(0,+) / Double(spineVals.count)
        let spineMin   = spineVals.isEmpty ? 180.0 : Double(spineVals.min() ?? 180)
        let kneeRange  = Double((kneeVals.max() ?? 0) - (kneeVals.min() ?? 0))
        let hipRange   = Double((hipVals.max()  ?? 0) - (hipVals.min()  ?? 0))
        let elbowRange = Double((elbowVals.max() ?? 0) - (elbowVals.min() ?? 0))
        let hipVsKnee  = hipRange / max(kneeRange, 1)

        func travel(_ vals: [CGFloat]) -> Double {
            guard let mx = vals.max(), let mn = vals.min() else { return 0 }
            return Double(mx - mn)
        }
        let wristYTravel = travel(wristYs)
        let elbowYTravel = travel(elbowYs)
        let elbowXTravel = travel(elbowXs)
        let hipYTravel   = travel(hipYs)

        // Global movement floor — still person should never match.
        guard kneeRange > 6 || hipRange > 6 || elbowRange > 6 || wristYTravel > 0.04 else {
            return .unknown
        }

        // ── CURL — check first ────────────────────────────────────────────────
        // Primary signal: wrists travel vertically while elbows stay put.
        // Stable elbow Y  → upper arm pinned (not a row/press).
        // Stable elbow X  → elbows not flaring out (distinguishes from JJ / overhead).
        // Low knee/hip    → body not doing a compound lift.
        let looksLikeCurl =
            wristYTravel > 0.06 &&       // wrists visibly moving up/down
            elbowYTravel < 0.07 &&       // elbows staying at roughly the same height
            elbowXTravel < 0.06 &&       // elbows not drifting laterally
            kneeRange    < 22  &&        // legs mostly still
            hipRange     < 24  &&        // hips mostly still
            spineMean    > 115           // somewhat upright

        if looksLikeCurl { return .curl }

        // ── Need knee or hip motion for squat / deadlift ─────────────────────
        guard kneeRange > 8 || hipRange > 8 else { return .unknown }

        // ── SQUAT — biomechanical signature ──────────────────────────────────
        // • Knee flexion drives the rep (kneeRange is the dominant joint motion).
        // • Torso stays upright throughout — high spineMean AND high spineMin.
        // • Hip descends because knees flex, not because of a deliberate hinge
        //   → hipVsKnee < 1.8 (hips and knees move together, knee slightly more).
        // • Knee range is at least 60% of hip range (squats are knee-dominant).
        let squatScore: Double = {
            var s = 0.0
            if spineMean > 145           { s += 3.0 }  // upright torso throughout
            else if spineMean > 130      { s += 1.5 }
            if spineMin > 128            { s += 2.0 }  // never leans far forward
            if kneeRange > 15            { s += 2.0 }  // significant knee drive
            if hipVsKnee < 1.6           { s += 2.5 }  // knee and hip move together
            if kneeRange > hipRange * 0.6 { s += 1.5 } // knee is dominant joint
            if hipYTravel < 0.12         { s += 1.0 }  // hips don't travel far vertically
            return s
        }()

        // ── DEADLIFT — biomechanical signature ───────────────────────────────
        // • Hip hinge clearly dominates (hipVsKnee > 1.6).
        // • Torso tilts forward at the bottom — spineMin drops.
        // • Hips travel vertically (bar comes off the floor).
        // • Wrists (bar) travel noticeably up/down.
        // • Knee bends but much less than in a squat.
        let deadliftScore: Double = {
            var s = 0.0
            if hipVsKnee > 2.0           { s += 3.5 }  // strong hip hinge
            else if hipVsKnee > 1.6      { s += 2.0 }
            if spineMin < 150            { s += 2.5 }  // forward lean at bottom
            else if spineMin < 162       { s += 1.0 }
            if hipYTravel > 0.07         { s += 2.5 }  // hips travel vertically
            else if hipYTravel > 0.04    { s += 1.0 }
            if wristYTravel > 0.07       { s += 2.0 }  // bar travels vertically
            else if wristYTravel > 0.04  { s += 1.0 }
            if hipRange > 18             { s += 1.5 }  // large hip range
            return s
        }()

        // Require a minimum score before committing to either exercise.
        let minScore = 4.5
        switch (squatScore >= minScore, deadliftScore >= minScore) {
        case (true, false):  return .squat
        case (false, true):  return .deadlift
        case (true, true):   return squatScore >= deadliftScore ? .squat : .deadlift
        default:             return .unknown
        }
    }
}
