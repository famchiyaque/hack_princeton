import Vision
import CoreGraphics
import QuartzCore

/// Applies EMA smoothing to joint positions, with:
///  - confidence gating (low-confidence joints are ignored, not blended)
///  - outlier rejection (large per-frame jumps are dropped as phantom detections)
///  - TTL eviction (joints not seen for `staleAfter` seconds are forgotten)
final class JointSmoother {
    private struct Entry {
        var point: CGPoint
        var lastUpdated: TimeInterval
    }

    private var entries: [VNHumanBodyPoseObservation.JointName: Entry] = [:]

    /// EMA weight on the new sample. Higher = faster response, less smoothing.
    private let alpha: CGFloat = 0.5
    /// Minimum confidence required to accept a joint sample.
    private let minConfidence: Float = 0.5
    /// Max allowed per-frame jump in normalized (0-1) coords. Beyond this, sample is rejected.
    private let maxJump: CGFloat = 0.18
    /// Drop cached joints that haven't been updated within this window.
    private let staleAfter: TimeInterval = 0.3

    func smooth(
        raw: [VNHumanBodyPoseObservation.JointName: CGPoint],
        confidences: [VNHumanBodyPoseObservation.JointName: Float]
    ) -> [VNHumanBodyPoseObservation.JointName: CGPoint] {

        let now = CACurrentMediaTime()

        for (joint, point) in raw {
            guard let conf = confidences[joint], conf >= minConfidence else { continue }

            if let prev = entries[joint] {
                let dx = point.x - prev.point.x
                let dy = point.y - prev.point.y
                let dist = sqrt(dx * dx + dy * dy)
                if dist > maxJump {
                    // Treat as phantom — keep the previous smoothed position, but refresh timestamp
                    // so we don't immediately evict a real-but-temporarily-noisy joint.
                    entries[joint] = Entry(point: prev.point, lastUpdated: now)
                    continue
                }
                let blended = CGPoint(
                    x: alpha * point.x + (1 - alpha) * prev.point.x,
                    y: alpha * point.y + (1 - alpha) * prev.point.y
                )
                entries[joint] = Entry(point: blended, lastUpdated: now)
            } else {
                entries[joint] = Entry(point: point, lastUpdated: now)
            }
        }

        // Evict stale joints (lost by Vision long enough ago that caching them is misleading).
        for (joint, entry) in entries where now - entry.lastUpdated > staleAfter {
            entries.removeValue(forKey: joint)
        }

        return entries.mapValues { $0.point }
    }

    func reset() { entries.removeAll() }
}
