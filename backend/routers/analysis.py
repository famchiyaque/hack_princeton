import os

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as DBSession

from database import get_db
from models import Session, Exercise
from schemas import SessionSummaryRequest, SessionSummaryResponse, CorrectionCount
from auth import get_current_user

router = APIRouter(prefix="/analysis", tags=["analysis"])

SYSTEM_PROMPT = (
    "You are a concise, encouraging fitness coach. "
    "Summarize this workout session in 2-3 sentences. "
    "Highlight what went well and one thing to improve next time."
)


def _build_prompt(session: Session, exercises_map: dict[str, str]) -> str:
    lines = [
        f"Duration: {(session.total_duration or 0) // 60} minutes",
        "",
    ]
    for ex in session.exercises:
        name = exercises_map.get(ex.exercise_id, ex.exercise_id)
        corrections = [CorrectionCount(**c) for c in (ex.corrections or [])]
        correction_str = ", ".join(f"{c.type} x{c.count}" for c in corrections)
        lines.append(
            f"- {name}: {ex.reps} reps, form score {ex.avg_score:.0f}/100, "
            f"corrections: {correction_str or 'none'}"
        )
    return "\n".join(lines)


@router.post("/session-summary", response_model=SessionSummaryResponse)
def session_summary(
    body: SessionSummaryRequest,
    current_user: dict = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    session = db.query(Session).filter(Session.id == body.sessionId).first()
    if not session:
        raise HTTPException(404, "Session not found")
    if session.user_id != current_user["user_id"]:
        raise HTTPException(403, "Not your session")

    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise HTTPException(503, "AI summary unavailable — no OPENAI_API_KEY configured")

    exercises = db.query(Exercise).all()
    exercises_map = {e.id: e.name for e in exercises}
    prompt = _build_prompt(session, exercises_map)

    try:
        from openai import OpenAI
        client = OpenAI(api_key=api_key)
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            max_tokens=256,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": prompt},
            ],
        )
        summary = response.choices[0].message.content
    except ImportError:
        raise HTTPException(503, "openai package not installed")
    except Exception as e:
        raise HTTPException(502, f"AI request failed: {e}")

    return SessionSummaryResponse(sessionId=body.sessionId, summary=summary)
