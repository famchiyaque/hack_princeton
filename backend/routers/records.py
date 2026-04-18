from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as DBSession

from database import get_db
from models import Session, SessionExercise
from schemas import RecordsResponse, ExerciseRecord

router = APIRouter(prefix="/records", tags=["records"])


@router.get("/{user_id}", response_model=RecordsResponse)
def user_records(user_id: str, db: DBSession = Depends(get_db)):
    sessions = db.query(Session).filter(Session.user_id == user_id).all()

    longest_minutes = 0
    longest_date = ""
    best_overall = 0.0
    best_overall_date = ""
    per_exercise: dict[str, dict] = {}

    for s in sessions:
        duration_min = (s.total_duration or 0) // 60
        session_date = s.started_at or s.created_at or ""

        if duration_min > longest_minutes:
            longest_minutes = duration_min
            longest_date = session_date

        for ex in s.exercises:
            score = ex.avg_score or 0.0
            reps = ex.reps or 0

            if score > best_overall:
                best_overall = score
                best_overall_date = session_date

            bucket = per_exercise.get(ex.exercise_id)
            if bucket is None:
                bucket = {
                    "bestScore": score,
                    "bestScoreDate": session_date,
                    "maxReps": reps,
                    "maxRepsDate": session_date,
                }
                per_exercise[ex.exercise_id] = bucket
            else:
                if score > bucket["bestScore"]:
                    bucket["bestScore"] = score
                    bucket["bestScoreDate"] = session_date
                if reps > bucket["maxReps"]:
                    bucket["maxReps"] = reps
                    bucket["maxRepsDate"] = session_date

    by_exercise = [
        ExerciseRecord(exerciseId=eid, **data)
        for eid, data in per_exercise.items()
    ]

    return RecordsResponse(
        longestSessionMinutes=longest_minutes,
        longestSessionDate=longest_date,
        bestOverallScore=best_overall,
        bestOverallScoreDate=best_overall_date,
        byExercise=by_exercise,
    )
