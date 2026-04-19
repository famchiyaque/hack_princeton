import CoreGraphics
import Vision

/// Tracks lateral drift of elbows relative to shoulders (normalized Vision space).
/// Used for bicep curl: excessive movement triggers a red joint cue.
struct ElbowStabilityTracker {
    private var emaLeft: CGFloat?
    private var emaRight: CGFloat?
    private let alpha: CGFloat = 0.12
    /// Max deviation from smoothed offset before we flag instability (tuned for ~480p–1080p normalized coords).
    private let driftThreshold: CGFloat = 0.042

    mutating func reset() {
        emaLeft = nil
        emaRight = nil
    }

    /// Returns per-arm stability; `false` means that elbow is moving too much laterally.
    mutating func update(pose: BodyPose) -> (leftOK: Bool, rightOK: Bool) {
        guard let ls = pose.point(for: .leftShoulder), let le = pose.point(for: .leftElbow),
              let rs = pose.point(for: .rightShoulder), let re = pose.point(for: .rightElbow) else {
            // Missing keypoints — don't treat as unstable (avoids red flash off-camera).
            return (true, true)
        }
        let offL = le.x - ls.x
        let offR = re.x - rs.x

        if emaLeft == nil {
            emaLeft = offL
            emaRight = offR
            return (true, true)
        }

        emaLeft = emaLeft! * (1 - alpha) + offL * alpha
        emaRight = emaRight! * (1 - alpha) + offR * alpha

        let leftOK = abs(offL - emaLeft!) < driftThreshold
        let rightOK = abs(offR - emaRight!) < driftThreshold
        return (leftOK, rightOK)
    }
}
