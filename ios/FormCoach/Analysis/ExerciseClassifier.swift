import Vision
import CoreGraphics
import os

private let log = Logger(subsystem: "com.formcoach", category: "Classifier")

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

/// Real-time classifier for squat and bicep curl.
///
/// Strategy:
///  - Maintain a ~0.5 s rolling window of angle samples.
///  - Extract signature features: elbow range (curls), knee range (squats),
///    spine uprightness, and hip range.
///  - Require `stickyWindows` consecutive matching windows before flipping
///    `detectedExercise` so the label doesn't flicker during transitions.
///  - After 2 confirmed reps, lock the classification so it never flips mid-set.
final class ExerciseClassifier: ObservableObject {
    @Published var detectedExercise: ExerciseType = .unknown
    @Published var isStable: Bool = false

    // MARK: - Tunables

    /// ~2 seconds at 30 fps — enough to capture a full rep.
    private let windowSize = 60
    private let classifyEvery = 10
    private let stickyWindows = 2

    // MARK: - State

    private struct Sample {
        let angles: BodyAngles
    }

    private var samples: [Sample] = []
    private var frameCount = 0
    private var candidateLabel: ExerciseType = .unknown
    private var candidateStreak: Int = 0
    private var isLocked = false

    // MARK: - Public API

    func update(angles: BodyAngles, pose: BodyPose) {
        guard !isLocked else { return }

        samples.append(Sample(angles: angles))
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

    func lockClassification() {
        isLocked = true
    }

    func unlock() {
        isLocked = false
    }

    func reset() {
        samples.removeAll()
        frameCount = 0
        candidateLabel = .unknown
        candidateStreak = 0
        isLocked = false
        DispatchQueue.main.async {
            self.detectedExercise = .unknown
            self.isStable = false
        }
    }

    // MARK: - Classification

    private func classifyWindow() -> ExerciseType {
        let kneeVals  = samples.compactMap { $0.angles.kneeAngle }
        let hipVals   = samples.compactMap { $0.angles.hipAngle }
        let elbowVals = samples.compactMap { $0.angles.elbowAngle }
        let spineVals = samples.compactMap { $0.angles.spine }

        let minSamples = windowSize / 4
        guard kneeVals.count >= minSamples || elbowVals.count >= minSamples else {
            return .unknown
        }

        let kneeRange  = (kneeVals.max() ?? 0) - (kneeVals.min() ?? 0)
        let hipRange   = (hipVals.max()  ?? 0) - (hipVals.min()  ?? 0)
        let elbowRange = (elbowVals.max() ?? 0) - (elbowVals.min() ?? 0)
        let spineMean  = spineVals.isEmpty ? 180.0 : spineVals.reduce(0, +) / Double(spineVals.count)

        log.debug("classify: elbow=\(String(format:"%.0f", elbowRange)) knee=\(String(format:"%.0f", kneeRange)) hip=\(String(format:"%.0f", hipRange)) spine=\(String(format:"%.0f", spineMean))")

        // Movement floor — person must be moving something.
        if kneeRange < 5 && elbowRange < 5 { return .unknown }

        // Curl: elbow-dominant, legs still.
        let looksLikeCurl =
            elbowRange > 20 &&
            kneeRange < 20 &&
            hipRange < 20

        // Squat: significant knee or hip motion, upright torso.
        let looksLikeSquat =
            (kneeRange > 10 || hipRange > 10) &&
            spineMean > 120

        log.debug("  curl=\(looksLikeCurl) squat=\(looksLikeSquat)")

        // Lower-body motion = knee + hip combined.
        let lowerBodyRange = kneeRange + hipRange

        switch (looksLikeCurl, looksLikeSquat) {
        case (true, false):  return .curl
        case (false, true):  return .squat
        case (true, true):
            return elbowRange > lowerBodyRange ? .curl : .squat
        default:             return .unknown
        }
    }

    private func meanY(_ a: CGPoint?, _ b: CGPoint?) -> CGFloat? {
        switch (a, b) {
        case let (l?, r?): return (l.y + r.y) / 2
        case let (l?, nil): return l.y
        case let (nil, r?): return r.y
        default: return nil
        }
    }
}
