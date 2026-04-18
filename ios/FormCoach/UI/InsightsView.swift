import SwiftUI

struct InsightsView: View {
    @ObservedObject var userStore: UserStore
    @State private var insights: APIInsights?
    @State private var isLoading = true
    @State private var errorMsg: String?

    var body: some View {
        ZStack {
            KineticColor.bgDark.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if isLoading {
                        ProgressView().tint(KineticColor.orange)
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let err = errorMsg {
                        errorCard(err)
                    } else if let insights {
                        content(insights)
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

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Insights")
                .font(KineticFont.display(32))
                .foregroundStyle(.white)
            Text("Your progress over time")
                .font(KineticFont.body(14))
                .foregroundStyle(KineticColor.textSecondary)
        }
    }

    private func errorCard(_ msg: String) -> some View {
        GlassCard {
            VStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 28)).foregroundStyle(KineticColor.warning)
                Text("Backend unreachable")
                    .font(KineticFont.heading(14)).foregroundStyle(.white)
                Text(msg).font(KineticFont.body(12))
                    .foregroundStyle(KineticColor.textSecondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func content(_ i: APIInsights) -> some View {
        VStack(spacing: 16) {
            // Top stat grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                stat("Sessions", "\(i.totalSessions)", icon: "square.stack.3d.up.fill", color: KineticColor.orange)
                stat("Total Reps", "\(i.totalReps)", icon: "repeat", color: .cyan)
                stat("Minutes", "\(i.totalMinutes)", icon: "clock.fill", color: .purple)
                stat("Avg Score", "\(Int(i.overallAvgScore))%", icon: "chart.line.uptrend.xyaxis", color: KineticColor.success)
            }

            // Streak + weekly activity
            GlassCard(padding: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CURRENT STREAK")
                                .font(KineticFont.caption(10)).kerning(2)
                                .foregroundStyle(KineticColor.textSecondary)
                            Text("\(i.streakDays) day\(i.streakDays == 1 ? "" : "s")")
                                .font(KineticFont.display(24))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Image(systemName: "flame.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(KineticColor.orange)
                    }

                    Divider().background(Color.white.opacity(0.1))

                    Text("LAST 7 DAYS").font(KineticFont.caption(10)).kerning(2)
                        .foregroundStyle(KineticColor.textSecondary)

                    weeklyBars(minutes: i.last7DaysMinutes)
                }
            }

            // By exercise
            if !i.byExercise.isEmpty {
                section(title: "By Exercise") {
                    VStack(spacing: 10) {
                        ForEach(i.byExercise) { s in
                            exerciseRow(s)
                        }
                    }
                }
            }

            // Top corrections
            if !i.topCorrections.isEmpty {
                section(title: "Most-Flagged Issues") {
                    VStack(spacing: 10) {
                        ForEach(i.topCorrections, id: \.type) { c in
                            GlassCard(padding: 12) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(KineticColor.warning)
                                    Text(SessionAnalyzer.humanize(c.type))
                                        .font(KineticFont.heading(14))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text("\(c.count)x").font(KineticFont.caption(12))
                                        .foregroundStyle(KineticColor.textSecondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func section<Content: View>(title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(KineticFont.heading(17)).foregroundStyle(.white)
            content()
        }
    }

    private func stat(_ label: String, _ value: String, icon: String, color: Color) -> some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    Circle().fill(color.opacity(0.18)).frame(width: 34, height: 34)
                    Image(systemName: icon).foregroundStyle(color)
                }
                Text(value).font(KineticFont.display(22)).foregroundStyle(.white)
                Text(label).font(KineticFont.caption(11)).foregroundStyle(KineticColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func weeklyBars(minutes: [Int]) -> some View {
        let maxV = max(minutes.max() ?? 1, 1)
        let labels = ["6d", "5d", "4d", "3d", "2d", "1d", "Today"]
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(minutes.enumerated()), id: \.offset) { idx, m in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(m > 0 ? KineticColor.orange : Color.white.opacity(0.1))
                        .frame(height: max(6, CGFloat(m) / CGFloat(maxV) * 70))
                    Text(labels[safe: idx] ?? "")
                        .font(KineticFont.caption(9))
                        .foregroundStyle(KineticColor.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 100)
    }

    private func exerciseRow(_ stat: APIExerciseStat) -> some View {
        let exercise = ExerciseType(rawValue: stat.exerciseId) ?? .unknown
        return GlassCard(padding: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(KineticColor.orangeSoft).frame(width: 38, height: 38)
                    Image(systemName: exercise.icon).foregroundStyle(KineticColor.orange)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.displayName)
                        .font(KineticFont.heading(14)).foregroundStyle(.white)
                    Text("\(stat.totalReps) reps · \(stat.sessionCount) sessions")
                        .font(KineticFont.caption(11))
                        .foregroundStyle(KineticColor.textSecondary)
                }
                Spacer()
                Text("\(Int(stat.avgScore))")
                    .font(KineticFont.heading(14))
                    .foregroundStyle(KineticColor.orange)
            }
        }
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        errorMsg = nil
        do {
            insights = try await APIClient.shared.getInsights()
        } catch {
            errorMsg = "Can't reach the backend. Check API URL in Profile."
        }
        isLoading = false
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
