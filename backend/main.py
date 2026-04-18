"""
FormCoach API — FastAPI backend
Run: uvicorn main:app --reload --port 8000
"""
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

load_dotenv("../.env")

from database import engine, SessionLocal
from models import Base
from routers import exercises, sessions, analysis
import seed_data

# ── App ──────────────────────────────────────────────────────────
app = FastAPI(title="FormCoach API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("CORS_ORIGINS", "*").split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Startup ──────────────────────────────────────────────────────
@app.on_event("startup")
def startup():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        seed_data.seed(db)
    finally:
        db.close()

# ── Routers ──────────────────────────────────────────────────────
app.include_router(exercises.router, prefix="/api")
app.include_router(sessions.router, prefix="/api")
app.include_router(analysis.router, prefix="/api")

# ── Health ───────────────────────────────────────────────────────
@app.get("/api/health")
def health():
    return {"status": "ok", "service": "formcoach"}
