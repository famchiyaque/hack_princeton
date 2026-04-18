import CoreGraphics
import Vision

enum AngleCalculator {
    /// Returns the angle in degrees (0–180) at the `vertex` joint.
    static func angle(between a: CGPoint, vertex b: CGPoint, and c: CGPoint) -> Double {
        let ba = CGPoint(x: a.x - b.x, y: a.y - b.y)
        let bc = CGPoint(x: c.x - b.x, y: c.y - b.y)
        let dot = ba.x * bc.x + ba.y * bc.y
        let magBA = sqrt(ba.x * ba.x + ba.y * ba.y)
        let magBC = sqrt(bc.x * bc.x + bc.y * bc.y)
        guard magBA > 0, magBC > 0 else { return 0 }
        let cos = max(-1, min(1, Double(dot / (magBA * magBC))))
        return acos(cos) * 180 / .pi
    }
}

// MARK: - Body angles derived from a BodyPose

struct BodyAngles {
    let leftElbow: Double?
    let rightElbow: Double?
    let leftKnee: Double?
    let rightKnee: Double?
    let leftHip: Double?
    let rightHip: Double?
    let leftShoulder: Double?
    let rightShoulder: Double?
    let spine: Double?

    var elbowAngle: Double? { mean(leftElbow, rightElbow) }
    var hipAngle: Double?   { mean(leftHip, rightHip) }
    /// Shoulder angle — angle between torso and upper arm. Used for jumping jacks, curls.
    var shoulderAngle: Double? { mean(leftShoulder, rightShoulder) }

    /// For squats/lunges we care about the deepest knee bend → use minimum.
    var kneeAngle: Double? {
        switch (leftKnee, rightKnee) {
        case let (l?, r?): return min(l, r)
        case let (l?, nil): return l
        case let (nil, r?): return r
        default: return nil
        }
    }

    private func mean(_ a: Double?, _ b: Double?) -> Double? {
        switch (a, b) {
        case let (l?, r?): return (l + r) / 2
        case let (l?, nil): return l
        case let (nil, r?): return r
        default: return nil
        }
    }

    static func from(pose: BodyPose) -> BodyAngles {
        func p(_ j: VNHumanBodyPoseObservation.JointName) -> CGPoint? { pose.point(for: j) }

        func angleAt(_ a: VNHumanBodyPoseObservation.JointName,
                     _ b: VNHumanBodyPoseObservation.JointName,
                     _ c: VNHumanBodyPoseObservation.JointName) -> Double? {
            guard let pa = p(a), let pb = p(b), let pc = p(c) else { return nil }
            return AngleCalculator.angle(between: pa, vertex: pb, and: pc)
        }

        let spine: Double? = {
            let shoulder = p(.leftShoulder) ?? p(.rightShoulder)
            guard let neck = p(.neck), let s = shoulder, let hip = p(.root) else { return nil }
            return AngleCalculator.angle(between: neck, vertex: s, and: hip)
        }()

        return BodyAngles(
            leftElbow:     angleAt(.leftShoulder,  .leftElbow,  .leftWrist),
            rightElbow:    angleAt(.rightShoulder, .rightElbow, .rightWrist),
            leftKnee:      angleAt(.leftHip,       .leftKnee,   .leftAnkle),
            rightKnee:     angleAt(.rightHip,      .rightKnee,  .rightAnkle),
            leftHip:       angleAt(.leftShoulder,  .leftHip,    .leftKnee),
            rightHip:      angleAt(.rightShoulder, .rightHip,   .rightKnee),
            leftShoulder:  angleAt(.leftHip,       .leftShoulder,  .leftElbow),
            rightShoulder: angleAt(.rightHip,      .rightShoulder, .rightElbow),
            spine: spine
        )
    }
}
