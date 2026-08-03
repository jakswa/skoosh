"""Create the selected low-poly expedition athlete and MomentumLean rig.

The skeleton names and animation clip preserve the proven multiplayer import
contract. Geometry, posture, equipment silhouette, and animation are new.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_asset_utils import box, material, reset_scene, smart_uv_all


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/characters/vector_expedition_runner.blend"
EXPORT = ROOT / "assets/models/characters/vector_expedition_runner.glb"


def add_bone(armature, name, head, tail, parent=None):
    bone = armature.edit_bones.new(name)
    bone.head = head
    bone.tail = tail
    bone.parent = parent
    return bone


def build() -> None:
    undersuit = material("Graphite pressure weave", (0.025, 0.035, 0.04, 1.0), 0.22, 0.88)
    ceramic = material("Weathered glacier shell", (0.32, 0.35, 0.35, 1.0), 0.08, 0.84)
    hardware = material("Dark expedition hardware", (0.07, 0.085, 0.09, 1.0), 0.72, 0.48)
    team_seed = material("Team role seed", (0.40, 0.08, 0.055, 1.0), 0.10, 0.78)
    signal = material(
        "Relay mint signal",
        (0.035, 0.52, 0.43, 1.0),
        0.10,
        0.28,
        emission=(0.05, 0.88, 0.66, 1.0),
        emission_strength=2.6,
    )

    armature_data = bpy.data.armatures.new("VectorRunnerSkeleton")
    rig = bpy.data.objects.new("VectorRunnerRig", armature_data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    root = add_bone(armature_data, "Root", (0, 0, 0), (0, 0, 0.3))
    pelvis = add_bone(armature_data, "Pelvis", (0, 0, 0.75), (0, 0, 1.05), root)
    spine = add_bone(armature_data, "Spine", (0, 0, 1.05), (0, -0.03, 1.52), pelvis)
    head = add_bone(armature_data, "Head", (0, -0.03, 1.52), (0, -0.08, 1.9), spine)
    for side, x in (("L", 1.0), ("R", -1.0)):
        upper_arm = add_bone(
            armature_data,
            f"UpperArm.{side}",
            (x * 0.25, -0.03, 1.42),
            (x * 0.58, -0.09, 1.23),
            spine,
        )
        add_bone(
            armature_data,
            f"Forearm.{side}",
            (x * 0.58, -0.09, 1.23),
            (x * 0.70, -0.20, 0.94),
            upper_arm,
        )
        thigh = add_bone(
            armature_data,
            f"Thigh.{side}",
            (x * 0.14, 0, 0.82),
            (x * 0.18, -0.08, 0.43),
            pelvis,
        )
        add_bone(
            armature_data,
            f"Shin.{side}",
            (x * 0.18, -0.08, 0.43),
            (x * 0.19, -0.18, 0.04),
            thigh,
        )
    bpy.ops.object.mode_set(mode="OBJECT")

    # Named roles are intentionally stable: runtime team materials use them.
    parts = [
        ("Pelvis shell", (0, 0.015, 0.88), (0.38, 0.25, 0.25), team_seed, "Pelvis", (0, 0, 0)),
        ("Torso", (0, 0.0, 1.27), (0.43, 0.28, 0.49), undersuit, "Spine", (math.radians(-5), 0, 0)),
        ("Chest plate", (0, -0.17, 1.31), (0.39, 0.07, 0.29), team_seed, "Spine", (math.radians(-7), 0, 0)),
        ("Backpack", (0, 0.18, 1.28), (0.24, 0.14, 0.45), hardware, "Spine", (math.radians(-8), 0, 0)),
        ("Signal spine", (0.07, 0.27, 1.43), (0.055, 0.08, 0.34), signal, "Spine", (math.radians(-12), 0, 0)),
        ("Jet pod L", (0.20, 0.25, 1.16), (0.12, 0.18, 0.46), team_seed, "Spine", (math.radians(-18), 0, math.radians(-6))),
        ("Jet pod R", (-0.20, 0.25, 1.16), (0.12, 0.18, 0.46), team_seed, "Spine", (math.radians(-18), 0, math.radians(6))),
        ("Helmet", (0, -0.055, 1.72), (0.34, 0.39, 0.31), team_seed, "Head", (math.radians(-6), 0, 0)),
        ("Visor", (0.035, -0.265, 1.74), (0.25, 0.045, 0.085), signal, "Head", (0, 0, math.radians(-4))),
        ("Helmet notch", (-0.12, -0.255, 1.83), (0.045, 0.035, 0.065), hardware, "Head", (0, 0, math.radians(18))),
    ]
    for side, x in (("L", 1.0), ("R", -1.0)):
        parts.extend(
            [
                (f"Shoulder fin {side}", (x * 0.32, 0.035, 1.43), (0.25, 0.30, 0.09), team_seed, "Spine", (math.radians(-12), 0, math.radians(x * -11))),
                (f"Upper arm {side}", (x * 0.41, -0.055, 1.32), (0.15, 0.18, 0.37), ceramic, f"UpperArm.{side}", (math.radians(-8), 0, math.radians(x * -8))),
                (f"Forearm {side}", (x * 0.63, -0.14, 1.08), (0.14, 0.17, 0.34), undersuit, f"Forearm.{side}", (math.radians(-12), 0, math.radians(x * -5))),
                (f"Thigh {side}", (x * 0.15, -0.035, 0.62), (0.18, 0.22, 0.40), ceramic, f"Thigh.{side}", (math.radians(-8), 0, 0)),
                (f"Thigh signal {side}", (x * 0.24, -0.14, 0.66), (0.035, 0.04, 0.20), team_seed, f"Thigh.{side}", (math.radians(-8), 0, 0)),
                (f"Shin {side}", (x * 0.18, -0.11, 0.23), (0.15, 0.20, 0.35), undersuit, f"Shin.{side}", (math.radians(-10), 0, 0)),
                (f"Boot stabilizer {side}", (x * 0.18, -0.23, 0.055), (0.19, 0.36, 0.09), hardware, f"Shin.{side}", (0, 0, math.radians(x * -3))),
            ]
        )

    for name, location, dimensions, mat, bone_name, rotation in parts:
        obj = box(name, location, dimensions, mat, 0.035, rotation=rotation)
        bpy.context.view_layer.objects.active = obj
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        group = obj.vertex_groups.new(name=bone_name)
        group.add(range(len(obj.data.vertices)), 1.0, "REPLACE")
        modifier = obj.modifiers.new("Vector runner skin", "ARMATURE")
        modifier.object = rig
        obj.parent = rig

    # A root-motion-free speed-scaled crouch cycle with visible counter-motion.
    bpy.context.view_layer.objects.active = rig
    rig.animation_data_create()
    action = bpy.data.actions.new("MomentumLean")
    rig.animation_data.action = action
    for frame, lean, sway in ((1, -11.0, -2.0), (15, -18.0, 2.5), (30, -11.0, -2.0)):
        keyed = {
            "Pelvis": (math.radians(-lean * 0.16), 0.0, math.radians(-sway * 0.35)),
            "Spine": (math.radians(lean), 0.0, math.radians(sway)),
            "UpperArm.L": (math.radians(-8.0), 0.0, math.radians(4.0 + sway)),
            "UpperArm.R": (math.radians(-8.0), 0.0, math.radians(-4.0 + sway)),
            "Thigh.L": (math.radians(5.0 if frame == 15 else -3.0), 0.0, math.radians(-1.5)),
            "Thigh.R": (math.radians(-5.0 if frame == 15 else 3.0), 0.0, math.radians(1.5)),
        }
        for bone_name, rotation in keyed.items():
            pose_bone = rig.pose.bones[bone_name]
            pose_bone.rotation_mode = "XYZ"
            pose_bone.rotation_euler = rotation
            pose_bone.keyframe_insert("rotation_euler", frame=frame)
    action.frame_start = 1
    action.frame_end = 30

    smart_uv_all()
    SOURCE.parent.mkdir(parents=True, exist_ok=True)
    EXPORT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(EXPORT),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_animations=True,
    )


reset_scene()
build()
print(f"Saved {SOURCE}")
print(f"Exported {EXPORT}")
