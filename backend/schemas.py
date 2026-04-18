from pydantic import BaseModel, Field
from typing import Any
import uuid


# ── Exercises ──────────────────────────────────────────────

class AngleRange(BaseModel):
    min: float
    max: float


class ExercisePhase(BaseModel):
    name: str
    referenceAngles: dict[str, AngleRange]


class ExerciseOut(BaseModel):
    id: str
    name: str
    phases: list[ExercisePhase]
    corrections: dict[str, str]

    model_config = {"from_attributes": True}


class ExercisesResponse(BaseModel):
    exercises: list[ExerciseOut]


# ── Sessions ───────────────────────────────────────────────

class CorrectionCount(BaseModel):
    type: str
    count: int


class SessionExerciseIn(BaseModel):
    exerciseId: str
    reps: int = 0
    avgScore: float = 0.0
    duration: int = 0
    corrections: list[CorrectionCount] = []


class CreateSessionBody(BaseModel):
    userId: str = "anonymous"
    exercises: list[SessionExerciseIn] = []
    totalDuration: int = 0
    startedAt: str = ""


class SessionExerciseOut(BaseModel):
    id: str
    exerciseId: str
    reps: int
    avgScore: float
    duration: int
    corrections: list[CorrectionCount]

    model_config = {"from_attributes": True}


class SessionOut(BaseModel):
    id: str
    userId: str
    totalDuration: int
    startedAt: str
    createdAt: str
    exercises: list[SessionExerciseOut] = []

    model_config = {"from_attributes": True}


class SessionsResponse(BaseModel):
    sessions: list[SessionOut]
    total: int


# ── Analysis ───────────────────────────────────────────────

class AnalysisRequest(BaseModel):
    sessionId: str
    rawData: dict[str, Any] = {}


class AnalysisResponse(BaseModel):
    summary: str
    tips: list[str]
