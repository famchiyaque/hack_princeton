import SwiftUI

enum AppFlow {
    case welcome, onboarding, main
}

enum MainTab: String, CaseIterable {
    case home, workouts, insights, profile

    var icon: String {
        switch self {
        case .home:     "house.fill"
        case .workouts: "figure.strengthtraining.traditional"
        case .insights: "chart.bar.fill"
        case .profile:  "person.fill"
        }
    }

    var title: String {
        switch self {
        case .home:     "Home"
        case .workouts: "Workouts"
        case .insights: "Insights"
        case .profile:  "Profile"
        }
    }
}

struct RootView: View {
    @StateObject private var userStore = UserStore.shared

    @State private var flow: AppFlow = .welcome
    @State private var selectedTab: MainTab = .home
    @State private var showSession = false
    @State private var showReport = false
    @State private var lastReport: SessionReport?

    var body: some View {
        ZStack {
            switch flow {
            case .welcome:
                WelcomeView(onGetStarted: {
                    flow = userStore.hasOnboarded ? .main : .onboarding
                })
                .transition(.opacity)

            case .onboarding:
                OnboardingView(
                    onComplete: { answers in
                        userStore.completeOnboarding(
                            goals: answers.goals,
                            fitnessLevel: answers.fitnessLevel,
                            weightLbs: answers.weightLbs,
                            heightFeet: answers.heightFeet,
                            heightInches: answers.heightInches,
                            age: answers.age,
                            gender: answers.gender,
                            healthNotes: answers.healthNotes,
                            bodyGoals: answers.bodyGoals
                        )
                        withAnimation(.easeInOut) { flow = .main }
                    },
                    onBackToWelcome: {
                        withAnimation(.easeInOut) { flow = .welcome }
                    }
                )
                .transition(.move(edge: .trailing))

            case .main:
                mainShell.transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: flow)
        .fullScreenCover(isPresented: $showSession) {
            SessionView(onEnd: { report in
                lastReport = report
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showReport = true
                }
            })
        }
        .fullScreenCover(isPresented: $showReport) {
            if let report = lastReport {
                ReportView(report: report, onDone: { showReport = false })
            }
        }
    }

    // MARK: - Main shell

    private var mainShell: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    DashboardView(userStore: userStore,
                                  onStartSession: { showSession = true })
                case .workouts:
                    WorkoutsView(userStore: userStore)
                case .insights:
                    InsightsView(userStore: userStore)
                case .profile:
                    ProfileView(userStore: userStore)
                }
            }
            BottomNavBar(selected: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Bottom nav bar

struct BottomNavBar: View {
    @Binding var selected: MainTab

    var body: some View {
        HStack {
            ForEach(MainTab.allCases, id: \.self) { tab in
                Button { selected = tab } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: .semibold))
                        Text(tab.title).font(KineticFont.caption(10))
                    }
                    .foregroundStyle(selected == tab ? KineticColor.orange : KineticColor.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1),
            alignment: .top
        )
    }
}
