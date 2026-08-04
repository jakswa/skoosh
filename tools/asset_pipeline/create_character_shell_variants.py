"""Generate three structurally distinct rigid-skinned SKOOSH character shells."""

from __future__ import annotations

import hashlib
import json
import math
import struct
import sys
from dataclasses import dataclass
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_asset_utils import (
    box,
    front_panel_prism,
    material,
    panel_prism,
    profile_prism,
    rectangular_duct,
    reset_scene,
    smart_uv_all,
    tapered_prism,
    tapered_prism_between,
)


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "assets/source/characters"
EXPORT_DIR = ROOT / "assets/models/characters"


@dataclass(frozen=True)
class Variant:
    slug: str
    title: str
    code: str


VARIANTS = (
    Variant("vector_sprinter_mk2", "Vector Sprinter Mk II", "VECTOR-MK2"),
    Variant("stratos_foilframe", "STRATOS Foilframe", "STRATOS-FF"),
    Variant("khepri_triune_salvage", "Khepri Triune Salvage", "KHEPRI-TS"),
)

BONE_CONTRACT = (
    "Root",
    "Pelvis",
    "Spine",
    "Head",
    "UpperArm.L",
    "Forearm.L",
    "Thigh.L",
    "Shin.L",
    "UpperArm.R",
    "Forearm.R",
    "Thigh.R",
    "Shin.R",
)
ANIMATED_BONE_CONTRACT = (
    "Pelvis",
    "Spine",
    "UpperArm.L",
    "UpperArm.R",
    "Thigh.L",
    "Thigh.R",
)
SEMANTIC_PART_CONTRACT = (
    "Pelvis shell", "Chest plate", "Helmet", "Visor", "Brow plane", "Sensor",
    "Torso frame", "Back frame", "Rear bib", "Spine rail",
    "Jet pod L", "Jet pod R", "Pod cowl L", "Pod cowl R",
    "Exhaust channel L", "Exhaust channel R",
    "Shoulder fin L", "Shoulder fin R", "Rib frame L", "Rib frame R",
    "Upper arm L", "Upper arm R", "Forearm L", "Forearm R",
    "Thigh armor L", "Thigh armor R", "Thigh signal L", "Thigh signal R",
    "Shin armor L", "Shin armor R", "Calf stabilizer L", "Calf stabilizer R",
    "Boot stabilizer L", "Boot stabilizer R",
    "Maintenance latch L", "Maintenance latch R",
    "Neck gaiter", "Waist flex",
    "Shoulder interface L", "Shoulder interface R",
    "Elbow interface L", "Elbow interface R", "Glove L", "Glove R",
    "Hip interface L", "Hip interface R", "Knee interface L", "Knee interface R",
    "Ankle interface L", "Ankle interface R",
)
PRIMARY_TEAM_PARTS = {
    "Pelvis shell", "Chest plate", "Helmet", "Rear bib",
}
SECONDARY_TEAM_PARTS = {
    "Jet pod L", "Jet pod R", "Shoulder fin L", "Shoulder fin R",
    "Thigh signal L", "Thigh signal R",
}
RUNTIME_ROLE_NAMES = {
    "graphite": "Graphite",
    "ceramic": "Ceramic",
    "hardware": "Hardware",
    "team_primary": "TeamPrimary",
    "team_secondary": "TeamSecondary",
    "mint": "Mint",
    "orange": "Orange",
    "bronze": "Bronze",
}
MAX_RUNTIME_MESHES = 7


def add_bone(armature, name, head, tail, parent=None):
    bone = armature.edit_bones.new(name)
    bone.head = head
    bone.tail = tail
    bone.parent = parent
    return bone


