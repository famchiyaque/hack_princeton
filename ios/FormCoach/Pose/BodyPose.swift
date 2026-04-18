import Vision
import CoreGraphics

struct BodyPose: Equatable {
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    let confidences: [VNHumanBodyPoseObservation.JointName: Float]
    let timestamp: TimeInterval

    func point(for joint: VNHumanBodyPoseObservation.JointName, minConfidence: Float = 0.3) -> CGPoint? {
        guard let confidence = confidences[joint], confidence >= minConfidence else { return nil }
        return joints[joint]
    }

    static let allJointNames: [VNHumanBodyPoseObservation.JointName] = [
        .nose, .leftEye, .rightEye, .leftEar, .rightEar,
        .neck, .leftShoulder, .rightShoulder, .root,
        .leftElbow, .rightElbow, .leftWrist, .rightWrist,
        .leftHip, .rightHip, .leftKnee, .rightKnee,
        .leftAnkle, .rightAnkle,
    ]
}
