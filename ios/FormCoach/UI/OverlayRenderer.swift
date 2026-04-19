import SwiftUI
import Vision

/// Per-joint styling when an exercise is locked (green = good, red = fault).
enum JointVisualState: Equatable {
    case neutral
    case good
    case bad
}

/// Pure-visual skeleton overlay. All HUD chrome lives in `SessionView`.
struct SkeletonOverlay: View {
    let pose: BodyPose?
    let viewSize: CGSize
    /// When `.unknown`, all tracked joints are shown (legacy behavior).
    var exercise: ExerciseType = .unknown
    /// Optional per-joint highlight (curl: arms green/red).
    var jointStates: [VNHumanBodyPoseObservation.JointName: JointVisualState] = [:]
    var color: Color = KineticColor.orange

    private typealias JN = VNHumanBodyPoseObservation.JointName

    private var bones: [(JN, JN)] {
        exercise == .unknown
            ? Self.defaultBones
            : ExerciseSkeletonProfile.bones(for: exercise)
    }

    private static let defaultBones: [(JN, JN)] = [
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

    private var visibleJoints: Set<JN> {
        exercise == .unknown ? Set(BodyPose.allJointNames) : ExerciseSkeletonProfile.visibleJoints(for: exercise)
    }

    var body: some View {
        Canvas { ctx, _ in
            guard let pose else { return }

            for (a, b) in bones {
                guard let pa = screen(a, in: pose), let pb = screen(b, in: pose) else { continue }
                let lineColor = boneColor(a: a, b: b)
                var path = Path()
                path.move(to: pa); path.addLine(to: pb)
                ctx.stroke(path, with: .color(lineColor.opacity(0.95)), lineWidth: 3)
            }
            for joint in visibleJoints {
                guard let p = screen(joint, in: pose) else { continue }
                let jointColor = fillColor(for: joint)
                let strokeColor = strokeColor(for: joint)
                let r = CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)
                ctx.fill(Path(ellipseIn: r), with: .color(.white))
                ctx.stroke(Path(ellipseIn: r), with: .color(strokeColor), lineWidth: 2)
            }
        }
        .frame(width: viewSize.width, height: viewSize.height)
        .allowsHitTesting(false)
    }

    private func boneColor(a: JN, b: JN) -> Color {
        // If either end is "bad", show warning on the segment.
        if state(a) == .bad || state(b) == .bad { return KineticColor.danger }
        if state(a) == .good && state(b) == .good { return KineticColor.success }
        if state(a) == .good || state(b) == .good { return KineticColor.success.opacity(0.85) }
        return color
    }

    private func state(_ j: JN) -> JointVisualState {
        jointStates[j] ?? .neutral
    }

    private func fillColor(for joint: JN) -> Color {
        switch state(joint) {
        case .bad:   return KineticColor.danger.opacity(0.25)
        case .good:  return KineticColor.success.opacity(0.2)
        case .neutral: return .white
        }
    }

    private func strokeColor(for joint: JN) -> Color {
        switch state(joint) {
        case .bad:   return KineticColor.danger
        case .good:  return KineticColor.success
        case .neutral: return color
        }
    }

    private func screen(_ joint: VNHumanBodyPoseObservation.JointName, in pose: BodyPose) -> CGPoint? {
        guard let p = pose.point(for: joint) else { return nil }
        return CGPoint(x: p.x * viewSize.width, y: (1 - p.y) * viewSize.height)
    }
}
