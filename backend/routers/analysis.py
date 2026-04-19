import os

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as DBSession

from database import get_db
from models import Session, Exercise
from schemas import SessionSummaryRequest, SessionSummaryResponse, CorrectionCount
from auth import get_current_user

router = APIRouter(prefix="/analysis", tags=["analysis"])

SYSTEM_PROMPT = (
    "You are a concise, knowledgeable strength & conditioning coach. "
    "Given a workout session's raw data (exercises, reps, per-exercise form score "
    "on a 0-100 scale, duration, and counted form corrections by joint/type), "
    "produce a short post-session debrief with three clearly labeled parts:\n"
    "1. Recap — 1-2 sentences summarizing volume and overall execution, "
    "referencing the actual numbers (reps, form scores, duration).\n"
    "2. Risks — 1-2 sentences calling out the most likely injury or overuse "
    "risks implied by the recurring corrections and low form scores "
    "(e.g. knee valgus on squats, lumbar flexion on deadlifts, shoulder "
    "impingement on presses). Be specific about which exercise and which "
    "joint/pattern is at risk. If the data genuinely shows no concerning "
    "pattern, say so instead of inventing one.\n"
    "3. Next focus — 1 sentence on the single highest-priority cue or drill "
    "to address the biggest risk next session.\n"
    "Stay encouraging but honest. Do not exceed ~90 words total. "
    "Ground every claim in the numbers provided — never fabricate reps, "
    "scores, or corrections that aren't in the data."
)


def _build_prompt(session: Session, exercises_map: dict[str, str]) -> str:
    total_seconds = session.total_duration or 0
    minutes = total_seconds // 60
    seconds = total_seconds % 60
    lines = [
        "Workout session data:",
        f"- Total duration: {minutes}m {seconds}s",
        f"- Exercises performed: {len(session.exercises)}",
        "",
        "Per-exercise breakdown (form score is 0-100, higher = better):",
    ]
    for ex in session.exercises:
        name = exercises_map.get(ex.exercise_id, ex.exercise_id)
        corrections = [CorrectionCount(**c) for c in (ex.corrections or [])]
        correction_str = (
            ", ".join(f"{c.type} x{c.count}" for c in corrections) or "none"
        )
        ex_minutes = (ex.duration or 0) // 60
        ex_seconds = (ex.duration or 0) % 60
        lines.append(
            f"- {name}: {ex.reps} reps over {ex_minutes}m {ex_seconds}s, "
            f"avg form score {ex.avg_score:.0f}/100, "
            f"corrections triggered: {correction_str}"
        )
    lines.append("")
    lines.append(
        "Write the Recap / Risks / Next focus debrief described in the system "
        "prompt. Pay particular attention to the corrections list — repeated "
        "corrections at the same joint are the strongest signal of injury risk."
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
            max_tokens=400,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": prompt},
            ],
        )
        summary = (response.choices[0].message.content or "").strip()
    except ImportError:
        raise HTTPException(503, "openai package not installed")
    except Exception as e:
        raise HTTPException(502, f"AI request failed: {e}")

    session.summary = summary
    db.add(session)
    db.commit()

    return SessionSummaryResponse(sessionId=body.sessionId, summary=summary)
