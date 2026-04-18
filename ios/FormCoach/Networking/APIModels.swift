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

// MARK: - Users

struct UserPayload: Codable {
    let id: String
    let name: String
    let goals: [String]
    let fitnessLevel: String
    let weightLbs: Int
    let heightFeet: Int
    let heightInches: Int
    let age: Int
    let gender: String
    let healthNotes: [String]
    let bodyGoals: [String]
}

struct APIUser: Codable, Identifiable {
    let id: String
    let name: String
    let goals: [String]
    let fitnessLevel: String
    let weightLbs: Int
    let heightFeet: Int
    let heightInches: Int
    let age: Int
    let gender: String
    let healthNotes: [String]
    let bodyGoals: [String]
    let createdAt: String
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

// MARK: - Insights

struct APIExerciseStat: Codable, Identifiable {
    var id: String { exerciseId }
    let exerciseId: String
    let totalReps: Int
    let avgScore: Double
    let sessionCount: Int
}

struct APIInsights: Codable {
    let totalSessions: Int
    let totalReps: Int
    let totalMinutes: Int
    let overallAvgScore: Double
    let streakDays: Int
    let byExercise: [APIExerciseStat]
    let topCorrections: [CorrectionCountPayload]
    let last7DaysMinutes: [Int]
}
