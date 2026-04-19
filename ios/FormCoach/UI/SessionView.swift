import SwiftUI
import Vision
import QuartzCore

struct SessionView: View {
    /// Drives the whole session flow (recording → ending → report → dismissed).
    @Binding var stage: SessionStage?

    @StateObject private var camera       = CameraManager()
    @StateObject private var poseDetector = PoseDetector()
    @StateObject private var classifier   = ExerciseClassifier()
    @StateObject private var sessionMgr   = SessionManager()
    @StateObject private var audioCoach   = AudioCoach()

    @State private var activeExercise: ExerciseType = .unknown
    @State private var repCounter = RepCounter(exercise: .unknown)
    @State private var formResult: FormResult?
    @State private var repCount = 0
    @State private var isPaused = false
    @State private var coachMessage = "Move in frame — we detect squat, deadlift, or bicep curl"

    // Curl-specific: second gate after position lock — elbow stability must hold.
    @State private var curlRepUnlocked = false
    @State private var curlReadyFrames = 0
    @State private var elbowTracker = ElbowStabilityTracker()
    @State private var lastElbowCueTime: TimeInterval = 0
    @State private var jointHighlightStates: [VNHumanBodyPoseObservation.JointName: JointVisualState] = [:]

    @State private var lastBubbleUpdate: TimeInterval = 0
    @State private var posDetector = StartingPositionDetector()
    @State private var skeletonColor: Color = KineticColor.orange
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

                SkeletonOverlay(
                    pose: poseDetector.currentPose,
                    viewSize: geo.size,
                    exercise: activeExercise,
                    jointStates: jointHighlightStates,
                    color: skeletonColor
                )

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

    // MARK: - Exercise setup

    private func handleExerciseChange(to new: ExerciseType) {
        activeExercise = new
        repCounter = RepCounter(exercise: new)
        repCount = 0
        peakAngle = new.downThreshold
        formResult = nil
        curlRepUnlocked = false
        curlReadyFrames = 0
        elbowTracker = ElbowStabilityTracker()
        jointHighlightStates = [:]
        posDetector.reset()
        skeletonColor = KineticColor.orange

        if new == .unknown {
            coachMessage = classifier.isStable
                ? "Exercise not recognized — try squat, deadlift, or bicep curl"
                : "Move in frame — we detect squat, deadlift, or bicep curl"
            return
        }

        coachMessage = new.startingPositionCue
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
        let angles = BodyAngles.from(pose: pose)
        classifier.update(angles: angles, pose: pose)

        let exercise = activeExercise
        guard exercise != .unknown else {
            throttleDetectingBubble()
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

        // Update starting-position detector; green flash on first lock.
        let prevState = posDetector.state
        let currentState = posDetector.update(angles: angles, exercise: exercise)

        if prevState != .locked, currentState == .locked {
            skeletonColor = .green
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                skeletonColor = KineticColor.orange
            }
            if let line = scheduler.onPositionLocked() {
                audioCoach.speak(line, priority: 8)
            }
        }

        let baseResult = comparator.evaluate(angles: angles, exercise: exercise, phase: phase)

        // Curl: extra elbow-stability gate on top of position lock.
        if exercise == .curl, currentState == .locked {
            var t = elbowTracker
            let stable = t.update(pose: pose)
            elbowTracker = t

            let unstable = !stable.leftOK || !stable.rightOK
            updateCurlJointHighlights(leftOK: stable.leftOK, rightOK: stable.rightOK, score: baseResult.score)

            if unstable {
                let now = CACurrentMediaTime()
                if now - lastElbowCueTime >= 2.2 {
                    lastElbowCueTime = now
                    audioCoach.speak("Keep elbows back in place", priority: 8)
                    coachMessage = "Keep elbows back in place"
                }
                formResult = FormResult(
                    score: max(0, baseResult.score - 25),
                    corrections: [FormCorrection(joint: "elbowStability",
                                                 message: "Keep elbows back in place",
                                                 severity: 0.85)] + baseResult.corrections,
                    phase: phase
                )
            } else {
                formResult = baseResult
            }

            if !curlRepUnlocked {
                if stable.leftOK && stable.rightOK && baseResult.score > 52 {
                    curlReadyFrames += 1
                    if curlReadyFrames >= 12 {
                        curlRepUnlocked = true
                        coachMessage = "Start curling — reps count now"
                    }
                } else {
                    curlReadyFrames = 0
                }
            }

            if !unstable, let line = scheduler.onFrame(result: baseResult, repPhase: repCounter.phase) {
                audioCoach.speak(line, priority: 6)
            }
        } else {
            if exercise != .curl || currentState != .locked {
                jointHighlightStates = [:]
            }
            if currentState == .locked {
                formResult = baseResult
                if let line = scheduler.onFrame(result: baseResult, repPhase: repCounter.phase) {
                    audioCoach.speak(line, priority: 6)
                }
            }
        }

        // Rep counting is gated: position must be locked (+ curl elbow gate).
        guard currentState == .locked, let angle = primaryAngle else {
            throttleCoachBubble(positionState: currentState, result: baseResult, exercise: exercise)
            return
        }

        switch exercise {
        case .jumpingJacks, .deadlift:
            peakAngle = max(peakAngle, angle)
        case .curl:
            peakAngle = min(peakAngle, angle)
        default:
            peakAngle = min(peakAngle, angle)
        }

        let allowReps = exercise != .curl || curlRepUnlocked
        if allowReps {
            let completed = repCounter.update(primaryAngle: angle)
            if completed {
                repCount = repCounter.repCount
                let snap = formResult ?? baseResult
                sessionMgr.recordRep(score: snap.score,
                                     corrections: snap.corrections,
                                     peakAngle: peakAngle)
                peakAngle = exercise.downThreshold
                if let line = scheduler.onRepCompleted(score: snap.score) {
                    audioCoach.speak(line, priority: 7)
                }
            }
        }

        throttleCoachBubble(positionState: currentState, result: formResult ?? baseResult, exercise: exercise)
    }

