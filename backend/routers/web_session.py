"""WebSocket endpoint for the web prototype's live frame pipeline."""
from __future__ import annotations

import json
import logging

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from web.exercise import ExerciseType
from web.session_state import SessionState

log = logging.getLogger("kinetic-web")
router = APIRouter()


@router.websocket("/ws/session")
async def ws_session(ws: WebSocket):
    await ws.accept()
    session = SessionState()
    log.info("web session started")
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
        log.info("web session disconnected")
    finally:
        session.close()
        log.info("web session closed")
