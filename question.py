from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime, timezone

from database import get_db
from models import User
from schemas import UserIn, UserOut
from auth import get_current_user

router = APIRouter(prefix="/users", tags=["users"])


def _goals_list(u: User) -> list[str]:
    raw = u.goals
    if raw:
        return list(raw)
    g = u.goal or "athleticism"
    return [g] if g else ["athleticism"]


def _to_out(u: User) -> UserOut:
    return UserOut(
        id=u.id,
        email=u.email or "",
        name=u.name or "Athlete",
        goals=_goals_list(u),
        fitnessLevel=u.fitness_level or "beginner",
        weightLbs=u.weight_lbs if u.weight_lbs is not None else 175,
        heightFeet=u.height_feet if u.height_feet is not None else 5,
        heightInches=u.height_inches if u.height_inches is not None else 10,
        age=u.age if u.age is not None else 30,
        gender=u.gender or "prefer_not_to_say",
        healthNotes=u.health_notes or [],
        bodyGoals=u.body_goals or [],
        createdAt=u.created_at or "",
    )


def _get_or_create(user_id: str, email: str, db: Session) -> User:
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        user = User(
            id=user_id,
            email=email,
            created_at=datetime.now(timezone.utc).isoformat(),
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    return user


@router.get("/me", response_model=UserOut)
def get_me(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Returns the authenticated user's profile, creating one if first login."""
    user = _get_or_create(current_user["user_id"], current_user["email"], db)
    return _to_out(user)