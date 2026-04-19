import Foundation
import Combine

// MARK: - Session end result

struct SessionEndResult {
    let sessionId: String?         // nil if backend save failed
    let saveError: String?         // human-readable reason, nil on success
}

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

    func endSession() async -> SessionEndResult {
        timer?.cancel()
        isActive = false
        if let active = activeExercise { completedExercises.append(active) }
        let result = await postToBackend()
        reset()
        return result
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

    private func postToBackend() async -> SessionEndResult {
        guard let start = sessionStart else {
            return SessionEndResult(sessionId: nil, saveError: "Session had no start time")
        }
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
            exercises: exercises,
            totalDuration: elapsedSeconds,
            startedAt: ISO8601DateFormatter().string(from: start)
        )
        do {
            let saved = try await APIClient.shared.createSession(payload)
            // Fire the AI summary request. We intentionally don't bubble
            // failures into `saveError` — the session is already persisted;
            // the summary is a best-effort enrichment that'll be filled in
            // server-side and picked up on the next dashboard refresh.
            Task.detached { [id = saved.id] in
                do {
                    _ = try await APIClient.shared.requestSessionSummary(sessionId: id)
                } catch {
                    #if DEBUG
                    print("[SessionManager] session-summary request failed: \(error)")
                    #endif
                }
            }
            return SessionEndResult(sessionId: saved.id, saveError: nil)
        } catch {
            let message: String
            if let urlErr = error as? URLError {
                switch urlErr.code {
                case .timedOut:         message = "Server took too long to respond"
                case .notConnectedToInternet, .networkConnectionLost:
                                        message = "No network connection"
                case .cannotConnectToHost, .cannotFindHost:
                                        message = "Couldn't reach the server"
                default:                message = "Network error (\(urlErr.code.rawValue))"
                }
            } else {
                message = "Sync failed: \(error.localizedDescription)"
            }
            return SessionEndResult(sessionId: nil, saveError: message)
        }
    }
}