    private func throttleCoachBubble(positionState: PositionState, result: FormResult, exercise: ExerciseType) {
        let now = CACurrentMediaTime()
        guard now - lastBubbleUpdate >= 0.5 else { return }
        lastBubbleUpdate = now

        // Don't overwrite an active elbow-stability cue.
        if exercise == .curl, result.corrections.contains(where: { $0.joint == "elbowStability" }) { return }

        switch positionState {
        case .waiting:
            coachMessage = exercise.startingPositionCue
        case .approaching:
            coachMessage = "Hold still… almost there"
        case .locked:
            coachMessage = scheduler.visualHint(result: result)
        }
    }

    private func updateCurlJointHighlights(leftOK: Bool, rightOK: Bool, score: Double) {
        typealias JN = VNHumanBodyPoseObservation.JointName
        var m: [JN: JointVisualState] = [:]
        let scoreGood = score > 48 || curlRepUnlocked

        if !leftOK {
            m[.leftShoulder] = .bad; m[.leftElbow] = .bad; m[.leftWrist] = .bad
        } else if leftOK && scoreGood {
            m[.leftShoulder] = .good; m[.leftElbow] = .good; m[.leftWrist] = .good
        }

        if !rightOK {
            m[.rightShoulder] = .bad; m[.rightElbow] = .bad; m[.rightWrist] = .bad
        } else if rightOK && scoreGood {
            m[.rightShoulder] = .good; m[.rightElbow] = .good; m[.rightWrist] = .good
        }

        jointHighlightStates = m
    }

    private func endSession() {
        var report = sessionMgr.buildReport()
        audioCoach.stop()
        camera.stop()
        stage = .ending
        Task { @MainActor in
            let result = await sessionMgr.endSession(report: report)
            report.saveError = result.saveError
            report.sessionId = result.sessionId
            stage = .report(report)
        }
    }

    // MARK: - Helpers

    /// Only show a scored status once position is locked; shows "READY" beforehand
    /// so the user isn't confused by flickering GOOD/FIX during the setup phase.
    private var formStatus: (label: String, color: Color) {
        guard posDetector.state == .locked else { return ("READY", KineticColor.textSecondary) }
        let s = formResult?.score ?? 0
        if s > 80 { return ("GOOD", KineticColor.success) }
        if s > 55 { return ("OK",   KineticColor.warning) }
        if s > 0  { return ("FIX",  KineticColor.danger)  }
        return ("READY", KineticColor.textSecondary)
    }

    private var exerciseStatus: (label: String, color: Color, icon: String) {
        switch classifier.detectedExercise {
        case .squat:
            return ("SQUAT", KineticColor.success, "figure.cooldown")
        case .deadlift:
            return ("DEADLIFT", KineticColor.success, "figure.strengthtraining.functional")
        case .curl:
            return ("BICEP CURL", KineticColor.success, "dumbbell.fill")
        case .unknown where classifier.isStable:
            return ("NOT RECOGNIZED", KineticColor.danger, "questionmark")
        default:
            return ("DETECTING…", KineticColor.textSecondary, "sparkle.magnifyingglass")
        }
    }

    private func throttleDetectingBubble() {
        let now = CACurrentMediaTime()
        guard now - lastBubbleUpdate >= 0.5 else { return }
        lastBubbleUpdate = now
        if classifier.isStable, classifier.detectedExercise == .unknown {
            coachMessage = "Exercise not recognized — try squat, deadlift, or bicep curl"
        } else {
            coachMessage = "Detecting movement…"
        }
    }

    private func formatted(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
