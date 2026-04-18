import Foundation

final class RepCounter {
    enum Phase { case up, goingDown, down, comingUp }

    private(set) var repCount = 0
    private(set) var phase: Phase = .up
    private(set) var lastCompletedPhase: Phase = .up

    private let downThreshold: Double
    private let upThreshold: Double

    init(exercise: ExerciseType) {
        switch exercise {
        case .pushup:
            downThreshold = 100; upThreshold = 155
        case .squat, .lunge:
            downThreshold = 100; upThreshold = 155
        case .plank, .unknown:
            downThreshold = 90; upThreshold = 90
        }
    }

    /// Returns true when a rep just completed.
    @discardableResult
    func update(primaryAngle: Double) -> Bool {
        let prev = repCount
        switch phase {
        case .up:
            if primaryAngle < downThreshold + 20 { phase = .goingDown }
        case .goingDown:
            if primaryAngle <= downThreshold     { phase = .down }
            if primaryAngle > upThreshold        { phase = .up }   // aborted
        case .down:
            if primaryAngle > downThreshold + 20 { phase = .comingUp }
        case .comingUp:
            if primaryAngle >= upThreshold {
                phase = .up
                repCount += 1
            }
            if primaryAngle <= downThreshold     { phase = .down }
        }
        return repCount > prev
    }

    func reset() { repCount = 0; phase = .up }
}
