import SwiftUI

enum AppFlow {
    case loading     // checking persisted auth session on launch
    case welcome     // not authenticated
    case login       // email/password login form
    case signup      // email/password signup form
    case onboarding  // first-time profile setup (post-auth)
    case main        // authenticated + onboarded
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
    @StateObject private var authManager = AuthManager.shared

    @State private var flow: AppFlow = .loading
    @State private var selectedTab: MainTab = .home
    @State private var showSession = false
    @State private var showReport = false
    @State private var lastReport: SessionReport?

    var body: some View {
        ZStack {
            switch flow {
            case .loading:
                loadingView

            case .welcome:
                WelcomeView(
                    onGetStarted: { withAnimation(.easeInOut) { flow = .signup } },
                    onSignIn: { withAnimation(.easeInOut) { flow = .login } }
                )
                .transition(.opacity)

            case .login:
                LoginView(
                    onSuccess: { handleAuthSuccess() },
                    onSwitchToSignUp: { withAnimation(.easeInOut) { flow = .signup } },
                    onBack: { withAnimation(.easeInOut) { flow = .welcome } }
                )
                .transition(.move(edge: .trailing))

            case .signup:
                SignUpView(
                    onSuccess: { handleAuthSuccess() },
                    onSwitchToLogin: { withAnimation(.easeInOut) { flow = .login } },
                    onBack: { withAnimation(.easeInOut) { flow = .welcome } }
                )
                .transition(.move(edge: .trailing))

            case .onboarding:
                OnboardingView(onComplete: { answers in
                    userStore.completeOnboarding(
                        goal: answers.goal,
                        fitnessLevel: answers.fitnessLevel,
                        healthNotes: answers.healthNotes,
                        bodyGoals: answers.bodyGoals
                    )
                    withAnimation(.easeInOut) { flow = .main }
                })
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
        .task {
            await authManager.restoreSession()
            if authManager.isAuthenticated {
                userStore.bindToAuthUser(
                    id: authManager.userId!,
                    email: authManager.userEmail ?? ""
                )
                flow = userStore.hasOnboarded ? .main : .onboarding
            } else {
                flow = .welcome
            }
        }
        .onChange(of: authManager.session == nil) { _, isNil in
            if isNil { flow = .welcome }
        }
    }

    // MARK: - Auth success handler

    private func handleAuthSuccess() {
        guard let userId = authManager.userId else { return }
        userStore.bindToAuthUser(id: userId, email: authManager.userEmail ?? "")

        Task {
            let backendUser = try? await APIClient.shared.getMe()
            let isNewUser = backendUser == nil || backendUser?.goal == "form" && !userStore.hasOnboarded
            withAnimation(.easeInOut) {
                flow = isNewUser ? .onboarding : .main
            }
            if let existing = backendUser, existing.goal != "form" {
                userStore.hydrateFromBackend(existing)
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        ZStack {
            KineticColor.bgDark.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("KINETIC")
                    .font(KineticFont.display(34))
                    .kerning(6)
                    .foregroundStyle(.white)
                ProgressView()
                    .tint(KineticColor.orange)
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
