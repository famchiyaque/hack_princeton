import SwiftUI

struct SessionView: View {
    /// Drives the whole session flow (recording → ending → report → dismissed).
    /// Binding rather than callback so the view drives its own transitions
    /// without racing against a parent `.dismiss()`.
    @Binding var stage: SessionStage?

    @StateObject private var camera       = CameraManager()
    @StateObject private var poseDetector = PoseDetector()
    @StateObject private var classifier   = ExerciseClassifier()
    @StateObject private var sessionMgr   = SessionManager()
    @StateObject private var audioCoach   = AudioCoach()

    /// Exercise is detected live by `ExerciseClassifier`. No manual picker —
    /// the classifier is the single source of truth and re-classifies whenever
    /// the user switches movements (squat ↔ deadlift ↔ not recognized).
    @State private var activeExercise: ExerciseType = .unknown
    @State private var repCounter = RepCounter(exercise: .unknown)
    @State private var formResult: FormResult?
    @State private var repCount = 0
    @State private var isPaused = false
    @State private var coachMessage: String = "Get into starting position"
    @State private var lastBubbleUpdate: TimeInterval = 0
    @State private var heartRate: Int = 112
    @State private var calories: Int = 34

    // Tracks the extreme of the primary angle during current rep for the report.
    @State private var peakAngle: Double = 0

    private let comparator = FormComparator()
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
            audioCoach.prefetch()  // download all ElevenLabs phrase audio in background
            camera.requestPermission()
            camera.onFrame = { [weak poseDetector] buf, orientation in
                guard !isPaused else { return }
                poseDetector?.process(sampleBuffer: buf, orientation: orientation)
            }
            sessionMgr.startSession()
        }
        .onDisappear { camera.stop() }
        .onChange(of: poseDetector.currentPose) { _, pose in
            guard let pose, !isPaused else { return }
            processFrame(pose)
        }
        .onChange(of: classifier.detectedExercise) { _, new in
            handleExerciseChange(to: new)
        }
    }

    // MARK: - Exercise change handling

    /// Fires when the classifier flips (sticky) to a new exercise label.
    /// Unknown → silence audio + pause rep counting; squat/deadlift → rebuild
    /// the RepCounter, reset per-exercise state, and speak the startup cue.
    private func handleExerciseChange(to new: ExerciseType) {
        activeExercise = new
        repCounter = RepCounter(exercise: new)
        repCount = 0
        peakAngle = new.downThreshold
        formResult = nil

        if new == .unknown {
            coachMessage = "Exercise not recognized — try squat or deadlift"
            return
        }

        sessionMgr.selectExercise(new)
        if let line = scheduler.onExerciseStarted(new) {
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
                // Explicit quit: tear down and close the whole flow — skips
                // the report because the user hasn't produced a complete session.
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
        let angles = BodyAngles.from(pose: pose)
        // Always feed the classifier — that's how we detect live exercise
        // switches (squat → deadlift) mid-session.
        classifier.update(angles: angles, pose: pose)

        let exercise = activeExercise
        // Unknown → no rep counting, no audio, no form scoring. The coach
        // bubble already shows "Exercise not recognized" (set in
        // handleExerciseChange). Just wait until the classifier confirms
        // a real exercise.
        guard exercise == .squat || exercise == .deadlift else {
            return
        }

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

        let result = comparator.evaluate(angles: angles, exercise: exercise, phase: phase)
        formResult = result

        // Per-frame silent accumulation + optional mid-rep cue
        if let line = scheduler.onFrame(result: result, repPhase: repCounter.phase) {
            audioCoach.speak(line, priority: 6)
        }

        // Track peak of the primary angle (direction depends on exercise)
        if let angle = primaryAngle {
            switch exercise {
            case .jumpingJacks, .deadlift:
                peakAngle = max(peakAngle, angle)
            case .curl:
                peakAngle = min(peakAngle, angle)
            default:
                peakAngle = min(peakAngle, angle)
            }

            let completed = repCounter.update(primaryAngle: angle)
            if completed {
                repCount = repCounter.repCount
                calories += 1
                sessionMgr.recordRep(score: result.score,
                                     corrections: result.corrections,
                                     peakAngle: peakAngle)
                peakAngle = exercise.downThreshold

                if let line = scheduler.onRepCompleted(score: result.score) {
                    audioCoach.speak(line, priority: 7)
                }
            }
        }

        // Throttle the visual bubble to ~2 Hz so it doesn't flicker at 30 fps.
        let now = CACurrentMediaTime()
        if now - lastBubbleUpdate >= 0.5 {
            lastBubbleUpdate = now
            coachMessage = scheduler.visualHint(result: result)
        }
    }

    private func endSession() {
        // 1) Freeze the on-device report immediately — we never depend on the
        //    network to show the user their stats.
        var report = sessionMgr.buildReport()

        // 2) Tear down audio + camera up front so the ending overlay is calm.
        audioCoach.stop()
        camera.stop()

        // 3) Flip to the ending overlay; SwiftUI swaps the body in place.
        stage = .ending

        // 4) Best-effort backend sync, then unconditionally route to the
        //    report screen. Even on timeout/error we surface a banner there.
        Task { @MainActor in
            let result = await sessionMgr.endSession()
            report.saveError = result.saveError
            stage = .report(report)
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

    /// Pill label + color for the live classifier state. "DETECTING…" is shown
    /// while we haven't confirmed a sticky label yet; once unknown is sticky,
    /// we flip to "NOT RECOGNIZED" to make the demo's "walk away" state obvious.
    private var exerciseStatus: (label: String, color: Color, icon: String) {
        switch classifier.detectedExercise {
        case .squat:
            return ("SQUAT", KineticColor.success, "figure.cooldown")
        case .deadlift:
            return ("DEADLIFT", KineticColor.success, "figure.strengthtraining.functional")
        case .unknown where classifier.isStable:
            return ("NOT RECOGNIZED", KineticColor.danger, "questionmark")
        default:
            return ("DETECTING…", KineticColor.textSecondary, "sparkle.magnifyingglass")
        }
    }

    private func formatted(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
