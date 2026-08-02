"""Build the Solar Nomad disc launcher and export a Godot-ready GLB.

Run from the repository root:
    blender --background --python tools/asset_pipeline/create_solar_nomad_launcher.py

The model uses only authored geometry and procedural materials, so it has no
external asset or texture dependencies.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

import bpy
from mathutils import Vector
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
SOURCE_PATH = ROOT / "assets/source/weapons/solar_nomad_disc_launcher.blend"
EXPORT_PATH = ROOT / "assets/models/weapons/solar_nomad_disc_launcher.glb"
DISC_EXPORT_PATH = ROOT / "assets/models/weapons/solar_nomad_disc.glb"
TEXTURE_DIR = ROOT / "assets/textures/weapons/solar_nomad"
TEXTURE_SIZE = 512


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials):
        # Materials are recreated below; clear orphaned data from repeat runs.
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def generate_surface_set(
    stem: str,
    base_rgb: tuple[int, int, int],
    roughness_value: int,
    style: str,
) -> dict[str, Path]:
    """Create deterministic subtle PBR maps; detail replaces noisy geometry."""
    TEXTURE_DIR.mkdir(parents=True, exist_ok=True)
    rng = random.Random(stem)
    size = TEXTURE_SIZE
    base = Image.new("RGB", (size, size))
    roughness = Image.new("L", (size, size))
    height = Image.new("L", (size, size), 128)
    base_pixels = base.load()
    roughness_pixels = roughness.load()
    height_pixels = height.load()
    for y in range(size):
        for x in range(size):
            grain = rng.gauss(0.0, 2.2)
            if style == "brushed":
                grain += math.sin(y * 0.36) * 2.0 + rng.gauss(0.0, 1.2)
            elif style == "graphite":
                grain += math.sin((x + y) * 0.09) * 1.3
            else:
                grain += math.sin(x * 0.025) * 0.7
            base_pixels[x, y] = tuple(
                max(0, min(255, round(channel + grain))) for channel in base_rgb
            )
            roughness_pixels[x, y] = max(
                0, min(255, round(roughness_value + grain * 2.2 + rng.gauss(0.0, 3.0)))
            )
            height_pixels[x, y] = max(0, min(255, round(128 + grain * 1.8)))

    # Sparse, shallow wear marks add material response without fake panel seams.
    height_draw = ImageDraw.Draw(height)
    roughness_draw = ImageDraw.Draw(roughness)
    mark_count = 18 if style != "ceramic" else 8
    for _index in range(mark_count):
        x = rng.randrange(0, size)
        y = rng.randrange(0, size)
        length = rng.randrange(18, 90)
        if style == "brushed":
            end = (min(size - 1, x + length), y + rng.randrange(-1, 2))
        else:
            end = (min(size - 1, x + length), min(size - 1, y + rng.randrange(-4, 5)))
        height_draw.line((x, y, *end), fill=116, width=1)
        roughness_draw.line((x, y, *end), fill=min(255, roughness_value + 28), width=1)
    height = height.filter(ImageFilter.GaussianBlur(radius=0.45))

    height_pixels = height.load()
    normal = Image.new("RGB", (size, size), (128, 128, 255))
    normal_pixels = normal.load()
    strength = 2.6
    for y in range(size):
        for x in range(size):
            left = height_pixels[(x - 1) % size, y]
            right = height_pixels[(x + 1) % size, y]
            down = height_pixels[x, (y - 1) % size]
            up = height_pixels[x, (y + 1) % size]
            dx = (right - left) / 255.0 * strength
            dy = (up - down) / 255.0 * strength
            nz = 1.0 / math.sqrt(dx * dx + dy * dy + 1.0)
            normal_pixels[x, y] = (
                round(((-dx * nz) * 0.5 + 0.5) * 255),
                round(((-dy * nz) * 0.5 + 0.5) * 255),
                round((nz * 0.5 + 0.5) * 255),
            )

    paths = {
        "base": TEXTURE_DIR / f"{stem}_base_color.png",
        "roughness": TEXTURE_DIR / f"{stem}_roughness.png",
        "normal": TEXTURE_DIR / f"{stem}_normal.png",
    }
    base.save(paths["base"])
    roughness.save(paths["roughness"])
    normal.save(paths["normal"])
    return paths


def add_texture_nodes(
    mat: bpy.types.Material,
    bsdf: bpy.types.Node,
    paths: dict[str, Path],
) -> None:
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    base_node = nodes.new("ShaderNodeTexImage")
    base_node.name = "Base color detail"
    base_node.image = bpy.data.images.load(str(paths["base"]), check_existing=True)
    links.new(base_node.outputs["Color"], bsdf.inputs["Base Color"])

    roughness_node = nodes.new("ShaderNodeTexImage")
    roughness_node.name = "Roughness detail"
    roughness_node.image = bpy.data.images.load(str(paths["roughness"]), check_existing=True)
    roughness_node.image.colorspace_settings.name = "Non-Color"
    links.new(roughness_node.outputs["Color"], bsdf.inputs["Roughness"])

    normal_texture = nodes.new("ShaderNodeTexImage")
    normal_texture.name = "Micro normal detail"
    normal_texture.image = bpy.data.images.load(str(paths["normal"]), check_existing=True)
    normal_texture.image.colorspace_settings.name = "Non-Color"
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 0.2
    links.new(normal_texture.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])


def material(
    name: str,
    color: tuple[float, float, float, float],
    metallic: float,
    roughness: float,
    emission: tuple[float, float, float, float] | None = None,
    emission_strength: float = 0.0,
    texture_paths: dict[str, Path] | None = None,
) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = emission
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    if texture_paths:
        add_texture_nodes(mat, bsdf, texture_paths)
    return mat


def finish_mesh(
    obj: bpy.types.Object,
    mat: bpy.types.Material,
    bevel: float = 0.012,
    smooth: bool = False,
) -> bpy.types.Object:
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = smooth
    if bevel > 0.0:
        modifier = obj.modifiers.new("Edge highlights", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
        modifier.limit_method = "ANGLE"
        normals = obj.modifiers.new("Clean weighted normals", "WEIGHTED_NORMAL")
        normals.keep_sharp = True
        normals.weight = 50
    return obj


def box(
    name: str,
    location: tuple[float, float, float],
    dimensions: tuple[float, float, float],
    mat: bpy.types.Material,
    bevel: float = 0.012,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish_mesh(obj, mat, bevel)


def cylinder(
    name: str,
    location: tuple[float, float, float],
    radius: float,
    depth: float,
    mat: bpy.types.Material,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    vertices: int = 32,
    bevel: float = 0.008,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    return finish_mesh(obj, mat, bevel, smooth=True)


def torus(
    name: str,
    location: tuple[float, float, float],
    major_radius: float,
    minor_radius: float,
    mat: bpy.types.Material,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(
        align="WORLD",
        major_segments=48,
        minor_segments=10,
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
    bevel: float = 0.012,
) -> bpy.types.Object:
    """Create a closed hard-surface body from (y, half_width, z_center, half_height)."""
    vertices: list[tuple[float, float, float]] = []
    for y, half_width, z_center, half_height in sections:
        vertices.extend(
            [
                (-half_width, y, z_center - half_height),
                (half_width, y, z_center - half_height),
                (half_width, y, z_center + half_height),
                (-half_width, y, z_center + half_height),
            ]
        )
    faces: list[tuple[int, ...]] = [(0, 3, 2, 1)]
    for index in range(len(sections) - 1):
        start = index * 4
        next_start = start + 4
        faces.extend(
            [
                (start, next_start, next_start + 3, start + 3),
                (start + 1, start + 2, next_start + 2, next_start + 1),
                (start + 3, next_start + 3, next_start + 2, start + 2),
                (start, start + 1, next_start + 1, next_start),
            ]
        )
    last = (len(sections) - 1) * 4
    faces.append((last, last + 1, last + 2, last + 3))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish_mesh(obj, mat, bevel)


def pipe(
    name: str,
    points: list[tuple[float, float, float]],
    radius: float,
    mat: bpy.types.Material,
) -> bpy.types.Object:
    curve = bpy.data.curves.new(f"{name}Curve", "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 2
    curve.bevel_depth = radius
    curve.bevel_resolution = 3
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for point, coordinate in zip(spline.bezier_points, points):
        point.co = coordinate
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def parent_keep_transform(obj: bpy.types.Object, parent: bpy.types.Object) -> None:
    bpy.context.view_layer.update()
    world_transform = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_parent_inverse = parent.matrix_world.inverted()
    obj.matrix_world = world_transform
    bpy.context.view_layer.update()


def build_launcher() -> None:
    TEXTURE_DIR.mkdir(parents=True, exist_ok=True)
    for old_texture in TEXTURE_DIR.glob("*.png"):
        old_texture.unlink()
    ceramic_maps = generate_surface_set("ceramic_ivory", (188, 199, 184), 68, "ceramic")
    gold_maps = generate_surface_set("solar_alloy", (214, 91, 18), 48, "brushed")
    ceramic = material(
        "Ceramic ivory", (0.74, 0.78, 0.72, 1.0), 0.18, 0.24, texture_paths=ceramic_maps
    )
    graphite = material("Graphite mechanism", (0.018, 0.026, 0.032, 1.0), 0.72, 0.23)
    gunmetal = material("Brushed gunmetal", (0.07, 0.10, 0.12, 1.0), 0.82, 0.19)
    gold = material(
        "Solar alloy", (0.88, 0.35, 0.055, 1.0), 0.78, 0.18,
        texture_paths=gold_maps,
    )
    energy = material(
        "Contained plasma",
        (0.01, 0.48, 0.58, 1.0),
        0.15,
        0.18,
        emission=(0.015, 0.9, 1.0, 1.0),
        emission_strength=7.0,
    )
    hot = material(
        "Solar charge",
        (1.0, 0.24, 0.025, 1.0),
        0.2,
        0.16,
        emission=(1.0, 0.055, 0.005, 1.0),
        emission_strength=4.5,
    )

    # A narrow mechanical spine and two simple ceramic shells replace the broad
    # slab from the first pass. The center gap exposes how the launcher works.
    loft(
        "Mechanical spine",
        [
            (-0.48, 0.145, -0.005, 0.13),
            (-0.20, 0.18, 0.01, 0.145),
            (0.28, 0.155, 0.015, 0.125),
            (0.84, 0.08, 0.01, 0.075),
            (1.03, 0.06, 0.005, 0.055),
        ],
        graphite,
        0.018,
    )
    for side in (-1.0, 1.0):
        shell = loft(
            f"Ceramic receiver shell {side:+.0f}",
            [
                (-0.40, 0.065, 0.125, 0.045),
                (-0.08, 0.078, 0.15, 0.052),
                (0.34, 0.06, 0.125, 0.04),
                (0.68, 0.04, 0.095, 0.028),
            ],
            ceramic,
            0.016,
        )
        shell.location.x = side * 0.105

    # Split forward rails create an unmistakable forked silhouette around the muzzle.
    for side in (-1.0, 1.0):
        loft(
            f"Ceramic accelerator rail {side:+.0f}",
            [
                (0.14, 0.045, 0.06, 0.055),
                (0.58, 0.055, 0.07, 0.05),
                (1.02, 0.035, 0.045, 0.04),
            ],
            ceramic,
            0.01,
        ).location.x = side * 0.16
        box(
            f"Gold rail inlay {side:+.0f}",
            (side * 0.159, 0.55, 0.127),
            (0.026, 0.61, 0.018),
            gold,
            0.004,
        )
        cylinder(
            f"Muzzle prong {side:+.0f}",
            (side * 0.16, 0.95, 0.04),
            0.052,
            0.23,
            gunmetal,
            rotation=(math.radians(90.0), 0.0, 0.0),
            vertices=24,
            bevel=0.006,
        )

    # The ammunition is now a distinct removable disc held above a compact
    # receiver by three functional clamps rather than a decorative platter.
    seat_center = Vector((-0.04, -0.13, 0.245))
    disc_center = Vector((-0.04, -0.13, 0.283))
    rotor_parts: list[bpy.types.Object] = []
    charge_parts: list[bpy.types.Object] = []
    rotor_parts.append(
        cylinder("Disc receiver", tuple(seat_center), 0.145, 0.038, graphite, vertices=40)
    )
    charge_parts.append(
        torus("Seated disc rim", tuple(disc_center), 0.105, 0.016, graphite)
    )
    charge_parts.append(
        cylinder(
            "Charged disc face",
            tuple(disc_center + Vector((0.0, 0.0, 0.004))),
            0.088,
            0.014,
            hot,
            vertices=48,
            bevel=0.002,
        )
    )
    charge_parts.append(
        torus(
            "Plasma containment ring",
            tuple(disc_center + Vector((0.0, 0.0, 0.012))),
            0.058,
            0.008,
            energy,
        )
    )
    rotor_parts.append(
        cylinder(
            "Rotor spindle",
            tuple(disc_center + Vector((0.0, 0.0, -0.01))),
            0.023,
            0.06,
            gunmetal,
            vertices=24,
        )
    )
    for clamp_index, angle_degrees in enumerate((25.0, 155.0, 265.0)):
        angle = math.radians(angle_degrees)
        clamp_position = disc_center + Vector((math.cos(angle) * 0.126, math.sin(angle) * 0.126, -0.006))
        rotor_parts.append(
            box(
                f"Disc clamp {clamp_index + 1}",
                tuple(clamp_position),
                (0.052, 0.032, 0.045),
                gold,
                0.006,
                rotation=(0.0, 0.0, angle),
            )
        )

    # A single plasma path replaces the former rows of mechanical surface detail.
    pipe(
        "Visible plasma conduit",
        [(-0.04, -0.03, 0.27), (0.0, 0.22, 0.19), (0.0, 0.58, 0.14), (0.0, 0.93, 0.07)],
        0.014,
        energy,
    )
    cylinder(
        "Muzzle energy lens",
        (0.0, 1.075, 0.04),
        0.064,
        0.022,
        energy,
        rotation=(math.radians(90.0), 0.0, 0.0),
        vertices=32,
        bevel=0.002,
    )
    torus(
        "Muzzle shroud",
        (0.0, 1.055, 0.04),
        0.08,
        0.018,
        gold,
        rotation=(math.radians(90.0), 0.0, 0.0),
    )

    # Angled grip, trigger guard, and rear counterweight complete the handled-tool read.
    box(
        "Grip core",
        (0.065, -0.24, -0.255),
        (0.145, 0.19, 0.43),
        graphite,
        0.025,
        rotation=(math.radians(-13.0), 0.0, math.radians(-4.0)),
    )
    box(
        "Grip ceramic face",
        (0.064, -0.267, -0.268),
        (0.105, 0.205, 0.29),
        ceramic,
        0.018,
        rotation=(math.radians(-13.0), 0.0, math.radians(-4.0)),
    )
    pipe(
        "Trigger guard",
        [(-0.04, -0.12, -0.10), (-0.04, 0.01, -0.20), (-0.04, -0.11, -0.29)],
        0.014,
        gold,
    )
    box("Rear counterweight", (0.0, -0.49, 0.0), (0.29, 0.16, 0.18), gunmetal, 0.025)
    box("Rear solar cap", (0.0, -0.585, 0.02), (0.22, 0.045, 0.12), gold, 0.01)

    # Export hierarchy is also the runtime animation contract.
    root = bpy.data.objects.new("SolarNomadDiscLauncher", None)
    bpy.context.collection.objects.link(root)
    rotor = bpy.data.objects.new("DiscRotor", None)
    rotor.location = tuple(seat_center)
    bpy.context.collection.objects.link(rotor)
    rotor.parent = root
    charge_core = bpy.data.objects.new("ChargeCore", None)
    charge_core.location = tuple(disc_center)
    bpy.context.collection.objects.link(charge_core)
    parent_keep_transform(charge_core, rotor)
    for obj in rotor_parts:
        parent_keep_transform(obj, rotor)
    for obj in charge_parts:
        parent_keep_transform(obj, charge_core)

    muzzle_socket = bpy.data.objects.new("MuzzleSocket", None)
    muzzle_socket.location = (0.0, 1.13, 0.04)
    bpy.context.collection.objects.link(muzzle_socket)
    muzzle_socket.parent = root
    for obj in list(bpy.context.scene.objects):
        if obj not in {root, rotor, charge_core, muzzle_socket} and obj.parent is None:
            obj.parent = root


def ensure_uvs() -> None:
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.025)
        bpy.ops.object.mode_set(mode="OBJECT")


def optimize_export_copy() -> None:
    """Bake modifiers and consolidate static parts into one draw surface per material.

    This runs only after the editable .blend is saved, so the source retains its
    named construction parts and non-destructive bevel modifiers.
    """
    for obj in list(bpy.context.scene.objects):
        if obj.type not in {"MESH", "CURVE"}:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        if obj.type == "CURVE":
            bpy.ops.object.convert(target="MESH")
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)

    groups: dict[tuple[str, str], list[bpy.types.Object]] = {}
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH" or not obj.data.materials:
            continue
        parent_name = obj.parent.name if obj.parent else "Static"
        groups.setdefault((parent_name, obj.data.materials[0].name), []).append(obj)
    for (parent_name, material_name), objects in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        if len(objects) > 1:
            bpy.ops.object.join()
        compact_material_name = material_name.replace(" ", "")
        objects[0].name = f"{parent_name}_{compact_material_name}"


def export_disc_copy() -> None:
    """Export the seated charge geometry as the projectile's shared visual."""
    charge_core = bpy.data.objects.get("ChargeCore")
    if charge_core is None:
        raise RuntimeError("ChargeCore export group is missing")
    export_root = bpy.data.objects.new("SolarNomadDisc", None)
    bpy.context.collection.objects.link(export_root)
    seat_origin = Vector((-0.04, -0.13, 0.283))
    duplicates: list[bpy.types.Object] = []
    bpy.context.view_layer.update()
    for source in charge_core.children:
        if source.type != "MESH":
            continue
        duplicate = source.copy()
        duplicate.data = source.data.copy()
        duplicate.parent = export_root
        duplicate.matrix_world = source.matrix_world.copy()
        duplicate.matrix_world.translation -= seat_origin
        bpy.context.collection.objects.link(duplicate)
        duplicates.append(duplicate)
    bpy.ops.object.select_all(action="DESELECT")
    export_root.select_set(True)
    for duplicate in duplicates:
        duplicate.select_set(True)
    bpy.context.view_layer.objects.active = export_root
    bpy.ops.export_scene.gltf(
        filepath=str(DISC_EXPORT_PATH),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )
    bpy.data.objects.remove(export_root, do_unlink=True)
    for duplicate in duplicates:
        if duplicate.name in bpy.data.objects:
            bpy.data.objects.remove(duplicate, do_unlink=True)


def save_and_export() -> None:
    SOURCE_PATH.parent.mkdir(parents=True, exist_ok=True)
    EXPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    ensure_uvs()
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
    export_disc_copy()
    print(f"Saved editable source: {SOURCE_PATH}")
    print(f"Exported optimized runtime model: {EXPORT_PATH}")
    print(f"Exported shared disc visual: {DISC_EXPORT_PATH}")


reset_scene()
build_launcher()
save_and_export()
