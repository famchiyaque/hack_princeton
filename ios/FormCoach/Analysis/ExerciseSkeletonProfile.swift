import Vision

/// Which joints and bones to draw once an exercise is locked (hides irrelevant pivots).
enum ExerciseSkeletonProfile {
    typealias JN = VNHumanBodyPoseObservation.JointName

    private static let faceJoints: Set<JN> = [.nose, .leftEye, .rightEye, .leftEar, .rightEar]

    /// Joints to render for the exercise (others are hidden).
    static func visibleJoints(for exercise: ExerciseType) -> Set<JN> {
        switch exercise {
        case .curl:
            return [
                .leftShoulder, .rightShoulder,
                .leftElbow, .rightElbow,
                .leftWrist, .rightWrist,
            ]
        case .squat, .deadlift:
            return Set(BodyPose.allJointNames).subtracting(faceJoints)
        default:
            return Set(BodyPose.allJointNames)
        }
    }

    /// Bones where both endpoints are visible for this exercise.
    static func bones(for exercise: ExerciseType) -> [(JN, JN)] {
        let visible = visibleJoints(for: exercise)
        let allBones: [(JN, JN)] = [
            (.nose, .neck),
            (.neck, .leftShoulder), (.neck, .rightShoulder),
            (.leftShoulder, .rightShoulder),
            (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
            (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
            (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
            (.leftHip, .rightHip),
            (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
            (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
        ]
        return allBones.filter { visible.contains($0.0) && visible.contains($0.1) }
    }
}
