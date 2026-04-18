import SwiftUI

struct SessionView: View {
    var onEnd: (SessionReport) -> Void = { _ in }

    @StateObject private var camera       = CameraManager()
    @StateObject private var poseDetector = PoseDetector()
    @StateObject private var classifier   = ExerciseClassifier()
    @StateObject private var sessionMgr   = SessionManager()
    @StateObject private var audioCoach   = AudioCoach()

    @State private var selectedExercise: ExerciseType = .squat
    @State private var repCounter = RepCounter(exercise: .squat)
    @State private var formResult: FormResult?
    @State private var repCount = 0
    @State private var isPaused = false
    @State private var lastFeedbackTime: TimeInterval = 0
    @State private var coachMessage: String = "Get into starting position"
    @State private var heartRate: Int = 112
    @State private var calories: Int = 34

    // Tracks the extreme of the primary angle during current rep for the report.
    @State private var peakAngle: Double = 0

    @Environment(\.dismiss) private var dismiss
    private let comparator = FormComparator()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                CameraPreviewView(session: camera.captureSession)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [.black.opacity(0.55), .clear, .clear, .black.opacity(0.75)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                SkeletonOverlay(pose: poseDetector.currentPose, viewSize: geo.size)

                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    HStack(alignment: .top) {
                        Spacer()
                        rightWidgets
                            .padding(.trailing, 16)
                            .padding(.top, 20)
                    }

                    Spacer()

                    HStack(alignment: .bottom) {
                        coachBubble
                            .padding(.leading, 16)
                        Spacer()
                    }
                    .padding(.bottom, 16)

                    controlBar
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }
            }
        }
        .statusBarHidden()
        .onAppear {
            camera.requestPermission()
            camera.onFrame = { [weak poseDetector] buf in
                guard !isPaused else { return }
                poseDetector?.process(sampleBuffer: buf)
            }
            sessionMgr.startSession()
            sessionMgr.selectExercise(selectedExercise)
            audioCoach.speak("Session started. \(selectedExercise.displayName).", priority: 9)
        }
        .onDisappear { camera.stop() }
        .onChange(of: poseDetector.currentPose) { _, pose in
            guard let pose, !isPaused else { return }
            processFrame(pose)
        }
        .onChange(of: selectedExercise) { _, new in
            repCounter = RepCounter(exercise: new)
            repCount = 0
            peakAngle = new.downThreshold
            sessionMgr.selectExercise(new)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            GlassCard(padding: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(KineticColor.textSecondary)
                    Text(formatted(sessionMgr.elapsedSeconds))
                        .font(KineticFont.heading(16).monospacedDigit())
                        .foregroundStyle(.white)
                }
            }

            Spacer()

            let status = formStatus
            HStack(spacing: 6) {
                Circle().fill(status.color).frame(width: 8, height: 8)
                Text("FORM: \(status.label)")
                    .font(KineticFont.caption(11))
                    .kerning(1.5)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(status.color.opacity(0.4), lineWidth: 1))

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
    }

    // MARK: - Right-side widgets

    private var rightWidgets: some View {
        VStack(spacing: 10) {
            widget(icon: "heart.fill",  value: "\(heartRate)", unit: "BPM",  color: KineticColor.danger)
            widget(icon: "flame.fill",  value: "\(calories)",  unit: "KCAL", color: KineticColor.orange)
            widget(icon: "repeat",      value: "\(repCount)",  unit: "REPS", color: .cyan)
        }
    }

    private func widget(icon: String, value: String, unit: String, color: Color) -> some View {
        GlassCard(padding: 10) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 14)).foregroundStyle(color)
                Text(value).font(KineticFont.heading(18)).foregroundStyle(.white)
                Text(unit).font(KineticFont.caption(9)).kerning(1).foregroundStyle(KineticColor.textSecondary)
            }
            .frame(width: 54)
        }
    }

    // MARK: - Coach bubble

    private var coachBubble: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(KineticColor.orange).frame(width: 36, height: 36)
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("AI COACH")
                    .font(KineticFont.caption(9))
                    .kerning(1.5)
                    .foregroundStyle(KineticColor.orange)
                Text(coachMessage)
                    .font(KineticFont.body(14))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
            }
            .padding(.trailing, 4)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(KineticColor.glassStroke, lineWidth: 1)
        )
        .frame(maxWidth: 280, alignment: .leading)
        .animation(.easeInOut, value: coachMessage)
    }

    // MARK: - Controls

    private var controlBar: some View {
        HStack(spacing: 16) {
            Button {
                isPaused.toggle()
                audioCoach.speak(isPaused ? "Paused" : "Resumed", priority: 9)
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(KineticColor.glassStroke, lineWidth: 1))
            }

            Button { endSession() } label: {
                ZStack {
                    Circle().fill(KineticColor.danger).frame(width: 80, height: 80)
                    RoundedRectangle(cornerRadius: 6).fill(.white).frame(width: 24, height: 24)
                }
                .shadow(color: KineticColor.danger.opacity(0.5), radius: 12, y: 6)
            }

            Button { camera.toggleCamera() } label: {
                Image(systemName: "camera.rotate.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(KineticColor.glassStroke, lineWidth: 1))
            }
        }
    }

    // MARK: - Frame logic

    private func processFrame(_ pose: BodyPose) {
        let angles = BodyAngles.from(pose: pose)
        let exercise = selectedExercise
        classifier.update(angles: angles, pose: pose)

        let (primaryAngle, phase): (Double?, String) = {
            switch exercise {
            case .pushup:
                let a = angles.elbowAngle
                return (a, (a ?? 180) < 120 ? "bottom" : "top")
            case .squat, .lunge:
                let a = angles.kneeAngle
                return (a, (a ?? 180) < 120 ? "bottom" : "top")
            case .deadlift:
                let a = angles.hipAngle
                return (a, (a ?? 180) < 130 ? "bottom" : "top")
            case .plank:
                return (angles.hipAngle, "hold")
            case .jumpingJacks:
                let a = angles.shoulderAngle
                return (a, (a ?? 0) > 100 ? "open" : "closed")
            case .curl:
                let a = angles.elbowAngle
                return (a, (a ?? 180) < 90 ? "top" : "bottom")
            case .unknown:
                return (nil, "top")
            }
        }()

        // Track peak of the primary angle (direction depends on exercise)
        if let angle = primaryAngle {
            switch exercise {
            case .jumpingJacks, .deadlift:
                peakAngle = max(peakAngle, angle)
            case .curl:
                peakAngle = min(peakAngle, angle)  // smaller elbow = deeper curl
            default:
                peakAngle = min(peakAngle, angle)  // smaller = deeper
            }

            let completed = repCounter.update(primaryAngle: angle)
            if completed {
                repCount = repCounter.repCount
                calories += 1
                if let result = formResult {
                    sessionMgr.recordRep(score: result.score,
                                         corrections: result.corrections,
                                         peakAngle: peakAngle)
                }
                peakAngle = exercise.downThreshold
            }
        }

        let result = comparator.evaluate(angles: angles, exercise: exercise, phase: phase)
        formResult = result

        if let top = result.corrections.first {
            coachMessage = top.message + "..."
        } else if result.score > 85 {
            coachMessage = "Great form, keep it up!"
        }

        let now = CACurrentMediaTime()
        if now - lastFeedbackTime >= 2.5 {
            lastFeedbackTime = now
            audioCoach.speakCorrections(result.corrections)
        }
    }

    private func endSession() {
        Task {
            let report = sessionMgr.buildReport()
            await sessionMgr.endSession()
            audioCoach.stop()
            camera.stop()
            onEnd(report)
            dismiss()
        }
    }

    // MARK: - Helpers

    private var formStatus: (label: String, color: Color) {
        let s = formResult?.score ?? 0
        if s > 80 { return ("GOOD", KineticColor.success) }
        if s > 55 { return ("OK",   KineticColor.warning) }
        if s > 0  { return ("FIX",  KineticColor.danger)  }
        return ("READY", KineticColor.textSecondary)
    }

    private func formatted(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
