import Foundation

struct AngleRange {
    let min: Double
    let max: Double

    func contains(_ v: Double) -> Bool { v >= min && v <= max }

    func deviation(from v: Double) -> Double {
        if v < min { return min - v }
        if v > max { return v - max }
        return 0
    }
}

struct FormCorrection {
    let joint: String
    let message: String
    let severity: Double  // 0–1, higher = worse
}

struct FormResult {
    let score: Double          // 0–100
    let corrections: [FormCorrection]
    let phase: String

    static let empty = FormResult(score: 0, corrections: [], phase: "")
}

struct ReferenceFrame {
    let elbowAngle: AngleRange?
    let kneeAngle: AngleRange?
    let hipAngle: AngleRange?
    let spineAngle: AngleRange?
    let shoulderAngle: AngleRange?

    init(
        elbowAngle:    AngleRange? = nil,
        kneeAngle:     AngleRange? = nil,
        hipAngle:      AngleRange? = nil,
        spineAngle:    AngleRange? = nil,
        shoulderAngle: AngleRange? = nil
    ) {
        self.elbowAngle = elbowAngle
        self.kneeAngle = kneeAngle
        self.hipAngle = hipAngle
        self.spineAngle = spineAngle
        self.shoulderAngle = shoulderAngle
    }
}

// MARK: - FormComparator

struct FormComparator {

    // ── Reference data ─────────────────────────────────────────────────
    static let reference: [ExerciseType: [String: ReferenceFrame]] = [
        .pushup: [
            "bottom": ReferenceFrame(elbowAngle: .init(min: 70,  max: 100),
                                     hipAngle:   .init(min: 160, max: 180),
                                     spineAngle: .init(min: 160, max: 180)),
            "top":    ReferenceFrame(elbowAngle: .init(min: 155, max: 180),
                                     hipAngle:   .init(min: 160, max: 180),
                                     spineAngle: .init(min: 160, max: 180)),
        ],
        .squat: [
            "bottom": ReferenceFrame(kneeAngle:  .init(min: 60,  max: 100),
                                     hipAngle:   .init(min: 60,  max: 100),
                                     spineAngle: .init(min: 150, max: 180)),
            "top":    ReferenceFrame(kneeAngle:  .init(min: 155, max: 180),
                                     hipAngle:   .init(min: 155, max: 180),
                                     spineAngle: .init(min: 150, max: 180)),
        ],
        .deadlift: [
            // Spine floor tightened to 155 — picks up mild rounding at the
            // bottom (safety critical) without flagging a normal hip-hinge.
            "bottom": ReferenceFrame(kneeAngle:  .init(min: 110, max: 140),
                                     hipAngle:   .init(min: 70,  max: 110),
                                     spineAngle: .init(min: 155, max: 180)),
            "top":    ReferenceFrame(kneeAngle:  .init(min: 165, max: 180),
                                     hipAngle:   .init(min: 165, max: 180),
                                     spineAngle: .init(min: 165, max: 180)),
        ],
        .plank: [
            "hold":   ReferenceFrame(elbowAngle: .init(min: 85,  max: 95),
                                     kneeAngle:  .init(min: 160, max: 180),
                                     hipAngle:   .init(min: 160, max: 180),
                                     spineAngle: .init(min: 160, max: 180)),
        ],
        .lunge: [
            "bottom": ReferenceFrame(kneeAngle:  .init(min: 85,  max: 100),
                                     hipAngle:   .init(min: 85,  max: 100),
                                     spineAngle: .init(min: 150, max: 180)),
            "top":    ReferenceFrame(kneeAngle:  .init(min: 155, max: 180),
                                     hipAngle:   .init(min: 155, max: 180),
                                     spineAngle: .init(min: 150, max: 180)),
        ],
        .jumpingJacks: [
            "open":   ReferenceFrame(hipAngle:      .init(min: 150, max: 180),
                                     shoulderAngle: .init(min: 150, max: 180)),
            "closed": ReferenceFrame(hipAngle:      .init(min: 165, max: 180),
                                     shoulderAngle: .init(min: 0,   max: 40)),
        ],
        .curl: [
            "bottom": ReferenceFrame(elbowAngle: .init(min: 150, max: 180),
                                     spineAngle: .init(min: 165, max: 180)),
            "top":    ReferenceFrame(elbowAngle: .init(min: 30,  max: 60),
                                     spineAngle: .init(min: 165, max: 180)),
        ],
    ]

