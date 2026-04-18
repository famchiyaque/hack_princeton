import Foundation

final class APIClient {
    static let shared = APIClient()

    var baseURL: String {
        UserDefaults.standard.string(forKey: "apiBaseURL") ?? Self.defaultBaseURL
    }

    static let defaultBaseURL = "http://localhost:8000/api"

    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    // MARK: - Auth-aware request builder

    /// Creates a URLRequest with the Supabase JWT attached.
    /// Every authenticated endpoint uses this so the backend can identify the user.
    @MainActor private func authorizedRequest(url: URL, method: String = "GET") -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthManager.shared.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    // MARK: - Health (public — no auth needed)

    func health() async throws -> Bool {
        let (data, _) = try await session.data(from: url("/health"))
        return (try? decoder.decode([String: String].self, from: data))?["status"] == "ok"
    }

    // MARK: - Exercises (public — no auth needed)

    func getExercises() async throws -> [APIExercise] {
        let (data, _) = try await session.data(from: url("/exercises"))
        return try decoder.decode(ExercisesResponse.self, from: data).exercises
    }

    // MARK: - Users (authenticated)

    func getMe() async throws -> APIUser {
        let req = await authorizedRequest(url: url("/users/me"))
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(APIUser.self, from: data)
    }

    func upsertUser(_ payload: UserPayload) async throws -> APIUser {
        var req = await authorizedRequest(url: url("/users"), method: "POST")
        req.httpBody = try encoder.encode(payload)
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(APIUser.self, from: data)
    }

    // MARK: - Sessions (authenticated)

    func createSession(_ payload: CreateSessionPayload) async throws -> APISession {
        var req = await authorizedRequest(url: url("/sessions"), method: "POST")
        req.httpBody = try encoder.encode(payload)
        req.timeoutInterval = 6.0
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(APISession.self, from: data)
    }

    func getSessions(limit: Int = 50) async throws -> [APISession] {
        var comps = URLComponents(string: baseURL + "/sessions")!
        comps.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        let req = await authorizedRequest(url: comps.url!)
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(SessionsResponse.self, from: data).sessions
    }

    // MARK: - Insights (authenticated — user derived from token)

    func getInsights() async throws -> APIInsights {
        let req = await authorizedRequest(url: url("/insights"))
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(APIInsights.self, from: data)
    }

    // MARK: - Helpers

    private func url(_ path: String) -> URL {
        URL(string: baseURL + path)!
    }
}
