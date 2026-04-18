import SwiftUI

// MARK: - Option models

struct OnboardingOption: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
}

struct OnboardingAnswers {
    var goal: String = ""
    var fitnessLevel: String = ""
    var healthNotes: [String] = []
    var bodyGoals: [String] = []
}

// MARK: - Onboarding flow

struct OnboardingView: View {
    var onComplete: (OnboardingAnswers) -> Void

    @State private var step = 1
    @State private var answers = OnboardingAnswers()
    private let totalSteps = 4

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
            HStack {
                Text("STEP 0\(step) / 0\(totalSteps)")
                    .font(KineticFont.caption(11)).kerning(2)
                    .foregroundStyle(.gray)
                Spacer()
                if step > 1 {
                    Button { step -= 1 } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(KineticFont.caption(12))
                            .foregroundStyle(.gray)
                    }
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
        case 3: healthStep
        default: bodyGoalsStep
        }
    }

    // MARK: - Step 1: primary goal

    private let goals: [OnboardingOption] = [
        .init(id: "muscle", title: "Build Muscle",  subtitle: "Hypertrophy focus",   icon: "dumbbell.fill"),
        .init(id: "lose",   title: "Lose Weight",   subtitle: "Fat loss program",    icon: "heart.fill"),
        .init(id: "form",   title: "Improve Form",  subtitle: "AI-guided coaching",  icon: "figure.mind.and.body"),
        .init(id: "endure", title: "Endurance",     subtitle: "Cardio & stamina",    icon: "bolt.heart.fill"),
    ]

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What is your primary")
                + Text("\nfitness goal?").foregroundColor(KineticColor.orangeDeep)
            gridOfOptions(
                goals,
                selected: { answers.goal == $0.id },
                tap: { answers.goal = $0.id }
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

    // MARK: - Step 3: health notes (multi-select)

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

    // MARK: - Step 4: body goals

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
                Text(step == totalSteps ? "Finish" : "Continue")
                Image(systemName: "arrow.right")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .opacity(canProceed ? 1 : 0.45)
        .disabled(!canProceed)
    }

    private var canProceed: Bool {
        switch step {
        case 1: !answers.goal.isEmpty
        case 2: !answers.fitnessLevel.isEmpty
        case 3: !answers.healthNotes.isEmpty
        case 4: !answers.bodyGoals.isEmpty
        default: false
        }
    }

    private func advance() {
        if step < totalSteps {
            step += 1
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
