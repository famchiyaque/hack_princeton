import Foundation
import Combine

struct WorkoutExercise {
    var exerciseId: String
    var reps: Int = 0
    var scores: [Double] = []
    var corrections: [String: Int] = [:]
    var startedAt: Date = .init()

    var avgScore: Double { scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count) }
    var duration: Int   { Int(Date().timeIntervalSince(startedAt)) }
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
    private var timer: AnyCancellable?

    // MARK: - Lifecycle

    func startSession() {
        sessionStart = .init()
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

    func recordRep(score: Double, corrections: [FormCorrection]) {
        totalReps += 1
        latestScore = score
        activeExercise?.reps += 1
        activeExercise?.scores.append(score)
        for c in corrections { activeExercise?.corrections[c.joint, default: 0] += 1 }
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
        sessionStart = nil
        completedExercises = []; activeExercise = nil
        timer?.cancel()
    }

    // MARK: - Backend sync

    private func postToBackend() async {
        guard let start = sessionStart else { return }
        let exercises = completedExercises.map { ex in
            SessionExercisePayload(
                exerciseId: ex.exerciseId,
                reps: ex.reps,
                avgScore: ex.avgScore,
                duration: ex.duration,
                corrections: ex.corrections.map { CorrectionCountPayload(type: $0.key, count: $0.value) }
            )
        }
        let payload = CreateSessionPayload(
            userId: "anonymous",
            exercises: exercises,
            totalDuration: elapsedSeconds,
            startedAt: ISO8601DateFormatter().string(from: start)
        )
        _ = try? await APIClient.shared.createSession(payload)
    }
}
