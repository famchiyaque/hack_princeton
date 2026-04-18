from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as DBSession
from collections import Counter
from datetime import datetime, timezone, timedelta

from database import get_db
from models import Session, SessionExercise
from schemas import InsightsResponse, ExerciseStat, CorrectionCount
from auth import get_current_user

router = APIRouter(prefix="/insights", tags=["insights"])


@router.get("", response_model=InsightsResponse)
def user_insights(
    current_user: dict = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    user_id = current_user["user_id"]
    sessions = db.query(Session).filter(Session.user_id == user_id).all()

    total_reps = 0
    total_seconds = 0
    all_scores: list[float] = []
    per_exercise: dict[str, dict] = {}
    correction_counter: Counter = Counter()

    today = datetime.now(timezone.utc).date()
    day_minutes = [0] * 7
    active_days: set = set()

    for s in sessions:
        total_seconds += s.total_duration or 0
        try:
            started = datetime.fromisoformat((s.started_at or s.created_at).replace("Z", "+00:00"))
            delta_days = (today - started.date()).days
            active_days.add(started.date())
            if 0 <= delta_days < 7:
                day_minutes[6 - delta_days] += (s.total_duration or 0) // 60
        except Exception:
            pass

        for ex in s.exercises:
            total_reps += ex.reps or 0
            if ex.avg_score:
                all_scores.append(ex.avg_score)

            bucket = per_exercise.setdefault(
                ex.exercise_id, {"reps": 0, "scoreSum": 0.0, "scoreCount": 0, "sessions": 0}
            )
            bucket["reps"] += ex.reps or 0
            bucket["sessions"] += 1
            if ex.avg_score:
                bucket["scoreSum"] += ex.avg_score
                bucket["scoreCount"] += 1

            for c in ex.corrections or []:
                correction_counter[c.get("type", "unknown")] += c.get("count", 0)

    by_exercise = [
        ExerciseStat(
            exerciseId=eid,
            totalReps=data["reps"],
            avgScore=(data["scoreSum"] / data["scoreCount"]) if data["scoreCount"] else 0.0,
            sessionCount=data["sessions"],
        )
        for eid, data in per_exercise.items()
    ]
    by_exercise.sort(key=lambda s: s.sessionCount, reverse=True)

    top_corrections = [
        CorrectionCount(type=t, count=c)
        for t, c in correction_counter.most_common(3)
    ]

    streak = _compute_streak(active_days, today)

    return InsightsResponse(
        totalSessions=len(sessions),
        totalReps=total_reps,
        totalMinutes=total_seconds // 60,
        overallAvgScore=(sum(all_scores) / len(all_scores)) if all_scores else 0.0,
        streakDays=streak,
        byExercise=by_exercise,
        topCorrections=top_corrections,
        last7DaysMinutes=day_minutes,
    )


def _compute_streak(active_days: set, today) -> int:
    if not active_days:
        return 0
    streak = 0
    day = today
    if day not in active_days:
        day = day - timedelta(days=1)
    while day in active_days:
        streak += 1
        day = day - timedelta(days=1)
    return streak
