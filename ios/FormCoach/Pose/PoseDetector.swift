import Vision
import AVFoundation
import Combine
import ImageIO

final class PoseDetector: ObservableObject {
    @Published var currentPose: BodyPose?

    private let smoother = JointSmoother()
    private let request = VNDetectHumanBodyPoseRequest()

    /// Minimum confidence required to include a joint in the raw frame.
    /// Kept deliberately loose — the smoother's outlier rejection + EMA
    /// handles noise better than an aggressive upfront filter, and a high
    /// threshold strangles full-body poses where Vision confidence dips.
    private let minJointConfidence: Float = 0.3

    func process(sampleBuffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: orientation,
            options: [:]
        )
        do {
            try handler.perform([request])
            guard let observation = request.results?.first else {
                smoother.reset()
                DispatchQueue.main.async { self.currentPose = nil }
                return
            }
            let (joints, confidences) = extract(from: observation)
            let smoothed = smoother.smooth(raw: joints, confidences: confidences)
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
            guard let point = try? observation.recognizedPoint(joint) else { continue }
            confidences[joint] = point.confidence
            guard point.confidence >= minJointConfidence else { continue }
            joints[joint] = CGPoint(x: point.location.x, y: point.location.y)
        }
        return (joints, confidences)
    }
}
