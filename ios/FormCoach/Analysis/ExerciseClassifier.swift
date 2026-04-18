import Vision

enum ExerciseType: String, CaseIterable, Identifiable, Codable {
    case pushup, squat, deadlift, plank, lunge, jumpingJacks = "jumping_jacks", curl, unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pushup:       "Push-Up"
        case .squat:        "Squat"
        case .deadlift:     "Deadlift"
        case .plank:        "Plank"
        case .lunge:        "Lunge"
        case .jumpingJacks: "Jumping Jacks"
        case .curl:         "Bicep Curl"
        case .unknown:      "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .pushup:       "figure.strengthtraining.traditional"
        case .squat:        "figure.cooldown"
        case .deadlift:     "figure.strengthtraining.functional"
        case .plank:        "figure.core.training"
        case .lunge:        "figure.step.training"
        case .jumpingJacks: "figure.mixed.cardio"
        case .curl:         "dumbbell.fill"
        case .unknown:      "questionmark"
        }
    }

    /// Thresholds used by the RepCounter for this exercise.
    var downThreshold: Double {
        switch self {
        case .pushup:       100  // elbow
        case .squat, .lunge: 100 // knee
        case .deadlift:     110  // hip
        case .curl:         60   // elbow (top of curl)
        case .jumpingJacks: 40   // shoulder (closed)
        case .plank, .unknown: 90
        }
    }

    var upThreshold: Double {
        switch self {
        case .pushup, .squat, .lunge, .deadlift: 155
        case .curl:         150
        case .jumpingJacks: 150
        case .plank, .unknown: 90
        }
    }
}

enum BodyOrientation { case upright, horizontal, other }

final class ExerciseClassifier: ObservableObject {
    @Published var detectedExercise: ExerciseType = .unknown

    private var recentAngles: [BodyAngles] = []
    private var frameCount = 0
    private let historySize = 15
    private let classifyEvery = 15

    func update(angles: BodyAngles, pose: BodyPose) {
        recentAngles.append(angles)
        if recentAngles.count > historySize { recentAngles.removeFirst() }
        frameCount += 1
        guard frameCount % classifyEvery == 0 else { return }

        let orientation = bodyOrientation(from: pose)
        let result = classify(angles: angles, orientation: orientation)
        DispatchQueue.main.async { self.detectedExercise = result }
    }

    private func bodyOrientation(from pose: BodyPose) -> BodyOrientation {
        guard let nose = pose.point(for: .nose), let hip = pose.point(for: .root) else { return .other }
        let vDiff = abs(nose.y - hip.y)
        let hDiff = abs(nose.x - hip.x)
        if vDiff > hDiff * 1.5 { return .upright }
        if hDiff > vDiff * 1.5 { return .horizontal }
        return .other
    }

    private func classify(angles: BodyAngles, orientation: BodyOrientation) -> ExerciseType {
        switch orientation {
        case .horizontal:
            if let hip = angles.hipAngle, let elbow = angles.elbowAngle, hip > 160, elbow > 150 {
                return .plank
            }
            return .pushup

        case .upright:
            if let lk = angles.leftKnee, let rk = angles.rightKnee, abs(lk - rk) > 30 {
                return .lunge
            }
            if let shoulder = angles.shoulderAngle, shoulder > 120 {
                return .jumpingJacks
            }
            if isBending(\.kneeAngle) {
                return .squat
            }
            return .unknown

        case .other:
            return .unknown
        }
    }

    private func isBending(_ kp: KeyPath<BodyAngles, Double?>) -> Bool {
        let vals = recentAngles.compactMap { $0[keyPath: kp] }
        guard vals.count >= 3 else { return false }
        return vals.last! < vals[vals.count - 3] - 15
    }
}
