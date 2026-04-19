from pydantic import BaseModel


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


# ── Users ──────────────────────────────────────────────────

class UserIn(BaseModel):
    name: str = "Athlete"
    goals: list[str] = []
    fitnessLevel: str = "beginner"
    weightLbs: int = 175
    heightFeet: int = 5
    heightInches: int = 10
    age: int = 30
    gender: str = "prefer_not_to_say"
    healthNotes: list[str] = []
    bodyGoals: list[str] = []


class UserOut(BaseModel):
    id: str
    email: str
    name: str
    goals: list[str]
    fitnessLevel: str
    weightLbs: int
    heightFeet: int
    heightInches: int
    age: int
    gender: str
    healthNotes: list[str]
    bodyGoals: list[str]
    createdAt: str

    model_config = {"from_attributes": True}


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
    summary: str | None = None
    exercises: list[SessionExerciseOut] = []

    model_config = {"from_attributes": True}


class SessionsResponse(BaseModel):
    sessions: list[SessionOut]
    total: int


class LatestSessionResponse(BaseModel):
    session: SessionOut | None


# ── Insights ───────────────────────────────────────────────

class ExerciseStat(BaseModel):
    exerciseId: str
    totalReps: int
    avgScore: float
    sessionCount: int


class InsightsResponse(BaseModel):
    totalSessions: int
    totalReps: int
    totalMinutes: int
    overallAvgScore: float
    streakDays: int
    byExercise: list[ExerciseStat]
    topCorrections: list[CorrectionCount]
    last7DaysMinutes: list[int]  # index 0 = 6 days ago, index 6 = today


# ── Records ───────────────────────────────────────────────

class ExerciseRecord(BaseModel):
    exerciseId: str
    bestScore: float
    bestScoreDate: str
    maxReps: int
    maxRepsDate: str

class RecordsResponse(BaseModel):
    longestSessionMinutes: int
    longestSessionDate: str
    bestOverallScore: float
    bestOverallScoreDate: str
    byExercise: list[ExerciseRecord]


# ── Analysis ──────────────────────────────────────────────

class SessionSummaryRequest(BaseModel):
    sessionId: str

class SessionSummaryResponse(BaseModel):
    sessionId: str
    summary: str
