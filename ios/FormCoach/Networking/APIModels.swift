import Foundation

// MARK: - Exercise

struct APIAngleRange: Codable {
    let min: Double
    let max: Double
}

struct APIExercisePhase: Codable {
    let name: String
    let referenceAngles: [String: APIAngleRange]
}

struct APIExercise: Codable, Identifiable {
    let id: String
    let name: String
    let phases: [APIExercisePhase]
    let corrections: [String: String]
}

struct ExercisesResponse: Codable {
    let exercises: [APIExercise]
}

// MARK: - Sessions

struct CorrectionCountPayload: Codable {
    let type: String
    let count: Int
}

struct SessionExercisePayload: Codable {
    let exerciseId: String
    let reps: Int
    let avgScore: Double
    let duration: Int
    let corrections: [CorrectionCountPayload]
}

struct CreateSessionPayload: Codable {
    let userId: String
    let exercises: [SessionExercisePayload]
    let totalDuration: Int
    let startedAt: String
}

struct APISessionExercise: Codable, Identifiable {
    let id: String
    let exerciseId: String
    let reps: Int
    let avgScore: Double
    let duration: Int
    let corrections: [CorrectionCountPayload]
}

struct APISession: Codable, Identifiable {
    let id: String
    let userId: String
    let totalDuration: Int
    let startedAt: String
    let createdAt: String
    let exercises: [APISessionExercise]
}

struct SessionsResponse: Codable {
    let sessions: [APISession]
    let total: Int
}
