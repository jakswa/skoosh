"""Build the Kestrel rail gatling and export its Godot runtime contract.

Run from the repository root:
    TMPDIR="$PWD/.tmp" blender --background --python \
        tools/asset_pipeline/create_kestrel_gatling.py

The model and its embedded ceramic surface maps are deterministic, local, and
project-authored. Blender +Y is the firing direction; glTF export converts that
to Godot -Z while preserving +Y up and an identity root.
"""

from __future__ import annotations

import hashlib
import json
import math
import random
import struct
import sys
from pathlib import Path

import bpy
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_asset_utils import (  # noqa: E402
    box,
    cylinder,
    finish_mesh,
    material,
    parent_keep_transform,
    reset_scene,
    smart_uv_all,
    tapered_prism_between,
)


ROOT = Path(__file__).resolve().parents[2]
SOURCE_PATH = ROOT / "assets/source/weapons/kestrel_rail_gatling.blend"
EXPORT_PATH = ROOT / "assets/models/weapons/kestrel_rail_gatling.glb"
MANIFEST_PATH = ROOT / "assets/manifests/kestrel_rail_gatling.json"
SCRATCH_PATH = ROOT / ".tmp/gatling-generator"


def weathered_ceramic_maps() -> tuple[Path, Path]:
    """Generate restrained, tileable slate variation for the packed material."""
    SCRATCH_PATH.mkdir(parents=True, exist_ok=True)
    size = 256
    rng = random.Random("skoosh-kestrel-rail-gatling-ceramic-v1")
    base = Image.new("RGB", (size, size))
    roughness = Image.new("L", (size, size))
    base_pixels = base.load()
    roughness_pixels = roughness.load()
    for y in range(size):
        for x in range(size):
            broad = math.sin(x * 0.045) * 2.4 + math.sin((x + y) * 0.021) * 1.6
            grain = rng.gauss(0.0, 1.2)
            value = broad + grain
            base_pixels[x, y] = (
                max(0, min(255, round(108 + value))),
                max(0, min(255, round(118 + value))),
                max(0, min(255, round(121 + value * 0.85))),
            )
            roughness_pixels[x, y] = max(
                0, min(255, round(184 + broad * 1.5 + rng.gauss(0.0, 3.0)))
            )

    # Sparse directional scuffs read as field wear without becoming panel noise.
    base_draw = ImageDraw.Draw(base)
    roughness_draw = ImageDraw.Draw(roughness)
    for _index in range(6):
        x = rng.randrange(size)
        y = rng.randrange(size)
        length = rng.randrange(16, 58)
        end = ((x + length) % size, max(0, min(size - 1, y + rng.randrange(-2, 3))))
        base_draw.line((x, y, *end), fill=(84, 92, 95), width=1)
        roughness_draw.line((x, y, *end), fill=216, width=1)
    base = base.filter(ImageFilter.GaussianBlur(radius=0.18))
    roughness = roughness.filter(ImageFilter.GaussianBlur(radius=0.3))
    base_path = SCRATCH_PATH / "weathered_slate_base.png"
    roughness_path = SCRATCH_PATH / "weathered_slate_roughness.png"
    base.save(base_path)
    roughness.save(roughness_path)
    return base_path, roughness_path


def weathered_ceramic_material() -> bpy.types.Material:
    base_path, roughness_path = weathered_ceramic_maps()
    result = material(
        "Weathered slate ceramic", (0.38, 0.42, 0.43, 1.0), 0.08, 0.72
    )
    nodes = result.node_tree.nodes
    links = result.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    base_image = bpy.data.images.load(str(base_path), check_existing=True)
    base_image.pack()
    base_texture = nodes.new("ShaderNodeTexImage")
    base_texture.name = "Packed slate variation"
    base_texture.image = base_image
    links.new(base_texture.outputs["Color"], bsdf.inputs["Base Color"])
    roughness_image = bpy.data.images.load(str(roughness_path), check_existing=True)
    roughness_image.colorspace_settings.name = "Non-Color"
    roughness_image.pack()
    roughness_texture = nodes.new("ShaderNodeTexImage")
    roughness_texture.name = "Packed ceramic roughness"
    roughness_texture.image = roughness_image
    links.new(roughness_texture.outputs["Color"], bsdf.inputs["Roughness"])
    return result


