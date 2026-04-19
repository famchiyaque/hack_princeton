import SwiftUI
import QuartzCore

struct SessionView: View {
    @Binding var stage: SessionStage?

    @StateObject private var camera       = CameraManager()
    @StateObject private var poseDetector = PoseDetector()
    @StateObject private var analyzer     = ExerciseAnalyzer()
    @StateObject private var sessionMgr   = SessionManager()
    @StateObject private var audioCoach   = AudioCoach()

    @State private var activeExercise: ExerciseType = .unknown
    @State private var formResult: FormResult?
    @State private var repCount = 0
    @State private var isPaused = false
    @State private var coachMessage: String = "Get into position..."
    @State private var lastBubbleUpdate: TimeInterval = 0
    @State private var skeletonColor: Color = .white
    @State private var lastRepCount = 0
    @State private var smoothedFormScore: Double = 100

    @State private var countdown: Int = 5
    @State private var isCountingDown = true

    @State private var scheduler = FeedbackScheduler()

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

                SkeletonOverlay(
                    pose: poseDetector.currentPose,
                    viewSize: geo.size,
                    exercise: activeExercise,
                    color: skeletonColor
                )

                if isCountingDown {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 16) {
                        Text("\(countdown)")
                            .font(.system(size: 96, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.3), value: countdown)
                        Text("Get into position")
                            .font(KineticFont.heading(20))
                            .foregroundStyle(KineticColor.textSecondary)
                    }
                }

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
            audioCoach.prefetch()
            camera.requestPermission()
            camera.onFrame = { [weak poseDetector] buf, orientation in
                guard !isPaused else { return }
                poseDetector?.process(sampleBuffer: buf, orientation: orientation)
            }
            startCountdown()
        }
        .onDisappear { camera.stop() }
        .onChange(of: poseDetector.currentPose) { _, pose in
            guard let pose, !isPaused, !isCountingDown else { return }
            processFrame(pose)
        }
    }

    // MARK: - Countdown

    private func startCountdown() {
        countdown = 5
        isCountingDown = true
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            countdown -= 1
            if countdown <= 0 {
                timer.invalidate()
                isCountingDown = false
                coachMessage = "Start moving — I'll detect your exercise"
                sessionMgr.startSession()
            }
        }
    }

    // MARK: - Exercise locked

    private func handleExerciseLocked(_ exercise: ExerciseType) {
        activeExercise = exercise
        repCount = 0
        lastRepCount = 0
        formResult = nil
        smoothedFormScore = 100

        skeletonColor = .green

        sessionMgr.selectExercise(exercise)
        if let line = scheduler.onExerciseStarted(exercise) {
            audioCoach.speak(line, priority: 9)
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

            VStack(spacing: 6) {
                let ex = exerciseStatus
                HStack(spacing: 6) {
                    Image(systemName: ex.icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ex.color)
                    Text("EXERCISE: \(ex.label)")
                        .font(KineticFont.caption(11))
                        .kerning(1.5)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(ex.color.opacity(0.45), lineWidth: 1))

                let status = formStatus
                HStack(spacing: 6) {
                    Circle().fill(status.color).frame(width: 8, height: 8)
                    Text("FORM: \(status.label)")
                        .font(KineticFont.caption(11))
                        .kerning(1.5)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(status.color.opacity(0.4), lineWidth: 1))
            }

            Spacer()

            Button {
                audioCoach.stop()
                camera.stop()
                stage = nil
            } label: {
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
            widget(icon: "repeat", value: "\(repCount)", unit: "REPS", color: .cyan)
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
                if let line = (isPaused ? scheduler.onPaused() : scheduler.onResumed()) {
                    audioCoach.speak(line, priority: 9)
                }
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
        let snapshot = analyzer.update(pose: pose)

        // Handle state transitions
        let exercise = snapshot.state.exercise
        if snapshot.state.isLocked && exercise != activeExercise {
            handleExerciseLocked(exercise)
        }
        if !snapshot.state.isLocked && activeExercise != .unknown {
            // Analyzer reset or unlocked
            activeExercise = .unknown
        }

        // Update form result (only meaningful when locked)
        formResult = snapshot.state.isLocked ? snapshot.formResult : nil

        // Detect new reps
        if snapshot.repCount > lastRepCount && snapshot.state.isLocked {
            let newReps = snapshot.repCount - lastRepCount
            lastRepCount = snapshot.repCount
            repCount = snapshot.repCount

            for _ in 0..<newReps {
                sessionMgr.recordRep(
                    score: snapshot.formResult.score,
                    corrections: snapshot.formResult.corrections,
                    peakAngle: 0
                )
            }

            if let line = scheduler.onRepCompleted(score: snapshot.formResult.score) {
                audioCoach.speak(line, priority: 7)
            }
        }

        // Mid-rep form cues (only when locked)
        if snapshot.state.isLocked,
           let line = scheduler.onFrame(result: snapshot.formResult, repPhase: .goingDown) {
            audioCoach.speak(line, priority: 6)
        }

        // Speak persistent form issues from FormFeedbackEngine
        if snapshot.state.isLocked, let worst = snapshot.formIssues.max(by: { $0.severity < $1.severity }) {
            if let line = scheduler.onFormIssue(worst) {
                audioCoach.speak(line, priority: 5)
            }
        }

        // Score-based fallback: if form drops and no engine issue fired,
        // speak the top FormComparator correction directly
        if snapshot.state.isLocked,
           snapshot.formIssues.isEmpty,
           smoothedFormScore < 60,
           let top = snapshot.formResult.corrections.first {
            if let line = scheduler.onFormCorrectionFallback(top.message) {
                audioCoach.speak(line, priority: 4)
            }
        }

        // Update skeleton color based on smoothed form score
        if snapshot.state.isLocked {
            let raw = snapshot.formResult.score
            smoothedFormScore = smoothedFormScore * 0.85 + raw * 0.15
            if smoothedFormScore > 70 {
                skeletonColor = .green
            } else if smoothedFormScore > 45 {
                skeletonColor = .yellow
            } else {
                skeletonColor = .red
            }
        } else {
            skeletonColor = .white
        }

        // Throttle coach bubble to ~2 Hz
        let now = CACurrentMediaTime()
        if now - lastBubbleUpdate >= 0.5 {
            lastBubbleUpdate = now
            switch snapshot.state {
            case .unknown:
                coachMessage = "Start moving — I'll detect your exercise"
            case .candidate(let e):
                coachMessage = "Looks like \(e.displayName)… keep going"
            case .locked:
                if let worst = snapshot.formIssues.max(by: { $0.severity < $1.severity }) {
                    coachMessage = worst.message
                } else {
                    coachMessage = scheduler.visualHint(result: snapshot.formResult)
                }
            }
        }
    }

    private func endSession() {
        var report = sessionMgr.buildReport()
        audioCoach.stop()
        camera.stop()
        stage = .ending
        Task { @MainActor in
            let result = await sessionMgr.endSession()
            report.saveError = result.saveError
            stage = .report(report)
        }
    }

    // MARK: - Helpers

    /// Only show a scored status once position is locked; shows "READY" beforehand
    /// so the user isn't confused by flickering GOOD/FIX during the setup phase.
    private var formStatus: (label: String, color: Color) {
        let s = smoothedFormScore
        guard activeExercise != .unknown else { return ("READY", KineticColor.textSecondary) }
        if s > 70 { return ("GOOD", KineticColor.success) }
        if s > 45 { return ("OK",   KineticColor.warning) }
        return ("FIX",  KineticColor.danger)
    }

    private var exerciseStatus: (label: String, color: Color, icon: String) {
        if activeExercise == .unknown {
            return ("DETECTING...", KineticColor.textSecondary, "questionmark")
        }
        return (activeExercise.displayName.uppercased(), KineticColor.success, activeExercise.icon)
    }

    private func formatted(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
