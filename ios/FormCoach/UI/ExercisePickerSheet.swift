import SwiftUI

struct ExercisePickerSheet: View {
    var onSelect: (ExerciseType) -> Void

    private let exercises: [ExerciseType] = [.squat, .deadlift, .pushup, .curl]

    var body: some View {
        ZStack {
            KineticColor.bgDark.ignoresSafeArea()

            VStack(spacing: 20) {
                Text("SELECT EXERCISE")
                    .font(KineticFont.display(20))
                    .kerning(3)
                    .foregroundStyle(.white)
                    .padding(.top, 24)

                Text("Choose the exercise you'll perform so the AI coach can track your form.")
                    .font(KineticFont.body(14))
                    .foregroundStyle(KineticColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(exercises) { exercise in
                        Button { onSelect(exercise) } label: {
                            VStack(spacing: 6) {
                                if let asset = exercise.assetName {
                                    Image(asset)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 52, height: 52)
                                } else {
                                    Image(systemName: exercise.icon)
                                        .font(.system(size: 32, weight: .semibold))
                                        .foregroundStyle(KineticColor.orange)
                                        .frame(width: 52, height: 52)
                                }

                                Text(exercise.displayName)
                                    .font(KineticFont.heading(14))
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 110)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(KineticColor.glassStroke, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }
}
