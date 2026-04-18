from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime, timezone

from database import get_db
from models import User
from schemas import UserIn, UserOut
from auth import get_current_user

router = APIRouter(prefix="/users", tags=["users"])


def _to_out(u: User) -> UserOut:
    return UserOut(
        id=u.id,
        email=u.email or "",
        name=u.name or "Athlete",
        goal=u.goal or "form",
        fitnessLevel=u.fitness_level or "beginner",
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
