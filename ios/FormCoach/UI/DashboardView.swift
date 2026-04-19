import SwiftUI

struct DashboardView: View {
    @ObservedObject var userStore: UserStore
    var onStartSession: () -> Void

    @State private var insights: APIInsights?
    @State private var latestSession: APISession?

    var body: some View {
        ZStack {
            KineticColor.bgDark.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    topBar
                    greeting
                    statsRow
                    programCard
                    startButton
                    lastSessionCard
                    weeklyInsights
                    Color.clear.frame(height: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .refreshable { await refresh() }
        }
        .task { await refresh() }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Circle()
                .fill(KineticColor.orangeSoft)
                .overlay(
                    Text(String(userStore.user.name.prefix(1)).uppercased())
                        .font(KineticFont.heading(16))
                        .foregroundStyle(KineticColor.orange)
                )
                .frame(width: 40, height: 40)

            Spacer()

            Text("KINETIC")
                .font(KineticFont.display(18))
                .kerning(4)
                .foregroundStyle(.white)

            Spacer()

            Button { } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(KineticColor.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
        }
    }

    // MARK: - Greeting

    private var greeting: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back,")
                    .font(KineticFont.body(15))
                    .foregroundStyle(KineticColor.textSecondary)
                Text("\(userStore.user.name)!")
                    .font(KineticFont.display(28))
                    .foregroundStyle(.white)
            }
            Spacer()
            let streak = insights?.streakDays ?? 0
            if streak > 0 {
                StreakPill(text: "\(streak)-DAY STREAK")
            }
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 12) {
            miniStat(icon: "flame.fill",  value: "\(insights?.totalReps ?? 0)",
                     label: "Total Reps", color: KineticColor.orange)
            miniStat(icon: "clock.fill",  value: "\(insights?.totalMinutes ?? 0)m",
                     label: "Trained", color: .cyan)
        }
    }

    private func miniStat(icon: String, value: String, label: String, color: Color) -> some View {
        GlassCard(padding: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(color.opacity(0.18)).frame(width: 36, height: 36)
                    Image(systemName: icon).foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(KineticFont.heading(16))
                        .foregroundStyle(.white)
                    Text(label)
                        .font(KineticFont.caption(11))
                        .foregroundStyle(KineticColor.textSecondary)
                }
                Spacer()
            }
        }
    }

    // MARK: - Program card

    private var programCard: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color(red: 0.18, green: 0.1, blue: 0.25),
                         Color(red: 0.4,  green: 0.15, blue: 0.05)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .overlay(
                Image(systemName: "figure.strengthtraining.functional")
                    .resizable().scaledToFit()
                    .foregroundStyle(.white.opacity(0.12))
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            )
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("TODAY'S FOCUS")
                    .font(KineticFont.caption(10)).kerning(2)
                    .foregroundStyle(KineticColor.textSecondary)
                Text(todaysProgram)
                    .font(KineticFont.display(24))
                    .foregroundStyle(.white)
                Text(planDescription)
                    .font(KineticFont.body(13))
                    .foregroundStyle(KineticColor.textSecondary)
            }
            .padding(20)
        }
    }

    private var todaysProgram: String {
        let primary = userStore.user.goals.first ?? "athleticism"
        switch primary {
        case "bodybuilding", "muscle": return "Hypertrophy Block"
        case "strength":     return "Strength Block"
        case "longevity":    return "Longevity & Recovery"
        case "fat_loss", "lose": return "Metabolic Circuit"
        case "athleticism", "form", "endure": return "Athletic Conditioning"
        case "aesthetic":    return "Sculpt & Define"
        case "physical_rehab": return "Recovery & Rehab"
        default:             return "Athletic Conditioning"
        }
    }

    private var planDescription: String {
        "Tailored for your \(levelDisplay) level"
    }

    private var levelDisplay: String {
        userStore.user.fitnessLevel.isEmpty ? "beginner" : userStore.user.fitnessLevel
    }

    // MARK: - Start button

    private var startButton: some View {
        Button(action: onStartSession) {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                Text("Start Session")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    // MARK: - Last session AI summary

    @ViewBuilder private var lastSessionCard: some View {
        if let session = latestSession, let summary = session.aiSummary, !summary.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Last Session Review")
                        .font(KineticFont.heading(18))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(relativeDate(session.createdAt))
                        .font(KineticFont.caption(11))
                        .foregroundStyle(KineticColor.textSecondary)
                }

                GlassCard(padding: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle().fill(KineticColor.orangeSoft).frame(width: 34, height: 34)
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(KineticColor.orange)
                        }
                        Text(summary)
                            .font(KineticFont.body(13))
                            .foregroundStyle(.white.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func relativeDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return "" }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .abbreviated
        return rel.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Weekly insights

    private var weeklyInsights: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Insights")
                .font(KineticFont.heading(18))
                .foregroundStyle(.white)
                .padding(.top, 4)

            if let i = insights, i.totalSessions > 0 {
                insightRow(icon: "chart.line.uptrend.xyaxis", title: "Avg Form Score",
                           trend: "\(Int(i.overallAvgScore))%", trendUp: i.overallAvgScore >= 70,
                           color: KineticColor.success)
                insightRow(icon: "repeat", title: "Sessions Logged",
                           trend: "\(i.totalSessions)", trendUp: true,
                           color: KineticColor.orange)
                if let top = i.topCorrections.first {
                    insightRow(icon: "exclamationmark.triangle.fill",
                               title: "Focus: \(SessionAnalyzer.humanize(top.type))",
                               trend: "\(top.count)x", trendUp: false,
                               color: KineticColor.warning)
                }
            } else {
                GlassCard {
                    Text("Complete a session to see insights appear here.")
                        .font(KineticFont.body(13))
                        .foregroundStyle(KineticColor.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func insightRow(icon: String, title: String, trend: String, trendUp: Bool, color: Color) -> some View {
        GlassCard(padding: 14) {
            HStack {
                ZStack {
                    Circle().fill(color.opacity(0.18)).frame(width: 38, height: 38)
                    Image(systemName: icon).foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(KineticFont.heading(14))
                        .foregroundStyle(.white)
                    Text("Last 7 days")
                        .font(KineticFont.caption(11))
                        .foregroundStyle(KineticColor.textSecondary)
                }
                Spacer()
                Text(trend)
                    .font(KineticFont.caption(13))
                    .foregroundStyle(trendUp ? KineticColor.success : color)
            }
        }
    }

    // MARK: - Data

    private func refresh() async {
        async let insightsTask = APIClient.shared.getInsights()
        async let sessionsTask = APIClient.shared.getSessions(limit: 1)
        insights = try? await insightsTask
        latestSession = (try? await sessionsTask)?.first
    }
}