def loft(
    name: str,
    sections: list[tuple[float, float, float, float]],
    mat: bpy.types.Material,
    bevel: float = 0.014,
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
    return finish_mesh(obj, mat, bevel)


def hex_rail(
    name: str,
    sections: list[tuple[float, float, float, float, float]],
    mat: bpy.types.Material,
) -> bpy.types.Object:
    """Create a tapered rail from y, x, z, half-width, half-height sections."""
    vertices: list[tuple[float, float, float]] = []
    for y, center_x, center_z, half_width, half_height in sections:
        chamfer = min(half_width, half_height) * 0.42
        vertices.extend(
            [
                (center_x - half_width + chamfer, y, center_z - half_height),
                (center_x + half_width - chamfer, y, center_z - half_height),
                (center_x + half_width, y, center_z - half_height + chamfer),
                (center_x + half_width, y, center_z + half_height - chamfer),
                (center_x + half_width - chamfer, y, center_z + half_height),
                (center_x - half_width + chamfer, y, center_z + half_height),
                (center_x - half_width, y, center_z + half_height - chamfer),
                (center_x - half_width, y, center_z - half_height + chamfer),
            ]
        )
    faces: list[tuple[int, ...]] = [tuple(range(7, -1, -1))]
    for section_index in range(len(sections) - 1):
        current = section_index * 8
        following = current + 8
        for side in range(8):
            next_side = (side + 1) % 8
            faces.append(
                (current + side, following + side, following + next_side, current + next_side)
            )
    end = (len(sections) - 1) * 8
    faces.append(tuple(end + index for index in range(8)))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish_mesh(obj, mat, 0.006)


def build_weapon() -> None:
    graphite = material("Graphite mechanism", (0.045, 0.055, 0.058, 1.0), 0.42, 0.62)
    ceramic = weathered_ceramic_material()
    steel = material("Dark brushed steel", (0.16, 0.19, 0.20, 1.0), 0.74, 0.40)
    mint = material(
        "Mint status channel",
        (0.025, 0.42, 0.32, 1.0),
        0.18,
        0.38,
        emission=(0.06, 0.92, 0.66, 1.0),
        emission_strength=3.0,
    )
    orange = material("Expedition orange index", (0.72, 0.19, 0.045, 1.0), 0.16, 0.6)

    static_parts: list[bpy.types.Object] = [
        loft(
            "Compact rear load frame",
            [
                (-0.52, 0.15, 0.015, 0.10),
                (-0.43, 0.20, 0.02, 0.135),
                (-0.13, 0.185, 0.02, 0.13),
                (0.06, 0.13, 0.01, 0.09),
            ],
            graphite,
            0.026,
        ),
        loft(
            "Left ceramic receiver shell",
            [
                (-0.48, 0.055, 0.045, 0.075),
                (-0.21, 0.072, 0.05, 0.09),
                (0.00, 0.045, 0.035, 0.06),
            ],
            ceramic,
            0.018,
        ),
        loft(
            "Right ceramic receiver shell",
            [
                (-0.46, 0.052, 0.035, 0.065),
                (-0.19, 0.066, 0.03, 0.078),
                (0.00, 0.04, 0.02, 0.052),
            ],
            ceramic,
            0.018,
        ),
        box(
            "Underslung grip core",
            (0.045, -0.33, -0.235),
            (0.13, 0.20, 0.29),
            graphite,
            0.026,
            rotation=(math.radians(-17.0), 0.0, math.radians(-3.0)),
        ),
        box(
            "Grip slate cheek",
            (0.05, -0.34, -0.245),
            (0.09, 0.13, 0.17),
            ceramic,
            0.018,
            rotation=(math.radians(-17.0), 0.0, math.radians(-3.0)),
        ),
        tapered_prism_between(
            "Lower brace",
            (0.02, -0.17, -0.10),
            (0.045, -0.37, -0.35),
            (0.06, 0.048),
            (0.72, 0.72),
            steel,
            0.012,
        ),
        box("Rear balance block", (-0.035, -0.57, 0.005), (0.24, 0.08, 0.11), steel, 0.018),
        box("Rear orange witness", (-0.09, -0.615, 0.03), (0.055, 0.014, 0.032), orange, 0.003),
        box("Left service shoulder", (-0.225, -0.23, 0.065), (0.045, 0.20, 0.12), ceramic, 0.012),
        box("Asymmetric sensor shoe", (-0.255, -0.045, 0.105), (0.055, 0.13, 0.06), steel, 0.008),
        box("Sensor orange index", (-0.285, -0.03, 0.116), (0.01, 0.055, 0.02), orange, 0.002),
    ]
    # Offset shell objects create a split housing with exposed mechanism between.
    static_parts[1].location.x = -0.12
    static_parts[2].location.x = 0.125

    motor = cylinder(
        "Exposed hex drive",
        (0.0, -0.035, 0.0),
        0.10,
        0.16,
        steel,
        vertices=8,
        bevel=0.008,
        rotation=(math.radians(90.0), 0.0, 0.0),
    )
    bearing = cylinder(
        "Graphite drive bearing",
        (0.0, 0.085, 0.0),
        0.125,
        0.045,
        graphite,
        vertices=12,
        bevel=0.006,
        rotation=(math.radians(90.0), 0.0, 0.0),
    )
    static_parts.extend([motor, bearing])

    rotor = bpy.data.objects.new("GatlingRotor", None)
    rotor.location = (0.0, 0.0, 0.0)
    bpy.context.collection.objects.link(rotor)
    rail_parts: list[bpy.types.Object] = []
    rail_layout = [
        ("Upper left accelerator", -0.16, 0.135, -0.008, 0.01),
        ("Upper right accelerator", 0.16, 0.135, 0.006, 0.0),
        ("Lower left accelerator", -0.17, -0.13, 0.004, -0.006),
        ("Lower right accelerator", 0.17, -0.13, -0.006, -0.004),
    ]
    for index, (name, x, z, front_x_offset, front_z_offset) in enumerate(rail_layout):
        rail = hex_rail(
            name,
            [
                (-0.06, x * 0.92, z * 0.92, 0.041, 0.033),
                (0.10, x, z, 0.045, 0.036),
                (0.78, x + front_x_offset * 0.5, z + front_z_offset * 0.5, 0.038, 0.031),
                (1.17, x + front_x_offset, z + front_z_offset, 0.032, 0.026),
            ],
            ceramic,
        )
        rail_parts.append(rail)
        shoe_x = x + front_x_offset
        shoe_z = z + front_z_offset
        rail_parts.append(
            box(
                f"Muzzle shoe {index + 1}",
                (shoe_x, 1.205, shoe_z),
                (0.075, 0.052, 0.06),
                steel,
                0.009,
            )
        )
        rail_parts.append(
            box(
                f"Rail root key {index + 1}",
                (x, 0.035, z),
                (0.08, 0.06, 0.066),
                graphite,
                0.009,
            )
        )

    # Small status traces and index marks keep energy color subordinate to form.
    rail_parts.extend(
        [
            box("Mint upper status trace", (0.161, 0.58, 0.174), (0.014, 0.48, 0.008), mint, 0.002),
            box("Mint muzzle ready mark", (0.165, 1.238, 0.136), (0.028, 0.01, 0.017), mint, 0.002),
            box("Orange rail phase index", (-0.17, 0.22, -0.169), (0.032, 0.06, 0.01), orange, 0.002),
            box("Upper muzzle tie", (0.0, 1.19, 0.184), (0.20, 0.028, 0.018), graphite, 0.003),
            box("Lower muzzle tie", (0.0, 1.19, -0.176), (0.19, 0.028, 0.016), graphite, 0.003),
        ]
    )

    muzzle_socket = bpy.data.objects.new("MuzzleSocket", None)
    muzzle_socket.location = (0.0, 1.275, 0.0)
    muzzle_socket.rotation_euler = (0.0, 0.0, 0.0)
    bpy.context.collection.objects.link(muzzle_socket)
    for part in rail_parts:
        parent_keep_transform(part, rotor)


def source_statistics() -> dict[str, int]:
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    return {
        "source_meshes": len(meshes),
        "source_vertices": sum(len(obj.data.vertices) for obj in meshes),
        "source_polygons": sum(len(obj.data.polygons) for obj in meshes),
        "source_materials": len(bpy.data.materials),
    }


def optimize_export_copy() -> None:
    """Bake modifiers and consolidate by articulated parent and material."""
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH":
            continue
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)

    groups: dict[tuple[str, str], list[bpy.types.Object]] = {}
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH" or not obj.data.materials:
            continue
        parent_name = obj.parent.name if obj.parent else "Unparented"
        material_name = obj.data.materials[0].name
        groups.setdefault((parent_name, material_name), []).append(obj)
    for (parent_name, material_name), objects in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        if len(objects) > 1:
            bpy.ops.object.join()
        objects[0].name = f"{parent_name}_{material_name}".replace(" ", "")


