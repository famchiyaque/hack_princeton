import SwiftUI

struct ProfileView: View {
    @ObservedObject var userStore: UserStore
    @State private var editingName = false
    @State private var tempName = ""
    @State private var showAPIEditor = false
    @State private var apiURL = APIClient.shared.baseURL
    @State private var showResetConfirm = false

    var body: some View {
        ZStack {
            KineticColor.bgDark.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    avatarCard
                    goalsCard
                    healthCard
                    developerCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .alert("Your Name", isPresented: $editingName) {
            TextField("Name", text: $tempName)
            Button("Save") { userStore.setName(tempName) }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showAPIEditor) {
            APIEditorSheet(apiURL: $apiURL, onSave: {
                UserDefaults.standard.set(apiURL, forKey: "apiBaseURL")
                showAPIEditor = false
            })
            .presentationDetents([.medium])
        }
        .alert("Reset everything?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) { userStore.resetAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will wipe onboarding and your local profile. Backend data remains.")
        }
    }

    // MARK: - Avatar / name

    private var avatarCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [KineticColor.orange, KineticColor.orangeDeep],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 96, height: 96)
                Text(String(userStore.user.name.prefix(1)).uppercased())
                    .font(KineticFont.display(38))
                    .foregroundStyle(.white)
            }
            .shadow(color: KineticColor.orange.opacity(0.3), radius: 16, y: 6)

            Button {
                tempName = userStore.user.name
                editingName = true
            } label: {
                HStack(spacing: 6) {
                    Text(userStore.user.name)
                        .font(KineticFont.display(24))
                        .foregroundStyle(.white)
                    Image(systemName: "pencil")
                        .foregroundStyle(KineticColor.textSecondary)
                        .font(.system(size: 14))
                }
            }
            .buttonStyle(.plain)

            Text(levelDisplay)
                .font(KineticFont.caption(11)).kerning(2)
                .foregroundStyle(KineticColor.orange)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    // MARK: - Goals

    private var goalsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("GOALS").font(KineticFont.caption(10)).kerning(2)
                    .foregroundStyle(KineticColor.textSecondary)
                HStack {
                    Image(systemName: "target").foregroundStyle(KineticColor.orange)
                    Text("Primary: \(goalDisplay)")
                        .font(KineticFont.body(14)).foregroundStyle(.white)
                }
                if !userStore.user.bodyGoals.isEmpty {
                    WrappedChips(items: userStore.user.bodyGoals.map(bodyGoalLabel))
                }
            }
        }
    }

    // MARK: - Health

    private var healthCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("HEALTH NOTES").font(KineticFont.caption(10)).kerning(2)
                    .foregroundStyle(KineticColor.textSecondary)
                if userStore.user.healthNotes.isEmpty || userStore.user.healthNotes == ["none"] {
                    HStack {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(KineticColor.success)
                        Text("No issues noted").font(KineticFont.body(14)).foregroundStyle(.white)
                    }
                } else {
                    WrappedChips(items: userStore.user.healthNotes.map(healthLabel))
                }
            }
        }
    }

    // MARK: - Developer / backend

    private var developerCard: some View {
        VStack(spacing: 10) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("BACKEND").font(KineticFont.caption(10)).kerning(2)
                        .foregroundStyle(KineticColor.textSecondary)

                    Button { showAPIEditor = true } label: {
                        HStack {
                            Image(systemName: "network").foregroundStyle(.cyan)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("API URL").font(KineticFont.body(13)).foregroundStyle(.white)
                                Text(apiURL).font(KineticFont.caption(11))
                                    .foregroundStyle(KineticColor.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(KineticColor.textMuted)
                        }
                    }
                    .buttonStyle(.plain)

                    Divider().background(Color.white.opacity(0.1))

                    HStack {
                        Image(systemName: "number").foregroundStyle(KineticColor.textSecondary)
                        Text("User ID").font(KineticFont.body(13)).foregroundStyle(.white)
                        Spacer()
                        Text(String(userStore.user.id.prefix(8)))
                            .font(KineticFont.caption(11).monospaced())
                            .foregroundStyle(KineticColor.textSecondary)
                    }
                }
            }

            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Label("Reset App Data", systemImage: "trash")
                    .font(KineticFont.body(13))
                    .foregroundStyle(KineticColor.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Labels

    private var goalDisplay: String {
        switch userStore.user.goal {
        case "muscle": "Build Muscle"
        case "lose":   "Lose Weight"
        case "form":   "Improve Form"
        case "endure": "Endurance"
        default:       "Improve Form"
        }
    }

    private var levelDisplay: String {
        userStore.user.fitnessLevel.uppercased()
    }

    private func bodyGoalLabel(_ id: String) -> String {
        switch id {
        case "stronger_core":  "Stronger Core"
        case "better_posture": "Better Posture"
        case "more_mobility":  "More Mobility"
        case "explosive":      "Explosive Power"
        default: id.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func healthLabel(_ id: String) -> String {
        switch id {
        case "knee_pain":  "Knee Pain"
        case "lower_back": "Lower Back"
        case "shoulder":   "Shoulder Injury"
        case "wrist":      "Wrist Pain"
        default: id.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

// MARK: - Chips

private struct WrappedChips: View {
    let items: [String]
    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(KineticFont.caption(12))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(KineticColor.orangeSoft, in: Capsule())
            }
        }
    }
}

/// Simple flowing layout for chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}

// MARK: - API editor sheet

private struct APIEditorSheet: View {
    @Binding var apiURL: String
    var onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("http://192.168.x.x:8000/api", text: $apiURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                } header: {
                    Text("Backend URL")
                } footer: {
                    Text("When running on a physical iPhone, use your laptop's LAN IP instead of localhost (e.g. http://192.168.1.10:8000/api).")
                }
            }
            .navigationTitle("API Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Save", action: onSave) }
            }
        }
    }
}
