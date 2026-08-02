"""Create a neutral modular CTF base shell for the asset-pipeline runway.

The model is presentation only. Godot retains the existing authoritative 14 m
box collision and places this shell at the same origin.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_asset_utils import (
    box,
    cylinder,
    material,
    parent_keep_transform,
    reset_scene,
    save_and_export,
)

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/environment/runway_base_kit.blend"
EXPORT = ROOT / "assets/models/environment/runway_base_kit.glb"


def build() -> None:
    graphite = material("Runway graphite", (0.035, 0.055, 0.065, 1.0), 0.42, 0.68)
    deck = material("Runway deck", (0.24, 0.28, 0.27, 1.0), 0.18, 0.82)
    ceramic = material("Runway ceramic", (0.58, 0.62, 0.57, 1.0), 0.12, 0.48)
    signal = material(
        "Neutral signal",
        (0.03, 0.55, 0.52, 1.0),
        0.1,
        0.34,
        emission=(0.02, 0.72, 0.65, 1.0),
        emission_strength=3.0,
    )

    root = bpy.data.objects.new("RunwayBaseKit", None)
    bpy.context.collection.objects.link(root)
    parts: list[bpy.types.Object] = []

    # Gameplay collision remains a simple 14 x 2 x 14 box. The layered render
    # shell gives it readable construction without changing traversal.
    parts.extend(
        [
            box("Structural deck", (0, 0, 0), (14, 14, 2), graphite, 0.22),
            box("Inset playing surface", (0, 0, 1.05), (12.8, 12.8, 0.18), deck, 0.12),
            cylinder("Load bearing pier", (0, 0, -7.0), 2.4, 12.0, graphite, 16, 0.12),
            cylinder("Pier collar", (0, 0, -1.5), 3.3, 0.65, ceramic, 20, 0.1),
            cylinder("Objective plinth", (0, 0, 1.08), 2.2, 0.16, ceramic, 24, 0.05),
            cylinder("Objective signal", (0, 0, 1.18), 1.55, 0.05, signal, 32, 0.018),
        ]
    )

    # Open x-facing approaches preserve the existing fast CTF route. Repeated
    # end modules establish a tiny reusable architecture vocabulary.
    for y_side in (-1.0, 1.0):
        y = y_side * 6.75
        parts.append(box(f"End beam {y_side:+.0f}", (0, y, 0.8), (10.4, 0.55, 0.7), ceramic, 0.12))
        parts.append(box(f"Signal rail {y_side:+.0f}", (0, y_side * 6.44, 1.18), (8.4, 0.08, 0.12), signal, 0.025))
        for x_side in (-1.0, 1.0):
            x = x_side * 5.7
            parts.append(box(f"Pylon {x_side:+.0f} {y_side:+.0f}", (x, y, 2.15), (0.72, 0.72, 3.2), graphite, 0.12))
            parts.append(box(
                f"Pylon face {x_side:+.0f} {y_side:+.0f}",
                (x, y - y_side * 0.39, 2.15),
                (0.42, 0.08, 2.15),
                signal,
                0.025,
            ))
            parts.append(box(
                f"Underside brace {x_side:+.0f} {y_side:+.0f}",
                (x_side * 3.5, y_side * 3.5, -2.1),
                (0.65, 6.6, 0.65),
                ceramic,
                0.08,
                rotation=(math.radians(y_side * 27.0), 0.0, math.radians(-x_side * 8.0)),
            ))

    # Edge notches make direction readable while remaining below the collision top.
    for x_side in (-1.0, 1.0):
        parts.append(box(f"Approach cheek {x_side:+.0f}", (x_side * 6.75, 0, 0.5), (0.5, 7.8, 1.1), ceramic, 0.12))
        parts.append(box(f"Approach signal {x_side:+.0f}", (x_side * 6.48, 0, 1.12), (0.08, 5.2, 0.11), signal, 0.02))

    for part in parts:
        parent_keep_transform(part, root)


reset_scene()
build()
save_and_export(SOURCE, EXPORT, consolidate_static=True)
print(f"Saved {SOURCE}")
print(f"Exported {EXPORT}")
