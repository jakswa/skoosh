"""Build the Kestrel Basin launcher, projectile, and relay-station shell.

Run from the repository root:
    blender --background --python tools/asset_pipeline/create_alpine_expedition_assets.py

All geometry and materials are authored here. No external assets are used.
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
WEAPON_SOURCE = ROOT / "assets/source/weapons/kestrel_induction_launcher.blend"
WEAPON_EXPORT = ROOT / "assets/models/weapons/kestrel_induction_launcher.glb"
DISC_EXPORT = ROOT / "assets/models/weapons/kestrel_relay_disc.glb"
BASE_SOURCE = ROOT / "assets/source/environment/kestrel_relay_station.blend"
BASE_EXPORT = ROOT / "assets/models/environment/kestrel_relay_station.glb"


def torus(
    name: str,
    location: tuple[float, float, float],
    major_radius: float,
    minor_radius: float,
    mat: bpy.types.Material,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(
        major_segments=32,
        minor_segments=8,
        location=location,
        rotation=rotation,
        major_radius=major_radius,
        minor_radius=minor_radius,
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def loft(
    name: str,
    sections: list[tuple[float, float, float, float]],
    mat: bpy.types.Material,
) -> bpy.types.Object:
    """Create an angular body from y, half-width, z-center, half-height sections."""
    vertices: list[tuple[float, float, float]] = []
    for y, width, z, height in sections:
        vertices.extend(
            [
                (-width, y, z - height),
                (width, y, z - height),
                (width, y, z + height),
                (-width, y, z + height),
            ]
        )
    faces: list[tuple[int, ...]] = [(0, 3, 2, 1)]
    for index in range(len(sections) - 1):
        current = index * 4
        following = current + 4
        faces.extend(
            [
                (current, following, following + 3, current + 3),
                (current + 1, current + 2, following + 2, following + 1),
                (current + 3, following + 3, following + 2, current + 2),
                (current, current + 1, following + 1, following),
            ]
        )
    end = (len(sections) - 1) * 4
    faces.append((end, end + 1, end + 2, end + 3))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new("Field-worn edges", "BEVEL")
    bevel.width = 0.016
    bevel.segments = 2
    bevel.limit_method = "ANGLE"
    return obj


def weapon_materials() -> dict[str, bpy.types.Material]:
    return {
        "graphite": material("Graphite mechanism", (0.026, 0.033, 0.035, 1.0), 0.68, 0.58),
        "ceramic": material("Worn glacier ceramic", (0.31, 0.34, 0.34, 1.0), 0.08, 0.88),
        "steel": material("Dark brushed steel", (0.09, 0.105, 0.105, 1.0), 0.82, 0.42),
        "hazard": material("Expedition orange", (0.53, 0.16, 0.055, 1.0), 0.24, 0.67),
        "mint": material(
            "Relay mint",
            (0.06, 0.58, 0.48, 1.0),
            0.12,
            0.28,
            emission=(0.08, 0.95, 0.72, 1.0),
            emission_strength=4.5,
        ),
    }


def build_launcher() -> None:
    mats = weapon_materials()
    root = bpy.data.objects.new("KestrelInductionLauncher", None)
    bpy.context.collection.objects.link(root)

    parts: list[bpy.types.Object] = []
    parts.append(
        loft(
            "Load frame",
            [
                (-0.58, 0.24, -0.02, 0.17),
                (-0.22, 0.28, 0.0, 0.2),
                (0.34, 0.22, 0.015, 0.16),
                (0.82, 0.12, 0.02, 0.1),
                (1.08, 0.075, 0.015, 0.065),
            ],
            mats["graphite"],
        )
    )
    for side in (-1.0, 1.0):
        shell = loft(
            f"Ceramic weather shroud {side:+.0f}",
            [
                (-0.46, 0.08, 0.12, 0.07),
                (-0.05, 0.095, 0.15, 0.08),
                (0.42, 0.065, 0.13, 0.055),
            ],
            mats["ceramic"],
        )
        shell.location.x = side * 0.19
        parts.append(shell)
        parts.append(
            box(
                f"Induction spar {side:+.0f}",
                (side * 0.205, 0.55, 0.01),
                (0.075, 0.92, 0.09),
                mats["steel"],
                0.014,
                rotation=(0.0, side * math.radians(2.5), 0.0),
            )
        )
        parts.append(
            box(
                f"Ceramic spar guard {side:+.0f}",
                (side * 0.265, 0.5, 0.08),
                (0.07, 0.72, 0.11),
                mats["ceramic"],
                0.014,
            )
        )
        parts.append(
            box(
                f"Hazard witness {side:+.0f}",
                (side * 0.304, 0.38, 0.11),
                (0.015, 0.26, 0.035),
                mats["hazard"],
                0.003,
            )
        )

    parts.extend(
        [
            box(
                "Reinforced field grip",
                (0.08, -0.28, -0.28),
                (0.17, 0.22, 0.46),
                mats["graphite"],
                0.025,
                rotation=(math.radians(-14.0), 0.0, math.radians(-3.0)),
            ),
            box(
                "Grip ceramic slab",
                (0.08, -0.29, -0.29),
                (0.115, 0.18, 0.30),
                mats["ceramic"],
                0.018,
                rotation=(math.radians(-14.0), 0.0, math.radians(-3.0)),
            ),
            box("Rear balance pack", (0.0, -0.56, 0.0), (0.38, 0.2, 0.22), mats["steel"], 0.035),
            box("Pack hazard latch", (0.0, -0.67, 0.02), (0.24, 0.035, 0.09), mats["hazard"], 0.006),
            cylinder(
                "Muzzle induction lens",
                (0.0, 1.13, 0.015),
                0.082,
                0.025,
                mats["mint"],
                28,
                0.003,
                rotation=(math.radians(90.0), 0.0, 0.0),
            ),
            torus(
                "Muzzle clamp",
                (0.0, 1.11, 0.015),
                0.105,
                0.022,
                mats["steel"],
                rotation=(math.radians(90.0), 0.0, 0.0),
            ),
        ]
    )

    rotor = bpy.data.objects.new("DiscRotor", None)
    rotor.location = (-0.13, -0.08, 0.26)
    rotor.parent = root
    bpy.context.collection.objects.link(rotor)
    charge = bpy.data.objects.new("ChargeCore", None)
    charge.location = (-0.13, -0.08, 0.27)
    charge.parent = rotor
    bpy.context.collection.objects.link(charge)
    disc_parts = [
        torus("Seated steel disc", (-0.13, -0.08, 0.29), 0.13, 0.026, mats["steel"]),
        cylinder("Seated relay core", (-0.13, -0.08, 0.29), 0.098, 0.025, mats["mint"], 32, 0.003),
        cylinder("Disc axle", (-0.13, -0.08, 0.305), 0.028, 0.05, mats["hazard"], 16, 0.003),
    ]
    for part in disc_parts:
        parent_keep_transform(part, charge)
    for index, angle_degrees in enumerate((30.0, 150.0, 270.0)):
        angle = math.radians(angle_degrees)
        clamp = box(
            f"Rotor clamp {index + 1}",
            (-0.13 + math.cos(angle) * 0.17, -0.08 + math.sin(angle) * 0.17, 0.25),
            (0.07, 0.035, 0.055),
            mats["hazard"],
            0.007,
            rotation=(0.0, 0.0, angle),
        )
        parent_keep_transform(clamp, rotor)

    muzzle_socket = bpy.data.objects.new("MuzzleSocket", None)
    muzzle_socket.location = (0.0, 1.17, 0.015)
    muzzle_socket.parent = root
    bpy.context.collection.objects.link(muzzle_socket)
    for part in parts:
        parent_keep_transform(part, root)


def build_disc() -> None:
    mats = weapon_materials()
    root = bpy.data.objects.new("KestrelRelayDisc", None)
    bpy.context.collection.objects.link(root)
    parts = [
        torus("Disc armature", (0, 0, 0), 0.13, 0.028, mats["steel"]),
        cylinder("Relay charge", (0, 0, 0), 0.098, 0.024, mats["mint"], 32, 0.003),
        cylinder("Hazard axle", (0, 0, 0.015), 0.027, 0.052, mats["hazard"], 16, 0.003),
    ]
    for part in parts:
        parent_keep_transform(part, root)


def build_station() -> None:
    graphite = material("Graphite frame", (0.035, 0.042, 0.043, 1.0), 0.7, 0.7)
    deck = material("Split slate deck", (0.12, 0.135, 0.13, 1.0), 0.16, 0.92)
    ceramic = material("Worn station ceramic", (0.43, 0.45, 0.42, 1.0), 0.08, 0.82)
    team = material("Team markings", (0.45, 0.05, 0.035, 1.0), 0.08, 0.72)
    mint = material(
        "Neutral relay mint",
        (0.025, 0.5, 0.42, 1.0),
        0.08,
        0.34,
        emission=(0.045, 0.9, 0.68, 1.0),
        emission_strength=2.8,
    )
    root = bpy.data.objects.new("KestrelRelayStation", None)
    bpy.context.collection.objects.link(root)
    parts: list[bpy.types.Object] = [
        box("Armored foundation", (0, 0, 0), (14, 14, 2), graphite, 0.18),
        box("Slate operations deck", (0, 0, 1.04), (12.9, 12.9, 0.16), deck, 0.08),
        cylinder("Relay bearing", (0, 0, -3.7), 2.2, 7.4, graphite, 16, 0.12),
        cylinder("Bearing collar", (0, 0, -0.9), 3.1, 0.45, ceramic, 20, 0.08),
        cylinder("Objective socket", (0, 0, 1.11), 2.1, 0.18, graphite, 24, 0.04),
        torus("Objective mint trace", (0, 0, 1.23), 1.55, 0.045, mint),
    ]
    # Two high signal gantries outside the authoritative deck box frame the base
    # without implying cover on the playable surface.
    for y_side in (-1.0, 1.0):
        y = y_side * 7.35
        parts.extend(
            [
                box(f"Gantry foot left {y_side:+.0f}", (-5.25, y, 2.25), (0.65, 0.65, 4.5), graphite, 0.08),
                box(f"Gantry foot right {y_side:+.0f}", (5.25, y, 2.25), (0.65, 0.65, 4.5), graphite, 0.08),
                box(f"Gantry header {y_side:+.0f}", (0, y, 4.35), (11.0, 0.55, 0.55), ceramic, 0.09),
                box(f"Team signal bar {y_side:+.0f}", (0, y - y_side * 0.3, 4.38), (7.0, 0.07, 0.18), team, 0.015),
                box(f"Floodlight rail {y_side:+.0f}", (0, y - y_side * 0.34, 3.86), (3.2, 0.09, 0.11), mint, 0.012),
            ]
        )
        for x_side in (-1.0, 1.0):
            parts.append(
                box(
                    f"Wind brace {x_side:+.0f} {y_side:+.0f}",
                    (x_side * 3.4, y_side * 3.55, -1.65),
                    (0.48, 7.2, 0.48),
                    ceramic,
                    0.07,
                    rotation=(math.radians(y_side * 28.0), 0.0, math.radians(-x_side * 8.0)),
                )
            )
    for x_side in (-1.0, 1.0):
        parts.extend(
            [
                box(f"Approach armor {x_side:+.0f}", (x_side * 6.78, 0, 0.45), (0.42, 8.8, 1.1), ceramic, 0.09),
                box(f"Approach team cable {x_side:+.0f}", (x_side * 6.53, 0, 1.13), (0.05, 6.4, 0.1), team, 0.012),
            ]
        )
        for panel_index, y in enumerate((-4.5, 0.0, 4.5)):
            parts.extend(
                [
                    box(
                        f"Foundation service panel {x_side:+.0f} {panel_index}",
                        (x_side * 7.015, y, 0.0),
                        (0.035, 3.45, 0.72),
                        ceramic,
                        0.015,
                    ),
                    box(
                        f"Foundation team mark {x_side:+.0f} {panel_index}",
                        (x_side * 7.04, y, 0.0),
                        (0.018, 1.35, 0.12),
                        team,
                        0.005,
                    ),
                ]
            )
    # A narrow neutral mast provides the expedition silhouette and objective bearing.
    parts.extend(
        [
            cylinder("Survey mast", (0, 5.9, 4.2), 0.09, 6.3, graphite, 12, 0.02),
            cylinder(
                "Survey crossbar",
                (0, 5.9, 6.9),
                0.07,
                2.4,
                ceramic,
                12,
                0.015,
                rotation=(0.0, math.radians(90.0), 0.0),
            ),
            box("Mint range finder", (0, 5.86, 7.0), (0.65, 0.16, 0.24), mint, 0.025),
        ]
    )
    for part in parts:
        parent_keep_transform(part, root)


reset_scene()
build_launcher()
save_and_export(WEAPON_SOURCE, WEAPON_EXPORT)
print(f"Saved {WEAPON_SOURCE}")
print(f"Exported {WEAPON_EXPORT}")

reset_scene()
build_disc()
save_and_export(ROOT / ".tmp/kestrel_relay_disc.blend", DISC_EXPORT)
print(f"Exported {DISC_EXPORT}")

reset_scene()
build_station()
save_and_export(BASE_SOURCE, BASE_EXPORT, consolidate_static=True)
print(f"Saved {BASE_SOURCE}")
print(f"Exported {BASE_EXPORT}")
