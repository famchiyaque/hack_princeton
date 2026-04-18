import os
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as DBSession
from database import get_db
from models import Session, SessionExercise
from schemas import AnalysisRequest, AnalysisResponse

router = APIRouter(prefix="/analysis", tags=["analysis"])


@router.post("", response_model=AnalysisResponse)
async def analyze_session(body: AnalysisRequest, db: DBSession = Depends(get_db)):
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        raise HTTPException(503, "ANTHROPIC_API_KEY not configured")

    session = db.query(Session).filter(Session.id == body.sessionId).first()
    if not session:
        raise HTTPException(404, "Session not found")

    try:
        import anthropic
        client = anthropic.Anthropic(api_key=api_key)

        exercises_summary = []
        for ex in session.exercises:
            corrections = ex.corrections or []
            top_correction = corrections[0]["type"] if corrections else "none"
            exercises_summary.append(
                f"- {ex.exercise_id}: {ex.reps} reps, avg score {ex.avg_score:.0f}/100, "
                f"main correction: {top_correction}"
            )

        prompt = (
            f"You are a personal fitness coach. Analyze this workout session:\n\n"
            f"Duration: {session.total_duration}s\n"
            f"Exercises:\n" + "\n".join(exercises_summary) + "\n\n"
            f"Give encouraging, specific feedback in 2-3 sentences. "
            f"Then list 3 actionable tips as a JSON array under 'tips'."
        )

        message = client.messages.create(
            model="claude-3-5-haiku-latest",
            max_tokens=400,
            messages=[{"role": "user", "content": prompt}],
        )

        text = message.content[0].text
        tips = _extract_tips(text)

        return AnalysisResponse(summary=text, tips=tips)

    except Exception as e:
        raise HTTPException(500, f"Analysis failed: {str(e)}")


def _extract_tips(text: str) -> list[str]:
    import re, json
    match = re.search(r'\[.*?\]', text, re.DOTALL)
    if match:
        try:
            return json.loads(match.group())
        except Exception:
            pass
    lines = [l.strip("- •").strip() for l in text.split("\n") if l.strip().startswith(("-", "•"))]
    return lines[:3] if lines else ["Keep up the great work!", "Focus on form over speed.", "Stay consistent."]
