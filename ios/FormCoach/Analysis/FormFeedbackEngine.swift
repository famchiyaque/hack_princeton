import Foundation

/// A single form issue detected by the feedback engine.
struct FormIssue: Equatable {
    let type: String
    let severity: Double          // 0–1
    let confidence: Double        // 0–1, how sure we are this is real
    let exercise: ExerciseType
    let phase: String
    let message: String

    static func == (lhs: FormIssue, rhs: FormIssue) -> Bool {
        lhs.type == rhs.type && lhs.exercise == rhs.exercise
    }
}

/// Phase-aware form feedback engine.
/// Evaluates form only when the exercise is locked and confidence is high.
/// Uses persistence thresholds — a single bad frame is never flagged.
final class FormFeedbackEngine {

    // MARK: - Configuration

    struct Config {
        /// Frames an issue must persist before it's reported.
        var persistenceThreshold: Int = 8
        /// Minimum confidence to trust a form warning.
        var minConfidence: Float = 0.3
        /// Minimum severity to report.
        var minSeverity: Double = 0.25
        /// How fast persistence decays when the issue disappears (frames per tick).
        var decayRate: Int = 1
    }

    private let config: Config

    init(config: Config = Config()) {
        self.config = config
    }

    // MARK: - State

    /// Tracks how many consecutive frames each issue type has been observed.
    private var issueCounters: [String: Int] = [:]

    /// Currently active (persisted) issues.
    private(set) var activeIssues: [FormIssue] = []

    // MARK: - Public API

    /// Evaluate a single frame. Call every frame when exercise is locked.
    /// Returns the currently active form issues (only those that passed persistence).
    @discardableResult
    func evaluate(
        features: PoseFeatures,
        exercise: ExerciseType,
        phase: String,
        profile: CalibrationProfile
    ) -> [FormIssue] {
        guard features.avgConfidence >= config.minConfidence else {
            decayAll()
            return activeIssues
        }

        let candidates: [FormIssue]
        switch exercise {
        case .squat: candidates = evaluateSquat(features: features, phase: phase, profile: profile)
        case .curl:  candidates = evaluateCurl(features: features, phase: phase, profile: profile)
        default:     candidates = []
        }

        var seenTypes: Set<String> = []
        for issue in candidates where issue.severity >= config.minSeverity {
            seenTypes.insert(issue.type)
            issueCounters[issue.type, default: 0] += 1
        }

        // Decay counters for issues not seen this frame.
        for key in issueCounters.keys where !seenTypes.contains(key) {
            issueCounters[key] = max(0, (issueCounters[key] ?? 0) - config.decayRate)
            if issueCounters[key] == 0 { issueCounters.removeValue(forKey: key) }
        }

        // Build active issues from persisted counters.
        activeIssues = candidates.filter { issue in
            (issueCounters[issue.type] ?? 0) >= config.persistenceThreshold
        }

        return activeIssues
    }

    func reset() {
        issueCounters.removeAll()
        activeIssues.removeAll()
    }

    // MARK: - Squat rules

