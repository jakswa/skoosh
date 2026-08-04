"""Build the selected Kestrel/Stratos/Khepri hybrid visual assets.

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
    root = bpy.data.objects.new("KestrelAerofoilDiscLauncher", None)
    bpy.context.collection.objects.link(root)

    parts: list[bpy.types.Object] = [
        loft(
            "Aerodynamic load frame",
            [
                (-0.50, 0.13, -0.01, 0.11),
                (-0.18, 0.19, 0.02, 0.14),
                (0.28, 0.14, 0.025, 0.10),
                (0.84, 0.055, 0.08, 0.05),
                (1.02, 0.035, 0.11, 0.03),
            ],
            mats["graphite"],
        ),
        box("Lower receiver bridge", (0.0, -0.20, 0.01), (0.34, 0.18, 0.09), mats["steel"], 0.018),
        box(
            "Reinforced field grip",
            (0.05, -0.34, -0.24),
            (0.14, 0.20, 0.40),
            mats["graphite"],
            0.026,
            rotation=(math.radians(-16.0), 0.0, math.radians(-3.0)),
        ),
        box("Grip ceramic slab", (0.057, -0.365, -0.235), (0.09, 0.21, 0.20), mats["ceramic"], 0.015),
        box("Rear balance foil", (0.0, -0.53, 0.03), (0.42, 0.13, 0.10), mats["ceramic"], 0.026),
        box("Rear expedition latch", (0.0, -0.61, 0.04), (0.18, 0.04, 0.07), mats["hazard"], 0.01),
        # A rectangular launch gate replaces every barrel, lens, iris, and nozzle cue.
        box("Upper launch gate", (0.0, 1.03, 0.18), (0.30, 0.055, 0.025), mats["mint"], 0.004),
        box("Lower launch gate", (0.0, 1.03, 0.06), (0.30, 0.055, 0.025), mats["steel"], 0.004),
    ]
    for side in (-1.0, 1.0):
        foil = loft(
            f"Glacier aerofoil {side:+.0f}",
            [
                (-0.43, 0.055, 0.14, 0.045),
                (-0.03, 0.075, 0.16, 0.055),
                (0.46, 0.05, 0.14, 0.04),
                (0.97, 0.025, 0.12, 0.025),
            ],
            mats["ceramic"],
        )
        foil.location.x = side * 0.16
        parts.append(foil)
        parts.extend(
            [
                box(
                    f"Disc carrier rail {side:+.0f}",
                    (side * 0.16, 0.31, 0.12),
                    (0.035, 1.02, 0.045),
                    mats["steel"],
                    0.006,
                ),
                box(
                    f"Expedition index {side:+.0f}",
                    (side * 0.22, 0.10, 0.215),
                    (0.025, 0.67, 0.018),
                    mats["hazard"],
                    0.004,
                    rotation=(0.0, 0.0, math.radians(side * 3.0)),
                ),
                box(
                    f"Rectangular accelerator {side:+.0f}",
                    (side * 0.16, 0.96, 0.12),
                    (0.055, 0.18, 0.055),
                    mats["steel"],
                    0.006,
                ),
            ]
        )

    seat = (0.0, -0.18, 0.20)
    rotor = bpy.data.objects.new("DiscRotor", None)
    rotor.location = seat
    rotor.parent = root
    bpy.context.collection.objects.link(rotor)
    charge = bpy.data.objects.new("ChargeCore", None)
    charge.location = seat
    charge.parent = root
    bpy.context.collection.objects.link(charge)
    disc_parts = [
        torus("Seated steel disc", seat, 0.13, 0.026, mats["steel"]),
        cylinder("Seated relay core", seat, 0.098, 0.025, mats["mint"], 32, 0.003),
        cylinder("Disc axle", (seat[0], seat[1], seat[2] + 0.015), 0.028, 0.05, mats["hazard"], 16, 0.003),
        box("Disc rotation index", (0.105, -0.18, 0.228), (0.045, 0.025, 0.018), mats["hazard"], 0.004),
    ]
    for part in disc_parts:
        parent_keep_transform(part, charge)
    for index, angle_degrees in enumerate((30.0, 150.0, 270.0)):
        angle = math.radians(angle_degrees)
        clamp = box(
            f"Rotor clamp {index + 1}",
            (math.cos(angle) * 0.17, -0.18 + math.sin(angle) * 0.17, 0.18),
            (0.07, 0.035, 0.055),
            mats["hazard"],
            0.007,
            rotation=(0.0, 0.0, angle),
        )
        parent_keep_transform(clamp, rotor)

    for name, location in (
        ("DiscSeatSocket", seat),
        ("FeedMidSocket", (0.0, 0.34, 0.12)),
        ("MuzzleSocket", (0.0, 1.06, 0.12)),
    ):
        socket = bpy.data.objects.new(name, None)
        socket.location = location
        socket.parent = root
        bpy.context.collection.objects.link(socket)
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
        box("Rotation index", (0.105, 0.0, 0.027), (0.045, 0.025, 0.018), mats["hazard"], 0.004),
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
    ]
    # Three paired phase vanes carry Khepri's monumental triune silhouette into
    # the practical daytime relay. Roots remain beyond the authoritative box.
    for anchor_index, angle_degrees in enumerate((30.0, 150.0, 270.0)):
        angle = math.radians(angle_degrees)
        radial = (math.cos(angle), math.sin(angle))
        tangent = (-radial[1], radial[0])
        parts.append(
            box(
                f"Objective triune trace {anchor_index + 1}",
                (radial[0] * 1.35, radial[1] * 1.35, 1.26),
                (0.11, 2.5, 0.035),
                mint,
                0.008,
                rotation=(0.0, 0.0, angle + math.radians(90.0)),
            )
        )
        for side in (-1.0, 1.0):
            x = radial[0] * 8.15 + tangent[0] * side * 1.05
            y = radial[1] * 8.15 + tangent[1] * side * 1.05
            rotation = (math.radians(side * 11.0), math.radians(-10.0), angle)
            parts.extend(
                [
                    box(
                        f"Phase vane {anchor_index + 1} {side:+.0f}",
                        (x, y, 3.25),
                        (0.62, 1.05, 5.3),
                        ceramic,
                        0.09,
                        rotation=rotation,
                    ),
                    box(
                        f"Team signal {anchor_index + 1} {side:+.0f}",
                        (x - radial[0] * 0.32, y - radial[1] * 0.32, 3.35),
                        (0.09, 0.62, 2.6),
                        team,
                        0.015,
                        rotation=rotation,
                    ),
                ]
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
    parts.append(box("Mint range finder", (0, 5.86, 2.7), (0.65, 0.16, 0.24), mint, 0.025))
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
