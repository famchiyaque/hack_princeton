"""Port of ios/FormCoach/Feedback/RepCounter.swift."""
from __future__ import annotations

from enum import Enum

from angles import BodyAngles
from exercise import ExerciseType


class Phase(str, Enum):
    UP = "up"
    GOING_DOWN = "goingDown"
    DOWN = "down"
    COMING_UP = "comingUp"


# Which BodyAngles attribute drives the rep for each exercise.
_PRIMARY = {
    ExerciseType.PUSHUP:        "elbowAngle",
    ExerciseType.SQUAT:         "kneeAngle",
    ExerciseType.LUNGE:         "kneeAngle",
    ExerciseType.DEADLIFT:      "hipAngle",
    ExerciseType.CURL:          "elbowAngle",
    ExerciseType.JUMPING_JACKS: "shoulderAngle",
}


class RepCounter:
    def __init__(self, exercise: ExerciseType):
        self.exercise = exercise
        self.down_threshold = exercise.down_threshold
        self.up_threshold = exercise.up_threshold
        self.rep_count = 0
        self.phase: Phase = Phase.UP

    def reset(self):
        self.rep_count = 0
        self.phase = Phase.UP

    def primary_angle(self, angles: BodyAngles):
        attr = _PRIMARY.get(self.exercise)
        if not attr:
            return None
        return getattr(angles, attr, None)

    def update(self, primary_angle: float) -> bool:
        """Returns True when a rep just completed. Mirrors Swift state machine."""
        prev = self.rep_count
        p = primary_angle
        if self.phase == Phase.UP:
            if p < self.down_threshold + 20:
                self.phase = Phase.GOING_DOWN
        elif self.phase == Phase.GOING_DOWN:
            if p <= self.down_threshold:
                self.phase = Phase.DOWN
            if p > self.up_threshold:
                self.phase = Phase.UP
        elif self.phase == Phase.DOWN:
            if p > self.down_threshold + 20:
                self.phase = Phase.COMING_UP
        elif self.phase == Phase.COMING_UP:
            if p >= self.up_threshold:
                self.phase = Phase.UP
                self.rep_count += 1
            if p <= self.down_threshold:
                self.phase = Phase.DOWN
        return self.rep_count > prev

    def scoring_phase(self) -> str:
        """Which FormComparator reference phase to evaluate against right now.

        The Swift app scores form continuously against whichever phase best
        describes the current posture. We mirror that with a simple map:
        when the rep counter thinks you're at/near the bottom of the rep,
        evaluate against 'bottom'; otherwise 'top'. (Curl's 'top' is the
        squeezed position where elbow is flexed — matches `Phase.DOWN` here,
        since down_threshold on a curl is the flexed elbow angle.)
        """
        if self.exercise == ExerciseType.PLANK:
            return "hold"
        if self.exercise == ExerciseType.JUMPING_JACKS:
            # 'down' = arms closed, 'up' = open
            return "closed" if self.phase in (Phase.DOWN, Phase.GOING_DOWN) else "open"
        if self.exercise == ExerciseType.CURL:
            # Curl "top" is the flexed position — which we model as DOWN here.
            return "top" if self.phase in (Phase.DOWN, Phase.GOING_DOWN) else "bottom"
        # pushup / squat / lunge / deadlift
        return "bottom" if self.phase in (Phase.DOWN, Phase.GOING_DOWN) else "top"
