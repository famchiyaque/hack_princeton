import asyncio
import base64
import logging
import os

import httpx
from fastapi import APIRouter, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/tts", tags=["tts"])

# ── ElevenLabs config ─────────────────────────────────────────────────────────
# Models (fastest → best quality):
#   eleven_turbo_v2_5   ~300 ms TTFB  ← default
#   eleven_turbo_v2     ~400 ms
#   eleven_multilingual_v2  best quality, ~600-800 ms
#
# Voices — copy any voice_id from elevenlabs.io/app/voice-library:
#   21m00Tcm4TlvDq8ikWAM  Rachel  – calm, clear American female  ← default
#   pNInz6obpgDQGcFmaJgB  Adam    – neutral American male
#   yoZ06aMxZJJ28mfd3POQ  Sam     – energetic male (good for coaching)
#   nPczCjzI2devNBz1zQrb  Brian   – deep male

VOICE_ID  = os.getenv("ELEVENLABS_VOICE_ID", "21m00Tcm4TlvDq8ikWAM")
MODEL_ID  = os.getenv("ELEVENLABS_MODEL_ID",  "eleven_turbo_v2_5")
BASE_URL  = "https://api.elevenlabs.io/v1"

# ── All static coaching phrases used by FeedbackScheduler ─────────────────────
# Must stay in sync with ios/FormCoach/Feedback/FeedbackScheduler.swift.
PHRASES: list[str] = [
    # startup cues
    "Feet shoulder width. Sink hips back, chest tall. Go.",
    "Stand strong, chest up. Three, two, one, squat.",
    "Eyes forward, weight in your heels. Begin.",
    "Body in a straight line from head to heels. Go.",
    "Tight core, hands under shoulders. Begin.",
    "Lock it in. Plank position, start when ready.",
    "Hands to sky, feet wide on the jump. Go.",
    "Big jumps, arms all the way up. Begin.",
    "Get into starting position. Begin when ready.",

    # squat faults
    "Sink deeper",
    "Go a little lower next rep",
    "Drop your hips further",
    "Chest up",
    "Keep your eyes forward",
    "Proud chest",
    "Sit your hips back",
    "Push your hips behind you",

    # pushup faults
    "Lower your chest",
    "Closer to the floor next rep",
    "Full range, go deeper",
    "Lock out at the top",
    "Full extension",
    "All the way up",
    "Brace your core",
    "Hips up, straight line",
    "Engage your abs",
    "Flat back",
    "Lengthen your spine",

    # jumping jacks faults
    "Arms higher",
    "Hands over your head",
    "Reach all the way up",
    "Feet wider",
    "Bigger jumps out",
    "Wider stance on the jump",

    # encouragement
    "Nice form",
    "Looking clean",
    "You're dialed in",
    "Strong rhythm",
    "Locked in",
    "That's the groove",

    # pause/resume
    "Paused",
    "Back at it",
    "Let's go",
]

# In-memory cache: phrase text → MP3 bytes
_cache: dict[str, bytes] = {}


async def _fetch_audio(text: str, api_key: str) -> bytes:
    url = f"{BASE_URL}/text-to-speech/{VOICE_ID}"
    headers = {
        "xi-api-key": api_key,
        "Content-Type": "application/json",
        "Accept": "audio/mpeg",
    }
    payload = {
        "text": text,
        "model_id": MODEL_ID,
        "voice_settings": {"stability": 0.4, "similarity_boost": 0.8},
    }
    async with httpx.AsyncClient(timeout=15.0) as client:
        r = await client.post(url, json=payload, headers=headers)
    r.raise_for_status()
    return r.content


async def warm_cache() -> None:
    """Pre-generate audio for all static phrases. Called at server startup."""
    api_key = os.getenv("ELEVENLABS_API_KEY")
    if not api_key:
        logger.warning("TTS cache warm skipped — no ELEVENLABS_API_KEY")
        return

    logger.info("Warming TTS cache for %d phrases…", len(PHRASES))
    for phrase in PHRASES:
        if phrase in _cache:
            continue
        try:
            _cache[phrase] = await _fetch_audio(phrase, api_key)
            logger.info("  cached: %r", phrase)
        except Exception as exc:
            logger.error("  failed to cache %r: %s", phrase, exc)
        await asyncio.sleep(0.1)  # be polite to the API

    logger.info("TTS cache warm complete (%d/%d phrases cached)", len(_cache), len(PHRASES))


# ── Endpoints ─────────────────────────────────────────────────────────────────

class TTSRequest(BaseModel):
    text: str


@router.post("/speak", response_class=Response)
async def speak(body: TTSRequest):
    """Return MP3 audio for a phrase. Serves from cache if available."""
    if body.text in _cache:
        return Response(content=_cache[body.text], media_type="audio/mpeg")

    api_key = os.getenv("ELEVENLABS_API_KEY")
    if not api_key:
        raise HTTPException(503, "ElevenLabs TTS unavailable — no ELEVENLABS_API_KEY configured")

    try:
        audio = await _fetch_audio(body.text, api_key)
    except httpx.TimeoutException:
        raise HTTPException(504, "ElevenLabs request timed out")
    except httpx.HTTPStatusError as e:
        raise HTTPException(e.response.status_code, f"ElevenLabs error: {e.response.text[:200]}")
    except httpx.RequestError as e:
        raise HTTPException(502, f"ElevenLabs request error: {e}")

    _cache[body.text] = audio  # cache for future calls
    return Response(content=audio, media_type="audio/mpeg")


@router.get("/bundle")
async def bundle():
    """
    Return all pre-cached phrase audio as a single JSON object.
    iOS downloads this once at session start and plays from local memory.
    Shape: { "phrases": { "<text>": "<base64 mp3>" } }
    """
    if not _cache:
        raise HTTPException(503, "TTS cache is not ready yet — try again in a moment")

    return {
        "phrases": {
            phrase: base64.b64encode(audio).decode()
            for phrase, audio in _cache.items()
        }
    }


@router.get("/status")
async def cache_status():
    return {
        "cached": len(_cache),
        "total": len(PHRASES),
        "ready": len(_cache) == len(PHRASES),
        "phrases": list(_cache.keys()),
    }
