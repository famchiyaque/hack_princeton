import Foundation

/// Per-user movement profile learned during a session.
/// Stores typical ranges and proportions so form feedback can adapt
/// to individual body types and flexibility rather than using
/// one-size-fits-all thresholds.
struct CalibrationProfile {

    // Body proportions (updated from early frames).
    var typicalTorsoLength: Double?
    var typicalShoulderWidth: Double?

    // Per-exercise ROM (updated after first few good reps).
    var typicalSquatKneeMin: Double?
    var typicalSquatKneeMax: Double?
    var typicalSquatHipMin: Double?
    var typicalSquatHipMax: Double?
    var typicalSquatSpineMean: Double?

    var typicalCurlElbowMin: Double?
    var typicalCurlElbowMax: Double?
    var typicalCurlSpineMean: Double?

    // Standing baseline angles (captured before first rep).
    var standingKneeAngle: Double?
    var standingHipAngle: Double?
    var standingElbowAngle: Double?
    var standingSpineAngle: Double?

    // Camera perspective hint.
    var isSideView: Bool = false

    /// Number of calibration samples collected.
    var sampleCount: Int = 0

    var isCalibrated: Bool { sampleCount >= 3 }

    // MARK: - Update

    /// Call once per completed rep with the angles observed during that rep.
    mutating func updateFromRep(
        exercise: ExerciseType,
        minAngles: BodyAngles,
        maxAngles: BodyAngles,
        meanSpine: Double?
    ) {
        sampleCount += 1
        let alpha = 1.0 / Double(sampleCount)

        switch exercise {
        case .squat:
            typicalSquatKneeMin = ema(typicalSquatKneeMin, minAngles.kneeAngle, alpha)
            typicalSquatKneeMax = ema(typicalSquatKneeMax, maxAngles.kneeAngle, alpha)
            typicalSquatHipMin = ema(typicalSquatHipMin, minAngles.hipAngle, alpha)
            typicalSquatHipMax = ema(typicalSquatHipMax, maxAngles.hipAngle, alpha)
            typicalSquatSpineMean = ema(typicalSquatSpineMean, meanSpine, alpha)
        case .curl:
            typicalCurlElbowMin = ema(typicalCurlElbowMin, minAngles.elbowAngle, alpha)
            typicalCurlElbowMax = ema(typicalCurlElbowMax, maxAngles.elbowAngle, alpha)
            typicalCurlSpineMean = ema(typicalCurlSpineMean, meanSpine, alpha)
        default:
            break
        }
    }

    mutating func updateBodyProportions(torso: Double?, shoulders: Double?) {
        if sampleCount == 0 {
            typicalTorsoLength = torso
            typicalShoulderWidth = shoulders
        } else {
            let alpha = 0.1
            typicalTorsoLength = ema(typicalTorsoLength, torso, alpha)
            typicalShoulderWidth = ema(typicalShoulderWidth, shoulders, alpha)
        }
    }

    mutating func captureStandingBaseline(_ angles: BodyAngles) {
        standingKneeAngle = angles.kneeAngle
        standingHipAngle = angles.hipAngle
        standingElbowAngle = angles.elbowAngle
        standingSpineAngle = angles.spine
    }

    // MARK: - Private

    private func ema(_ current: Double?, _ new: Double?, _ alpha: Double) -> Double? {
        guard let n = new else { return current }
        guard let c = current else { return n }
        return c * (1 - alpha) + n * alpha
    }
}
