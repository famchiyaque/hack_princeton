"""FastAPI app: WebSocket for live frames + static frontend."""
from __future__ import annotations

import json
import logging
from pathlib import Path

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from exercise import ExerciseType
from session_state import SessionState

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("kinetic-web")

app = FastAPI(title="Kinetic Web Prototype")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

FRONTEND_DIR = Path(__file__).resolve().parent.parent / "frontend"


@app.get("/api/health")
def health():
    return {"status": "ok"}


@app.websocket("/ws/session")
async def ws_session(ws: WebSocket):
    await ws.accept()
    session = SessionState()
    log.info("session started")
    try:
        while True:
            msg = await ws.receive()
            if msg.get("type") == "websocket.disconnect":
                break
            if msg.get("bytes") is not None:
                result = session.process_frame(msg["bytes"])
                await ws.send_text(json.dumps(result))
            elif msg.get("text") is not None:
                try:
                    payload = json.loads(msg["text"])
                except json.JSONDecodeError:
                    continue
                ptype = payload.get("type")
                if ptype == "end":
                    report = session.build_report()
                    await ws.send_text(json.dumps({"type": "report", "report": report.to_dict()}))
                    break
                if ptype == "setExercise":
                    val = payload.get("exercise")
                    try:
                        ex = ExerciseType(val) if val else None
                    except ValueError:
                        ex = None
                    session.set_forced_exercise(ex)
    except WebSocketDisconnect:
        log.info("session disconnected")
    finally:
        session.close()
        log.info("session closed")


# Serve the frontend from the same origin so getUserMedia + WS work without CORS dance.
if FRONTEND_DIR.exists():
    app.mount("/static", StaticFiles(directory=FRONTEND_DIR), name="static")

    @app.get("/")
    def index():
        return FileResponse(FRONTEND_DIR / "index.html")

    @app.get("/app.js")
    def app_js():
        return FileResponse(FRONTEND_DIR / "app.js")

    @app.get("/styles.css")
    def styles_css():
        return FileResponse(FRONTEND_DIR / "styles.css")
