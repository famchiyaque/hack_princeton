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

    g = body.goals or []
    legacy_goal = g[0] if g else "athleticism"

    if user is None:
        user = User(
            id=user_id,
            name=body.name,
            goal=legacy_goal,
            goals=g,
            fitness_level=body.fitnessLevel,
            weight_lbs=body.weightLbs,
            height_feet=body.heightFeet,
            height_inches=body.heightInches,
            age=body.age,
            gender=body.gender,
            health_notes=body.healthNotes,
            body_goals=body.bodyGoals,
            created_at=datetime.now(timezone.utc).isoformat(),
        )
        db.add(user)
    else:
        user.name = body.name
        user.goals = g
        user.goal = legacy_goal
        user.fitness_level = body.fitnessLevel
        user.weight_lbs = body.weightLbs
        user.height_feet = body.heightFeet
        user.height_inches = body.heightInches
        user.age = body.age
        user.gender = body.gender
        user.health_notes = body.healthNotes
        user.body_goals = body.bodyGoals


@router.get("/me", response_model=UserOut)
def get_me(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Returns the authenticated user's profile, creating one if first login."""
    user = _get_or_create(current_user["user_id"], current_user["email"], db)
    return _to_out(user)


@router.post("", response_model=UserOut, status_code=201)
def update_user(
    body: UserIn,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Updates the authenticated user's profile (e.g. after onboarding)."""
    user = _get_or_create(current_user["user_id"], current_user["email"], db)
    user.name = body.name
    user.goal = body.goal
    user.fitness_level = body.fitnessLevel
    user.health_notes = body.healthNotes
    user.body_goals = body.bodyGoals
    db.commit()
    db.refresh(user)
    return _to_out(user)


@router.get("/{user_id}", response_model=UserOut)
def get_user(
    user_id: str,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if user_id != current_user["user_id"]:
        raise HTTPException(403, "Cannot view another user's profile")
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(404, "User not found")
    return _to_out(user)
