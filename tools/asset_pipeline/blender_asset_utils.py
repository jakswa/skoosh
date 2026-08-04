"""Small reusable Blender helpers for repository-authored hard-surface assets.

This module deliberately handles construction/export mechanics, not art direction.
Asset generators should keep their dimensions, materials, hierarchy, and concept
in their own file.
"""

from __future__ import annotations

from pathlib import Path

import bpy
from mathutils import Euler, Vector


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (
        bpy.data.meshes,
        bpy.data.curves,
        bpy.data.materials,
        bpy.data.armatures,
        bpy.data.actions,
    ):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def material(
    name: str,
    color: tuple[float, float, float, float],
    metallic: float = 0.0,
    roughness: float = 0.7,
    emission: tuple[float, float, float, float] | None = None,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    result = bpy.data.materials.new(name)
    result.diffuse_color = color
    result.use_nodes = True
    bsdf = result.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = emission
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return result


def finish_mesh(
    obj: bpy.types.Object,
    mat: bpy.types.Material,
    bevel: float = 0.08,
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
    bevel: float = 0.08,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish_mesh(obj, mat, bevel)


def _mesh_object(
    name: str,
    vertices: list[tuple[float, float, float]],
    faces: list[tuple[int, ...]],
    location: tuple[float, float, float],
    rotation: tuple[float, float, float],
) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = Euler(rotation, "XYZ")
    return obj


def tapered_prism(
    name: str,
    location: tuple[float, float, float],
    dimensions: tuple[float, float, float],
    top_scale: tuple[float, float],
    mat: bpy.types.Material,
    bevel: float = 0.04,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    """Create a vertically tapered eight-vertex hard-surface prism."""
    width, depth, height = dimensions
    bottom_x, bottom_y = width * 0.5, depth * 0.5
    top_x, top_y = bottom_x * top_scale[0], bottom_y * top_scale[1]
    z0, z1 = -height * 0.5, height * 0.5
    vertices = [
        (-bottom_x, -bottom_y, z0),
        (bottom_x, -bottom_y, z0),
        (bottom_x, bottom_y, z0),
        (-bottom_x, bottom_y, z0),
        (-top_x, -top_y, z1),
        (top_x, -top_y, z1),
        (top_x, top_y, z1),
        (-top_x, top_y, z1),
    ]
    faces = [
        (0, 3, 2, 1),
        (4, 5, 6, 7),
        (0, 1, 5, 4),
        (1, 2, 6, 5),
        (2, 3, 7, 6),
        (3, 0, 4, 7),
    ]
    return finish_mesh(
        _mesh_object(name, vertices, faces, location, rotation), mat, bevel
    )


def profile_prism(
    name: str,
    location: tuple[float, float, float],
    half_width: float,
    yz_profile: list[tuple[float, float]],
    mat: bpy.types.Material,
    bevel: float = 0.035,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    """Extrude a closed Y/Z profile across X for wedges and stabilizers."""
    count = len(yz_profile)
    vertices = [(-half_width, y, z) for y, z in yz_profile]
    vertices.extend((half_width, y, z) for y, z in yz_profile)
    faces: list[tuple[int, ...]] = [tuple(range(count - 1, -1, -1))]
    faces.append(tuple(range(count, count * 2)))
    for index in range(count):
        following = (index + 1) % count
        faces.append((index, following, count + following, count + index))
    return finish_mesh(
        _mesh_object(name, vertices, faces, location, rotation), mat, bevel
    )


def panel_prism(
    name: str,
    location: tuple[float, float, float],
    xy_outline: list[tuple[float, float]],
    thickness: float,
    mat: bpy.types.Material,
    bevel: float = 0.025,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    """Extrude an X/Y outline through Z for delta and aerofoil panels."""
    count = len(xy_outline)
    z0, z1 = -thickness * 0.5, thickness * 0.5
    vertices = [(x, y, z0) for x, y in xy_outline]
    vertices.extend((x, y, z1) for x, y in xy_outline)
    faces: list[tuple[int, ...]] = [tuple(range(count - 1, -1, -1))]
    faces.append(tuple(range(count, count * 2)))
    for index in range(count):
        following = (index + 1) % count
        faces.append((index, following, count + following, count + index))
    return finish_mesh(
        _mesh_object(name, vertices, faces, location, rotation), mat, bevel
    )


def front_panel_prism(
    name: str,
    location: tuple[float, float, float],
    xz_outline: list[tuple[float, float]],
    depth: float,
    mat: bpy.types.Material,
    bevel: float = 0.025,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    """Extrude an X/Z outline through Y for readable frontal contours."""
    count = len(xz_outline)
    y0, y1 = -depth * 0.5, depth * 0.5
    vertices = [(x, y0, z) for x, z in xz_outline]
    vertices.extend((x, y1, z) for x, z in xz_outline)
    faces: list[tuple[int, ...]] = [tuple(range(count - 1, -1, -1))]
    faces.append(tuple(range(count, count * 2)))
    for index in range(count):
        following = (index + 1) % count
        faces.append((index, following, count + following, count + index))
    return finish_mesh(
        _mesh_object(name, vertices, faces, location, rotation), mat, bevel
    )


def tapered_prism_between(
    name: str,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    width_depth: tuple[float, float],
    top_scale: tuple[float, float],
    mat: bpy.types.Material,
    bevel: float = 0.03,
    overlap: float = 0.04,
) -> bpy.types.Object:
    """Create a tapered limb or strut aligned between two world-space points."""
    start_vector = Vector(start)
    end_vector = Vector(end)
    direction = end_vector - start_vector
    length = direction.length + overlap
    midpoint = (start_vector + end_vector) * 0.5
    rotation = direction.to_track_quat("Z", "Y").to_euler("XYZ")
    return tapered_prism(
        name,
        tuple(midpoint),
        (width_depth[0], width_depth[1], length),
        top_scale,
        mat,
        bevel,
        tuple(rotation),
    )


def rectangular_duct(
    name: str,
    location: tuple[float, float, float],
    outer_size: tuple[float, float],
    depth: float,
    wall: float,
    mat: bpy.types.Material,
    bevel: float = 0.025,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    """Create a hollow rectangular Y-axis duct with readable negative space."""
    outer_x, outer_z = outer_size[0] * 0.5, outer_size[1] * 0.5
    inner_x, inner_z = outer_x - wall, outer_z - wall
    if inner_x <= 0.0 or inner_z <= 0.0:
        raise ValueError("Duct wall must leave a positive aperture")
    y0, y1 = -depth * 0.5, depth * 0.5
    vertices: list[tuple[float, float, float]] = []
    for y in (y0, y1):
        vertices.extend(
            [
                (-outer_x, y, -outer_z),
                (outer_x, y, -outer_z),
                (outer_x, y, outer_z),
                (-outer_x, y, outer_z),
                (-inner_x, y, -inner_z),
                (inner_x, y, -inner_z),
                (inner_x, y, inner_z),
                (-inner_x, y, inner_z),
            ]
        )
    faces: list[tuple[int, ...]] = []
    for offset, reverse in ((0, False), (8, True)):
        rings = [
            (0, 1, 5, 4),
            (1, 2, 6, 5),
            (2, 3, 7, 6),
            (3, 0, 4, 7),
        ]
        faces.extend(
            tuple(offset + index for index in (reversed(face) if reverse else face))
            for face in rings
        )
    for ring_start in (0, 4):
        for index in range(4):
            following = (index + 1) % 4
            a, b = ring_start + index, ring_start + following
            faces.append((a, a + 8, b + 8, b))
    return finish_mesh(
        _mesh_object(name, vertices, faces, location, rotation), mat, bevel
    )


def cylinder(
    name: str,
    location: tuple[float, float, float],
    radius: float,
    depth: float,
    mat: bpy.types.Material,
    vertices: int = 24,
    bevel: float = 0.05,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
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


def parent_keep_transform(obj: bpy.types.Object, parent: bpy.types.Object) -> None:
    bpy.context.view_layer.update()
    world = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_parent_inverse = parent.matrix_world.inverted()
    obj.matrix_world = world


def smart_uv_all(angle_limit_degrees: float = 66.0, island_margin: float = 0.025) -> None:
    import math

    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(
            angle_limit=math.radians(angle_limit_degrees), island_margin=island_margin
        )
        bpy.ops.object.mode_set(mode="OBJECT")


def consolidate_static_meshes_by_material() -> None:
    """Apply modifiers and reduce a static export to one mesh per material."""
    groups: dict[str, list[bpy.types.Object]] = {}
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH":
            continue
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        material_name = obj.data.materials[0].name if obj.data.materials else "Unassigned"
        groups.setdefault(material_name, []).append(obj)
    for material_name, objects in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        if len(objects) > 1:
            bpy.ops.object.join()
        objects[0].name = material_name.replace(" ", "")


def save_and_export(
    source_path: Path,
    export_path: Path,
    consolidate_static: bool = False,
) -> None:
    source_path.parent.mkdir(parents=True, exist_ok=True)
    export_path.parent.mkdir(parents=True, exist_ok=True)
    smart_uv_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(source_path))
    if consolidate_static:
        consolidate_static_meshes_by_material()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(export_path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )
