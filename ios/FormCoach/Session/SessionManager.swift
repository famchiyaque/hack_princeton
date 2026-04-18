import Foundation
import Combine

// MARK: - Internal session state

struct WorkoutExercise {
    var exerciseId: String
    var reps: [RepRecord] = []
    var corrections: [String: Int] = [:]
    var startedAt: Date = .init()

    var repCount: Int { reps.count }
    var scores: [Double] { reps.map(\.score) }
    var avgScore: Double { scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count) }
    var duration: Int { Int(Date().timeIntervalSince(startedAt)) }
}

@MainActor
final class SessionManager: ObservableObject {
    @Published var isActive = false
    @Published var currentExercise: ExerciseType = .unknown
    @Published var totalReps = 0
    @Published var latestScore: Double = 0
    @Published var elapsedSeconds = 0

    private var sessionStart: Date?
    private var completedExercises: [WorkoutExercise] = []
    private var activeExercise: WorkoutExercise?
    private var lastRepAt: Date?
    private var timer: AnyCancellable?

    // MARK: - Lifecycle

    func startSession() {
        sessionStart = .init()
        lastRepAt = .init()
        isActive = true
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                guard let self, let start = sessionStart else { return }
                elapsedSeconds = Int(Date().timeIntervalSince(start))
            }
    }

    func selectExercise(_ type: ExerciseType) {
        if let active = activeExercise { completedExercises.append(active) }
        currentExercise = type
        activeExercise = WorkoutExercise(exerciseId: type.rawValue)
    }

    func recordRep(score: Double, corrections: [FormCorrection], peakAngle: Double) {
        totalReps += 1
        latestScore = score

        let now = Date()
        let durationMs = Int((now.timeIntervalSince(lastRepAt ?? now)) * 1000)
        lastRepAt = now

        let record = RepRecord(
            index: (activeExercise?.repCount ?? 0) + 1,
            exercise: currentExercise,
            score: score,
            peakPrimaryAngle: peakAngle,
            durationMs: durationMs,
            topCorrection: corrections.first?.joint
        )
        activeExercise?.reps.append(record)
        for c in corrections { activeExercise?.corrections[c.joint, default: 0] += 1 }
    }

    /// Build the on-device report for the active exercise.
    func buildReport() -> SessionReport {
        let active = activeExercise ?? WorkoutExercise(exerciseId: currentExercise.rawValue)
        return SessionAnalyzer.analyze(
            exercise: currentExercise,
            durationSeconds: elapsedSeconds,
            reps: active.reps,
            correctionsByType: active.corrections
        )
    }

    func endSession() async {
        timer?.cancel()
        isActive = false
        if let active = activeExercise { completedExercises.append(active) }
        await postToBackend()
        reset()
    }

    func reset() {
        isActive = false
        currentExercise = .unknown
        totalReps = 0; latestScore = 0; elapsedSeconds = 0
        sessionStart = nil; lastRepAt = nil
        completedExercises = []; activeExercise = nil
        timer?.cancel()
    }

    // MARK: - Backend sync

    private func postToBackend() async {
        guard let start = sessionStart else { return }
        let userId = await UserStore.shared.user.id

        let exercises = completedExercises.map { ex in
            SessionExercisePayload(
                exerciseId: ex.exerciseId,
                reps: ex.repCount,
                avgScore: ex.avgScore,
                duration: ex.duration,
                corrections: ex.corrections.map { CorrectionCountPayload(type: $0.key, count: $0.value) }
            )
        }
        let payload = CreateSessionPayload(
            userId: userId,
            exercises: exercises,
            totalDuration: elapsedSeconds,
            startedAt: ISO8601DateFormatter().string(from: start)
        )
        _ = try? await APIClient.shared.createSession(payload)
    }
}
