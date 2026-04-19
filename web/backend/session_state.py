"""Per-connection session state + frame processing."""
from __future__ import annotations

import time
from collections import Counter
from typing import Optional

import cv2
import numpy as np

from angles import BodyAngles, body_angles_from_joints
from classifier import ExerciseClassifier
from exercise import ExerciseType
from form_comparator import evaluate as evaluate_form
from pose import PoseDetector, Point
from rep_counter import RepCounter
from session_analyzer import RepRecord, SessionReport, analyze


class SessionState:
    def __init__(self):
        self.pose = PoseDetector()
        self.classifier = ExerciseClassifier()
        self.rep_counters: dict[ExerciseType, RepCounter] = {}
        self.rep_records: list[RepRecord] = []
        self.corrections_counter: Counter[str] = Counter()
        self.started_at = time.time()
        self.last_rep_time = self.started_at
        self.current_exercise = ExerciseType.UNKNOWN

    def close(self):
        self.pose.close()

    def _counter_for(self, exercise: ExerciseType) -> RepCounter:
        if exercise not in self.rep_counters:
            self.rep_counters[exercise] = RepCounter(exercise)
        return self.rep_counters[exercise]

    def process_frame(self, jpeg_bytes: bytes) -> dict:
        """Decode one JPEG frame, run the pipeline, return a JSON-ready dict."""
        arr = np.frombuffer(jpeg_bytes, dtype=np.uint8)
        bgr = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if bgr is None:
            return {"type": "frame", "error": "decode_failed"}
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)

        joints = self.pose.detect(rgb)
        if not joints:
            return {"type": "frame", "landmarks": {}, "exercise": "unknown"}

        angles = body_angles_from_joints(joints)
        exercise = self.classifier.update(angles, joints)
        self.current_exercise = exercise

        rep_count = 0
        score = 0.0
        corrections: list[dict] = []
        phase = ""

        if exercise != ExerciseType.UNKNOWN:
            counter = self._counter_for(exercise)
            primary = counter.primary_angle(angles)
            rep_completed = False
            if primary is not None:
                rep_completed = counter.update(primary)
            rep_count = counter.rep_count
            phase = counter.scoring_phase()
            form = evaluate_form(angles, exercise, phase)
            score = form.score
            corrections = [
                {"joint": c.joint, "message": c.message, "severity": c.severity}
                for c in form.corrections
            ]

            if rep_completed:
                now = time.time()
                duration_ms = int((now - self.last_rep_time) * 1000)
                self.last_rep_time = now
                top_corr = form.corrections[0].joint if form.corrections else None
                self.rep_records.append(RepRecord(
                    index=len(self.rep_records) + 1,
                    exercise=exercise.value,
                    score=form.score,
                    peak_primary_angle=primary if primary is not None else 0.0,
                    duration_ms=duration_ms,
                    top_correction=top_corr,
                ))
                for c in form.corrections:
                    self.corrections_counter[c.joint] += 1

        # Serialize landmarks for the client's overlay renderer.
        lm_out = {
            name: {"x": p.x, "y": p.y, "c": round(p.confidence, 2)}
            for name, p in joints.items()
        }

        return {
            "type": "frame",
            "landmarks": lm_out,
            "angles": angles.to_dict(),
            "exercise": exercise.value,
            "exerciseDisplay": exercise.display_name,
            "phase": phase,
            "repCount": rep_count,
            "score": round(score, 1),
            "corrections": corrections,
        }

    def build_report(self) -> SessionReport:
        duration_s = int(time.time() - self.started_at)
        # Report uses the exercise most reps were performed for (fallback: current).
        if self.rep_records:
            per_ex = Counter(r.exercise for r in self.rep_records)
            top = per_ex.most_common(1)[0][0]
            exercise = ExerciseType(top)
            reps = [r for r in self.rep_records if r.exercise == top]
        else:
            exercise = self.current_exercise
            reps = []
        return analyze(exercise, duration_s, reps, dict(self.corrections_counter))
