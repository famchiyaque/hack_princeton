import Foundation

enum PositionState: Equatable {
    case waiting     // not close to start position yet
    case approaching // trending toward correct position, not stable
    case locked      // held correct position for required frames
}

/// Detects whether the user is in the correct starting (top) position for an exercise
/// before rep counting begins.
///
/// Uses `FormComparator.reference[exercise]["top"]` with `tolerance` degrees of extra
/// headroom as the definition of a valid start position. Requires `requiredFrames`
/// consecutive in-position frames to transition to `.locked`. Frame count decays (−2)
/// when out of position rather than snapping to zero, so minor wobble doesn't break
/// an otherwise good setup.
struct StartingPositionDetector {

    // MARK: - Tunables

    /// ~20 frames at 30 fps ≈ 0.67 s of sustained good position before lock.
    private let requiredFrames = 20
    /// Extra degrees of headroom applied to the lower bound of each reference range.
    /// Keeps the gate achievable without requiring textbook-perfect posture.
    private let tolerance = 15.0
    /// Fraction of checked joints that must be in range before a frame counts.
    private let passingThreshold = 0.75

    // MARK: - State

    private(set) var state: PositionState = .waiting
    /// The `BodyAngles` snapshot captured the moment the detector first locked.
    /// Available for downstream use as a per-user baseline.
    private(set) var lockedAngles: BodyAngles? = nil
    private var framesInPosition = 0

    // MARK: - Public API

    mutating func reset() {
        state = .waiting
        lockedAngles = nil
        framesInPosition = 0
    }

    @discardableResult
    mutating func update(angles: BodyAngles, exercise: ExerciseType) -> PositionState {
        guard exercise != .unknown else {
            framesInPosition = max(0, framesInPosition - 2)
            if framesInPosition == 0 { state = .waiting }
            return state
        }

        if isInStartPosition(angles: angles, exercise: exercise) {
            framesInPosition = min(framesInPosition + 1, requiredFrames)
        } else {
            framesInPosition = max(0, framesInPosition - 2)
        }

        // Once locked, stay locked until reset() is called.
        if state == .locked { return .locked }

        if framesInPosition >= requiredFrames {
            state = .locked
            lockedAngles = angles
        } else if framesInPosition > requiredFrames / 3 {
            state = .approaching
        } else {
            state = .waiting
        }
        return state
    }

    // MARK: - Private

    private func isInStartPosition(angles: BodyAngles, exercise: ExerciseType) -> Bool {
        guard let topRef = FormComparator.reference[exercise]?[exercise.startPositionPhase] else { return false }

        var checks = 0
        var passed = 0

        func check(_ angle: Double?, range: AngleRange?) {
            guard let angle, let range else { return }
            checks += 1
            if angle >= (range.min - tolerance) && angle <= (range.max + tolerance) {
                passed += 1
            }
        }

        check(angles.elbowAngle,    range: topRef.elbowAngle)
        check(angles.kneeAngle,     range: topRef.kneeAngle)
        check(angles.hipAngle,      range: topRef.hipAngle)
        check(angles.spine,         range: topRef.spineAngle)
        check(angles.shoulderAngle, range: topRef.shoulderAngle)

        guard checks >= 2 else { return false }
        return Double(passed) / Double(checks) >= passingThreshold
    }
}

// MARK: - Per-exercise extensions

extension ExerciseType {
    /// Which FormComparator phase key represents the correct starting position.
    /// - curl: "bottom" (arms extended) — "top" means arm curled up, which is wrong
    /// - jumpingJacks: "closed" (neutral stance) — no "top" key exists
    /// - plank: "hold" — only phase available
    /// - all others: "top" (standing/extended)
    var startPositionPhase: String {
        switch self {
        case .curl:         return "bottom"
        case .jumpingJacks: return "closed"
        case .plank:        return "hold"
        default:            return "top"
        }
    }

    /// Prompt shown in the coach bubble while the user hasn't yet locked into position.
    var startingPositionCue: String {
        switch self {
        case .squat:        "Stand tall, feet shoulder-width apart"
        case .deadlift:     "Stand tall, hip-width stance"
        case .pushup:       "Get into a high plank, arms fully extended"
        case .plank:        "Get into forearm plank position"
        case .lunge:        "Stand tall, feet hip-width apart"
        case .jumpingJacks: "Stand straight, arms at your sides"
        case .curl:         "Stand tall, arms extended at sides"
        case .unknown:      "Get into starting position"
        }
    }
}

