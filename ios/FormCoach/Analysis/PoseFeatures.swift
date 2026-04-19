import CoreGraphics
import Vision

/// Body-relative features extracted from a single pose frame.
/// All positional measurements are normalized by body size references
/// (torso length or shoulder width) so classification and form feedback
/// are independent of camera distance and user height.
struct PoseFeatures {
    let timestamp: TimeInterval
    let angles: BodyAngles

    // Body-relative vertical positions (normalized by torso length).
    // In Vision coordinates Y increases upward.
    let hipCenterY: Double?
    let leftWristY: Double?
    let rightWristY: Double?

    // Wrist-to-shoulder distance normalized by torso length.
    let wristToShoulderDistLeft: Double?
    let wristToShoulderDistRight: Double?

    // Body size references (raw Vision-normalized units).
    let torsoLength: Double?
    let shoulderWidth: Double?

    // Confidence
    let avgConfidence: Float
    let jointCount: Int

    // MARK: - Convenience composites

    var wristY: Double? { Self.mean(leftWristY, rightWristY) }
    var wristToShoulderDist: Double? { Self.mean(wristToShoulderDistLeft, wristToShoulderDistRight) }

    var kneeSymmetry: Double? {
        guard let l = angles.leftKnee, let r = angles.rightKnee else { return nil }
        return 1.0 - abs(l - r) / max(abs(l), abs(r), 1)
    }

    var elbowSymmetry: Double? {
        guard let l = angles.leftElbow, let r = angles.rightElbow else { return nil }
        return 1.0 - abs(l - r) / max(abs(l), abs(r), 1)
    }

    var hipSymmetry: Double? {
        guard let l = angles.leftHip, let r = angles.rightHip else { return nil }
        return 1.0 - abs(l - r) / max(abs(l), abs(r), 1)
    }

    // MARK: - Extraction

    static func extract(from pose: BodyPose) -> PoseFeatures {
        let angles = BodyAngles.from(pose: pose)

        let ls = pose.point(for: .leftShoulder)
        let rs = pose.point(for: .rightShoulder)
        let neck = pose.point(for: .neck)
        let root = pose.point(for: .root)
        let lh = pose.point(for: .leftHip)
        let rh = pose.point(for: .rightHip)
        let lw = pose.point(for: .leftWrist)
        let rw = pose.point(for: .rightWrist)

        let shoulderWidth = dist(ls, rs)

        let torsoLength: Double? = {
            guard let n = neck, let r = root else { return nil }
            return Double(hypot(n.x - r.x, n.y - r.y))
        }()

        let tl = (torsoLength ?? 0) > 0.01 ? torsoLength! : nil

        let hipCenterY: Double? = {
            let hc = midpoint(lh, rh)
            guard let p = hc else { return nil }
            return tl != nil ? Double(p.y) / tl! : Double(p.y)
        }()

        func normY(_ p: CGPoint?) -> Double? {
            guard let p else { return nil }
            return tl != nil ? Double(p.y) / tl! : Double(p.y)
        }

        func wristShoulderDist(_ wrist: CGPoint?, _ shoulder: CGPoint?) -> Double? {
            guard let d = dist(wrist, shoulder) else { return nil }
            return tl != nil ? d / tl! : d
        }

        let confs = Array(pose.confidences.values)
        let avg = confs.isEmpty ? 0 : confs.reduce(0, +) / Float(confs.count)

        return PoseFeatures(
            timestamp: pose.timestamp,
            angles: angles,
            hipCenterY: hipCenterY,
            leftWristY: normY(lw),
            rightWristY: normY(rw),
            wristToShoulderDistLeft: wristShoulderDist(lw, ls),
            wristToShoulderDistRight: wristShoulderDist(rw, rs),
            torsoLength: torsoLength,
            shoulderWidth: shoulderWidth,
            avgConfidence: avg,
            jointCount: pose.joints.count
        )
    }

    // MARK: - Helpers

    private static func dist(_ a: CGPoint?, _ b: CGPoint?) -> Double? {
        guard let a, let b else { return nil }
        return Double(hypot(a.x - b.x, a.y - b.y))
    }

    private static func midpoint(_ a: CGPoint?, _ b: CGPoint?) -> CGPoint? {
        switch (a, b) {
        case let (a?, b?): return CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        case let (a?, nil): return a
        case let (nil, b?): return b
        default: return nil
        }
    }

    static func mean(_ a: Double?, _ b: Double?) -> Double? {
        switch (a, b) {
        case let (l?, r?): return (l + r) / 2
        case let (l?, nil): return l
        case let (nil, r?): return r
        default: return nil
        }
    }
}
