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
    let spine: Double?

    var elbowAngle: Double? {
        switch (leftElbow, rightElbow) {
        case let (l?, r?): return (l + r) / 2
        case let (l?, nil): return l
        case let (nil, r?): return r
        default: return nil
        }
    }

    var kneeAngle: Double? {
        switch (leftKnee, rightKnee) {
        case let (l?, r?): return min(l, r)
        case let (l?, nil): return l
        case let (nil, r?): return r
        default: return nil
        }
    }

    var hipAngle: Double? {
        switch (leftHip, rightHip) {
        case let (l?, r?): return (l + r) / 2
        case let (l?, nil): return l
        case let (nil, r?): return r
        default: return nil
        }
    }

    static func from(pose: BodyPose) -> BodyAngles {
        func p(_ j: VNHumanBodyPoseObservation.JointName) -> CGPoint? { pose.point(for: j) }

        let leftElbow: Double? = {
            guard let a = p(.leftShoulder), let b = p(.leftElbow), let c = p(.leftWrist) else { return nil }
            return AngleCalculator.angle(between: a, vertex: b, and: c)
        }()

        let rightElbow: Double? = {
            guard let a = p(.rightShoulder), let b = p(.rightElbow), let c = p(.rightWrist) else { return nil }
            return AngleCalculator.angle(between: a, vertex: b, and: c)
        }()

        let leftKnee: Double? = {
            guard let a = p(.leftHip), let b = p(.leftKnee), let c = p(.leftAnkle) else { return nil }
            return AngleCalculator.angle(between: a, vertex: b, and: c)
        }()

        let rightKnee: Double? = {
            guard let a = p(.rightHip), let b = p(.rightKnee), let c = p(.rightAnkle) else { return nil }
            return AngleCalculator.angle(between: a, vertex: b, and: c)
        }()

        let leftHip: Double? = {
            guard let a = p(.leftShoulder), let b = p(.leftHip), let c = p(.leftKnee) else { return nil }
            return AngleCalculator.angle(between: a, vertex: b, and: c)
        }()

        let rightHip: Double? = {
            guard let a = p(.rightShoulder), let b = p(.rightHip), let c = p(.rightKnee) else { return nil }
            return AngleCalculator.angle(between: a, vertex: b, and: c)
        }()

        let spine: Double? = {
            let shoulder = p(.leftShoulder) ?? p(.rightShoulder)
            guard let neck = p(.neck), let s = shoulder, let hip = p(.root) else { return nil }
            return AngleCalculator.angle(between: neck, vertex: s, and: hip)
        }()

        return BodyAngles(
            leftElbow: leftElbow, rightElbow: rightElbow,
            leftKnee: leftKnee, rightKnee: rightKnee,
            leftHip: leftHip, rightHip: rightHip,
            spine: spine
        )
    }
}
