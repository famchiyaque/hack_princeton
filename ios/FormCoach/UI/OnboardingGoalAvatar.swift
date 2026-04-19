import SwiftUI

/// Static SF Symbol icons for onboarding goal tiles.
struct OnboardingGoalAvatarView: View {
    let goalId: String
    var isSelected: Bool

    private var ink: Color { isSelected ? .white : .black }

    private var iconName: String {
        switch goalId {
        case "bodybuilding": return "figure.strengthtraining.traditional"
        case "strength": return "scalemass.fill"
        case "longevity": return "leaf.fill"
        case "fat_loss": return "flame.fill"
        case "athleticism": return "figure.run"
        case "aesthetic": return "sparkles"
        case "physical_rehab": return "bandage.fill"
        default: return "figure.walk"
        }
    }

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(ink)
            .frame(width: 30, height: 30)
    }
}
