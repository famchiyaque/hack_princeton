import Foundation
import SwiftUI

struct LocalUser: Codable, Equatable {
    var id: String
    var email: String
    var name: String
    var goal: String           // "muscle" | "lose" | "form" | "endure"
    var fitnessLevel: String   // "beginner" | "intermediate" | "advanced"
    var healthNotes: [String]  // e.g. ["knee_pain", "lower_back"]
    var bodyGoals: [String]    // e.g. ["stronger_core", "better_posture"]

    static let empty = LocalUser(
        id: "",
        email: "",
        name: "Athlete",
        goal: "form",
        fitnessLevel: "beginner",
        healthNotes: [],
        bodyGoals: []
    )
}

@MainActor
final class UserStore: ObservableObject {
    static let shared = UserStore()

    @Published var user: LocalUser
    @Published var hasOnboarded: Bool

    private let userKey = "kinetic.user"
    private let onboardedKey = "kinetic.hasOnboarded"

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: userKey),
           let decoded = try? JSONDecoder().decode(LocalUser.self, from: data) {
            self.user = decoded
        } else {
            self.user = .empty
        }
        self.hasOnboarded = defaults.bool(forKey: onboardedKey)
    }

    // MARK: - Auth binding

    /// Called after Supabase auth succeeds — sets the user ID to the
    /// Supabase UUID so all backend calls reference the same identity.
    func bindToAuthUser(id: String, email: String) {
        update {
            $0.id = id
            $0.email = email
        }
    }

    /// Populates local user from a backend response (returning user who
    /// already completed onboarding on another device).
    func hydrateFromBackend(_ apiUser: APIUser) {
        update {
            $0.name = apiUser.name
            $0.goal = apiUser.goal
            $0.fitnessLevel = apiUser.fitnessLevel
            $0.healthNotes = apiUser.healthNotes
            $0.bodyGoals = apiUser.bodyGoals
        }
        hasOnboarded = true
        UserDefaults.standard.set(true, forKey: onboardedKey)
    }

    // MARK: - Mutations

    func update(_ mutate: (inout LocalUser) -> Void) {
        var copy = user
        mutate(&copy)
        user = copy
        persist()
    }

    func completeOnboarding(goal: String, fitnessLevel: String,
                            healthNotes: [String], bodyGoals: [String]) {
        update {
            $0.goal = goal
            $0.fitnessLevel = fitnessLevel
            $0.healthNotes = healthNotes
            $0.bodyGoals = bodyGoals
        }
        hasOnboarded = true
        UserDefaults.standard.set(true, forKey: onboardedKey)
        Task { await syncToBackend() }
    }

    func setName(_ name: String) {
        update { $0.name = name }
        Task { await syncToBackend() }
    }

    // MARK: - Sign out

    func logout() {
        UserDefaults.standard.removeObject(forKey: userKey)
        UserDefaults.standard.removeObject(forKey: onboardedKey)
        user = .empty
        hasOnboarded = false
    }

    // MARK: - Backend sync

    func syncToBackend() async {
        let payload = UserPayload(
            name: user.name,
            goal: user.goal,
            fitnessLevel: user.fitnessLevel,
            healthNotes: user.healthNotes,
            bodyGoals: user.bodyGoals
        )
        _ = try? await APIClient.shared.upsertUser(payload)
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }

    func resetAll() {
        logout()
    }
}
