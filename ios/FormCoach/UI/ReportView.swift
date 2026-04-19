import SwiftUI

struct ReportView: View {
    let report: SessionReport
    var onDone: () -> Void

    @State private var saveErrorDismissed: Bool = false

    var body: some View {
        ZStack {
            KineticColor.bgDark.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    if let err = report.saveError, !saveErrorDismissed {
                        saveErrorBanner(message: err)
                    }
                    header
                    statCards
                    tempoCard
                    strengthsSection
                    risksSection
                    precisionGraph
                    aiCoachPlaceholder
                    actions
                    Color.clear.frame(height: 80)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
    }

    // MARK: - Save-error banner

    private func saveErrorBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(KineticColor.warning)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text("Couldn't sync to server")
                    .font(KineticFont.heading(14))
                    .foregroundStyle(.white)
                Text("\(message). Showing local stats only.")
                    .font(KineticFont.body(12))
                    .foregroundStyle(KineticColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { saveErrorDismissed = true }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 24, height: 24)
                    .background(.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(KineticColor.warning.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(KineticColor.warning.opacity(0.45), lineWidth: 1)
        )
    }

    // MARK: - AI Coach review (live)

    private var aiCoachPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI COACH REVIEW")
                .font(KineticFont.caption(10)).kerning(2)
                .foregroundStyle(KineticColor.textSecondary)

            AICoachSummaryCard(sessionId: report.sessionId, saveError: report.saveError)
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

// MARK: - AI Coach summary card

/// Fetches the server-side AI summary for the session and renders it.
/// States: loading (shimmer), error (friendly message), ready (3-paragraph summary).
private struct AICoachSummaryCard: View {
    let sessionId: String?
    let saveError: String?

    @State private var phase: Phase = .loading
    @State private var shimmer: CGFloat = -1

    private enum Phase {
        case loading
        case ready(String)
        case error(String)
    }

    var body: some View {
        GlassCard(padding: 18) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(KineticColor.orangeSoft)
                        .frame(width: 40, height: 40)
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(KineticColor.orange)
                }

                VStack(alignment: .leading, spacing: 6) {
                    switch phase {
                    case .loading:
                        Text("Your AI coach is reviewing…")
                            .font(KineticFont.heading(15))
                            .foregroundStyle(.white)
                        Text("Analyzing your form, pacing, and corrections.")
                            .font(KineticFont.body(12))
                            .foregroundStyle(KineticColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    case .ready(let text):
                        Text("AI Coach Review")
                            .font(KineticFont.heading(15))
                            .foregroundStyle(.white)
                        Text(text)
                            .font(KineticFont.body(13))
                            .foregroundStyle(.white.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                    case .error(let message):
                        Text("AI review unavailable")
                            .font(KineticFont.heading(15))
                            .foregroundStyle(.white)
                        Text(message)
                            .font(KineticFont.body(12))
                            .foregroundStyle(KineticColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .overlay(isLoading ? AnyView(shimmerOverlay) : AnyView(EmptyView()))
        .mask(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onAppear { start() }
    }

    private var isLoading: Bool {
        if case .loading = phase { return true }
        return false
    }

    private func start() {
        if saveError != nil || sessionId == nil {
            phase = .error("Couldn't sync this session, so we can't generate a deeper review.")
            return
        }

        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: false)) {
            shimmer = 1.6
        }

        guard let id = sessionId else { return }
        Task { @MainActor in
            do {
                let summary = try await APIClient.shared.requestSessionSummary(sessionId: id)
                phase = .ready(summary)
            } catch {
                phase = .error("We couldn't reach the coach right now — try again later.")
            }
        }
    }

    private var shimmerOverlay: some View {
        GeometryReader { geo in
            let w = geo.size.width
            LinearGradient(
                colors: [
                    .clear,
                    KineticColor.orange.opacity(0.18),
                    .clear
                ],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: w * 0.6)
            .offset(x: w * shimmer)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
        }
    }
}
