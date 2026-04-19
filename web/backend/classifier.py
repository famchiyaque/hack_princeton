"""Port of ios/FormCoach/Analysis/ExerciseClassifier.swift.

Rolling-window feature-based classifier for squat/deadlift/curl/unknown.
"""
from __future__ import annotations

from collections import deque
from dataclasses import dataclass
from typing import Optional

from angles import BodyAngles
from exercise import ExerciseType


@dataclass
class _Sample:
    angles: BodyAngles
    wrist_y: Optional[float]
    hip_y: Optional[float]
    shoulder_y: Optional[float]


class ExerciseClassifier:
    WINDOW_SIZE = 15       # ~0.5s at 30fps
    CLASSIFY_EVERY = 5
    STICKY_WINDOWS = 2

    def __init__(self):
        self.detected: ExerciseType = ExerciseType.UNKNOWN
        self.is_stable: bool = False
        self._samples: deque[_Sample] = deque(maxlen=self.WINDOW_SIZE)
        self._frame_count = 0
        self._candidate: ExerciseType = ExerciseType.UNKNOWN
        self._streak = 0

    @staticmethod
    def _mean_y(a: Optional[float], b: Optional[float]) -> Optional[float]:
        if a is not None and b is not None:
            return (a + b) / 2
        return a if a is not None else b

    def update(self, angles: BodyAngles, joints: dict) -> ExerciseType:
        lw = joints.get("leftWrist")
        rw = joints.get("rightWrist")
        lh = joints.get("leftHip")
        rh = joints.get("rightHip")
        ls = joints.get("leftShoulder")
        rs = joints.get("rightShoulder")
        self._samples.append(_Sample(
            angles=angles,
            wrist_y=self._mean_y(lw.y if lw else None, rw.y if rw else None),
            hip_y=self._mean_y(lh.y if lh else None, rh.y if rh else None),
            shoulder_y=self._mean_y(ls.y if ls else None, rs.y if rs else None),
        ))

        self._frame_count += 1
        if self._frame_count % self.CLASSIFY_EVERY != 0:
            return self.detected
        if len(self._samples) < self.WINDOW_SIZE:
            return self.detected

        raw = self._classify_window()
        if raw == self._candidate:
            self._streak += 1
        else:
            self._candidate = raw
            self._streak = 1

        if self._streak >= self.STICKY_WINDOWS:
            if self._candidate != self.detected:
                self.detected = self._candidate
            self.is_stable = True
        return self.detected

    def reset(self):
        self._samples.clear()
        self._frame_count = 0
        self._candidate = ExerciseType.UNKNOWN
        self._streak = 0
        self.detected = ExerciseType.UNKNOWN
        self.is_stable = False

    # ── Feature extraction ────────────────────────────────────────────
    def _classify_window(self) -> ExerciseType:
        spine_vals = [s.angles.spine for s in self._samples if s.angles.spine is not None]
        knee_vals  = [s.angles.kneeAngle for s in self._samples if s.angles.kneeAngle is not None]
        hip_vals   = [s.angles.hipAngle for s in self._samples if s.angles.hipAngle is not None]
        wrist_ys   = [s.wrist_y for s in self._samples if s.wrist_y is not None]
        elbow_vals = [s.angles.elbowAngle for s in self._samples if s.angles.elbowAngle is not None]
        shoulder_ys = [s.shoulder_y for s in self._samples if s.shoulder_y is not None]
        hip_ys     = [s.hip_y for s in self._samples if s.hip_y is not None]

        if len(knee_vals) < self.WINDOW_SIZE // 3 or len(hip_vals) < self.WINDOW_SIZE // 3:
            return ExerciseType.UNKNOWN

        spine_mean = sum(spine_vals) / len(spine_vals) if spine_vals else 180.0
        knee_range = (max(knee_vals) - min(knee_vals)) if knee_vals else 0
        hip_range  = (max(hip_vals) - min(hip_vals)) if hip_vals else 0
        hip_vs_knee = hip_range / max(knee_range, 1)
        wrist_travel = (max(wrist_ys) - min(wrist_ys)) if wrist_ys else 0
        elbow_range = (max(elbow_vals) - min(elbow_vals)) if elbow_vals else 0

        # Torso orientation in image-space: ~0 when horizontal (push-up/plank),
        # large when upright (standing/curl/squat/deadlift). Positive means
        # shoulders are lower than hips in the frame; we take abs.
        if shoulder_ys and hip_ys:
            shoulder_hip_dy = abs(
                sum(shoulder_ys) / len(shoulder_ys) - sum(hip_ys) / len(hip_ys)
            )
        else:
            shoulder_hip_dy = 1.0  # unknown → assume upright

        if knee_range < 8 and hip_range < 8 and elbow_range < 8:
            return ExerciseType.UNKNOWN

        # Push-up: horizontal torso + elbow flexion drives the rep.
        # Checked before curl since both feature high elbow range.
        looks_like_pushup = (
            shoulder_hip_dy < 0.15
            and elbow_range > 20
            and knee_range < 20
        )
        if looks_like_pushup:
            return ExerciseType.PUSHUP

        looks_like_curl = (
            shoulder_hip_dy > 0.2        # upright torso (rules out push-up)
            and elbow_range > 14
            and knee_range < 28
            and hip_range < 32
            and spine_mean > 115
            and elbow_range > knee_range * 0.85
        )
        if looks_like_curl:
            return ExerciseType.CURL

        if knee_range < 8 and hip_range < 8:
            return ExerciseType.UNKNOWN

        looks_like_squat = (
            spine_mean > 135
            and knee_range > 10
            and hip_vs_knee < 2.0
        )
        looks_like_deadlift = (
            hip_range > 10
            and hip_vs_knee > 1.3
        )

        if looks_like_squat and not looks_like_deadlift:
            return ExerciseType.SQUAT
        if looks_like_deadlift and not looks_like_squat:
            return ExerciseType.DEADLIFT
        if looks_like_squat and looks_like_deadlift:
            if wrist_travel > 0.07:
                return ExerciseType.DEADLIFT
            return ExerciseType.DEADLIFT if hip_vs_knee > 1.7 else ExerciseType.SQUAT
        return ExerciseType.UNKNOWN
