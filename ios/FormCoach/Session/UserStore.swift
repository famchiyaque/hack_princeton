import Foundation
import SwiftUI

struct LocalUser: Codable, Equatable {
    var id: String
    var email: String
    var name: String
    /// Training intent ids from onboarding, e.g. "bodybuilding", "strength", "fat_loss"
    var goals: [String]
    var fitnessLevel: String   // "beginner" | "intermediate" | "advanced"
    var weightLbs: Int
    var heightFeet: Int        // imperial, feet portion (e.g. 5)
    var heightInches: Int      // 0...11
    var age: Int
    var gender: String         // "male" | "female" | "non_binary" | "prefer_not_to_say"
    var healthNotes: [String]  // e.g. ["knee_pain", "lower_back"]
    var bodyGoals: [String]    // e.g. ["stronger_core", "better_posture"]

    enum CodingKeys: String, CodingKey {
        case id, name, fitnessLevel, healthNotes, bodyGoals, goals
        case weightLbs, heightFeet, heightInches, age, gender
        case legacyGoal = "goal"
    }

    init(id: String, name: String, goals: [String], fitnessLevel: String,
         weightLbs: Int, heightFeet: Int, heightInches: Int, age: Int, gender: String,
         healthNotes: [String], bodyGoals: [String]) {
        self.id = id
        self.name = name
        self.goals = goals
        self.fitnessLevel = fitnessLevel
        self.weightLbs = weightLbs
        self.heightFeet = heightFeet
        self.heightInches = heightInches
        self.age = age
        self.gender = gender
        self.healthNotes = healthNotes
        self.bodyGoals = bodyGoals
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        fitnessLevel = try c.decode(String.self, forKey: .fitnessLevel)
        weightLbs = try c.decodeIfPresent(Int.self, forKey: .weightLbs) ?? 175
        heightFeet = try c.decodeIfPresent(Int.self, forKey: .heightFeet) ?? 5
        heightInches = try c.decodeIfPresent(Int.self, forKey: .heightInches) ?? 10
        age = try c.decodeIfPresent(Int.self, forKey: .age) ?? 30
        gender = try c.decodeIfPresent(String.self, forKey: .gender) ?? "prefer_not_to_say"
        healthNotes = try c.decode([String].self, forKey: .healthNotes)
        bodyGoals = try c.decode([String].self, forKey: .bodyGoals)
        if let arr = try c.decodeIfPresent([String].self, forKey: .goals), !arr.isEmpty {
            goals = arr
        } else if let legacy = try c.decodeIfPresent(String.self, forKey: .legacyGoal), !legacy.isEmpty {
            goals = [legacy]
        } else {
            goals = ["athleticism"]
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(goals, forKey: .goals)
        try c.encode(fitnessLevel, forKey: .fitnessLevel)
        try c.encode(weightLbs, forKey: .weightLbs)
        try c.encode(heightFeet, forKey: .heightFeet)
        try c.encode(heightInches, forKey: .heightInches)
        try c.encode(age, forKey: .age)
        try c.encode(gender, forKey: .gender)
        try c.encode(healthNotes, forKey: .healthNotes)
        try c.encode(bodyGoals, forKey: .bodyGoals)
    }

    static let empty = LocalUser(
        id: "",
        email: "",
        name: "Athlete",
        goals: ["athleticism"],
        fitnessLevel: "beginner",
        weightLbs: 175,
        heightFeet: 5,
        heightInches: 10,
        age: 30,
        gender: "prefer_not_to_say",
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

    func completeOnboarding(goals: [String], fitnessLevel: String,
                            weightLbs: Int, heightFeet: Int, heightInches: Int, age: Int, gender: String,
                            healthNotes: [String], bodyGoals: [String]) {
        update {
            $0.goals = goals
            $0.fitnessLevel = fitnessLevel
            $0.weightLbs = weightLbs
            $0.heightFeet = heightFeet
            $0.heightInches = heightInches
            $0.age = age
            $0.gender = gender
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
            goals: user.goals,
            fitnessLevel: user.fitnessLevel,
            weightLbs: user.weightLbs,
            heightFeet: user.heightFeet,
            heightInches: user.heightInches,
            age: user.age,
            gender: user.gender,
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
