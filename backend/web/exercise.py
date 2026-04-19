"""Exercise enum + rep-counter thresholds (from ExerciseClassifier.swift)."""
from __future__ import annotations

from enum import Enum


class ExerciseType(str, Enum):
    PUSHUP = "pushup"
    SQUAT = "squat"
    DEADLIFT = "deadlift"
    PLANK = "plank"
    LUNGE = "lunge"
    JUMPING_JACKS = "jumping_jacks"
    CURL = "curl"
    UNKNOWN = "unknown"

    @property
    def display_name(self) -> str:
        return {
            "pushup": "Push-Up",
            "squat": "Squat",
            "deadlift": "Deadlift",
            "plank": "Plank",
            "lunge": "Lunge",
            "jumping_jacks": "Jumping Jacks",
            "curl": "Bicep Curl",
            "unknown": "Unknown",
        }[self.value]

    @property
    def down_threshold(self) -> float:
        return {
            "pushup": 100.0,
            "squat": 100.0,
            "lunge": 100.0,
            "deadlift": 110.0,
            "curl": 60.0,
            "jumping_jacks": 40.0,
            "plank": 90.0,
            "unknown": 90.0,
        }[self.value]

    @property
    def up_threshold(self) -> float:
        return {
            "pushup": 155.0,
            "squat": 155.0,
            "lunge": 155.0,
            "deadlift": 155.0,
            "curl": 150.0,
            "jumping_jacks": 150.0,
            "plank": 90.0,
            "unknown": 90.0,
        }[self.value]