    private func evaluateSquat(features: PoseFeatures, phase: String, profile: CalibrationProfile) -> [FormIssue] {
        var issues: [FormIssue] = []
        let angles = features.angles

        // Spine: torso leaning too far forward.
        if let spine = angles.spine {
            let threshold = profile.typicalSquatSpineMean.map { $0 - 15 } ?? 140.0
            if spine < threshold {
                let dev = threshold - spine
                issues.append(FormIssue(
                    type: "squat_spine_lean",
                    severity: min(1, dev / 30),
                    confidence: Double(features.avgConfidence),
                    exercise: .squat,
                    phase: phase,
                    message: "Keep your chest up"
                ))
            }
        }

        // Depth: knees not bending enough at bottom.
        if phase == "bottom", let knee = angles.kneeAngle {
            let depthTarget = profile.typicalSquatKneeMin ?? 90.0
            let tolerance = 15.0
            if knee > depthTarget + tolerance {
                let dev = knee - (depthTarget + tolerance)
                issues.append(FormIssue(
                    type: "squat_depth",
                    severity: min(1, dev / 30),
                    confidence: Double(features.avgConfidence),
                    exercise: .squat,
                    phase: phase,
                    message: "Sink deeper"
                ))
            }
        }

        // Knee symmetry: one side collapsing.
        if let sym = features.kneeSymmetry, sym < 0.75 {
            issues.append(FormIssue(
                type: "squat_knee_asymmetry",
                severity: min(1, (0.75 - sym) / 0.3),
                confidence: Double(features.avgConfidence) * 0.8,
                exercise: .squat,
                phase: phase,
                message: "Keep your knees even"
            ))
        }

        // Hip not opening enough.
        if phase == "bottom", let hip = angles.hipAngle {
            let threshold = profile.typicalSquatHipMin ?? 85.0
            let tolerance = 15.0
            if hip > threshold + tolerance {
                let dev = hip - (threshold + tolerance)
                issues.append(FormIssue(
                    type: "squat_hip_open",
                    severity: min(1, dev / 30),
                    confidence: Double(features.avgConfidence),
                    exercise: .squat,
                    phase: phase,
                    message: "Open your hips more"
                ))
            }
        }

        return issues
    }

    // MARK: - Curl rules

    private func evaluateCurl(features: PoseFeatures, phase: String, profile: CalibrationProfile) -> [FormIssue] {
        var issues: [FormIssue] = []
        let angles = features.angles

        // Body swing: spine should stay upright during curls.
        if let spine = angles.spine {
            let threshold = profile.typicalCurlSpineMean.map { $0 - 15 } ?? 155.0
            if spine < threshold {
                let dev = threshold - spine
                issues.append(FormIssue(
                    type: "curl_body_swing",
                    severity: min(1, dev / 20),
                    confidence: Double(features.avgConfidence),
                    exercise: .curl,
                    phase: phase,
                    message: "Stop swinging — use your arms"
                ))
            }
        }

        // Incomplete ROM at top: elbow not closing enough.
        if phase == "top", let elbow = angles.elbowAngle {
            let target = profile.typicalCurlElbowMin ?? 50.0
            let tolerance = 15.0
            if elbow > target + tolerance {
                let dev = elbow - (target + tolerance)
                issues.append(FormIssue(
                    type: "curl_incomplete_top",
                    severity: min(1, dev / 30),
                    confidence: Double(features.avgConfidence),
                    exercise: .curl,
                    phase: phase,
                    message: "Curl higher"
                ))
            }
        }

        // Incomplete ROM at bottom: elbow not extending enough.
        if phase == "bottom", let elbow = angles.elbowAngle {
            let target = profile.typicalCurlElbowMax ?? 155.0
            let tolerance = 15.0
            if elbow < target - tolerance {
                let dev = (target - tolerance) - elbow
                issues.append(FormIssue(
                    type: "curl_incomplete_bottom",
                    severity: min(1, dev / 30),
                    confidence: Double(features.avgConfidence),
                    exercise: .curl,
                    phase: phase,
                    message: "Fully extend at the bottom"
                ))
            }
        }

        // Elbow drift: shoulder angle changing means upper arm is swinging.
        if let shoulder = angles.shoulderAngle, shoulder > 45 {
            let dev = shoulder - 45
            issues.append(FormIssue(
                type: "curl_elbow_drift",
                severity: min(1, dev / 30),
                confidence: Double(features.avgConfidence) * 0.7,
                exercise: .curl,
                phase: phase,
                message: "Keep your elbows pinned"
            ))
        }

        // Lower body compensating.
        if let knee = angles.kneeAngle, knee < 150 {
            issues.append(FormIssue(
                type: "curl_leg_drive",
                severity: min(1, (150 - knee) / 30),
                confidence: Double(features.avgConfidence) * 0.6,
                exercise: .curl,
                phase: phase,
                message: "Keep your legs still"
            ))
        }

        return issues
    }

    // MARK: - Private

    private func decayAll() {
        for key in issueCounters.keys {
            issueCounters[key] = max(0, (issueCounters[key] ?? 0) - config.decayRate)
            if issueCounters[key] == 0 { issueCounters.removeValue(forKey: key) }
        }
    }
}
