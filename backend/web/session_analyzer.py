"""Port of ios/FormCoach/Analysis/SessionAnalyzer.swift."""
from __future__ import annotations

import math
from dataclasses import dataclass, asdict
from typing import Optional

from .exercise import ExerciseType


@dataclass
class RepRecord:
    index: int
    exercise: str
    score: float
    peak_primary_angle: float
    duration_ms: int
    top_correction: Optional[str]


@dataclass
class TempoAnalysis:
    avg_rep_seconds: float
    fastest: float
    slowest: float
    label: str  # Controlled | Rushed | Variable | —


@dataclass
class SessionReport:
    exercise: str
    reps: int
    duration: int
    avg_score: float
    per_rep_scores: list[float]
    corrections_by_type: dict[str, int]
    best_rep: Optional[RepRecord]
    worst_rep: Optional[RepRecord]
    strengths: list[str]
    risks: list[str]
    tempo: TempoAnalysis
    consistency: float

    def to_dict(self) -> dict:
        return {
            "exercise": self.exercise,
            "reps": self.reps,
            "duration": self.duration,
            "avgScore": round(self.avg_score, 1),
            "perRepScores": [round(s, 1) for s in self.per_rep_scores],
            "correctionsByType": self.corrections_by_type,
            "bestRep": asdict(self.best_rep) if self.best_rep else None,
            "worstRep": asdict(self.worst_rep) if self.worst_rep else None,
            "strengths": self.strengths,
            "risks": self.risks,
            "tempo": asdict(self.tempo),
            "consistency": round(self.consistency, 1),
        }


def _compute_tempo(reps: list[RepRecord]) -> TempoAnalysis:
    if not reps:
        return TempoAnalysis(0, 0, 0, "—")
    durations = [r.duration_ms / 1000 for r in reps]
    avg = sum(durations) / len(durations)
    fastest = min(durations)
    slowest = max(durations)
    if avg < 1.2:
        label = "Rushed"
    elif slowest - fastest > 2.5:
        label = "Variable"
    else:
        label = "Controlled"
    return TempoAnalysis(avg, fastest, slowest, label)


def _compute_consistency(scores: list[float]) -> float:
    if len(scores) < 2:
        return 0.0 if not scores else 100.0
    mean = sum(scores) / len(scores)
    variance = sum((s - mean) ** 2 for s in scores) / len(scores)
    stddev = math.sqrt(variance)
    return max(0.0, 100.0 - stddev * 2.5)


def _humanize(key: str) -> str:
    return {
        "elbowAngle":    "Elbow depth",
        "kneeAngle":     "Knee depth",
        "hipAngle":      "Hip position",
        "spineAngle":    "Back alignment",
        "shoulderAngle": "Shoulder range",
    }.get(key, key.capitalize())


def _build_strengths(avg: float, consistency: float, reps: list[RepRecord], tempo: TempoAnalysis) -> list[str]:
    out: list[str] = []
    if avg >= 85:
        out.append(f"Excellent form — averaged {int(avg)}/100.")
    elif avg >= 70:
        out.append("Solid form throughout the session.")
    if consistency >= 80:
        out.append("Very consistent form rep-to-rep.")
    if tempo.label == "Controlled" and reps:
        out.append(f"Controlled tempo averaging {tempo.avg_rep_seconds:.1f}s per rep.")
    if reps:
        best = max(reps, key=lambda r: r.score)
        if best.score >= 90:
            out.append(f"Peak rep scored {int(best.score)}/100 — your form when it clicks is great.")
    if not out:
        out.append("You showed up and put in reps — that's the hardest part.")
    return out


def _build_risks(corrections: dict[str, int], reps: list[RepRecord], tempo: TempoAnalysis, avg: float) -> list[str]:
    out: list[str] = []
    if corrections:
        top_key = max(corrections, key=lambda k: corrections[k])
        n = corrections[top_key]
        out.append(f"{_humanize(top_key)} flagged {n} time{'' if n == 1 else 's'} — focus here next session.")
    if avg < 60 and reps:
        out.append("Overall score below 60. Consider reducing load and slowing down.")
    if tempo.label == "Rushed":
        out.append("Reps averaged under 1.2s — slow the eccentric for more control.")
    if tempo.label == "Variable":
        out.append("Tempo varied a lot — aim for a consistent cadence.")
    if len(reps) >= 6:
        mid = len(reps) // 2
        first = [r.score for r in reps[:mid]]
        second = [r.score for r in reps[-mid:]]
        avg_first = sum(first) / len(first)
        avg_second = sum(second) / len(second)
        if avg_first - avg_second > 12:
            out.append(
                f"Form dropped ~{int(avg_first - avg_second)} pts in the second half — watch for fatigue."
            )
    if not out:
        out.append("No major issues detected. Keep progressing thoughtfully.")
    return out


def analyze(
    exercise: ExerciseType,
    duration_seconds: int,
    reps: list[RepRecord],
    corrections_by_type: dict[str, int],
) -> SessionReport:
    scores = [r.score for r in reps]
    avg = sum(scores) / len(scores) if scores else 0.0
    tempo = _compute_tempo(reps)
    consistency = _compute_consistency(scores)
    best = max(reps, key=lambda r: r.score) if reps else None
    worst = min(reps, key=lambda r: r.score) if reps else None
    strengths = _build_strengths(avg, consistency, reps, tempo)
    risks = _build_risks(corrections_by_type, reps, tempo, avg)
    return SessionReport(
        exercise=exercise.display_name,
        reps=len(reps),
        duration=duration_seconds,
        avg_score=avg,
        per_rep_scores=scores,
        corrections_by_type=corrections_by_type,
        best_rep=best,
        worst_rep=worst,
        strengths=strengths,
        risks=risks,
        tempo=tempo,
        consistency=consistency,
    )
