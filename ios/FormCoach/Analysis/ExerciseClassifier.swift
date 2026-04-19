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
        case .pushup:   "pushup"
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

/// Real-time classifier restricted (for the demo) to squat, deadlift, or unknown.
///
/// Strategy:
///  - Maintain a ~0.7 s rolling window of angle samples + wrist-y travel.
///  - Each classification tick, extract signature features (spine uprightness,
///    knee vs hip motion range, wrist vertical sweep).
///  - Require `stickyWindows` consecutive matching windows before flipping
///    `detectedExercise` so the label doesn't flicker during transitions.
final class ExerciseClassifier: ObservableObject {
    @Published var detectedExercise: ExerciseType = .unknown
    /// True once the current label has been confirmed by the sticky filter.
    /// Useful for UI that wants to show a "Detecting..." state early on.
    @Published var isStable: Bool = false
    /// After the first locked exercise, recognition stops (no more `update` work).
    @Published private(set) var recognitionSuspended: Bool = false

    // MARK: - Tunables

    /// Window size in frames (~0.5 s at 30 fps).
    private let windowSize = 15
    /// Classify every N frames.
    private let classifyEvery = 5
    /// Consecutive windows that must agree before `detectedExercise` flips.
    private let stickyWindows = 2

    // MARK: - State

    private struct Sample {
        let angles: BodyAngles
        let wristY: CGFloat?      // mean of left/right wrist y (normalized 0-1)
        let hipY: CGFloat?        // mean hip y
    }

    private var samples: [Sample] = []
    private var frameCount = 0
    private var candidateLabel: ExerciseType = .unknown
    private var candidateStreak: Int = 0

    // MARK: - Public API

    /// Call once a stable exercise is chosen; classifier stops consuming frames.
    func suspendRecognition() {
        DispatchQueue.main.async {
            self.recognitionSuspended = true
        }
    }

    func update(angles: BodyAngles, pose: BodyPose) {
        guard !recognitionSuspended else { return }

        samples.append(Sample(
            angles: angles,
            wristY: meanY(pose.point(for: .leftWrist), pose.point(for: .rightWrist)),
            hipY:   meanY(pose.point(for: .leftHip),   pose.point(for: .rightHip))
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
        let wristYs   = samples.compactMap { $0.wristY }

        // Need enough data in the primary channels to say anything at all.
        guard kneeVals.count >= windowSize / 3,
              hipVals.count  >= windowSize / 3 else {
            return .unknown
        }

        let spineMean = spineVals.isEmpty ? 180.0 : spineVals.reduce(0, +) / Double(spineVals.count)
        let kneeRange = (kneeVals.max() ?? 0) - (kneeVals.min() ?? 0)
        let hipRange  = (hipVals.max()  ?? 0) - (hipVals.min()  ?? 0)
        let hipVsKnee = hipRange / max(kneeRange, 1)
        let wristYTravel: Double = {
            guard let mx = wristYs.max(), let mn = wristYs.min() else { return 0 }
            return Double(mx - mn)
        }()

        let elbowVals = samples.compactMap { $0.angles.elbowAngle }
        let elbowRange = (elbowVals.max() ?? 0) - (elbowVals.min() ?? 0)

        // Movement floor: require at least some joint motion so a still person
        // doesn't accidentally match. Kept deliberately loose.
        if kneeRange < 8 && hipRange < 8 && elbowRange < 8 {
            return .unknown
        }

        // Bicep curl: elbow flexion dominates; knees/hips stay relatively quiet vs squat/deadlift.
        let looksLikeCurl =
            elbowRange > 14 &&
            kneeRange < 28 &&
            hipRange < 32 &&
            spineMean > 115 &&
            elbowRange > kneeRange * 0.85

        if looksLikeCurl {
            return .curl
        }

        if kneeRange < 8 && hipRange < 8 {
            return .unknown
        }

        // Squat: upright torso, knee angle is the primary driver of the rep.
        // hipVsKnee < 2.0 allows for some hip movement (normal in a deep squat)
        // without requiring perfect isolation.
        let looksLikeSquat =
            spineMean > 135 &&
            kneeRange > 10 &&
            hipVsKnee < 2.0

        // Deadlift: hip hinge clearly dominates over knee. Wrist travel is a
        // soft signal only — unreliable at distance, so not required.
        let looksLikeDeadlift =
            hipRange > 10 &&
            hipVsKnee > 1.3

        switch (looksLikeSquat, looksLikeDeadlift) {
        case (true, false):  return .squat
        case (false, true):  return .deadlift
        case (true, true):
            // Both match — tie-break. Wrist travel helps when visible;
            // otherwise fall back to hip-vs-knee ratio.
            if wristYTravel > 0.07 { return .deadlift }
            return hipVsKnee > 1.7 ? .deadlift : .squat
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
