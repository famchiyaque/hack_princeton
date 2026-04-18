import SwiftUI

/// Shown in place of the session / report while the app wraps up the session
/// and performs the best-effort backend save. Bounded by the request timeout
/// so the user never sits here longer than ~6 seconds.
struct SessionEndingOverlay: View {
    @State private var pulse: Bool = false

    var body: some View {
        ZStack {
            KineticColor.bgDark.ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(KineticColor.glassStroke, lineWidth: 2)
                        .frame(width: 68, height: 68)

                    Circle()
                        .trim(from: 0, to: 0.25)
                        .stroke(
                            LinearGradient(colors: [KineticColor.orange, KineticColor.orangeDeep],
                                           startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(pulse ? 360 : 0))
                        .frame(width: 68, height: 68)
                        .animation(.linear(duration: 1.1).repeatForever(autoreverses: false),
                                   value: pulse)
                }

                VStack(spacing: 6) {
                    Text("Saving session")
                        .font(KineticFont.heading(18))
                        .foregroundStyle(.white)
                    Text("Wrapping up your stats...")
                        .font(KineticFont.body(13))
                        .foregroundStyle(KineticColor.textSecondary)
                }
            }
        }
        .onAppear { pulse = true }
    }
}
