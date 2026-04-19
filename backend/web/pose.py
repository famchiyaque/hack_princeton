"""MediaPipe Pose wrapper — returns joints using the iOS Vision naming scheme.

Uses the modern `mediapipe.tasks.vision.PoseLandmarker` API (required on
Python 3.13 / mediapipe >= 0.10.30, where the legacy `mp.solutions.pose`
module is no longer shipped).
"""
from __future__ import annotations

import time
import urllib.request
from pathlib import Path
from typing import Optional

import mediapipe as mp
import numpy as np
from mediapipe.tasks import python as mp_python
from mediapipe.tasks.python import vision

from .geometry import Point

__all__ = ["PoseDetector", "Point"]

_MODEL_URL = (
    "https://storage.googleapis.com/mediapipe-models/pose_landmarker/"
    "pose_landmarker_lite/float16/latest/pose_landmarker_lite.task"
)
_MODEL_PATH = Path(__file__).resolve().parent / "pose_landmarker_lite.task"


def _ensure_model() -> Path:
    if not _MODEL_PATH.exists():
        print(f"[pose] downloading model → {_MODEL_PATH.name} …", flush=True)
        urllib.request.urlretrieve(_MODEL_URL, _MODEL_PATH)
        print(f"[pose] model ready ({_MODEL_PATH.stat().st_size // 1024} KB)", flush=True)
    return _MODEL_PATH


# BlazePose 33-keypoint indices → iOS Vision naming.
_MP_TO_IOS = {
    "nose": 0,
    "leftEye": 2,
    "rightEye": 5,
    "leftEar": 7,
    "rightEar": 8,
    "leftShoulder": 11,
    "rightShoulder": 12,
    "leftElbow": 13,
    "rightElbow": 14,
    "leftWrist": 15,
    "rightWrist": 16,
    "leftHip": 23,
    "rightHip": 24,
    "leftKnee": 25,
    "rightKnee": 26,
    "leftAnkle": 27,
    "rightAnkle": 28,
}


class PoseDetector:
    """One instance per WS session. Thread-bound (mediapipe Tasks are not re-entrant)."""

    def __init__(self, min_confidence: float = 0.3):
        self.min_confidence = min_confidence
        model_path = _ensure_model()
        options = vision.PoseLandmarkerOptions(
            base_options=mp_python.BaseOptions(model_asset_path=str(model_path)),
            running_mode=vision.RunningMode.VIDEO,
            num_poses=1,
            min_pose_detection_confidence=0.5,
            min_tracking_confidence=0.5,
        )
        self._landmarker = vision.PoseLandmarker.create_from_options(options)
        self._t0 = time.time()

    def close(self):
        self._landmarker.close()

    def _now_ms(self) -> int:
        return int((time.time() - self._t0) * 1000)

    def detect(self, rgb_frame: np.ndarray) -> dict[str, Point]:
        """rgb_frame: HxWx3 uint8 RGB. Returns joint-name → Point (normalized 0-1)."""
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_frame)
        result = self._landmarker.detect_for_video(mp_image, self._now_ms())
        if not result.pose_landmarks:
            return {}

        lms = result.pose_landmarks[0]  # first (and only) detected person
        joints: dict[str, Point] = {}

        for name, idx in _MP_TO_IOS.items():
            lm = lms[idx]
            vis = getattr(lm, "visibility", 1.0)
            if vis < self.min_confidence:
                continue
            joints[name] = Point(x=lm.x, y=lm.y, confidence=vis)

        # Synthetic joints: neck (shoulder midpoint), root (hip midpoint).
        if "leftShoulder" in joints and "rightShoulder" in joints:
            ls, rs = joints["leftShoulder"], joints["rightShoulder"]
            joints["neck"] = Point(
                x=(ls.x + rs.x) / 2,
                y=(ls.y + rs.y) / 2,
                confidence=min(ls.confidence, rs.confidence),
            )
        if "leftHip" in joints and "rightHip" in joints:
            lh, rh = joints["leftHip"], joints["rightHip"]
            joints["root"] = Point(
                x=(lh.x + rh.x) / 2,
                y=(lh.y + rh.y) / 2,
                confidence=min(lh.confidence, rh.confidence),
            )

        return joints