def create_rig() -> bpy.types.Object:
    armature_data = bpy.data.armatures.new("CharacterShellSkeleton")
    rig = bpy.data.objects.new("CharacterShellRig", armature_data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    root = add_bone(armature_data, "Root", (0, 0, 0), (0, 0, 0.3))
    pelvis = add_bone(armature_data, "Pelvis", (0, 0, 0.78), (0, 0, 1.08), root)
    spine = add_bone(armature_data, "Spine", (0, 0, 1.08), (0, -0.03, 1.67), pelvis)
    add_bone(armature_data, "Head", (0, -0.03, 1.67), (0, -0.10, 2.14), spine)
    for side, sign in (("L", 1.0), ("R", -1.0)):
        upper_arm = add_bone(
            armature_data,
            f"UpperArm.{side}",
            (sign * 0.25, -0.03, 1.56),
            (sign * 0.39, -0.11, 1.31),
            spine,
        )
        add_bone(
            armature_data,
            f"Forearm.{side}",
            (sign * 0.39, -0.11, 1.31),
            (sign * 0.37, -0.23, 1.04),
            upper_arm,
        )
        thigh = add_bone(
            armature_data,
            f"Thigh.{side}",
            (sign * 0.135, 0, 0.88),
            (sign * 0.16, -0.05, 0.51),
            pelvis,
        )
        add_bone(
            armature_data,
            f"Shin.{side}",
            (sign * 0.16, -0.05, 0.51),
            (sign * 0.17, -0.14, 0.10),
            thigh,
        )
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def create_materials(variant: Variant) -> dict[str, bpy.types.Material]:
    team_colors = {
        "VECTOR-MK2": (0.36, 0.075, 0.045, 1.0),
        "STRATOS-FF": (0.28, 0.07, 0.055, 1.0),
        "KHEPRI-TS": (0.33, 0.085, 0.04, 1.0),
    }
    team_color = team_colors[variant.code]
    result = {
        "graphite": material("Graphite weave", (0.018, 0.026, 0.029, 1.0), 0.18, 0.91),
        "hardware": material("Graphite mechanism", (0.047, 0.061, 0.064, 1.0), 0.58, 0.53),
        "team_primary": material("Team primary seed", team_color, 0.08, 0.76),
        "team_secondary": material(
            "Team secondary seed",
            tuple(channel * 0.72 for channel in team_color[:3]) + (1.0,),
            0.18,
            0.72,
        ),
        "mint": material(
            "Active mint channel",
            (0.025, 0.40, 0.32, 1.0),
            0.05,
            0.34,
            emission=(0.04, 0.82, 0.62, 1.0),
            emission_strength=2.0,
        ),
        "orange": material("Expedition orange latch", (0.72, 0.20, 0.035, 1.0), 0.18, 0.57),
    }
    if variant.code == "KHEPRI-TS":
        result["bronze"] = material(
            "Oxidized salvage bronze", (0.30, 0.17, 0.085, 1.0), 0.66, 0.61
        )
    else:
        result["ceramic"] = material(
            "Weathered glacier ceramic", (0.34, 0.38, 0.38, 1.0), 0.04, 0.84
        )
    return result


def skin_part(obj: bpy.types.Object, rig: bpy.types.Object, bone_name: str) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    group = obj.vertex_groups.new(name=bone_name)
    group.add(range(len(obj.data.vertices)), 1.0, "REPLACE")
    modifier = obj.modifiers.new("Rigid shell skin", "ARMATURE")
    modifier.object = rig
    obj.parent = rig
    obj["semantic_role"] = obj.name
    obj["rigid_skin_bone"] = bone_name


def build_shell(variant: Variant, rig: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    made: list[tuple[bpy.types.Object, str]] = []

    def add(obj: bpy.types.Object, bone: str) -> None:
        made.append((obj, bone))

    if variant.code == "VECTOR-MK2":
        build_vector_core(add, mats)
    elif variant.code == "STRATOS-FF":
        build_stratos_core(add, mats)
    else:
        build_khepri_core(add, mats)
    build_connected_limbs(variant, add, mats)

    semantic_names = {obj.name for obj, _bone_name in made}
    if semantic_names != set(SEMANTIC_PART_CONTRACT):
        missing = sorted(set(SEMANTIC_PART_CONTRACT) - semantic_names)
        unexpected = sorted(semantic_names - set(SEMANTIC_PART_CONTRACT))
        raise RuntimeError(f"Semantic part contract mismatch: missing={missing}, unexpected={unexpected}")

    material_roles = {mat: role for role, mat in mats.items()}
    for obj, bone_name in made:
        assigned_material = obj.data.materials[0]
        if assigned_material == mats["team_primary"]:
            if obj.name in SECONDARY_TEAM_PARTS:
                obj.data.materials[0] = mats["team_secondary"]
                assigned_material = mats["team_secondary"]
            elif obj.name not in PRIMARY_TEAM_PARTS:
                raise RuntimeError(f"Unclassified team-colored semantic part: {obj.name}")
        obj["runtime_material_role"] = material_roles[assigned_material]
        skin_part(obj, rig, bone_name)


def build_vector_core(add, mats: dict[str, bpy.types.Material]) -> None:
    add(
        front_panel_prism(
            "Torso frame", (0, 0.0, 1.38),
            [(-0.35, 0.27), (0.35, 0.27), (0.19, -0.28), (0, -0.35), (-0.19, -0.28)],
            0.25, mats["graphite"], 0.035,
        ),
        "Spine",
    )
    add(
        front_panel_prism(
            "Chest plate", (0, -0.15, 1.40),
            [(-0.29, 0.21), (0.29, 0.21), (0.14, -0.21), (0, -0.30), (-0.14, -0.21)],
            0.055, mats["team_primary"], 0.022,
        ),
        "Spine",
    )
    add(
        front_panel_prism(
            "Back frame", (0, 0.18, 1.38),
            [(-0.29, 0.23), (0.29, 0.23), (0.21, -0.27), (-0.21, -0.27)],
            0.12, mats["hardware"], 0.022,
        ),
        "Spine",
    )
    add(
        front_panel_prism(
            "Rear bib", (0, 0.29, 1.42),
            [(-0.23, 0.18), (0.23, 0.18), (0.16, -0.20), (0, -0.25), (-0.16, -0.20)],
            0.045, mats["team_primary"], 0.014,
        ),
        "Spine",
    )
    add(tapered_prism("Spine rail", (0, 0.335, 1.39), (0.065, 0.05, 0.46), (0.58, 0.72), mats["hardware"], 0.012), "Spine")
    add(
        front_panel_prism(
            "Pelvis shell", (0, -0.015, 0.94),
            [(-0.32, 0.15), (0.32, 0.15), (0.25, -0.13), (0, -0.20), (-0.25, -0.13)],
            0.25, mats["team_primary"], 0.025,
        ),
        "Pelvis",
    )
    add(profile_prism("Helmet", (0, -0.01, 1.94), 0.15, [(-0.31, -0.15), (-0.35, 0.05), (-0.18, 0.18), (0.15, 0.13), (0.19, -0.14)], mats["team_primary"], 0.027, (math.radians(-4), 0, 0)), "Head")
    add(box("Brow plane", (0, -0.322, 2.02), (0.27, 0.04, 0.055), mats["graphite"], 0.012, (math.radians(-4), 0, 0)), "Head")
    add(box("Visor", (0, -0.338, 1.95), (0.26, 0.032, 0.115), mats["mint"], 0.014, (math.radians(-4), 0, 0)), "Head")
    add(profile_prism("Sensor", (0.14, -0.015, 2.09), 0.018, [(-0.04, -0.04), (-0.035, 0.06), (0.02, 0.08), (0.025, -0.05)], mats["hardware"], 0.006, (0, 0, math.radians(-8))), "Head")

    for side, sign in (("L", 1.0), ("R", -1.0)):
        add(panel_prism(f"Shoulder fin {side}", (0, 0.015, 1.50), [(sign * 0.08, -0.10), (sign * 0.53, 0.01), (sign * 0.45, 0.12), (sign * 0.13, 0.065)], 0.065, mats["team_primary"], 0.016, (math.radians(-7), 0, 0)), "Spine")
        add(profile_prism(f"Rib frame {side}", (sign * 0.25, -0.01, 1.35), 0.035, [(-0.12, -0.22), (-0.10, 0.20), (0.04, 0.17), (0.06, -0.20)], mats["hardware"], 0.012), "Spine")
        pod_x = sign * 0.205
        pod_y = 0.27 if side == "L" else 0.34
        pod_z = 1.35 if side == "L" else 1.41
        add(rectangular_duct(f"Jet pod {side}", (pod_x, pod_y, pod_z), (0.30, 0.17), 0.36, 0.035, mats["team_primary"], 0.016, (math.radians(-8), 0, 0)), "Spine")
        add(panel_prism(f"Pod cowl {side}", (pod_x, pod_y, pod_z + 0.10), [(sign * -0.15, -0.17), (sign * 0.17, -0.12), (sign * 0.14, 0.13), (sign * -0.12, 0.16)], 0.035, mats["graphite"], 0.010), "Spine")
        add(box(f"Exhaust channel {side}", (pod_x, pod_y + 0.192, pod_z - 0.01), (0.16, 0.032, 0.065), mats["mint"], 0.008, (math.radians(-8), 0, 0)), "Spine")


def build_stratos_core(add, mats: dict[str, bpy.types.Material]) -> None:
    add(
        front_panel_prism(
            "Torso frame", (0, 0.0, 1.38),
            [(-0.48, 0.25), (0.48, 0.25), (0.16, -0.31), (-0.16, -0.31)],
            0.23, mats["graphite"], 0.035,
        ),
        "Spine",
    )
    add(
        front_panel_prism(
            "Chest plate", (0, -0.145, 1.43),
            [(-0.45, 0.19), (0.45, 0.19), (0.22, -0.20), (0.10, -0.29), (-0.10, -0.29), (-0.22, -0.20)],
            0.06, mats["team_primary"], 0.022,
        ),
        "Spine",
    )
    add(front_panel_prism("Back frame", (0, 0.17, 1.37), [(-0.31, 0.24), (0.31, 0.24), (0.18, -0.28), (-0.18, -0.28)], 0.12, mats["hardware"], 0.022), "Spine")
    add(front_panel_prism("Rear bib", (0, 0.285, 1.43), [(-0.34, 0.19), (0.34, 0.19), (0.20, -0.22), (0, -0.29), (-0.20, -0.22)], 0.05, mats["team_primary"], 0.014), "Spine")
    add(tapered_prism("Spine rail", (0, 0.34, 1.39), (0.055, 0.045, 0.48), (0.72, 0.66), mats["hardware"], 0.01), "Spine")
    add(front_panel_prism("Pelvis shell", (0, -0.015, 0.94), [(-0.27, 0.15), (0.27, 0.15), (0.18, -0.18), (-0.18, -0.18)], 0.23, mats["team_primary"], 0.023), "Pelvis")
    add(profile_prism("Helmet", (0, -0.005, 1.95), 0.19, [(-0.25, -0.13), (-0.27, 0.05), (-0.12, 0.14), (0.14, 0.12), (0.18, -0.12)], mats["team_primary"], 0.028, (math.radians(-6), 0, 0)), "Head")
    add(box("Brow plane", (0, -0.275, 2.015), (0.34, 0.038, 0.05), mats["graphite"], 0.011, (math.radians(-6), 0, 0)), "Head")
    add(box("Visor", (0, -0.293, 1.95), (0.33, 0.03, 0.105), mats["mint"], 0.013, (math.radians(-6), 0, 0)), "Head")
    add(box("Sensor", (0, 0.135, 2.075), (0.075, 0.045, 0.045), mats["hardware"], 0.008), "Head")

    for side, sign in (("L", 1.0), ("R", -1.0)):
        add(panel_prism(f"Shoulder fin {side}", (0, 0.015, 1.59), [(0, -0.11), (sign * 0.68, -0.035), (sign * 0.60, 0.09), (0, 0.045)], 0.095, mats["team_primary"], 0.017, (math.radians(-5), 0, 0)), "Spine")
        add(profile_prism(f"Rib frame {side}", (sign * 0.20, -0.005, 1.34), 0.03, [(-0.08, -0.23), (-0.08, 0.22), (0.035, 0.18), (0.045, -0.21)], mats["ceramic"], 0.01), "Spine")
        pod_x = sign * 0.235
        pod_y = 0.27 if side == "L" else 0.35
        pod_z = 1.34 if side == "L" else 1.40
        add(rectangular_duct(f"Jet pod {side}", (pod_x, pod_y, pod_z), (0.18, 0.44), 0.32, 0.034, mats["team_primary"], 0.015, (math.radians(-7), 0, 0)), "Spine")
        add(panel_prism(f"Pod cowl {side}", (pod_x, pod_y + 0.005, pod_z + 0.01), [(sign * -0.09, -0.15), (sign * 0.12, -0.13), (sign * 0.055, -0.015), (sign * 0.12, 0.15), (sign * -0.09, 0.13)], 0.47, mats["graphite"], 0.012), "Spine")
        add(box(f"Exhaust channel {side}", (pod_x, pod_y + 0.175, pod_z - 0.10), (0.095, 0.03, 0.12), mats["mint"], 0.008, (math.radians(-7), 0, 0)), "Spine")


def build_khepri_core(add, mats: dict[str, bpy.types.Material]) -> None:
    add(front_panel_prism("Torso frame", (0, 0.0, 1.38), [(-0.35, 0.28), (0, 0.35), (0.35, 0.28), (0.27, -0.18), (0, -0.34), (-0.27, -0.18)], 0.27, mats["graphite"], 0.035), "Spine")
    add(front_panel_prism("Chest plate", (0, -0.16, 1.43), [(-0.30, 0.19), (0, 0.29), (0.30, 0.19), (0.20, -0.13), (0, -0.26), (-0.20, -0.13)], 0.06, mats["team_primary"], 0.02), "Spine")
    add(front_panel_prism("Back frame", (0, 0.19, 1.38), [(-0.25, 0.23), (0, 0.30), (0.25, 0.23), (0.20, -0.25), (0, -0.32), (-0.20, -0.25)], 0.13, mats["bronze"], 0.022), "Spine")
    add(front_panel_prism("Rear bib", (0, 0.305, 1.41), [(-0.20, 0.17), (0, 0.25), (0.20, 0.17), (0.14, -0.19), (0, -0.25), (-0.14, -0.19)], 0.045, mats["team_primary"], 0.012), "Spine")
    add(tapered_prism("Spine rail", (0, 0.35, 1.38), (0.085, 0.05, 0.47), (0.38, 0.70), mats["bronze"], 0.012), "Spine")
    add(front_panel_prism("Pelvis shell", (0, -0.01, 0.94), [(-0.29, 0.13), (0, 0.21), (0.29, 0.13), (0.20, -0.12), (0, -0.20), (-0.20, -0.12)], 0.27, mats["team_primary"], 0.024), "Pelvis")
    add(front_panel_prism("Helmet", (0, -0.01, 1.95), [(-0.22, -0.12), (-0.08, 0.17), (0.14, 0.13), (0.23, -0.02), (0.10, -0.16)], 0.37, mats["team_primary"], 0.027, (math.radians(-7), 0, 0)), "Head")
    add(front_panel_prism("Brow plane", (-0.015, -0.215, 2.01), [(-0.17, -0.035), (0.12, 0.015), (0.18, -0.025), (0.05, -0.075), (-0.15, -0.075)], 0.04, mats["bronze"], 0.01, (math.radians(-7), 0, 0)), "Head")
    add(front_panel_prism("Visor", (0.01, -0.238, 1.945), [(-0.15, 0.04), (0.15, 0.07), (0.12, -0.05), (-0.13, -0.075)], 0.035, mats["mint"], 0.011, (math.radians(-7), 0, 0)), "Head")
    add(panel_prism("Sensor", (-0.205, -0.03, 2.09), [(-0.025, -0.08), (0.035, -0.045), (0.02, 0.15), (-0.02, 0.20)], 0.045, mats["bronze"], 0.007, (math.radians(-8), 0, math.radians(-9))), "Head")

    for side, sign in (("L", 1.0), ("R", -1.0)):
        inner = 0.05 if side == "L" else 0.09
        reach = 0.52 if side == "L" else 0.47
        add(panel_prism(f"Shoulder fin {side}", (0, 0.01, 1.56), [(sign * inner, -0.12), (sign * reach, -0.035), (sign * (reach - 0.09), 0.10), (sign * 0.14, 0.055)], 0.07, mats["team_primary"], 0.016, (math.radians(-7), 0, math.radians(sign * 2))), "Spine")
        add(profile_prism(f"Rib frame {side}", (sign * 0.22, -0.005, 1.35), 0.045, [(-0.11, -0.22), (-0.07, 0.20), (0.05, 0.15), (0.075, -0.17)], mats["bronze"], 0.012, (0, 0, math.radians(sign * -7))), "Spine")
        pod_x = sign * (0.215 if side == "L" else 0.245)
        pod_z = 1.24 if side == "L" else 1.40
        pod_y = 0.25 if side == "L" else 0.38
        add(rectangular_duct(f"Jet pod {side}", (pod_x, pod_y, pod_z), (0.22, 0.29), 0.33, 0.035, mats["team_primary"], 0.015, (math.radians(-9), 0, math.radians(sign * 3))), "Spine")
        add(panel_prism(f"Pod cowl {side}", (pod_x, pod_y + 0.005, pod_z), [(sign * -0.11, -0.16), (sign * 0.14, -0.13), (sign * 0.045, -0.015), (sign * 0.14, 0.14), (sign * -0.08, 0.11)], 0.32, mats["bronze"], 0.012, (0, 0, math.radians(sign * -4))), "Spine")
        add(box(f"Exhaust channel {side}", (pod_x, pod_y + 0.175, pod_z - 0.055), (0.115, 0.03, 0.085), mats["mint"], 0.008, (math.radians(-9), 0, 0)), "Spine")


def build_connected_limbs(variant: Variant, add, mats: dict[str, bpy.types.Material]) -> None:
    is_vector = variant.code == "VECTOR-MK2"
    is_stratos = variant.code == "STRATOS-FF"
    is_khepri = variant.code == "KHEPRI-TS"

    neck_width = 0.30 if is_vector else (0.32 if is_stratos else 0.28)
    add(tapered_prism("Neck gaiter", (0, 0.005, 1.70), (neck_width, 0.24, 0.24), (0.82, 0.86), mats["graphite"], 0.035), "Head")
    waist_width = 0.25 if is_stratos else (0.31 if is_vector else 0.29)
    add(tapered_prism("Waist flex", (0, 0.0, 1.055), (waist_width, 0.23, 0.23), (0.88, 0.92), mats["graphite"], 0.032), "Pelvis")

    arm_mat = mats["hardware"] if is_vector else mats["graphite"]
    thigh_mat = mats["graphite"] if not is_stratos else mats["ceramic"]
    shin_mat = mats["hardware"] if is_vector else mats["graphite"]
    calf_mat = mats["bronze"] if is_khepri else mats["ceramic"]
    boot_length = 0.56 if is_vector else (0.39 if is_stratos else 0.43)

    for side, sign in (("L", 1.0), ("R", -1.0)):
        shoulder = (sign * 0.25, -0.03, 1.56)
        elbow = (sign * 0.39, -0.11, 1.31)
        wrist = (sign * 0.37, -0.23, 1.04)
        add(tapered_prism_between(f"Shoulder interface {side}", (sign * 0.20, -0.015, 1.57), (sign * 0.30, -0.055, 1.51), (0.17, 0.19), (0.82, 0.84), mats["graphite"], 0.025, 0.10), f"UpperArm.{side}")
        add(tapered_prism_between(f"Upper arm {side}", shoulder, elbow, (0.145, 0.17), (0.76, 0.78), arm_mat, 0.024, 0.13), f"UpperArm.{side}")
        add(tapered_prism(f"Elbow interface {side}", elbow, (0.16, 0.18, 0.17), (0.82, 0.82), mats["graphite"], 0.026, (math.radians(-8), 0, math.radians(sign * -4))), f"Forearm.{side}")
        add(tapered_prism_between(f"Forearm {side}", elbow, wrist, (0.145, 0.17), (0.80, 0.76), mats["graphite"], 0.023, 0.15), f"Forearm.{side}")
        add(tapered_prism(f"Glove {side}", (sign * 0.365, -0.245, 1.025), (0.155, 0.19, 0.20), (0.86, 0.82), mats["hardware"], 0.027, (math.radians(-10), 0, math.radians(sign * -3))), f"Forearm.{side}")

        hip = (sign * 0.135, 0.0, 0.88)
        knee = (sign * 0.16, -0.05, 0.51)
        ankle = (sign * 0.17, -0.14, 0.10)
        add(tapered_prism(f"Hip interface {side}", hip, (0.18, 0.22, 0.20), (0.82, 0.88), mats["graphite"], 0.028), f"Thigh.{side}")
        thigh_width = 0.17 if is_stratos else (0.16 if is_vector else 0.18)
        add(tapered_prism_between(f"Thigh armor {side}", hip, knee, (thigh_width, 0.21), (0.74, 0.72), thigh_mat, 0.025, 0.14), f"Thigh.{side}")
        add(front_panel_prism(f"Thigh signal {side}", (sign * 0.18, -0.15, 0.70), [(-0.055, 0.11), (0.055, 0.08), (0.045, -0.12), (-0.045, -0.09)], 0.025, mats["team_primary"], 0.008), f"Thigh.{side}")
        add(tapered_prism(f"Knee interface {side}", knee, (0.17, 0.21, 0.18), (0.84, 0.82), mats["graphite"], 0.027, (math.radians(-7), 0, 0)), f"Shin.{side}")
        shin_width = 0.14 if is_vector else (0.16 if is_stratos else 0.17)
        add(tapered_prism_between(f"Shin armor {side}", knee, ankle, (shin_width, 0.19), (0.74, 0.80), shin_mat, 0.024, 0.15), f"Shin.{side}")
        add(tapered_prism(f"Ankle interface {side}", (sign * 0.17, -0.14, 0.13), (0.16, 0.21, 0.17), (0.84, 0.80), mats["graphite"], 0.026, (math.radians(-8), 0, 0)), f"Shin.{side}")

        calf_depth = 0.29 if is_stratos else (0.20 if is_vector else 0.25)
        calf_offset = 0.015 if side == "L" else (-0.005 if is_khepri else 0.015)
        add(profile_prism(f"Calf stabilizer {side}", (sign * 0.17, calf_offset, 0.29), 0.075 if is_vector else 0.09, [(-calf_depth * 0.46, -0.17), (-calf_depth * 0.52, 0.15), (calf_depth * 0.50, 0.20), (calf_depth * 0.33, -0.14)], calf_mat, 0.021), f"Shin.{side}")
        boot_y = -0.235 if is_vector else (-0.20 if is_stratos else (-0.21 if side == "L" else -0.17))
        add(profile_prism(f"Boot stabilizer {side}", (sign * 0.17, boot_y, 0.075), 0.095 if is_vector else 0.105, [(-boot_length * 0.62, -0.06), (-boot_length * 0.54, 0.075), (boot_length * 0.35, 0.065), (boot_length * 0.43, -0.045)], mats["hardware"], 0.02, (0, 0, math.radians(sign * (-2 if is_vector else 1)))), f"Shin.{side}")
        add(box(f"Maintenance latch {side}", (sign * 0.425, -0.25, 1.08), (0.03, 0.026, 0.07), mats["orange"], 0.006, (math.radians(-10), 0, 0)), f"Forearm.{side}")


def create_animation(rig: bpy.types.Object) -> None:
    rig.animation_data_create()
    action = bpy.data.actions.new("MomentumLean")
    rig.animation_data.action = action
    for frame, lean, sway in ((1, -10.0, -2.0), (15, -17.0, 2.5), (30, -10.0, -2.0)):
        keyed = {
            "Pelvis": (math.radians(-lean * 0.14), 0.0, math.radians(-sway * 0.30)),
            "Spine": (math.radians(lean), 0.0, math.radians(sway)),
            "UpperArm.L": (math.radians(-5.0), 0.0, math.radians(2.0 + sway * 0.5)),
            "UpperArm.R": (math.radians(-5.0), 0.0, math.radians(-2.0 + sway * 0.5)),
            "Thigh.L": (math.radians(4.0 if frame == 15 else -2.0), 0.0, math.radians(-1.0)),
            "Thigh.R": (math.radians(-4.0 if frame == 15 else 2.0), 0.0, math.radians(1.0)),
        }
        for bone_name, rotation in keyed.items():
            pose_bone = rig.pose.bones[bone_name]
            pose_bone.rotation_mode = "XYZ"
            pose_bone.rotation_euler = rotation
            pose_bone.keyframe_insert("rotation_euler", frame=frame)
    action.frame_start = 1
    action.frame_end = 30
    action["root_transform_contract"] = "unchanged"
    action["animated_bones"] = ",".join(ANIMATED_BONE_CONTRACT)


def mesh_statistics(meshes: list[bpy.types.Object]) -> tuple[int, int, int]:
    vertices = 0
    triangles = 0
    materials: set[bpy.types.Material] = set()
    for obj in meshes:
        obj.data.calc_loop_triangles()
        vertices += len(obj.data.vertices)
        triangles += len(obj.data.loop_triangles)
        materials.update(slot.material for slot in obj.material_slots if slot.material is not None)
    return vertices, triangles, len(materials)


def consolidate_runtime_meshes(rig: bpy.types.Object) -> list[bpy.types.Object]:
    groups: dict[str, list[bpy.types.Object]] = {}
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            groups.setdefault(str(obj["runtime_material_role"]), []).append(obj)

    consolidated: list[bpy.types.Object] = []
    for role in sorted(groups):
        objects = sorted(groups[role], key=lambda candidate: candidate.name)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        if len(objects) > 1:
            bpy.ops.object.join()
        joined = bpy.context.object
        joined.name = RUNTIME_ROLE_NAMES[role]
        joined.data.name = f"{joined.name}Mesh"
        joined["runtime_material_role"] = role
        if joined.parent != rig:
            raise RuntimeError(f"Runtime role {role} lost its armature parent")
        armature_modifiers = [modifier for modifier in joined.modifiers if modifier.type == "ARMATURE"]
        if len(armature_modifiers) != 1 or armature_modifiers[0].object != rig:
            raise RuntimeError(f"Runtime role {role} lost its armature modifier")
        if len(joined.material_slots) != 1:
            raise RuntimeError(
                f"Runtime role {role} expected one material slot, found {len(joined.material_slots)}"
            )
        consolidated.append(joined)

    if len(consolidated) > MAX_RUNTIME_MESHES:
        raise RuntimeError(
            f"Runtime mesh budget exceeded: {len(consolidated)} > {MAX_RUNTIME_MESHES}"
        )
    return consolidated


def glb_statistics(path: Path) -> tuple[int, int, int, int]:
    contents = path.read_bytes()
    magic, version, total_length = struct.unpack_from("<4sII", contents)
    if magic != b"glTF" or version != 2 or total_length != len(contents):
        raise RuntimeError(f"Invalid GLB output: {path}")
    json_length, json_type = struct.unpack_from("<II", contents, 12)
    if json_type != 0x4E4F534A:
        raise RuntimeError(f"GLB JSON chunk missing: {path}")
    document = json.loads(contents[20:20 + json_length].decode("utf-8"))
    accessors = document.get("accessors", [])
    primitives = [
        primitive
        for mesh in document.get("meshes", [])
        for primitive in mesh.get("primitives", [])
    ]
    vertices = sum(accessors[primitive["attributes"]["POSITION"]]["count"] for primitive in primitives)
    triangles = sum(accessors[primitive["indices"]]["count"] // 3 for primitive in primitives)
    used_materials = {primitive.get("material") for primitive in primitives}
    used_materials.discard(None)
    return len(document.get("meshes", [])), vertices, triangles, len(used_materials)


def save_export_and_report(variant: Variant, rig: bpy.types.Object) -> None:
    source = SOURCE_DIR / f"{variant.slug}.blend"
    export = EXPORT_DIR / f"{variant.slug}.glb"
    smart_uv_all()
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    source_meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if len(source_meshes) != len(SEMANTIC_PART_CONTRACT):
        raise RuntimeError(f"Expected {len(SEMANTIC_PART_CONTRACT)} source meshes")
    source_vertices, source_triangles, source_materials = mesh_statistics(source_meshes)
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    runtime_meshes = consolidate_runtime_meshes(rig)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(export),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_animations=True,
    )
    runtime_mesh_count, runtime_vertices, runtime_triangles, runtime_materials = glb_statistics(export)
    if runtime_mesh_count != len(runtime_meshes):
        raise RuntimeError(
            f"GLB mesh count changed during export: {runtime_mesh_count} != {len(runtime_meshes)}"
        )
    if runtime_triangles != source_triangles:
        raise RuntimeError(
            f"GLB triangle count changed during consolidation: {runtime_triangles} != {source_triangles}"
        )
    print(
        f"CHARACTER_SHELL {variant.slug}: source_meshes={len(source_meshes)} "
        f"source_vertices={source_vertices} source_triangles={source_triangles} "
        f"source_materials={source_materials} runtime_meshes={runtime_mesh_count} "
        f"runtime_vertices={runtime_vertices} runtime_triangles={runtime_triangles} "
        f"runtime_materials={runtime_materials} source_bytes={source.stat().st_size} "
        f"runtime_bytes={export.stat().st_size} "
        f"runtime_sha256={hashlib.sha256(export.read_bytes()).hexdigest()} "
        f"bones={len(BONE_CONTRACT)} "
        f"animation=MomentumLean animated_bones={','.join(ANIMATED_BONE_CONTRACT)} "
        "root_transform=unchanged"
    )
    print(f"Saved {source}")
    print(f"Exported {export}")


def build_variant(variant: Variant) -> None:
    reset_scene()
    rig = create_rig()
    rig["skeleton_contract"] = ",".join(BONE_CONTRACT)
    rig["variant"] = variant.title
    build_shell(variant, rig, create_materials(variant))
    create_animation(rig)
    save_export_and_report(variant, rig)


for shell_variant in VARIANTS:
    build_variant(shell_variant)
