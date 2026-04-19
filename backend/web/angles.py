"""Port of ios/FormCoach/Analysis/AngleCalculator.swift."""
from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Optional

from .geometry import Point


def angle_at(a: Point, vertex: Point, c: Point) -> float:
    """Angle at `vertex` between points a and c, in degrees (0-180)."""
    bax, bay = a.x - vertex.x, a.y - vertex.y
    bcx, bcy = c.x - vertex.x, c.y - vertex.y
    dot = bax * bcx + bay * bcy
    mag_ba = math.sqrt(bax * bax + bay * bay)
    mag_bc = math.sqrt(bcx * bcx + bcy * bcy)
    if mag_ba == 0 or mag_bc == 0:
        return 0.0
    cos_v = max(-1.0, min(1.0, dot / (mag_ba * mag_bc)))
    return math.degrees(math.acos(cos_v))


def _mean(a: Optional[float], b: Optional[float]) -> Optional[float]:
    if a is not None and b is not None:
        return (a + b) / 2
    return a if a is not None else b


@dataclass
class BodyAngles:
    leftElbow: Optional[float] = None
    rightElbow: Optional[float] = None
    leftKnee: Optional[float] = None
    rightKnee: Optional[float] = None
    leftHip: Optional[float] = None
    rightHip: Optional[float] = None
    leftShoulder: Optional[float] = None
    rightShoulder: Optional[float] = None
    spine: Optional[float] = None

    @property
    def elbowAngle(self) -> Optional[float]:
        return _mean(self.leftElbow, self.rightElbow)

    @property
    def hipAngle(self) -> Optional[float]:
        return _mean(self.leftHip, self.rightHip)

    @property
    def shoulderAngle(self) -> Optional[float]:
        return _mean(self.leftShoulder, self.rightShoulder)

    @property
    def kneeAngle(self) -> Optional[float]:
        """For squats/lunges we care about the deepest knee bend → use min."""
        lk, rk = self.leftKnee, self.rightKnee
        if lk is not None and rk is not None:
            return min(lk, rk)
        return lk if lk is not None else rk

    def to_dict(self) -> dict:
        return {
            "elbow": self.elbowAngle,
            "knee": self.kneeAngle,
            "hip": self.hipAngle,
            "shoulder": self.shoulderAngle,
            "spine": self.spine,
        }


def _tri(joints: dict[str, Point], a: str, b: str, c: str) -> Optional[float]:
    pa, pb, pc = joints.get(a), joints.get(b), joints.get(c)
    if pa is None or pb is None or pc is None:
        return None
    return angle_at(pa, pb, pc)


def body_angles_from_joints(joints: dict[str, Point]) -> BodyAngles:
    # Spine: angle at a shoulder between neck and pelvis (root).
    spine = None
    shoulder = joints.get("leftShoulder") or joints.get("rightShoulder")
    neck = joints.get("neck")
    root = joints.get("root")
    if shoulder is not None and neck is not None and root is not None:
        spine = angle_at(neck, shoulder, root)

    return BodyAngles(
        leftElbow=_tri(joints, "leftShoulder", "leftElbow", "leftWrist"),
        rightElbow=_tri(joints, "rightShoulder", "rightElbow", "rightWrist"),
        leftKnee=_tri(joints, "leftHip", "leftKnee", "leftAnkle"),
        rightKnee=_tri(joints, "rightHip", "rightKnee", "rightAnkle"),
        leftHip=_tri(joints, "leftShoulder", "leftHip", "leftKnee"),
        rightHip=_tri(joints, "rightShoulder", "rightHip", "rightKnee"),
        leftShoulder=_tri(joints, "leftHip", "leftShoulder", "leftElbow"),
        rightShoulder=_tri(joints, "rightHip", "rightShoulder", "rightElbow"),
        spine=spine,
    )
