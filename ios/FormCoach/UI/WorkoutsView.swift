import SwiftUI

struct WorkoutsView: View {
    @ObservedObject var userStore: UserStore
    @State private var sessions: [APISession] = []
    @State private var isLoading = true
    @State private var errorMsg: String?

    var body: some View {
        ZStack {
            KineticColor.bgDark.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if isLoading {
                        loadingView
                    } else if let err = errorMsg {
                        errorView(err)
                    } else if sessions.isEmpty {
                        emptyView
                    } else {
                        sessionList
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
            .refreshable { await load() }
        }
        .task { await load() }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Workouts")
                .font(KineticFont.display(32))
                .foregroundStyle(.white)
            Text("Your session history")
                .font(KineticFont.body(14))
                .foregroundStyle(KineticColor.textSecondary)
        }
    }

    private var loadingView: some View {
        VStack {
            ProgressView().tint(KineticColor.orange)
            Text("Loading sessions…")
                .font(KineticFont.body(13))
                .foregroundStyle(KineticColor.textSecondary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func errorView(_ message: String) -> some View {
        GlassCard {
            VStack(spacing: 10) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 28))
                    .foregroundStyle(KineticColor.warning)
                Text("Can't reach the backend")
                    .font(KineticFont.heading(15))
                    .foregroundStyle(.white)
                Text(message)
                    .font(KineticFont.body(12))
                    .foregroundStyle(KineticColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var emptyView: some View {
        GlassCard(padding: 28) {
            VStack(spacing: 10) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 34))
                    .foregroundStyle(KineticColor.orange)
                Text("No sessions yet")
                    .font(KineticFont.heading(16))
                    .foregroundStyle(.white)
                Text("Complete a workout from the Home tab and it'll show up here.")
                    .font(KineticFont.body(12))
                    .foregroundStyle(KineticColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var sessionList: some View {
        VStack(spacing: 12) {
            ForEach(sessions) { session in
                SessionCard(session: session)
            }
        }
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        errorMsg = nil
        do {
            sessions = try await APIClient.shared.getSessions()
        } catch {
            errorMsg = "Make sure the backend is running and your API URL is set correctly in Profile."
        }
        isLoading = false
    }
}

// MARK: - Session card

private struct SessionCard: View {
    let session: APISession

    private var date: String {
        let iso = ISO8601DateFormatter()
        guard let d = iso.date(from: session.createdAt) ?? iso.date(from: session.startedAt) else {
            return session.createdAt
        }
        return d.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    private var avgScore: Double {
        let arr = session.exercises.map(\.avgScore).filter { $0 > 0 }
        guard !arr.isEmpty else { return 0 }
        return arr.reduce(0, +) / Double(arr.count)
    }

    private var totalReps: Int {
        session.exercises.map(\.reps).reduce(0, +)
    }

    var body: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(date)
                            .font(KineticFont.heading(14))
                            .foregroundStyle(.white)
                        Text(exerciseNames)
                            .font(KineticFont.body(12))
                            .foregroundStyle(KineticColor.textSecondary)
                    }
                    Spacer()
                    ScoreBadge(score: avgScore)
                }

                HStack(spacing: 16) {
                    statPill(icon: "repeat",   value: "\(totalReps)", label: "reps")
                    statPill(icon: "clock",    value: formatDuration(session.totalDuration), label: "time")
                    statPill(icon: "chart.bar.fill",
                             value: "\(session.exercises.count)", label: "exercises")
                }
            }
        }
    }

    private var exerciseNames: String {
        let names = session.exercises.map { ex -> String in
            ExerciseType(rawValue: ex.exerciseId)?.displayName ?? ex.exerciseId.capitalized
        }
        return names.joined(separator: " · ")
    }

    private func statPill(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11))
            Text(value).font(KineticFont.heading(12))
            Text(label).font(KineticFont.caption(11)).foregroundStyle(KineticColor.textSecondary)
        }
        .foregroundStyle(.white)
    }

    private func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        return "\(seconds / 60)m"
    }
}

private struct ScoreBadge: View {
    let score: Double
    var color: Color {
        score > 80 ? KineticColor.success : score > 55 ? KineticColor.warning : KineticColor.danger
    }
    var body: some View {
        VStack(spacing: 0) {
            Text("\(Int(score))")
                .font(KineticFont.display(18))
                .foregroundStyle(color)
            Text("SCORE")
                .font(KineticFont.caption(8)).kerning(1)
                .foregroundStyle(KineticColor.textSecondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
