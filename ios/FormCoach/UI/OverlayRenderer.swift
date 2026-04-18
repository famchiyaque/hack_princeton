import SwiftUI
import Vision

/// Pure-visual skeleton overlay. All HUD chrome lives in `SessionView`.
struct SkeletonOverlay: View {
    let pose: BodyPose?
    let viewSize: CGSize
    var color: Color = KineticColor.orange

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
            guard let pose else { return }

            for (a, b) in bones {
                guard let pa = screen(a, in: pose), let pb = screen(b, in: pose) else { continue }
                var path = Path()
                path.move(to: pa); path.addLine(to: pb)
                ctx.stroke(path, with: .color(color.opacity(0.9)), lineWidth: 3)
            }
            for joint in BodyPose.allJointNames {
                guard let p = screen(joint, in: pose) else { continue }
                let r = CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)
                ctx.fill(Path(ellipseIn: r), with: .color(.white))
                ctx.stroke(Path(ellipseIn: r), with: .color(color), lineWidth: 2)
            }
        }
        .frame(width: viewSize.width, height: viewSize.height)
        .allowsHitTesting(false)
    }

    private func screen(_ joint: VNHumanBodyPoseObservation.JointName, in pose: BodyPose) -> CGPoint? {
        guard let p = pose.point(for: joint) else { return nil }
        return CGPoint(x: p.x * viewSize.width, y: (1 - p.y) * viewSize.height)
    }
}
