import Foundation
import QuartzCore

/// Event-driven coaching scheduler.
///
/// Design:
///  - Silent by default. Only speaks on *events*, not ticks.
///  - Accumulates faults over a rep, then critiques the worst one AFTER the rep.
///  - At most one mid-rep cue, only if a severe fault (>0.8) happens while going down.
///  - Global 3.5s cooldown between any utterance (startup/pause bypass).
///  - Picks phrase variants randomly, avoiding the last 2 spoken phrases.
final class FeedbackScheduler {

    // MARK: - Tunables

    private let globalCooldown: TimeInterval = 3.5
    private let encouragementCooldown: TimeInterval = 15
    private let encouragementEveryNReps = 3
    /// Lowered from 0.8 so we actually cue common descent faults (0.8 is rare
    /// in practice — the user went a full minute without any audio).
    private let midRepSeverityThreshold: Double = 0.6
    private let postRepSeverityThreshold: Double = 0.45
    private let recentPhrasesMemory = 2   // don't repeat the last N spoken phrases

    // MARK: - State

    private var currentRepFaults: [String: Double] = [:]
    private var recentPhrases: [String] = []
    private var lastSpokenAt: TimeInterval = 0
    private var lastEncouragementAt: TimeInterval = 0
    private var consecutiveGoodReps: Int = 0
    private var midRepCueFiredThisRep: Bool = false
    private var currentExercise: ExerciseType = .unknown
    private var repsCompleted: Int = 0

    // MARK: - Public events

    /// Call whenever the selected exercise changes (including session start).
    /// Always speaks a setup cue.
    func onExerciseStarted(_ exercise: ExerciseType) -> String? {
        currentExercise = exercise
        resetRepState()
        consecutiveGoodReps = 0
        repsCompleted = 0
        let line = pick(from: Phrases.startup[exercise.rawValue] ?? Phrases.genericStart)
        markSpoken(line)
        return line
    }

    /// Called every frame. Returns an utterance only for critical mid-rep cues.
    func onFrame(result: FormResult, repPhase: RepCounter.Phase) -> String? {
        // Accumulate worst severity per fault during the rep
        for c in result.corrections {
            let key = faultKey(exercise: currentExercise, correction: c)
            currentRepFaults[key] = max(currentRepFaults[key] ?? 0, c.severity)
        }

        // One mid-rep cue per rep, only on the way down, only if severe
        guard !midRepCueFiredThisRep,
              repPhase == .goingDown,
              let worst = result.corrections.first,
              worst.severity >= midRepSeverityThreshold,
              canSpeak()
        else { return nil }

        let key = faultKey(exercise: currentExercise, correction: worst)
        guard let bank = Phrases.faults[key] else { return nil }

        midRepCueFiredThisRep = true
        let line = pick(from: bank)
        markSpoken(line)
        return line
    }

    /// Called when RepCounter reports a rep just completed.
    /// Returns post-rep critique, encouragement, or nil (silence).
    func onRepCompleted(score: Double) -> String? {
        defer { resetRepState(); repsCompleted += 1 }

        // First rep always gets acknowledged so the user knows audio is alive.
        if repsCompleted == 0, canSpeak() {
            let line = "One rep in the books"
            markSpoken(line)
            return line
        }

        // Identify worst accumulated fault this rep
        if let (worstKey, worstSev) = currentRepFaults.max(by: { $0.value < $1.value }),
           worstSev >= postRepSeverityThreshold,
           let bank = Phrases.faults[worstKey],
           canSpeak() {
            consecutiveGoodReps = 0
            let line = pick(from: bank)
            markSpoken(line)
            return line
        }

        // Clean rep
        consecutiveGoodReps += 1
        let now = CACurrentMediaTime()
        if consecutiveGoodReps > 0,
           consecutiveGoodReps % encouragementEveryNReps == 0,
           now - lastEncouragementAt >= encouragementCooldown,
           canSpeak() {
            let line = pick(from: Phrases.encouragement)
            lastEncouragementAt = now
            markSpoken(line)
            return line
        }
        return nil
    }

    func onPaused() -> String? {
        let line = "Paused"
        markSpoken(line, bypassCooldown: true)
        return line
    }

