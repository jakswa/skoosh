"""Create a neutral skinned player mannequin and one locomotion-loop proof.

This is a rig/import experiment, not a proposed SKOOSH character design.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_asset_utils import box, material, reset_scene, smart_uv_all

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/characters/runway_suit_rig.blend"
EXPORT = ROOT / "assets/models/characters/runway_suit_rig.glb"


def add_bone(armature, name, head, tail, parent=None):
    bone = armature.edit_bones.new(name)
    bone.head = head
    bone.tail = tail
    bone.parent = parent
    return bone


def build() -> None:
    suit = material("Neutral suit", (0.16, 0.2, 0.21, 1.0), 0.28, 0.7)
    armor = material("Neutral armor", (0.52, 0.56, 0.53, 1.0), 0.16, 0.48)
    visor = material(
        "Visor signal", (0.02, 0.28, 0.32, 1.0), 0.55, 0.2,
        emission=(0.01, 0.5, 0.58, 1.0), emission_strength=2.2,
    )

    armature_data = bpy.data.armatures.new("RunwaySuitSkeleton")
    rig = bpy.data.objects.new("RunwaySuitRig", armature_data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    root = add_bone(armature_data, "Root", (0, 0, 0), (0, 0, 0.3))
    pelvis = add_bone(armature_data, "Pelvis", (0, 0, 0.75), (0, 0, 1.05), root)
    spine = add_bone(armature_data, "Spine", (0, 0, 1.05), (0, 0, 1.52), pelvis)
    head = add_bone(armature_data, "Head", (0, 0, 1.52), (0, 0, 1.9), spine)
    bones = {"Pelvis": pelvis, "Spine": spine, "Head": head}
    for side, x in (("L", 1.0), ("R", -1.0)):
        upper_arm = add_bone(armature_data, f"UpperArm.{side}", (x * 0.25, 0, 1.42), (x * 0.62, 0, 1.25), spine)
        forearm = add_bone(armature_data, f"Forearm.{side}", (x * 0.62, 0, 1.25), (x * 0.78, -0.04, 0.95), upper_arm)
        thigh = add_bone(armature_data, f"Thigh.{side}", (x * 0.15, 0, 0.82), (x * 0.18, 0, 0.42), pelvis)
        shin = add_bone(armature_data, f"Shin.{side}", (x * 0.18, 0, 0.42), (x * 0.18, -0.03, 0.04), thigh)
        bones[f"UpperArm.{side}"] = upper_arm
        bones[f"Forearm.{side}"] = forearm
        bones[f"Thigh.{side}"] = thigh
        bones[f"Shin.{side}"] = shin
    bpy.ops.object.mode_set(mode="OBJECT")

    parts = [
        ("Pelvis shell", (0, 0, 0.88), (0.42, 0.27, 0.28), armor, "Pelvis"),
        ("Torso", (0, 0, 1.27), (0.55, 0.3, 0.55), suit, "Spine"),
        ("Chest plate", (0, -0.17, 1.31), (0.43, 0.08, 0.34), armor, "Spine"),
        ("Backpack", (0, 0.22, 1.27), (0.44, 0.18, 0.48), suit, "Spine"),
        ("Jet pod L", (0.22, 0.33, 1.12), (0.13, 0.16, 0.52), armor, "Spine"),
        ("Jet pod R", (-0.22, 0.33, 1.12), (0.13, 0.16, 0.52), armor, "Spine"),
        ("Helmet", (0, 0, 1.7), (0.38, 0.36, 0.35), armor, "Head"),
        ("Visor", (0, -0.195, 1.72), (0.27, 0.05, 0.11), visor, "Head"),
    ]
    for side, x in (("L", 1.0), ("R", -1.0)):
        parts.extend([
            (f"Upper arm {side}", (x * 0.43, 0, 1.33), (0.18, 0.2, 0.43), armor, f"UpperArm.{side}"),
            (f"Forearm {side}", (x * 0.69, -0.02, 1.1), (0.16, 0.18, 0.37), suit, f"Forearm.{side}"),
            (f"Thigh {side}", (x * 0.16, 0, 0.61), (0.2, 0.24, 0.43), armor, f"Thigh.{side}"),
            (f"Shin {side}", (x * 0.18, -0.02, 0.22), (0.17, 0.22, 0.38), suit, f"Shin.{side}"),
        ])

    for name, location, dimensions, mat, bone_name in parts:
        obj = box(name, location, dimensions, mat, 0.045)
        bpy.context.view_layer.objects.active = obj
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        group = obj.vertex_groups.new(name=bone_name)
        group.add(range(len(obj.data.vertices)), 1.0, "REPLACE")
        modifier = obj.modifiers.new("Runway suit skin", "ARMATURE")
        modifier.object = rig
        obj.parent = rig

    # A tiny looping ski/airborne lean proves animation survives GLB import.
    bpy.context.view_layer.objects.active = rig
    rig.animation_data_create()
    action = bpy.data.actions.new("MomentumLean")
    rig.animation_data.action = action
    for frame, angle in ((1, -8.0), (15, -15.0), (30, -8.0)):
        pose_bone = rig.pose.bones["Spine"]
        pose_bone.rotation_mode = "XYZ"
        pose_bone.rotation_euler.x = math.radians(angle)
        pose_bone.keyframe_insert("rotation_euler", frame=frame)
        for side, phase in (("L", 1.0), ("R", -1.0)):
            leg = rig.pose.bones[f"Thigh.{side}"]
            leg.rotation_mode = "XYZ"
            leg.rotation_euler.x = math.radians(phase * (4.0 if frame == 15 else -2.0))
            leg.keyframe_insert("rotation_euler", frame=frame)
    action.frame_start = 1
    action.frame_end = 30

    smart_uv_all()
    SOURCE.parent.mkdir(parents=True, exist_ok=True)
    EXPORT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(EXPORT), export_format="GLB", use_selection=True,
        export_apply=True, export_yup=True, export_animations=True,
    )


reset_scene()
build()
print(f"Saved {SOURCE}")
print(f"Exported {EXPORT}")
