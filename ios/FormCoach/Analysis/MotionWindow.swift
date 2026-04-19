import Foundation

/// Rolling window of PoseFeatures with computed motion statistics.
/// All range/amplitude calculations use body-relative values from PoseFeatures.
struct MotionWindow {

    // MARK: - Configuration

    struct Config {
        /// Maximum frames to retain (~3 seconds at 30 fps).
        var maxFrames: Int = 90
        /// Minimum frames before statistics are meaningful.
        var minFrames: Int = 20
        /// Minimum average confidence to trust the window.
        var minConfidence: Float = 0.25
    }

    private(set) var config: Config
    private(set) var frames: [PoseFeatures] = []

    init(config: Config = Config()) {
        self.config = config
    }

    // MARK: - Mutation

    mutating func append(_ features: PoseFeatures) {
        frames.append(features)
        if frames.count > config.maxFrames {
            frames.removeFirst(frames.count - config.maxFrames)
        }
    }

    mutating func clear() {
        frames.removeAll()
    }

    var isReady: Bool { frames.count >= config.minFrames }
    var duration: TimeInterval {
        guard let first = frames.first, let last = frames.last else { return 0 }
        return last.timestamp - first.timestamp
    }

    // MARK: - Motion statistics

    /// Range of a signal over the window (max - min). Returns nil if insufficient data.
    func range(of keyPath: (PoseFeatures) -> Double?) -> Double? {
        let vals = frames.compactMap(keyPath)
        guard vals.count >= config.minFrames / 2 else { return nil }
        return (vals.max() ?? 0) - (vals.min() ?? 0)
    }

    func mean(of keyPath: (PoseFeatures) -> Double?) -> Double? {
        let vals = frames.compactMap(keyPath)
        guard !vals.isEmpty else { return nil }
        return vals.reduce(0, +) / Double(vals.count)
    }

    func latest(of keyPath: (PoseFeatures) -> Double?) -> Double? {
        frames.last.flatMap(keyPath)
    }

    /// Average confidence across all frames in the window.
    var avgConfidence: Float {
        guard !frames.isEmpty else { return 0 }
        return frames.map(\.avgConfidence).reduce(0, +) / Float(frames.count)
    }

    // MARK: - Convenience accessors for common signals

    var kneeRange: Double? { range(of: { $0.angles.kneeAngle }) }
    var hipRange: Double? { range(of: { $0.angles.hipAngle }) }
    var elbowRange: Double? { range(of: { $0.angles.elbowAngle }) }
    var shoulderRange: Double? { range(of: { $0.angles.shoulderAngle }) }
    var spineRange: Double? { range(of: { $0.angles.spine }) }
    var spineMean: Double? { mean(of: { $0.angles.spine }) }
    var hipCenterYRange: Double? { range(of: { $0.hipCenterY }) }
    var wristYRange: Double? { range(of: { $0.wristY }) }

    // MARK: - Cycle detection

    /// Detects repeated cycles (peaks and valleys) in a signal.
    /// Returns the number of complete cycles (valley → peak → valley) detected.
    /// `hysteresis` is the minimum amplitude change to qualify as a direction reversal.
    func countCycles(
        of keyPath: (PoseFeatures) -> Double?,
        hysteresis: Double
    ) -> Int {
        let vals = frames.compactMap(keyPath)
        guard vals.count >= config.minFrames / 2 else { return 0 }

        enum Direction { case none, rising, falling }
        var dir: Direction = .none
        var extremeVal = vals[0]
        var valleys = 0
        var peaks = 0

        for val in vals.dropFirst() {
            switch dir {
            case .none:
                if val - extremeVal > hysteresis {
                    dir = .rising
                    extremeVal = val
                } else if extremeVal - val > hysteresis {
                    dir = .falling
                    extremeVal = val
                }
            case .rising:
                if val > extremeVal { extremeVal = val }
                if extremeVal - val > hysteresis {
                    peaks += 1
                    dir = .falling
                    extremeVal = val
                }
            case .falling:
                if val < extremeVal { extremeVal = val }
                if val - extremeVal > hysteresis {
                    valleys += 1
                    dir = .rising
                    extremeVal = val
                }
            }
        }

        return min(peaks, valleys)
    }
}