def glb_statistics(path: Path) -> dict[str, int]:
    with path.open("rb") as glb_file:
        magic, version, _length = struct.unpack("<4sII", glb_file.read(12))
        if magic != b"glTF" or version != 2:
            raise RuntimeError(f"Unexpected GLB header in {path}")
        json_length, json_type = struct.unpack("<II", glb_file.read(8))
        if json_type != 0x4E4F534A:
            raise RuntimeError(f"Missing GLB JSON chunk in {path}")
        document = json.loads(glb_file.read(json_length).decode("utf-8"))
    accessors = document.get("accessors", [])
    triangle_count = 0
    vertex_count = 0
    primitive_count = 0
    for mesh in document.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            primitive_count += 1
            position_accessor = primitive.get("attributes", {}).get("POSITION")
            if position_accessor is not None:
                vertex_count += int(accessors[position_accessor]["count"])
            index_accessor = primitive.get("indices")
            if index_accessor is not None:
                triangle_count += int(accessors[index_accessor]["count"]) // 3
            else:
                triangle_count += int(accessors[position_accessor]["count"]) // 3
    return {
        "runtime_bytes": path.stat().st_size,
        # Godot adds one identity scene root above the top-level glTF nodes.
        "runtime_nodes": len(document.get("nodes", [])) + 1,
        "runtime_meshes": len(document.get("meshes", [])),
        "runtime_primitives": primitive_count,
        "runtime_vertices": vertex_count,
        "runtime_triangles": triangle_count,
        "runtime_materials": len(document.get("materials", [])),
        "embedded_textures": len(document.get("textures", [])),
    }


