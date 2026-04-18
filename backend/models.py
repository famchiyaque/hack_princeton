from sqlalchemy import Column, String, Integer, Float, JSON, ForeignKey, func
from sqlalchemy.orm import relationship
from database import Base
import uuid


def new_id():
    return str(uuid.uuid4())


class Exercise(Base):
    __tablename__ = "exercises"

    id = Column(String, primary_key=True, default=new_id)
    name = Column(String, nullable=False)
    reference_data = Column(JSON, nullable=False)


class Session(Base):
    __tablename__ = "sessions"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(String, default="anonymous")
    total_duration = Column(Integer)
    started_at = Column(String)
    created_at = Column(String, default=func.datetime("now"))

    exercises = relationship("SessionExercise", back_populates="session", cascade="all, delete-orphan")


class SessionExercise(Base):
    __tablename__ = "session_exercises"

    id = Column(String, primary_key=True, default=new_id)
    session_id = Column(String, ForeignKey("sessions.id"), nullable=False)
    exercise_id = Column(String, nullable=False)
    reps = Column(Integer, default=0)
    avg_score = Column(Float, default=0.0)
    duration = Column(Integer, default=0)
    corrections = Column(JSON, default=list)

    session = relationship("Session", back_populates="exercises")
