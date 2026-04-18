import Vision
import AVFoundation
import Combine

final class PoseDetector: ObservableObject {
    @Published var currentPose: BodyPose?

    private let smoother = JointSmoother()
    private let request = VNDetectHumanBodyPoseRequest()

    func process(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
            guard let observation = request.results?.first else {
                DispatchQueue.main.async { self.currentPose = nil }
                return
            }
            let (joints, confidences) = extract(from: observation)
            let smoothed = smoother.smooth(joints)
            let pose = BodyPose(joints: smoothed, confidences: confidences, timestamp: CACurrentMediaTime())
            DispatchQueue.main.async { self.currentPose = pose }
        } catch {
            // Skip frame on Vision error
        }
    }

    private func extract(
        from observation: VNHumanBodyPoseObservation
    ) -> (
        joints: [VNHumanBodyPoseObservation.JointName: CGPoint],
        confidences: [VNHumanBodyPoseObservation.JointName: Float]
    ) {
        var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        var confidences: [VNHumanBodyPoseObservation.JointName: Float] = [:]

        for joint in BodyPose.allJointNames {
            if let point = try? observation.recognizedPoint(joint) {
                joints[joint] = CGPoint(x: point.location.x, y: point.location.y)
                confidences[joint] = point.confidence
            }
        }
        return (joints, confidences)
    }
}
