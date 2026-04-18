import Foundation

/// Per-rep record captured during a session.
struct RepRecord {
    let index: Int
    let exercise: ExerciseType
    let score: Double
    let peakPrimaryAngle: Double  // deepest point reached (min for squat/pushup, max for curl top etc.)
    let durationMs: Int
    let topCorrection: String?    // most severe correction joint on this rep
}

/// Everything the Report screen needs — produced entirely on-device.
struct SessionReport {
    let exercise: ExerciseType
    let reps: Int
    let duration: Int               // seconds
    let avgScore: Double            // 0–100
    let perRepScores: [Double]
    let correctionsByType: [String: Int]

    // Insights
    let bestRep: RepRecord?
    let worstRep: RepRecord?
    let strengths: [String]         // things done well
    let risks: [String]             // key risks / recurring issues
    let tempo: TempoAnalysis
    let consistency: Double         // 0–100, std-dev based

    // Populated post-build by SessionView if the server sync failed.
    var saveError: String? = nil
}

struct TempoAnalysis {
    let avgRepSeconds: Double
    let fastest: Double
    let slowest: Double
    let label: String               // "Controlled" | "Rushed" | "Variable"
}

// MARK: - Analyzer

enum SessionAnalyzer {

    static func analyze(
        exercise: ExerciseType,
        durationSeconds: Int,
        reps: [RepRecord],
        correctionsByType: [String: Int]
    ) -> SessionReport {
        let scores = reps.map(\.score)
        let avg = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)

        let tempo = computeTempo(reps)
        let consistency = computeConsistency(scores)

        let best  = reps.max(by: { $0.score < $1.score })
        let worst = reps.min(by: { $0.score < $1.score })

        let strengths = buildStrengths(avg: avg, consistency: consistency, reps: reps, tempo: tempo)
        let risks     = buildRisks(corrections: correctionsByType, reps: reps, tempo: tempo, avg: avg)

        return SessionReport(
            exercise: exercise,
            reps: reps.count,
            duration: durationSeconds,
            avgScore: avg,
            perRepScores: scores,
            correctionsByType: correctionsByType,
            bestRep: best,
            worstRep: worst,
            strengths: strengths,
            risks: risks,
            tempo: tempo,
            consistency: consistency
        )
    }

    // MARK: - Tempo

    private static func computeTempo(_ reps: [RepRecord]) -> TempoAnalysis {
        guard !reps.isEmpty else {
            return TempoAnalysis(avgRepSeconds: 0, fastest: 0, slowest: 0, label: "—")
        }
        let durations = reps.map { Double($0.durationMs) / 1000 }
        let avg = durations.reduce(0, +) / Double(durations.count)
        let fastest = durations.min() ?? 0
        let slowest = durations.max() ?? 0

        let label: String
        if avg < 1.2          { label = "Rushed" }
        else if slowest - fastest > 2.5 { label = "Variable" }
        else                  { label = "Controlled" }

        return TempoAnalysis(avgRepSeconds: avg, fastest: fastest, slowest: slowest, label: label)
    }

    // MARK: - Consistency (100 - stddev)

    private static func computeConsistency(_ scores: [Double]) -> Double {
        guard scores.count > 1 else { return scores.isEmpty ? 0 : 100 }
        let mean = scores.reduce(0, +) / Double(scores.count)
        let variance = scores.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(scores.count)
        let stddev = sqrt(variance)
        return max(0, 100 - stddev * 2.5)
    }

    // MARK: - Insight text generation

    private static func buildStrengths(avg: Double, consistency: Double,
                                       reps: [RepRecord], tempo: TempoAnalysis) -> [String] {
        var out: [String] = []
        if avg >= 85         { out.append("Excellent form — averaged \(Int(avg))/100.") }
        else if avg >= 70    { out.append("Solid form throughout the session.") }
        if consistency >= 80 { out.append("Very consistent form rep-to-rep.") }
        if tempo.label == "Controlled" && !reps.isEmpty {
            out.append("Controlled tempo averaging \(String(format: "%.1f", tempo.avgRepSeconds))s per rep.")
        }
        if let best = reps.max(by: { $0.score < $1.score }), best.score >= 90 {
            out.append("Peak rep scored \(Int(best.score))/100 — your form when it clicks is great.")
        }
        if out.isEmpty { out.append("You showed up and put in reps — that's the hardest part.") }
        return out
    }

    private static func buildRisks(corrections: [String: Int], reps: [RepRecord],
                                   tempo: TempoAnalysis, avg: Double) -> [String] {
        var out: [String] = []

        // Most frequent correction
        if let top = corrections.max(by: { $0.value < $1.value }) {
            let jointName = humanize(top.key)
            out.append("\(jointName) flagged \(top.value) time\(top.value == 1 ? "" : "s") — focus here next session.")
        }

        if avg < 60 {
            out.append("Overall score below 60. Consider reducing load and slowing down.")
        }

        if tempo.label == "Rushed" {
            out.append("Reps averaged under 1.2s — slow the eccentric for more control.")
        }
        if tempo.label == "Variable" {
            out.append("Tempo varied a lot — aim for a consistent cadence.")
        }

        // Fatigue detection: score drops from first half to second half
        if reps.count >= 6 {
            let mid = reps.count / 2
            let first = reps.prefix(mid).map(\.score)
            let second = reps.suffix(mid).map(\.score)
            let avgFirst  = first.reduce(0, +) / Double(first.count)
            let avgSecond = second.reduce(0, +) / Double(second.count)
            if avgFirst - avgSecond > 12 {
                out.append("Form dropped ~\(Int(avgFirst - avgSecond)) pts in the second half — watch for fatigue.")
            }
        }

        if out.isEmpty {
            out.append("No major issues detected. Keep progressing thoughtfully.")
        }
        return out
    }

    static func humanize(_ key: String) -> String {
        switch key {
        case "elbowAngle":    "Elbow depth"
        case "kneeAngle":     "Knee depth"
        case "hipAngle":      "Hip position"
        case "spineAngle":    "Back alignment"
        case "shoulderAngle": "Shoulder range"
        default: key.capitalized
        }
    }
}
