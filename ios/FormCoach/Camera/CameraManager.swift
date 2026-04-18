import AVFoundation
import Combine
import ImageIO

final class CameraManager: NSObject, ObservableObject {
    let captureSession = AVCaptureSession()

    @Published var isRunning = false
    @Published var permissionGranted = false

    /// Delivers each video frame along with the orientation Vision should use
    /// to interpret it. The buffer itself is in the sensor's native landscape
    /// layout — Vision needs the orientation hint to return coords in the
    /// portrait space we actually display.
    var onFrame: ((CMSampleBuffer, CGImagePropertyOrientation) -> Void)?

    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.formcoach.camera.session", qos: .userInitiated)
    private let outputQueue = DispatchQueue(label: "com.formcoach.camera.output", qos: .userInitiated)
    private var currentPosition: AVCaptureDevice.Position = .back

    /// Orientation Vision needs to correctly interpret the buffer.
    /// Assumes portrait device orientation (which is locked elsewhere).
    private var visionOrientation: CGImagePropertyOrientation {
        currentPosition == .front ? .leftMirrored : .right
    }

    func requestPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { self.permissionGranted = true }
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async { self?.permissionGranted = granted }
                if granted { self?.setupSession() }
            }
        default:
            break
        }
    }

    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            captureSession.beginConfiguration()
            captureSession.sessionPreset = .hd1280x720

            addInput(for: currentPosition)

            videoOutput.setSampleBufferDelegate(self, queue: outputQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
                // Set portrait orientation
                if let connection = videoOutput.connection(with: .video) {
                    if connection.isVideoRotationAngleSupported(90) {
                        connection.videoRotationAngle = 90
                    }
                }
            }

            captureSession.commitConfiguration()
            captureSession.startRunning()
            DispatchQueue.main.async { self.isRunning = true }
        }
    }

    private func addInput(for position: AVCaptureDevice.Position) {
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
            let input = try? AVCaptureDeviceInput(device: device),
            captureSession.canAddInput(input)
        else { return }
        captureSession.addInput(input)
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
            DispatchQueue.main.async { self?.isRunning = false }
        }
    }

    func toggleCamera() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            captureSession.beginConfiguration()
            currentPosition = (currentPosition == .back) ? .front : .back
            addInput(for: currentPosition)
            captureSession.commitConfiguration()
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        onFrame?(sampleBuffer, visionOrientation)
    }
}
