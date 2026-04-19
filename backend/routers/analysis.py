import os

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as DBSession

from database import get_db
from models import Session, Exercise
from schemas import SessionSummaryRequest, SessionSummaryResponse, CorrectionCount
from auth import get_current_user

router = APIRouter(prefix="/analysis", tags=["analysis"])

SYSTEM_PROMPT = (
    "You are an expert strength coach giving a concise, encouraging post-workout review. "
    "Respond in exactly three short paragraphs separated by blank lines, in this order:\n"
    "1) Overall take on the session (tone: warm, honest).\n"
    "2) Biggest win — the specific thing the athlete did well, referencing the numbers.\n"
    "3) Next-session focus — one concrete, actionable cue based on the top risk/correction.\n"
    "Keep each paragraph to 1-2 sentences. Do not use bullet points or headings."
)


def _build_prompt_from_report(report: dict) -> str:
    tempo = report.get("tempo") or {}
    lines = [
        f"Exercise: {report.get('exercise', 'unknown')}",
        f"Reps: {report.get('reps', 0)}",
        f"Duration: {report.get('duration', 0)}s",
        f"Average form score: {float(report.get('avgScore') or 0):.0f}/100",
        f"Consistency: {float(report.get('consistency') or 0):.0f}/100",
    ]
    if tempo:
        lines.append(
            f"Tempo: {tempo.get('label', '—')} "
            f"(avg {float(tempo.get('avgRepSeconds') or 0):.1f}s/rep, "
            f"fastest {float(tempo.get('fastest') or 0):.1f}s, "
            f"slowest {float(tempo.get('slowest') or 0):.1f}s)"
        )
    per_rep = report.get("perRepScores") or []
    if per_rep:
        rounded = [int(round(float(s))) for s in per_rep]
        lines.append(f"Per-rep scores: {rounded}")
    strengths = report.get("strengths") or []
    if strengths:
        lines.append("Strengths:")
        lines.extend(f"- {s}" for s in strengths)
    risks = report.get("risks") or []
    if risks:
        lines.append("Risks:")
        lines.extend(f"- {r}" for r in risks)
    corrections = report.get("correctionsByType") or {}
    if corrections:
        parts = ", ".join(f"{k} x{v}" for k, v in corrections.items())
        lines.append(f"Corrections: {parts}")
    return "\n".join(lines)


def _build_prompt_from_db(session: Session, exercises_map: dict[str, str]) -> str:
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

    if session.ai_summary:
        return SessionSummaryResponse(sessionId=body.sessionId, summary=session.ai_summary)

    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise HTTPException(503, "AI summary unavailable — no OPENAI_API_KEY configured")

    if session.client_report:
        prompt = _build_prompt_from_report(session.client_report)
    else:
        exercises = db.query(Exercise).all()
        exercises_map = {e.id: e.name for e in exercises}
        prompt = _build_prompt_from_db(session, exercises_map)

    try:
        from openai import OpenAI
        client = OpenAI(api_key=api_key)
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            max_tokens=320,
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

    session.ai_summary = summary
    db.commit()

    return SessionSummaryResponse(sessionId=body.sessionId, summary=summary)
