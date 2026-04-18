import SwiftUI

struct ReportView: View {
    let report: SessionReport
    var onDone: () -> Void

    var body: some View {
        ZStack {
            KineticColor.bgDark.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    header
                    statCards
                    tempoCard
                    strengthsSection
                    risksSection
                    precisionGraph
                    actions
                    Color.clear.frame(height: 80)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(KineticColor.success)
                Text("SESSION COMPLETE!")
                    .font(KineticFont.caption(11)).kerning(2)
                    .foregroundStyle(KineticColor.success)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(KineticColor.success.opacity(0.15), in: Capsule())

            Text("Mastery")
                .font(KineticFont.display(36))
                .foregroundStyle(.white)
            + Text(" Achieved")
                .font(KineticFont.display(36))
                .foregroundStyle(KineticColor.orange)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Stat cards

    private var statCards: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statBox(title: "Duration", value: formatDuration(report.duration),
                        icon: "clock.fill", accent: .cyan)
                statBox(title: report.exercise.displayName + "s",
                        value: "\(report.reps)", icon: "repeat",
                        accent: KineticColor.orange)
            }

            GlassCard(padding: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("FORM SCORE")
                                .font(KineticFont.caption(10)).kerning(2)
                                .foregroundStyle(KineticColor.textSecondary)
                            Text("\(Int(report.avgScore))%")
                                .font(KineticFont.display(32))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        ZStack {
                            Circle().stroke(Color.white.opacity(0.12), lineWidth: 6).frame(width: 56, height: 56)
                            Circle()
                                .trim(from: 0, to: min(1, report.avgScore / 100))
                                .stroke(KineticColor.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 56, height: 56)
                        }
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.12))
                            Capsule()
                                .fill(LinearGradient(colors: [KineticColor.orange, KineticColor.orangeDeep],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * min(1, report.avgScore / 100))
                        }
                    }
                    .frame(height: 6)

                    HStack {
                        Label("Consistency \(Int(report.consistency))%", systemImage: "waveform")
                        Spacer()
                        Label(report.tempo.label, systemImage: "metronome")
                    }
                    .font(KineticFont.caption(11))
                    .foregroundStyle(KineticColor.textSecondary)
                    .padding(.top, 4)
                }
            }
        }
    }

    private func statBox(title: String, value: String, icon: String, accent: Color) -> some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    Circle().fill(accent.opacity(0.18)).frame(width: 34, height: 34)
                    Image(systemName: icon).foregroundStyle(accent)
                }
                Text(value)
                    .font(KineticFont.display(22))
                    .foregroundStyle(.white)
                Text(title)
                    .font(KineticFont.caption(11))
                    .foregroundStyle(KineticColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Tempo card

    @ViewBuilder private var tempoCard: some View {
        if report.reps > 0 {
            GlassCard(padding: 16) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TEMPO")
                            .font(KineticFont.caption(10)).kerning(2)
                            .foregroundStyle(KineticColor.textSecondary)
                        Text(String(format: "%.1fs", report.tempo.avgRepSeconds))
                            .font(KineticFont.display(20))
                            .foregroundStyle(.white)
                        Text("per rep avg")
                            .font(KineticFont.caption(11))
                            .foregroundStyle(KineticColor.textSecondary)
                    }
                    Divider().background(Color.white.opacity(0.15)).frame(height: 50)
                    tempoStat(label: "Fastest", value: String(format: "%.1fs", report.tempo.fastest))
                    tempoStat(label: "Slowest", value: String(format: "%.1fs", report.tempo.slowest))
                    Spacer()
                }
            }
        }
    }

    private func tempoStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(KineticFont.caption(10)).kerning(2)
                .foregroundStyle(KineticColor.textSecondary)
            Text(value).font(KineticFont.heading(15)).foregroundStyle(.white)
        }
    }

    // MARK: - Strengths / Risks

    @ViewBuilder private var strengthsSection: some View {
        if !report.strengths.isEmpty {
            insightSection(
                title: "What You Did Well",
                icon: "checkmark.circle.fill",
                color: KineticColor.success,
                items: report.strengths
            )
        }
    }

    @ViewBuilder private var risksSection: some View {
        if !report.risks.isEmpty {
            insightSection(
                title: "Key Risks & Focus Areas",
                icon: "exclamationmark.triangle.fill",
                color: KineticColor.warning,
                items: report.risks
            )
        }
    }

    private func insightSection(title: String, icon: String, color: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(KineticFont.heading(17))
                .foregroundStyle(.white)

            ForEach(Array(items.enumerated()), id: \.offset) { _, text in
                GlassCard(padding: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: icon).foregroundStyle(color)
                            .padding(.top, 2)
                        Text(text)
                            .font(KineticFont.body(13))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    // MARK: - Precision graph

    private var precisionGraph: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Form Precision")
                .font(KineticFont.heading(17))
                .foregroundStyle(.white)

            GlassCard(padding: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Score per rep")
                        .font(KineticFont.caption(11))
                        .foregroundStyle(KineticColor.textSecondary)

                    if report.perRepScores.isEmpty {
                        Text("No reps tracked this session.")
                            .font(KineticFont.body(13))
                            .foregroundStyle(KineticColor.textMuted)
                            .frame(maxWidth: .infinity, minHeight: 80)
                    } else {
                        barChart
                    }
                }
            }
        }
    }

    private var barChart: some View {
        GeometryReader { geo in
            let count = report.perRepScores.count
            let spacing: CGFloat = 4
            let barWidth = max(4, (geo.size.width - CGFloat(count - 1) * spacing) / CGFloat(count))
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(report.perRepScores.enumerated()), id: \.offset) { _, score in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color(for: score))
                        .frame(width: barWidth, height: max(4, geo.size.height * (score / 100)))
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 100)
    }

    private func color(for score: Double) -> Color {
        if score > 80 { return KineticColor.success }
        if score > 55 { return KineticColor.warning }
        return KineticColor.danger
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 12) {
            Button(action: onDone) { Text("Done") }
                .buttonStyle(PrimaryButtonStyle())
            Button {} label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Results")
                }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(.top, 8)
    }

    private func formatDuration(_ seconds: Int) -> String {
        if seconds >= 60 { return "\(seconds / 60)m \(seconds % 60)s" }
        return "\(seconds)s"
    }
}
