"""Lightweight shared types (no heavy deps)."""
from __future__ import annotations

from dataclasses import dataclass


@dataclass
class Point:
    x: float
    y: float
    confidence: float
