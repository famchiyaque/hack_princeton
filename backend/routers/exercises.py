from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from models import Exercise
from schemas import ExerciseOut, ExercisesResponse

router = APIRouter(prefix="/exercises", tags=["exercises"])


def _to_out(ex: Exercise) -> ExerciseOut:
    rd = ex.reference_data
    phases = [
        {
            "name": p["name"],
            "referenceAngles": p["referenceAngles"],
        }
        for p in rd.get("phases", [])
    ]
    return ExerciseOut(
        id=ex.id,
        name=ex.name,
        phases=phases,
        corrections=rd.get("corrections", {}),
    )


@router.get("", response_model=ExercisesResponse)
def list_exercises(db: Session = Depends(get_db)):
    exercises = db.query(Exercise).all()
    return ExercisesResponse(exercises=[_to_out(e) for e in exercises])


@router.get("/{exercise_id}", response_model=ExerciseOut)
def get_exercise(exercise_id: str, db: Session = Depends(get_db)):
    ex = db.query(Exercise).filter(Exercise.id == exercise_id).first()
    if not ex:
        raise HTTPException(404, f"Exercise '{exercise_id}' not found")
    return _to_out(ex)
