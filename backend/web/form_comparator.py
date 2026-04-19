"""Port of ios/FormCoach/Analysis/FormComparator.swift."""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional

from .angles import BodyAngles
from .exercise import ExerciseType


@dataclass
class AngleRange:
    lo: float
    hi: float

    def deviation(self, v: float) -> float:
        if v < self.lo:
            return self.lo - v
        if v > self.hi:
            return v - self.hi
        return 0.0


@dataclass
class FormCorrection:
    joint: str
    message: str
    severity: float  # 0-1


@dataclass
class FormResult:
    score: float
    corrections: list[FormCorrection]
    phase: str


def _R(lo: float, hi: float) -> AngleRange:
    return AngleRange(lo, hi)


# Reference angle ranges — copied verbatim from FormComparator.swift.
REFERENCE: dict[ExerciseType, dict[str, dict[str, AngleRange]]] = {
    ExerciseType.PUSHUP: {
        "bottom": {"elbow": _R(70, 100),  "hip": _R(160, 180), "spine": _R(160, 180)},
        "top":    {"elbow": _R(155, 180), "hip": _R(160, 180), "spine": _R(160, 180)},
    },
    ExerciseType.SQUAT: {
        "bottom": {"knee": _R(60, 100),   "hip": _R(60, 100),   "spine": _R(150, 180)},
        "top":    {"knee": _R(155, 180),  "hip": _R(155, 180),  "spine": _R(150, 180)},
    },
    ExerciseType.DEADLIFT: {
        "bottom": {"knee": _R(110, 140),  "hip": _R(70, 110),   "spine": _R(155, 180)},
        "top":    {"knee": _R(165, 180),  "hip": _R(165, 180),  "spine": _R(165, 180)},
    },
    ExerciseType.PLANK: {
        "hold":   {"elbow": _R(85, 95),   "knee": _R(160, 180), "hip": _R(160, 180), "spine": _R(160, 180)},
    },
    ExerciseType.LUNGE: {
        "bottom": {"knee": _R(85, 100),   "hip": _R(85, 100),   "spine": _R(150, 180)},
        "top":    {"knee": _R(155, 180),  "hip": _R(155, 180),  "spine": _R(150, 180)},
    },
    ExerciseType.JUMPING_JACKS: {
        "open":   {"hip": _R(150, 180),   "shoulder": _R(150, 180)},
        "closed": {"hip": _R(165, 180),   "shoulder": _R(0, 40)},
    },
    ExerciseType.CURL: {
        "bottom": {"elbow": _R(150, 180), "spine": _R(165, 180)},
        "top":    {"elbow": _R(30, 60),   "spine": _R(165, 180)},
    },
}

WEIGHTS: dict[ExerciseType, dict[str, float]] = {
    ExerciseType.PUSHUP:        {"elbow": 0.40, "hip": 0.30, "spine": 0.30},
    ExerciseType.SQUAT:         {"knee":  0.40, "hip": 0.25, "spine": 0.35},
    ExerciseType.DEADLIFT:      {"spine": 0.50, "hip": 0.30, "knee":  0.20},
    ExerciseType.PLANK:         {"hip":   0.40, "spine": 0.30, "elbow": 0.20, "knee": 0.10},
    ExerciseType.LUNGE:         {"knee":  0.40, "hip": 0.30, "spine": 0.30},
    ExerciseType.JUMPING_JACKS: {"shoulder": 0.50, "hip": 0.50},
    ExerciseType.CURL:          {"elbow": 0.70, "spine": 0.30},
}

MESSAGES: dict[str, dict[str, str]] = {
    "pushup":        {"elbow_high": "Go deeper", "elbow_low": "Fully extend your arms",
                      "hip_low": "Keep your hips up", "spine_low": "Straighten your back"},
    "squat":         {"knee_high": "Go deeper", "spine_low": "Keep your chest up",
                      "hip_low": "Open your hips"},
    "deadlift":      {"spine_low": "Keep your back flat", "hip_low": "Drive hips forward",
                      "knee_low": "Don't squat the lift"},
    "plank":         {"hip_low": "Raise your hips", "hip_high": "Lower your hips",
                      "spine_low": "Straighten your back"},
    "lunge":         {"knee_high": "Lower your back knee", "spine_low": "Keep your torso upright"},
    "jumping_jacks": {"shoulder_low": "Raise your arms higher", "hip_low": "Jump wider"},
    "curl":          {"elbow_high": "Curl higher", "elbow_low": "Fully extend at the bottom",
                      "spine_low": "Stop swinging"},
}


EMPTY_RESULT = FormResult(score=0.0, corrections=[], phase="")


def evaluate(angles: BodyAngles, exercise: ExerciseType, phase: str) -> FormResult:
    if exercise == ExerciseType.UNKNOWN:
        return EMPTY_RESULT
    ref_phases = REFERENCE.get(exercise)
    if not ref_phases or phase not in ref_phases:
        return EMPTY_RESULT
    ref = ref_phases[phase]
    weights = WEIGHTS[exercise]

    # Map joint name → current angle.
    current = {
        "elbow": angles.elbowAngle,
        "knee": angles.kneeAngle,
        "hip": angles.hipAngle,
        "spine": angles.spine,
        "shoulder": angles.shoulderAngle,
    }

    total_weight = 0.0
    weighted_score = 0.0
    corrections: list[FormCorrection] = []

    for name, rng in ref.items():
        angle = current.get(name)
        w = weights.get(name)
        if angle is None or w is None:
            continue
        total_weight += w
        dev = rng.deviation(angle)
        joint_score = 100.0 if dev == 0 else max(0.0, 100.0 - (dev / 30.0) * 100.0)
        weighted_score += w * joint_score
        if dev > 10:
            key = f"{name}_low" if angle < rng.lo else f"{name}_high"
            default = f"Improve your {name}" if angle < rng.lo else "Don't overextend"
            msg = MESSAGES.get(exercise.value, {}).get(key, default)
            corrections.append(FormCorrection(
                joint=f"{name}Angle",  # match iOS key shape for humanize()
                message=msg,
                severity=min(1.0, dev / 30.0),
            ))

    score = weighted_score / total_weight if total_weight > 0 else 50.0
    corrections.sort(key=lambda c: c.severity, reverse=True)
    return FormResult(score=score, corrections=corrections, phase=phase)
