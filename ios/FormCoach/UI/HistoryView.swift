import SwiftUI

struct HistoryView: View {
    @State private var sessions: [APISession] = []
    @State private var isLoading = true
    @State private var errorMsg: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading history…")
                } else if let err = errorMsg {
                    ContentUnavailableView(
                        "Couldn't Load History",
                        systemImage: "wifi.slash",
                        description: Text(err)
                    )
                } else if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions Yet",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("Complete a workout to see it here.")
                    )
                } else {
                    List(sessions) { session in
                        SessionRow(session: session)
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        errorMsg = nil
        do {
            sessions = try await APIClient.shared.getSessions()
        } catch {
            errorMsg = "Make sure the backend is running on your laptop."
        }
        isLoading = false
    }
}

private struct SessionRow: View {
    let session: APISession

    private var dateString: String {
        let iso = ISO8601DateFormatter()
        guard let date = iso.date(from: session.createdAt) else { return session.createdAt }
        return date.formatted(.dateTime.month().day().hour().minute())
    }

    private var avgScore: Double {
        let scores = session.exercises.map(\.avgScore)
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(dateString).font(.subheadline.bold())
                Spacer()
                ScoreChip(score: avgScore)
            }

            HStack(spacing: 16) {
                Label("\(session.exercises.map(\.reps).reduce(0, +)) reps", systemImage: "repeat")
                Label(formatDuration(session.totalDuration), systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            let names = session.exercises.map(\.exerciseId).map { $0.capitalized }.joined(separator: ", ")
            if !names.isEmpty {
                Text(names).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDuration(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds)s" : "\(seconds / 60)m \(seconds % 60)s"
    }
}

private struct ScoreChip: View {
    let score: Double
    var color: Color { score > 80 ? .green : score > 55 ? .orange : .red }

    var body: some View {
        Text("\(Int(score))")
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color, in: Capsule())
    }
}
