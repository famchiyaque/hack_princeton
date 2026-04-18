from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime, timezone
import uuid

from database import get_db
from models import User
from schemas import UserIn, UserOut

router = APIRouter(prefix="/users", tags=["users"])


def _to_out(u: User) -> UserOut:
    return UserOut(
        id=u.id,
        name=u.name or "Athlete",
        goal=u.goal or "form",
        fitnessLevel=u.fitness_level or "beginner",
        healthNotes=u.health_notes or [],
        bodyGoals=u.body_goals or [],
        createdAt=u.created_at or "",
    )


@router.post("", response_model=UserOut, status_code=201)
def create_or_update_user(body: UserIn, db: Session = Depends(get_db)):
    """Upserts a user. If `id` is blank or missing, a new user is created."""
    user_id = body.id or str(uuid.uuid4())
    user = db.query(User).filter(User.id == user_id).first()

    if user is None:
        user = User(
            id=user_id,
            name=body.name,
            goal=body.goal,
            fitness_level=body.fitnessLevel,
            health_notes=body.healthNotes,
            body_goals=body.bodyGoals,
            created_at=datetime.now(timezone.utc).isoformat(),
        )
        db.add(user)
    else:
        user.name = body.name
        user.goal = body.goal
        user.fitness_level = body.fitnessLevel
        user.health_notes = body.healthNotes
        user.body_goals = body.bodyGoals

    db.commit()
    db.refresh(user)
    return _to_out(user)


@router.get("/{user_id}", response_model=UserOut)
def get_user(user_id: str, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(404, "User not found")
    return _to_out(user)
