import SwiftUI

struct WelcomeView: View {
    var onGetStarted: () -> Void
    var onSignIn: () -> Void = {}

    var body: some View {
        ZStack {
            backgroundImage

            LinearGradient(
                colors: [.black.opacity(0.3), .black.opacity(0.9)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                logoSection
                    .padding(.top, 40)

                Spacer()

                headline

                HStack(spacing: 12) {
                    statCard(value: "99.8%", label: "Accuracy")
                    statCard(value: "AI", label: "Driven Insights")
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)

                Spacer()

                actions
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Sections

    private var backgroundImage: some View {
        // Placeholder gradient — swap for an actual athlete photo asset when available.
        LinearGradient(
            colors: [
                Color(red: 0.1, green: 0.05, blue: 0.02),
                Color(red: 0.3, green: 0.1, blue: 0.02),
                Color(red: 0.05, green: 0.03, blue: 0.01),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "figure.strengthtraining.traditional")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white.opacity(0.06))
                .padding(80)
        )
        .ignoresSafeArea()
    }

    private var logoSection: some View {
        VStack(spacing: 6) {
            Text("KINETIC")
                .font(KineticFont.display(34))
                .kerning(6)
                .foregroundStyle(.white)
            Text("INTELLIGENCE IN MOTION")
                .font(KineticFont.caption(10))
                .kerning(3)
                .foregroundStyle(KineticColor.textSecondary)
        }
    }

    private var headline: some View {
        VStack(spacing: 4) {
            Text("Evolve Your")
                .foregroundStyle(.white)
            HStack(spacing: 8) {
                Text("Human")
                    .foregroundStyle(.white)
                Text("Potential")
                    .foregroundStyle(KineticColor.orange)
            }
        }
        .font(KineticFont.display(38))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
    }

    private func statCard(value: String, label: String) -> some View {
        GlassCard(padding: 18) {
            VStack(spacing: 4) {
                Text(value)
                    .font(KineticFont.display(22))
                    .foregroundStyle(.white)
                Text(label)
                    .font(KineticFont.caption(11))
                    .kerning(1)
                    .foregroundStyle(KineticColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var actions: some View {
        VStack(spacing: 16) {
            Button(action: onGetStarted) {
                HStack(spacing: 8) {
                    Text("Get Started")
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(PrimaryButtonStyle())

            Button(action: onSignIn) {
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .foregroundStyle(KineticColor.textSecondary)
                    Text("Sign In")
                        .foregroundStyle(KineticColor.orange)
                }
                .font(KineticFont.body(14))
            }
        }
    }
}

#Preview { WelcomeView(onGetStarted: {}) }
