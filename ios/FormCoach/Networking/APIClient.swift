import Foundation

final class APIClient {
    static let shared = APIClient()

    /// Override at runtime via UserDefaults key "apiBaseURL" — useful when the
    /// backend is running on a different machine's LAN IP.
    var baseURL: String {
        UserDefaults.standard.string(forKey: "apiBaseURL") ?? Self.defaultBaseURL
    }

    static let defaultBaseURL = "http://localhost:8000/api"

    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    // MARK: - Health

    func health() async throws -> Bool {
        let (data, _) = try await session.data(from: url("/health"))
        return (try? decoder.decode([String: String].self, from: data))?["status"] == "ok"
    }

    // MARK: - Exercises

    func getExercises() async throws -> [APIExercise] {
        let (data, _) = try await session.data(from: url("/exercises"))
        return try decoder.decode(ExercisesResponse.self, from: data).exercises
    }

    // MARK: - Users

    func upsertUser(_ payload: UserPayload) async throws -> APIUser {
        var req = URLRequest(url: url("/users"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(payload)
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(APIUser.self, from: data)
    }

    func getUser(id: String) async throws -> APIUser {
        let (data, _) = try await session.data(from: url("/users/\(id)"))
        return try decoder.decode(APIUser.self, from: data)
    }

    // MARK: - Sessions

    func createSession(_ payload: CreateSessionPayload) async throws -> APISession {
        var req = URLRequest(url: url("/sessions"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(payload)
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(APISession.self, from: data)
    }

    func getSessions(userId: String, limit: Int = 50) async throws -> [APISession] {
        var comps = URLComponents(string: baseURL + "/sessions")!
        comps.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "limit",  value: String(limit)),
        ]
        let (data, _) = try await session.data(from: comps.url!)
        return try decoder.decode(SessionsResponse.self, from: data).sessions
    }

    // MARK: - Insights

    func getInsights(userId: String) async throws -> APIInsights {
        let (data, _) = try await session.data(from: url("/insights/\(userId)"))
        return try decoder.decode(APIInsights.self, from: data)
    }

    // MARK: - Helpers

    private func url(_ path: String) -> URL {
        URL(string: baseURL + path)!
    }
}
