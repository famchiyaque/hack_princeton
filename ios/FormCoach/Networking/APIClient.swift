import Foundation

final class APIClient {
    static let shared = APIClient()

    private let baseURL: String
    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(baseURL: String = "http://localhost:8000/api") {
        self.baseURL = baseURL
    }

    // MARK: - Exercises

    func getExercises() async throws -> [APIExercise] {
        let (data, _) = try await session.data(from: url("/exercises"))
        return try decoder.decode(ExercisesResponse.self, from: data).exercises
    }

    func getExercise(id: String) async throws -> APIExercise {
        let (data, _) = try await session.data(from: url("/exercises/\(id)"))
        return try decoder.decode(APIExercise.self, from: data)
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

    func getSessions(userId: String = "anonymous", limit: Int = 20) async throws -> [APISession] {
        var comps = URLComponents(string: baseURL + "/sessions")!
        comps.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "limit",  value: String(limit)),
        ]
        let (data, _) = try await session.data(from: comps.url!)
        return try decoder.decode(SessionsResponse.self, from: data).sessions
    }

    // MARK: - Helpers

    private func url(_ path: String) -> URL {
        URL(string: baseURL + path)!
    }
}