def write_manifest(source_stats: dict[str, int], runtime_stats: dict[str, int]) -> None:
    statistics = {
        **source_stats,
        "source_bytes": SOURCE_PATH.stat().st_size,
        **runtime_stats,
    }
    manifest = {
        "asset_name": "Kestrel Rail Gatling",
        "category": "shared first- and third-person weapon presentation model",
        "status": "production gatling proxy replacement",
        "creator": "Project-local deterministic Blender generation",
        "source_url": None,
        "acquisition_date": "2026-08-05",
        "price_usd": 0,
        "license": "Original project work; no external asset dependencies",
        "commercial_use": True,
        "redistribution": "May be redistributed with the project and game exports",
        "attribution_required": False,
        "ai_generated_service": None,
        "generator": "tools/asset_pipeline/create_kestrel_gatling.py",
        "generator_command": "TMPDIR=\"$PWD/.tmp\" blender --background --python tools/asset_pipeline/create_kestrel_gatling.py",
        "source_files": [
            "tools/asset_pipeline/create_kestrel_gatling.py",
            "tools/asset_pipeline/blender_asset_utils.py",
            "assets/source/weapons/kestrel_rail_gatling.blend",
        ],
        "runtime_files": ["assets/models/weapons/kestrel_rail_gatling.glb"],
        "contract": {
            "root": "Identity Node3D import root",
            "articulation_node": "GatlingRotor",
            "presentation_socket": "MuzzleSocket",
            "orientation": "Identity root; Godot +Y up and -Z firing",
            "collision": "None; presentation only",
            "shared_usage": "The same GLB is instanced by WorldGatlingProxy and ViewGatlingProxy",
        },
        "design": [
            "Compact split rear housing, exposed hex drive, and underslung grip establish handheld scale.",
            "Four chamfered accelerator rails rotate around an open centerline and end in independent muzzle shoes.",
            "Graphite and dark steel mechanisms support weathered slate ceramic, minute mint status channels, and sparse expedition-orange indices.",
            "No roof prism, square facade/gate, conventional barrel, collision, downloaded asset, or external service is used.",
        ],
        "runtime_statistics": statistics,
        "runtime_sha256": hashlib.sha256(EXPORT_PATH.read_bytes()).hexdigest(),
        "budgets": {
            "maximum_runtime_triangles": 12000,
            "maximum_runtime_bytes": 1500000,
            "maximum_runtime_nodes": 20,
            "maximum_runtime_materials": 5,
        },
        "known_limitations": [
            "No hand mesh, skeletal grip pose, authored LODs, or collision are included.",
            "Ceramic wear is a compact generated packed texture rather than a hand-painted unique unwrap.",
        ],
    }
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="ascii")


def save_export_and_manifest() -> None:
    SOURCE_PATH.parent.mkdir(parents=True, exist_ok=True)
    EXPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    smart_uv_all()
    stats = source_statistics()
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_PATH))
    optimize_export_copy()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(EXPORT_PATH),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )
    runtime_stats = glb_statistics(EXPORT_PATH)
    write_manifest(stats, runtime_stats)
    print(f"Saved editable source: {SOURCE_PATH}")
    print(f"Exported runtime model: {EXPORT_PATH}")
    print(f"Wrote provenance manifest: {MANIFEST_PATH}")
    print(f"Runtime statistics: {runtime_stats}")


reset_scene()
build_weapon()
save_export_and_manifest()
