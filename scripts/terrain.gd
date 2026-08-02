extends StaticBody3D

const ALPINE_TERRAIN_SHADER := preload("res://assets/materials/terrain/alpine_hardpack.gdshader")

## Deterministic, single-mesh alpine basin. The same height function is used for
## rendering, collision, course placement, and out-of-bounds checks.

@export_category("Terrain")
@export var terrain_size: float = 512.0
@export_range(33, 257, 2) var resolution: int = 129
@export var height_scale: float = 1.0
@export var noise_seed: int = 73021

var _broad_noise: FastNoiseLite
var _detail_noise: FastNoiseLite
var _mesh_instance: MeshInstance3D
var _collision_shape: CollisionShape3D
var _generated := false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	generate()


func _configure_noise() -> void:
	if _broad_noise != null:
		return
	_broad_noise = FastNoiseLite.new()
	_broad_noise.seed = noise_seed
	_broad_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_broad_noise.frequency = 0.0065
	_broad_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_broad_noise.fractal_octaves = 3
	_broad_noise.fractal_gain = 0.48
	_broad_noise.fractal_lacunarity = 1.9

	_detail_noise = FastNoiseLite.new()
	_detail_noise.seed = noise_seed + 991
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail_noise.frequency = 0.021
	_detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_detail_noise.fractal_octaves = 2
	_detail_noise.fractal_gain = 0.4


func _gaussian(x: float, z: float, cx: float, cz: float, radius: float) -> float:
	var distance_squared := (x - cx) * (x - cx) + (z - cz) * (z - cz)
	return exp(-distance_squared / (radius * radius))


func height_at(x: float, z: float) -> float:
	_configure_noise()
	var height := 3.0
	height += _broad_noise.get_noise_2d(x, z) * 13.0
	height += _detail_noise.get_noise_2d(x, z) * 2.2
	height += sin(z * 0.024 + sin(x * 0.011) * 1.2) * 4.5
	height += sin((x + z) * 0.014) * 3.0

	# Broad authored shapes create the opening dive, jet crest, landing bowl,
	# and final descent without introducing collision chatter.
	height += _gaussian(x, z, 0.0, -215.0, 58.0) * 23.0
	height -= _gaussian(x, z, -22.0, -126.0, 74.0) * 13.0
	height += _gaussian(x, z, 35.0, 54.0, 57.0) * 14.0
	height -= _gaussian(x, z, 58.0, 112.0, 54.0) * 12.0
	height += _gaussian(x, z, 21.0, 154.0, 42.0) * 8.0
	height -= _gaussian(x, z, 0.0, 197.0, 49.0) * 7.0

	# Blend a clean launch lane through the opening ridge. It gives a new player
	# an immediately readable fall line before the course begins to turn.
	var lane_across: float = exp(-pow(absf(x) / 38.0, 4.0))
	var lane_along: float = smoothstep(-242.0, -225.0, z) * (1.0 - smoothstep(-155.0, -140.0, z))
	var lane_height: float = 27.0 - (z + 218.0) * 0.36 + x * x * 0.0015
	height = lerpf(height, lane_height, lane_across * lane_along)

	# A smooth raised rim contains the play space while leaving the route clear.
	var edge: float = maxf(absf(x), absf(z))
	if edge > 214.0:
		var rim_t: float = clampf((edge - 214.0) / 42.0, 0.0, 1.0)
		rim_t = rim_t * rim_t * (3.0 - 2.0 * rim_t)
		height += rim_t * 42.0
	return height * height_scale


func normal_at(x: float, z: float) -> Vector3:
	var sample_step := terrain_size / float(resolution - 1)
	var dx := height_at(x + sample_step, z) - height_at(x - sample_step, z)
	var dz := height_at(x, z + sample_step) - height_at(x, z - sample_step)
	return Vector3(-dx / (sample_step * 2.0), 1.0, -dz / (sample_step * 2.0)).normalized()


func generate() -> void:
	if _generated:
		return
	_configure_noise()
	_generated = true

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "TerrainMesh"
	add_child(_mesh_instance)
	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "TerrainCollision"
	add_child(_collision_shape)

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var step := terrain_size / float(resolution - 1)
	var half_size := terrain_size * 0.5
	vertices.resize(resolution * resolution)
	normals.resize(resolution * resolution)
	colors.resize(resolution * resolution)

	for z_index in resolution:
		var z := -half_size + float(z_index) * step
		for x_index in resolution:
			var x := -half_size + float(x_index) * step
			var vertex_index := z_index * resolution + x_index
			var y := height_at(x, z)
			var normal := normal_at(x, z)
			vertices[vertex_index] = Vector3(x, y, z)
			normals[vertex_index] = normal
			colors[vertex_index] = _terrain_color(y, normal.y)

	for z_index in resolution - 1:
		for x_index in resolution - 1:
			var top_left := z_index * resolution + x_index
			var bottom_left := top_left + resolution
			# Godot treats clockwise triangles as front-facing. This winding makes
			# the generated surface (and its collision normals) face upward.
			indices.append(top_left)
			indices.append(top_left + 1)
			indices.append(bottom_left)
			indices.append(top_left + 1)
			indices.append(bottom_left + 1)
			indices.append(bottom_left)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var terrain_mesh := ArrayMesh.new()
	terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material := ShaderMaterial.new()
	material.shader = ALPINE_TERRAIN_SHADER
	terrain_mesh.surface_set_material(0, material)
	_mesh_instance.mesh = terrain_mesh
	_collision_shape.shape = terrain_mesh.create_trimesh_shape()


func _terrain_color(height: float, normal_y: float) -> Color:
	var basin_ice := Color("#a8b8bd")
	var hardpack := Color("#c6d2d3")
	var sun_crust := Color("#d8dfdd")
	var slate := Color("#262e32")
	var high_slate := Color("#41484a")
	var color := basin_ice.lerp(hardpack, smoothstep(-8.0, 15.0, height))
	color = color.lerp(sun_crust, smoothstep(18.0, 43.0, height))
	var steepness := smoothstep(0.92, 0.56, normal_y)
	var rock_color := slate.lerp(high_slate, smoothstep(12.0, 42.0, height))
	color = color.lerp(rock_color, steepness * 0.96)
	# Tight elevation strata expose grade changes before a skier reaches them.
	var contour_band := int(floor((height + 64.0) / 3.25)) & 1
	return color.darkened(0.045 * contour_band)
