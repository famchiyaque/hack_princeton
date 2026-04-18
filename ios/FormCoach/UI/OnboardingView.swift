import SwiftUI

// MARK: - Option models

struct OnboardingOption: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
}

struct OnboardingAnswers {
    var goals: [String] = []
    var fitnessLevel: String = ""
    var weightLbs: Int = 175
    var heightFeet: Int = 5
    var heightInches: Int = 10
    var age: Int = 30
    var gender: String = "prefer_not_to_say"
    var healthNotes: [String] = []
    var bodyGoals: [String] = []
}

// MARK: - Onboarding flow

struct OnboardingView: View {
    var onComplete: (OnboardingAnswers) -> Void
    /// Returns to the welcome screen (Get Started / Sign In) from step 1.
    var onBackToWelcome: () -> Void = {}

    @State private var step = 1
    /// Sub-steps inside profile step (weight → height → age → gender).
    @State private var profileSubstep = 0
    @State private var answers = OnboardingAnswers()
    private let totalSteps = 5

    private let weightPickerRange = Array(80...400)
    private let heightFeetRange = Array(4...7)
    private let heightInchesRange = Array(0...11)
    private let agePickerRange = Array(13...100)
    private let genderPickerOptions: [(id: String, title: String)] = [
        ("male", "Male"),
        ("female", "Female"),
        ("non_binary", "Non-binary"),
        ("prefer_not_to_say", "Prefer not to say"),
    ]

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        stepContent
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 120)
                }

                continueButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("STEP \(stepPadded(step)) / \(stepPadded(totalSteps))")
                        .font(KineticFont.caption(11)).kerning(2)
                        .foregroundStyle(.gray)
                    if step == 3 {
                        Text("Profile · \(profileSubstep + 1) of 4")
                            .font(KineticFont.caption(10)).kerning(1)
                            .foregroundStyle(KineticColor.orange.opacity(0.9))
                    }
                }
                Spacer()
                Button { goBack() } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(KineticFont.caption(12))
                        .foregroundStyle(.gray)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.06))
                    Capsule()
                        .fill(KineticColor.orange)
                        .frame(width: geo.size.width * CGFloat(step) / CGFloat(totalSteps))
                        .animation(.easeInOut, value: step)
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 1: goalStep
        case 2: fitnessLevelStep
        case 3: profileStep
        case 4: healthStep
        default: bodyGoalsStep
        }
    }

    private func stepPadded(_ n: Int) -> String {
        n < 10 ? "0\(n)" : "\(n)"
    }

    // MARK: - Step 3: profile (4 wheel questions)

    @ViewBuilder
    private var profileStep: some View {
        switch profileSubstep {
        case 0: profileWeightQuestion
        case 1: profileHeightQuestion
        case 2: profileAgeQuestion
        default: profileGenderQuestion
        }
    }

    private var profileWeightQuestion: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's your")
                + Text("\nweight?").foregroundColor(KineticColor.orangeDeep)
            Text("Scroll to select — pounds (lb)")
                .font(KineticFont.body(13))
                .foregroundStyle(.gray)
            wheelPicker {
                Picker("Weight", selection: $answers.weightLbs) {
                    ForEach(weightPickerRange, id: \.self) { w in
                        Text("\(w) lb").tag(w)
                    }
                }
                .pickerStyle(.wheel)
            }
        }
        .font(KineticFont.display(26))
        .foregroundStyle(.black)
    }

    private var profileHeightQuestion: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's your")
                + Text("\nheight?").foregroundColor(KineticColor.orangeDeep)
            Text("Feet and inches")
                .font(KineticFont.body(13))
                .foregroundStyle(.gray)
            wheelPicker {
                HStack(spacing: 0) {
                    Picker("Feet", selection: $answers.heightFeet) {
                        ForEach(heightFeetRange, id: \.self) { ft in
                            Text("\(ft) ft").tag(ft)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    Picker("Inches", selection: $answers.heightInches) {
                        ForEach(heightInchesRange, id: \.self) { inch in
                            Text("\(inch) in").tag(inch)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .font(KineticFont.display(26))
        .foregroundStyle(.black)
    }

    private var profileAgeQuestion: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How old")
                + Text("\nare you?").foregroundColor(KineticColor.orangeDeep)
            Text("Scroll to select your age")
                .font(KineticFont.body(13))
                .foregroundStyle(.gray)
            wheelPicker {
                Picker("Age", selection: $answers.age) {
                    ForEach(agePickerRange, id: \.self) { y in
                        Text("\(y) years").tag(y)
                    }
                }
                .pickerStyle(.wheel)
            }
        }
        .font(KineticFont.display(26))
        .foregroundStyle(.black)
    }

    private var profileGenderQuestion: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How do you")
                + Text("\nidentify?").foregroundColor(KineticColor.orangeDeep)
            Text("Scroll to select")
                .font(KineticFont.body(13))
                .foregroundStyle(.gray)
            wheelPicker {
                Picker("Gender", selection: $answers.gender) {
                    ForEach(genderPickerOptions, id: \.id) { opt in
                        Text(opt.title).tag(opt.id)
                    }
                }
                .pickerStyle(.wheel)
            }
        }
        .font(KineticFont.display(26))
        .foregroundStyle(.black)
    }

    private func wheelPicker<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(height: 192)
            .background(Color.black.opacity(0.03), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Step 1: fitness goals (multi-select)

    private let goals: [OnboardingOption] = [
        .init(id: "bodybuilding", title: "Bodybuilding", subtitle: "Hypertrophy", icon: "figure.strengthtraining.traditional"),
        .init(id: "strength", title: "Strength", subtitle: "Powerlifting", icon: "scalemass.fill"),
        .init(id: "longevity", title: "Longevity", subtitle: "Sustainable training", icon: "leaf.fill"),
        .init(id: "fat_loss", title: "Fat Loss", subtitle: "Lean out", icon: "flame.fill"),
        .init(id: "athleticism", title: "Athleticism", subtitle: "Speed & agility", icon: "figure.run"),
        .init(id: "aesthetic", title: "Aesthetic", subtitle: "Sculpt & symmetry", icon: "sparkles"),
        .init(id: "physical_rehab", title: "Physical Rehab", subtitle: "Recovery & care", icon: "bandage.fill"),
    ]

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What are your")
                + Text("\nfitness goals?").foregroundColor(KineticColor.orangeDeep)

            Text("Select all that apply")
                .font(KineticFont.body(13))
                .foregroundStyle(.gray)

            gridOfGoalOptions(
                goals,
                selected: { answers.goals.contains($0.id) },
                tap: { opt in
                    if answers.goals.contains(opt.id) {
                        answers.goals.removeAll { $0 == opt.id }
                    } else {
                        answers.goals.append(opt.id)
                    }
                }
            )
        }
        .font(KineticFont.display(26))
        .foregroundStyle(.black)
    }

    // MARK: - Step 2: fitness level

    private let levels: [OnboardingOption] = [
        .init(id: "beginner",    title: "Beginner",    subtitle: "0–6 months training",   icon: "sparkles"),
        .init(id: "intermediate", title: "Intermediate", subtitle: "6–24 months",         icon: "flame.fill"),
        .init(id: "advanced",    title: "Advanced",    subtitle: "2+ years consistent",   icon: "bolt.fill"),
    ]

    private var fitnessLevelStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's your current")
                + Text("\nfitness level?").foregroundColor(KineticColor.orangeDeep)

            VStack(spacing: 12) {
                ForEach(levels) { level in
                    listOption(level, isSelected: answers.fitnessLevel == level.id) {
                        answers.fitnessLevel = level.id
                    }
                }
            }
        }
        .font(KineticFont.display(26))
        .foregroundStyle(.black)
    }

    // MARK: - Step 4: health notes (multi-select)

    private let healthOptions: [OnboardingOption] = [
        .init(id: "knee_pain",     title: "Knee Pain",      subtitle: "Avoid deep squats",          icon: "figure.walk"),
        .init(id: "lower_back",    title: "Lower Back",     subtitle: "Careful with deadlifts",     icon: "figure.mind.and.body"),
        .init(id: "shoulder",      title: "Shoulder Injury", subtitle: "Modify pressing movements", icon: "figure.arms.open"),
        .init(id: "wrist",         title: "Wrist Pain",     subtitle: "Use modified push-ups",      icon: "hand.raised.fill"),
        .init(id: "none",          title: "No Issues",      subtitle: "Ready for anything",         icon: "checkmark.seal.fill"),
    ]

    private var healthStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Any health notes")
                + Text("\nwe should know?").foregroundColor(KineticColor.orangeDeep)

            Text("Select all that apply")
                .font(KineticFont.body(13))
                .foregroundStyle(.gray)

            VStack(spacing: 10) {
                ForEach(healthOptions) { opt in
                    listOption(opt, isSelected: answers.healthNotes.contains(opt.id)) {
                        toggle(opt.id, in: &answers.healthNotes, exclusiveWith: "none")
                    }
                }
            }
        }
        .font(KineticFont.display(26))
        .foregroundStyle(.black)
    }

    // MARK: - Step 5: body goals

    private let bodyGoalOptions: [OnboardingOption] = [
        .init(id: "stronger_core",  title: "Stronger Core",    subtitle: "Stability & posture",    icon: "figure.core.training"),
        .init(id: "better_posture", title: "Better Posture",   subtitle: "Open up the chest",      icon: "figure.stand"),
        .init(id: "more_mobility",  title: "More Mobility",    subtitle: "Move more freely",       icon: "figure.flexibility"),
        .init(id: "explosive",      title: "Explosive Power",  subtitle: "Jump higher, hit harder", icon: "bolt.fill"),
    ]

    private var bodyGoalsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What body goals")
                + Text("\nmatter most?").foregroundColor(KineticColor.orangeDeep)

            Text("Select up to three")
                .font(KineticFont.body(13))
                .foregroundStyle(.gray)

            gridOfOptions(
                bodyGoalOptions,
                selected: { answers.bodyGoals.contains($0.id) },
                tap: { opt in
                    if answers.bodyGoals.contains(opt.id) {
                        answers.bodyGoals.removeAll { $0 == opt.id }
                    } else if answers.bodyGoals.count < 3 {
                        answers.bodyGoals.append(opt.id)
                    }
                }
            )
        }
        .font(KineticFont.display(26))
        .foregroundStyle(.black)
    }

    // MARK: - Option primitives

    private func gridOfGoalOptions(_ options: [OnboardingOption],
                                   selected: @escaping (OnboardingOption) -> Bool,
                                   tap: @escaping (OnboardingOption) -> Void) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible())], spacing: 12) {
            ForEach(options) { opt in
                goalGridCard(opt, isSelected: selected(opt)) { tap(opt) }
            }
        }
    }

    private func goalGridCard(_ opt: OnboardingOption, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle().fill(isSelected ? KineticColor.orange : Color.black.opacity(0.05))
                            .frame(width: 44, height: 44)
                        OnboardingGoalAvatarView(goalId: opt.id, isSelected: isSelected)
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(KineticColor.orange)
                            .font(.system(size: 20))
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(opt.title).font(KineticFont.heading(15)).foregroundStyle(.black)
                    Text(opt.subtitle).font(KineticFont.body(11)).foregroundStyle(.gray)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? KineticColor.orange : Color.black.opacity(0.08),
                                  lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func gridOfOptions(_ options: [OnboardingOption],
                                selected: @escaping (OnboardingOption) -> Bool,
                                tap: @escaping (OnboardingOption) -> Void) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible())], spacing: 12) {
            ForEach(options) { opt in
                gridCard(opt, isSelected: selected(opt)) { tap(opt) }
            }
        }
    }

    private func gridCard(_ opt: OnboardingOption, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle().fill(isSelected ? KineticColor.orange : Color.black.opacity(0.05))
                            .frame(width: 44, height: 44)
                        Image(systemName: opt.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : .black)
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(KineticColor.orange)
                            .font(.system(size: 20))
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(opt.title).font(KineticFont.heading(15)).foregroundStyle(.black)
                    Text(opt.subtitle).font(KineticFont.body(11)).foregroundStyle(.gray)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? KineticColor.orange : Color.black.opacity(0.08),
                                  lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func listOption(_ opt: OnboardingOption, isSelected: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(isSelected ? KineticColor.orange : Color.black.opacity(0.05))
                        .frame(width: 44, height: 44)
                    Image(systemName: opt.icon)
                        .foregroundStyle(isSelected ? .white : .black)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(opt.title).font(KineticFont.heading(15)).foregroundStyle(.black)
                    Text(opt.subtitle).font(KineticFont.body(12)).foregroundStyle(.gray)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(KineticColor.orange)
                        .font(.system(size: 22))
                }
            }
            .padding(16)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? KineticColor.orange : Color.black.opacity(0.08),
                                  lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Continue button

    private var continueButton: some View {
        Button { advance() } label: {
            HStack(spacing: 8) {
                Text(continueButtonTitle)
                Image(systemName: "arrow.right")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .opacity(canProceed ? 1 : 0.45)
        .disabled(!canProceed)
    }

    private var continueButtonTitle: String {
        if step == totalSteps { return "Finish" }
        if step == 3, profileSubstep < 3 { return "Next" }
        return "Continue"
    }

    private var canProceed: Bool {
        switch step {
        case 1: !answers.goals.isEmpty
        case 2: !answers.fitnessLevel.isEmpty
        case 3: true
        case 4: !answers.healthNotes.isEmpty
        case 5: !answers.bodyGoals.isEmpty
        default: false
        }
    }

    private func goBack() {
        if step == 1 {
            onBackToWelcome()
            return
        }
        if step == 3 {
            if profileSubstep > 0 {
                profileSubstep -= 1
            } else {
                step = 2
            }
            return
        }
        step -= 1
    }

    private func advance() {
        if step == 3 {
            if profileSubstep < 3 {
                profileSubstep += 1
                return
            }
            step = 4
            return
        }
        if step < totalSteps {
            step += 1
            if step == 3 {
                profileSubstep = 0
            }
        } else {
            onComplete(answers)
        }
    }

    private func toggle(_ id: String, in arr: inout [String], exclusiveWith exclusiveId: String) {
        if id == exclusiveId {
            arr = [exclusiveId]
        } else {
            arr.removeAll { $0 == exclusiveId }
            if arr.contains(id) {
                arr.removeAll { $0 == id }
            } else {
                arr.append(id)
            }
        }
    }
}

#Preview { OnboardingView(onComplete: { _ in }) }
