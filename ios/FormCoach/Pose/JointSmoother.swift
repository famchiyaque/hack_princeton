import Vision
import CoreGraphics

/// Applies Exponential Moving Average to reduce jitter in joint positions.
final class JointSmoother {
    private var smoothed: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    private let alpha: CGFloat = 0.3

    func smooth(_ raw: [VNHumanBodyPoseObservation.JointName: CGPoint])
        -> [VNHumanBodyPoseObservation.JointName: CGPoint]
    {
        for (joint, point) in raw {
            if let prev = smoothed[joint] {
                smoothed[joint] = CGPoint(
                    x: alpha * point.x + (1 - alpha) * prev.x,
                    y: alpha * point.y + (1 - alpha) * prev.y
                )
            } else {
                smoothed[joint] = point
            }
        }
        return smoothed
    }

    func reset() { smoothed.removeAll() }
}
