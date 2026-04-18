import SwiftUI

// MARK: - Kinetic Design System

enum KineticColor {
    static let orange       = Color(red: 1.0, green: 0.478, blue: 0.0)      // #FF7A00
    static let orangeDeep   = Color(red: 0.86, green: 0.38, blue: 0.0)
    static let orangeSoft   = Color(red: 1.0, green: 0.478, blue: 0.0).opacity(0.15)

    static let bgDark       = Color(red: 0.04, green: 0.04, blue: 0.05)     // near-black
    static let bgCard       = Color(red: 0.09, green: 0.09, blue: 0.10)
    static let bgLight      = Color(red: 0.98, green: 0.98, blue: 0.98)

    static let textPrimary  = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let textMuted    = Color.white.opacity(0.4)

    static let success      = Color(red: 0.2, green: 0.8, blue: 0.5)
    static let warning      = Color(red: 1.0, green: 0.75, blue: 0.2)
    static let danger       = Color(red: 0.95, green: 0.3, blue: 0.3)

    static let glassStroke  = Color.white.opacity(0.12)
}

enum KineticFont {
    /// Manrope falls back to system rounded if not bundled.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }
    static func heading(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
    static func caption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}

// MARK: - Reusable components

struct GlassCard<Content: View>: View {
    let padding: CGFloat
    let content: Content

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(KineticColor.glassStroke, lineWidth: 1)
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KineticFont.heading(17))
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .padding(.horizontal, 28)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                LinearGradient(
                    colors: [KineticColor.orange, KineticColor.orangeDeep],
                    startPoint: .top, endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(color: KineticColor.orange.opacity(0.35), radius: 16, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KineticFont.heading(16))
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .padding(.horizontal, 24)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct StreakPill: View {
    let text: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill").font(.system(size: 11, weight: .bold))
            Text(text).font(KineticFont.caption(11))
        }
        .foregroundStyle(KineticColor.orange)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(KineticColor.orangeSoft, in: Capsule())
    }
}
