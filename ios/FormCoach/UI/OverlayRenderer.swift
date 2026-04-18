import SwiftUI
import Vision

struct OverlayRenderer: View {
    let pose: BodyPose?
    let formResult: FormResult?
    let exercise: ExerciseType
    let repCount: Int
    let viewSize: CGSize

    var body: some View {
        ZStack {
            if let pose {
                SkeletonView(pose: pose, viewSize: viewSize, color: .green)
            }

            VStack(spacing: 0) {
                // Top bar
                HStack(alignment: .top) {
                    FormScoreBadge(score: formResult?.score ?? 0)
                    Spacer()
                    ExerciseBadge(exercise: exercise)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()

                // Bottom bar
                HStack(alignment: .bottom) {
                    RepBadge(count: repCount)
                    Spacer()
                    if let msg = formResult?.corrections.first?.message {
                        CorrectionBadge(text: msg)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120) // above control bar
            }
        }
    }
}

// MARK: - Skeleton

private struct SkeletonView: View {
    let pose: BodyPose
    let viewSize: CGSize
    let color: Color

    private typealias JN = VNHumanBodyPoseObservation.JointName

    private let bones: [(JN, JN)] = [
        (.nose, .neck),
        (.neck, .leftShoulder), (.neck, .rightShoulder),
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
        (.leftHip, .rightHip),
        (.leftHip, .leftKnee),   (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
    ]

    var body: some View {
        Canvas { ctx, _ in
            for (a, b) in bones {
                guard let pa = screen(a), let pb = screen(b) else { continue }
                var path = Path()
                path.move(to: pa); path.addLine(to: pb)
                ctx.stroke(path, with: .color(color.opacity(0.85)), lineWidth: 3)
            }
            for joint in BodyPose.allJointNames {
                guard let p = screen(joint) else { continue }
                let r = CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)
                ctx.fill(Path(ellipseIn: r), with: .color(color))
            }
        }
        .frame(width: viewSize.width, height: viewSize.height)
    }

    /// Converts normalized Vision coords (origin bottom-left) → view coords.
    private func screen(_ joint: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
        guard let p = pose.point(for: joint) else { return nil }
        return CGPoint(x: p.x * viewSize.width, y: (1 - p.y) * viewSize.height)
    }
}

// MARK: - Badges

private struct FormScoreBadge: View {
    let score: Double
    var color: Color { score > 80 ? .green : score > 55 ? .yellow : .red }

    var body: some View {
        VStack(spacing: 1) {
            Text("\(Int(score))")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text("FORM").font(.caption2.bold()).foregroundStyle(.white.opacity(0.7))
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct RepBadge: View {
    let count: Int
    var body: some View {
        VStack(spacing: 1) {
            Text("\(count)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("REPS").font(.caption2.bold()).foregroundStyle(.white.opacity(0.7))
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ExerciseBadge: View {
    let exercise: ExerciseType
    var body: some View {
        Text(exercise.displayName.uppercased())
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
    }
}

private struct CorrectionBadge: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline.bold())
            .foregroundStyle(.orange)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .transition(.opacity.combined(with: .scale))
    }
}
