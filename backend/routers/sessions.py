from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as DBSession
from database import get_db
from models import Session, SessionExercise
from schemas import CreateSessionBody, SessionOut, SessionsResponse, SessionExerciseOut, CorrectionCount, LatestSessionResponse
from auth import get_current_user
from datetime import datetime, timezone
import uuid

router = APIRouter(prefix="/sessions", tags=["sessions"])


def _exercise_to_out(se: SessionExercise) -> SessionExerciseOut:
    corrections = [CorrectionCount(**c) for c in (se.corrections or [])]
    return SessionExerciseOut(
        id=se.id,
        exerciseId=se.exercise_id,
        reps=se.reps,
        avgScore=se.avg_score,
        duration=se.duration,
        corrections=corrections,
    )


def _session_to_out(s: Session) -> SessionOut:
    return SessionOut(
        id=s.id,
        userId=s.user_id,
        totalDuration=s.total_duration or 0,
        startedAt=s.started_at or "",
        createdAt=s.created_at or "",
        summary=s.summary,
        exercises=[_exercise_to_out(e) for e in s.exercises],
    )


@router.post("", response_model=SessionOut, status_code=201)
def create_session(
    body: CreateSessionBody,
    current_user: dict = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    session_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).isoformat()

    session = Session(
        id=session_id,
        user_id=current_user["user_id"],
        total_duration=body.totalDuration,
        started_at=body.startedAt or now,
        created_at=now,
    )
    db.add(session)

    for ex in body.exercises:
        db.add(SessionExercise(
            id=str(uuid.uuid4()),
            session_id=session_id,
            exercise_id=ex.exerciseId,
            reps=ex.reps,
            avg_score=ex.avgScore,
            duration=ex.duration,
            corrections=[c.model_dump() for c in ex.corrections],
        ))

    db.commit()
    db.refresh(session)
    return _session_to_out(session)


@router.get("", response_model=SessionsResponse)
def list_sessions(
    limit: int = 20,
    offset: int = 0,
    current_user: dict = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    user_id = current_user["user_id"]
    query = db.query(Session).filter(Session.user_id == user_id)
    total = query.count()
    sessions = query.order_by(Session.created_at.desc()).offset(offset).limit(limit).all()
    return SessionsResponse(sessions=[_session_to_out(s) for s in sessions], total=total)


@router.get("/latest", response_model=LatestSessionResponse)
def latest_session(
    current_user: dict = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    """Most recent session for the signed-in user (used to populate the dashboard)."""
    user_id = current_user["user_id"]
    s = (
        db.query(Session)
        .filter(Session.user_id == user_id)
        .order_by(Session.created_at.desc())
        .first()
    )
    return LatestSessionResponse(session=_session_to_out(s) if s else None)


@router.get("/{session_id}", response_model=SessionOut)
def get_session(
    session_id: str,
    current_user: dict = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    s = db.query(Session).filter(Session.id == session_id).first()
    if not s:
        raise HTTPException(404, "Session not found")
    if s.user_id != current_user["user_id"]:
        raise HTTPException(403, "Not your session")
    return _session_to_out(s)


@router.delete("/{session_id}", status_code=204)
def delete_session(
    session_id: str,
    current_user: dict = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    s = db.query(Session).filter(Session.id == session_id).first()
    if not s:
        raise HTTPException(404, "Session not found")
    if s.user_id != current_user["user_id"]:
        raise HTTPException(403, "Not your session")
    db.delete(s)
    db.commit()
