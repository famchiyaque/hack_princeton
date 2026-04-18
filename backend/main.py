"""
Kinetic API — FastAPI backend
Run: uvicorn main:app --reload --port 8000 --host 0.0.0.0

NOTE on architecture:
 - All real-time form analysis, rep counting, and in-session feedback
   happens ON-DEVICE in the iOS app for latency and offline support.
 - This backend's responsibilities are strictly:
     * Serve canonical exercise reference data
     * Store user profile (onboarding answers)
     * Persist completed session summaries
     * Aggregate historical data for the Insights tab
 - No AI / LLM calls are made server-side. Session reports are
   computed deterministically by the iOS client (SessionAnalyzer.swift).
"""
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

load_dotenv("../.env")

from database import engine, SessionLocal
from models import Base
from routers import exercises, sessions, users, insights, records, analysis
import seed_data

app = FastAPI(title="Kinetic API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("CORS_ORIGINS", "*").split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def startup():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        seed_data.seed(db)
    finally:
        db.close()


app.include_router(exercises.router, prefix="/api")
app.include_router(sessions.router, prefix="/api")
app.include_router(users.router, prefix="/api")
app.include_router(insights.router, prefix="/api")
app.include_router(records.router, prefix="/api")
app.include_router(analysis.router, prefix="/api")


@app.get("/api/health")
def health():
    return {"status": "ok", "service": "kinetic"}
