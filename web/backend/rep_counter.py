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
    """Adaptive rep counter.

    Instead of fixed angle thresholds (which don't fit every user's range of
    motion), we track the primary angle's observed min/max, place a midpoint
    + hysteresis deadband between them, and count one rep per full cycle
    (two midpoint crossings). Calibrates automatically after ~30° of motion.
    """

    MIN_SPAN = 30.0       # degrees of travel required before we start counting
    HYSTERESIS = 0.15     # fraction of the span used as a deadband

    def __init__(self, exercise: ExerciseType):
        self.exercise = exercise
        # Kept for the debug HUD / FormComparator reference phase lookup.
        self.down_threshold = exercise.down_threshold
        self.up_threshold = exercise.up_threshold

        self.rep_count = 0
        self.phase: Phase = Phase.UP

        # Adaptive calibration state.
        self._min_seen: float = 180.0
        self._max_seen: float = 0.0
        self._last_side: str | None = None   # "high" | "low" | None
        self._flip_count: int = 0

    def reset(self):
        self.rep_count = 0
        self.phase = Phase.UP
        self._min_seen = 180.0
        self._max_seen = 0.0
        self._last_side = None
        self._flip_count = 0

    def primary_angle(self, angles: BodyAngles):
        attr = _PRIMARY.get(self.exercise)
        if not attr:
            return None
        return getattr(angles, attr, None)

    def update(self, primary_angle: float) -> bool:
        p = primary_angle
        # Slow decay toward current value so stale extremes don't freeze the
        # calibration (e.g., if a detection blip hit an outlier once).
        self._min_seen = min(self._min_seen, p) * 0.999 + p * 0.001
        self._max_seen = max(self._max_seen, p) * 0.999 + p * 0.001
        # But hard-update the true min/max on each frame.
        if p < self._min_seen:
            self._min_seen = p
        if p > self._max_seen:
            self._max_seen = p

        span = self._max_seen - self._min_seen
        if span < self.MIN_SPAN:
            return False

        midpoint = (self._min_seen + self._max_seen) / 2
        deadband = span * self.HYSTERESIS

        if p > midpoint + deadband:
            side = "high"
        elif p < midpoint - deadband:
            side = "low"
        else:
            return False  # within deadband — no state change

        if self._last_side is None:
            # Count the calibration motion itself as the first half of a rep.
            self._last_side = side
            self._flip_count = 1
            return False
        if side == self._last_side:
            return False

        # Side flipped. Update phase for the scoring_phase() lookup.
        self._last_side = side
        self._flip_count += 1
        self.phase = Phase.UP if side == "high" else Phase.DOWN

        # A full rep is two flips (high→low→high or low→high→low).
        if self._flip_count >= 2:
            self._flip_count = 0
            self.rep_count += 1
            return True
        return False

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