    func onResumed() -> String? {
        let line = pick(from: Phrases.resume)
        markSpoken(line, bypassCooldown: true)
        return line
    }

    /// Hint text for the coach-bubble UI. Visual only, no speech.
    /// Picks the worst currently-accumulated fault, or a default.
    func visualHint(result: FormResult) -> String {
        if let top = result.corrections.first, top.severity > 0.4 {
            return top.message
        }
        if result.score > 85 { return "Looking good" }
        if result.score > 55 { return "Stay focused" }
        return "Get in position"
    }

    // MARK: - Private

    private func resetRepState() {
        currentRepFaults.removeAll()
        midRepCueFiredThisRep = false
    }

    private func canSpeak() -> Bool {
        CACurrentMediaTime() - lastSpokenAt >= globalCooldown
    }

    private func markSpoken(_ line: String, bypassCooldown: Bool = false) {
        if !bypassCooldown { lastSpokenAt = CACurrentMediaTime() }
        recentPhrases.append(line)
        if recentPhrases.count > recentPhrasesMemory {
            recentPhrases.removeFirst()
        }
    }

    private func pick(from bank: [String]) -> String {
        let fresh = bank.filter { !recentPhrases.contains($0) }
        return (fresh.isEmpty ? bank : fresh).randomElement() ?? bank.first ?? ""
    }

    private func faultKey(exercise: ExerciseType, correction: FormCorrection) -> String {
        // Correction message tells us which side of the range was violated;
        // we reuse FormComparator's convention of `{joint}_{low|high}`.
        // Reconstruct the key from the exercise + joint + message lookup.
        let exerciseKey = exercise.rawValue
        // Find which _low/_high key matches the stored message.
        if let bank = FormComparator.messages[exerciseKey] {
            for (k, v) in bank where v == correction.message {
                return "\(exerciseKey):\(k)"
            }
        }
        return "\(exerciseKey):\(correction.joint)_high"
    }
}

// MARK: - Phrase bank

private enum Phrases {
    static let startup: [String: [String]] = [
        "squat": [
            "Feet shoulder width. Sink hips back, chest tall. Go.",
            "Stand strong, chest up. Three, two, one, squat.",
            "Eyes forward, weight in your heels. Begin.",
        ],
        "pushup": [
            "Body in a straight line from head to heels. Go.",
            "Tight core, hands under shoulders. Begin.",
            "Lock it in. Plank position, start when ready.",
        ],
        "jumping_jacks": [
            "Hands to sky, feet wide on the jump. Go.",
            "Big jumps, arms all the way up. Begin.",
        ],
    ]

    static let genericStart: [String] = [
        "Get into starting position. Begin when ready.",
    ]

    static let faults: [String: [String]] = [
        // Squat
        "squat:kneeAngle_high": [
            "Sink deeper",
            "Go a little lower next rep",
            "Drop your hips further",
        ],
        "squat:spineAngle_low": [
            "Chest up",
            "Keep your eyes forward",
            "Proud chest",
        ],
        "squat:hipAngle_low": [
            "Sit your hips back",
            "Push your hips behind you",
        ],
        // Pushup
        "pushup:elbowAngle_high": [
            "Lower your chest",
            "Closer to the floor next rep",
            "Full range, go deeper",
        ],
        "pushup:elbowAngle_low": [
            "Lock out at the top",
            "Full extension",
            "All the way up",
        ],
        "pushup:hipAngle_low": [
            "Brace your core",
            "Hips up, straight line",
            "Engage your abs",
        ],
        "pushup:spineAngle_low": [
            "Flat back",
            "Lengthen your spine",
        ],
        // Jumping jacks
        "jumping_jacks:shoulderAngle_low": [
            "Arms higher",
            "Hands over your head",
            "Reach all the way up",
        ],
        "jumping_jacks:hipAngle_low": [
            "Feet wider",
            "Bigger jumps out",
            "Wider stance on the jump",
        ],
    ]

    static let encouragement: [String] = [
        "Nice form",
        "Looking clean",
        "You're dialed in",
        "Strong rhythm",
        "Locked in",
        "That's the groove",
    ]

    static let resume: [String] = [
        "Back at it",
        "Let's go",
    ]
}