    static let weights: [ExerciseType: [String: Double]] = [
        .pushup:       ["elbowAngle": 0.40, "hipAngle": 0.30, "spineAngle": 0.30],
        .squat:        ["kneeAngle":  0.40, "hipAngle": 0.25, "spineAngle": 0.35],
        .deadlift:     ["spineAngle": 0.50, "hipAngle": 0.30, "kneeAngle":  0.20],
        .plank:        ["hipAngle":   0.40, "spineAngle": 0.30, "elbowAngle": 0.20, "kneeAngle": 0.10],
        .lunge:        ["kneeAngle":  0.40, "hipAngle": 0.30, "spineAngle": 0.30],
        .jumpingJacks: ["shoulderAngle": 0.50, "hipAngle": 0.50],
        .curl:         ["elbowAngle": 0.70, "spineAngle": 0.30],
    ]

    static let messages: [String: [String: String]] = [
        "pushup":        ["elbowAngle_high": "Go deeper", "elbowAngle_low": "Fully extend your arms",
                          "hipAngle_low": "Keep your hips up", "spineAngle_low": "Straighten your back"],
        "squat":         ["kneeAngle_high": "Go deeper", "spineAngle_low": "Keep your chest up",
                          "hipAngle_low": "Open your hips"],
        "deadlift":      ["spineAngle_low": "Keep your back flat", "hipAngle_low": "Drive hips forward",
                          "kneeAngle_low": "Don't squat the lift"],
        "plank":         ["hipAngle_low": "Raise your hips", "hipAngle_high": "Lower your hips",
                          "spineAngle_low": "Straighten your back"],
        "lunge":         ["kneeAngle_high": "Lower your back knee", "spineAngle_low": "Keep your torso upright"],
        "jumping_jacks": ["shoulderAngle_low": "Raise your arms higher", "hipAngle_low": "Jump wider"],
        "curl":          ["elbowAngle_high": "Curl higher", "elbowAngle_low": "Fully extend at the bottom",
                          "spineAngle_low": "Stop swinging"],
    ]

    // ── Evaluation ─────────────────────────────────────────────────────
    func evaluate(angles: BodyAngles, exercise: ExerciseType, phase: String) -> FormResult {
        guard exercise != .unknown,
              let ref = Self.reference[exercise]?[phase],
              let w = Self.weights[exercise]
        else { return .empty }

        var totalWeight = 0.0
        var weightedScore = 0.0
        var corrections: [FormCorrection] = []

        func check(angle: Double?, range: AngleRange?, name: String) {
            guard let angle, let range, let weight = w[name] else { return }
            totalWeight += weight
            let dev = range.deviation(from: angle)
            let jointScore = dev == 0 ? 100.0 : max(0, 100 - (dev / 30) * 100)
            weightedScore += weight * jointScore

            if dev > 10 {
                let key = angle < range.min ? "\(name)_low" : "\(name)_high"
                let msg = Self.messages[exercise.rawValue]?[key]
                    ?? (angle < range.min ? "Improve your \(name)" : "Don't overextend")
                corrections.append(FormCorrection(joint: name, message: msg, severity: min(1, dev / 30)))
            }
        }

        check(angle: angles.elbowAngle,    range: ref.elbowAngle,    name: "elbowAngle")
        check(angle: angles.kneeAngle,     range: ref.kneeAngle,     name: "kneeAngle")
        check(angle: angles.hipAngle,      range: ref.hipAngle,      name: "hipAngle")
        check(angle: angles.spine,         range: ref.spineAngle,    name: "spineAngle")
        check(angle: angles.shoulderAngle, range: ref.shoulderAngle, name: "shoulderAngle")

        let score = totalWeight > 0 ? weightedScore / totalWeight : 50
        return FormResult(
            score: score,
            corrections: corrections.sorted { $0.severity > $1.severity },
            phase: phase
        )
    }
}
