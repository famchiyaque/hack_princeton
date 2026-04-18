import SwiftUI

struct SessionView: View {
    @StateObject private var camera       = CameraManager()
    @StateObject private var poseDetector = PoseDetector()
    @StateObject private var classifier   = ExerciseClassifier()
    @StateObject private var sessionMgr   = SessionManager()
    @StateObject private var audioCoach   = AudioCoach()

    @State private var selectedExercise: ExerciseType = .squat
    @State private var repCounter = RepCounter(exercise: .squat)
    @State private var formResult: FormResult?
    @State private var repCount = 0
    @State private var lastFeedbackTime: TimeInterval = 0

    private let comparator = FormComparator()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                CameraPreviewView(session: camera.captureSession)
                    .ignoresSafeArea()

                OverlayRenderer(
                    pose:       poseDetector.currentPose,
                    formResult: formResult,
                    exercise:   selectedExercise,
                    repCount:   repCount,
                    viewSize:   geo.size
                )

                VStack {
                    Spacer()
                    controlBar
                }
            }
        }
        .onAppear {
            camera.requestPermission()
            camera.onFrame = { [weak poseDetector] buf in
                poseDetector?.process(sampleBuffer: buf)
            }
        }
        .onChange(of: poseDetector.currentPose) { _, pose in
            guard let pose else { return }
            processFrame(pose)
        }
        .onChange(of: selectedExercise) { _, exercise in
            repCounter = RepCounter(exercise: exercise)
            repCount = 0
            if sessionMgr.isActive { sessionMgr.selectExercise(exercise) }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Workout")
    }

    // MARK: - Frame processing (runs on main thread, fast path)

    private func processFrame(_ pose: BodyPose) {
        let angles  = BodyAngles.from(pose: pose)
        let exercise = selectedExercise
        classifier.update(angles: angles, pose: pose)
        guard exercise != .unknown else { return }

        // Determine current phase
        let (primaryAngle, phase): (Double?, String) = {
            switch exercise {
            case .pushup:
                let a = angles.elbowAngle
                return (a, (a ?? 180) < 120 ? "bottom" : "top")
            case .squat, .lunge:
                let a = angles.kneeAngle
                return (a, (a ?? 180) < 120 ? "bottom" : "top")
            case .plank:
                return (angles.hipAngle, "hold")
            case .unknown:
                return (nil, "top")
            }
        }()

        // Rep counting
        if let angle = primaryAngle {
            let completed = repCounter.update(primaryAngle: angle)
            if completed {
                repCount = repCounter.repCount
                if let result = formResult {
                    sessionMgr.recordRep(score: result.score, corrections: result.corrections)
                }
            }
        }

        // Form evaluation
        let result = comparator.evaluate(angles: angles, exercise: exercise, phase: phase)
        formResult = result

        // Audio feedback (throttled)
        let now = CACurrentMediaTime()
        if now - lastFeedbackTime >= 2.5 {
            lastFeedbackTime = now
            audioCoach.speakCorrections(result.corrections)
        }
    }

    // MARK: - Control bar

    private var controlBar: some View {
        HStack(spacing: 12) {
            // Start / End
            if sessionMgr.isActive {
                Button(role: .destructive) {
                    Task { await sessionMgr.endSession() }
                    repCounter.reset(); repCount = 0
                } label: {
                    Label("End", systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                Button {
                    sessionMgr.startSession()
                    sessionMgr.selectExercise(selectedExercise)
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }

            // Exercise picker
            Menu {
                ForEach(ExerciseType.allCases.filter { $0 != .unknown }) { type in
                    Button(type.displayName) { selectedExercise = type }
                }
            } label: {
                Label(selectedExercise.displayName, systemImage: "figure.strengthtraining.traditional")
            }
            .buttonStyle(.bordered)

            Spacer()

            // Timer
            if sessionMgr.isActive {
                Text(formatted(sessionMgr.elapsedSeconds))
                    .font(.system(.body, design: .monospaced).bold())
                    .foregroundStyle(.white)
            }

            // Camera flip
            Button { camera.toggleCamera() } label: {
                Image(systemName: "camera.rotate")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func formatted(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
