extends StaticBody3D

const ALPINE_TERRAIN_SHADER := preload("res://assets/materials/terrain/alpine_hardpack.gdshader")
const MapCatalog = preload("res://scripts/map_catalog.gd")

## Deterministic, single-mesh alpine basin. The same height function is used for
## rendering, collision, course placement, and out-of-bounds checks.

@export_category("Terrain")
@export var terrain_size: float = 512.0
@export_range(33, 257, 2) var resolution: int = 129
@export var height_scale: float = 1.0
@export var noise_seed: int = 73021
@export var consume_command_line_map := false

var map_id := MapCatalog.LEGACY_MAP_ID

var _broad_noise: FastNoiseLite
var _detail_noise: FastNoiseLite
var _mesh_instance: MeshInstance3D
var _collision_shape: CollisionShape3D
var _generated := false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	if consume_command_line_map:
		map_id = MapCatalog.selected_id_from_args()
	elif map_id.is_empty():
		map_id = MapCatalog.LEGACY_MAP_ID
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


func _elliptical(x: float, z: float, cx: float, cz: float, radius_x: float, radius_z: float) -> float:
	var normalized_x := (x - cx) / radius_x
	var normalized_z := (z - cz) / radius_z
	return exp(-(normalized_x * normalized_x + normalized_z * normalized_z))


func height_at(x: float, z: float) -> float:
	if map_id == "faultline_basin":
		return _faultline_height(x, z) * height_scale
	if map_id == "cairn_steps":
		return _cairn_steps_height(x, z) * height_scale
	return _kestrel_height(x, z) * height_scale


func _kestrel_height(x: float, z: float) -> float:
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
	return height


func _faultline_height(x: float, z: float) -> float:
	var mirrored_x := absf(x)
	var height := 4.0
	# Three continuous east-west landforms do the routing: open trench, exposed
	# basalt spine, and a gully hidden behind a lower screening shoulder.
	height -= _elliptical(x, z, 0.0, 0.0, 315.0, 38.0) * 11.5
	height += _elliptical(x, z, 0.0, -80.0, 286.0, 31.0) * 24.0
	height += _elliptical(x, z, 0.0, 54.0, 292.0, 19.0) * 14.0
	height -= _elliptical(x, z, 0.0, 103.0, 278.0, 30.0) * 12.5

	# Broad, mirrored launch shoulders and landing bowls create planned grade
	# changes without adding small collision chatter.
	height += _elliptical(mirrored_x, z, 225.0, -7.0, 42.0, 48.0) * 7.0
	height += _elliptical(mirrored_x, z, 182.0, -53.0, 50.0, 34.0) * 5.0
	height -= _elliptical(mirrored_x, z, 112.0, 2.0, 48.0, 42.0) * 4.5
	height -= _elliptical(mirrored_x, z, 132.0, 97.0, 55.0, 34.0) * 3.5
	height += sin(z * 0.052) * 0.8
	return height + _perimeter_rise(x, z)


func _cairn_steps_height(x: float, z: float) -> float:
	var mirrored_z := absf(z)
	var height := 3.5
	# A transverse central escarpment blocks the base-to-base view. Its three
	# crossings are separately authored rather than being rotated copies: a low
	# east chute, a bent west cut, and a shorter high-energy central saddle.
	height += _elliptical(x, z, 0.0, 0.0, 210.0, 49.0) * 29.0
	height -= _elliptical(x, z, 94.0, 0.0, 34.0, 73.0) * 22.0
	height -= _elliptical(x, z, 0.0, 0.0, 42.0, 58.0) * 10.0
	height += _elliptical(x, z, -48.0, 0.0, 31.0, 105.0) * 11.0

	var switchback_x := -112.0 + 40.0 * exp(-pow((mirrored_z - 72.0) / 35.0, 2.0))
	height -= exp(-pow((x - switchback_x) / 27.0, 2.0)) * exp(-pow(z / 139.0, 4.0)) * 17.0
	# Wide transverse steps provide anticipation and recoverable landings on both
	# approaches while keeping the high saddle visibly distinct from the chute.
	height += exp(-pow((mirrored_z - 112.0) / 31.0, 4.0)) * 5.5
	height += exp(-pow((mirrored_z - 174.0) / 36.0, 4.0)) * 3.0
	height += _elliptical(x, mirrored_z, 0.0, 218.0, 62.0, 39.0) * 4.0
	height += cos(x * 0.043) * 0.65
	return height + _perimeter_rise(x, z)


func boundary_ratio(x: float, z: float) -> float:
	var boundary := MapCatalog.get_map(map_id)["boundary"] as Dictionary
	var boundary_type := str(boundary["type"])
	if boundary_type == "capsule_x":
		var segment_half_length := float(boundary["segment_half_length"])
		var nearest_x := clampf(x, -segment_half_length, segment_half_length)
		return Vector2(x - nearest_x, z).length() / float(boundary["radius"])
	if boundary_type == "superellipse":
		var half_extents := boundary["half_extents"] as Vector2
		var exponent := float(boundary["exponent"])
		return pow(
			pow(absf(x) / half_extents.x, exponent) + pow(absf(z) / half_extents.y, exponent),
			1.0 / exponent
		)
	var half_extents := boundary["half_extents"] as Vector2
	return maxf(absf(x) / half_extents.x, absf(z) / half_extents.y)


func is_within_playable_boundary(position: Vector2) -> bool:
	return boundary_ratio(position.x, position.y) <= 1.0


func _perimeter_rise(x: float, z: float) -> float:
	var ratio := boundary_ratio(x, z)
	# Put the physical crest just inside the recovery line so terrain, rather
	# than an invisible teleport plane, stops ordinary skiing and jetting.
	var wall := smoothstep(0.80, 0.98, ratio) * 52.0
	return wall + smoothstep(0.98, 1.10, ratio) * 14.0


func get_mesh_size() -> Vector2:
	if map_id == MapCatalog.LEGACY_MAP_ID:
		return Vector2(terrain_size, terrain_size)
	return MapCatalog.get_map(map_id)["mesh_size"] as Vector2


func get_grid_resolution() -> Vector2i:
	if map_id == MapCatalog.LEGACY_MAP_ID:
		return Vector2i(resolution, resolution)
	return MapCatalog.get_map(map_id)["grid_resolution"] as Vector2i


func normal_at(x: float, z: float) -> Vector3:
	var mesh_size := get_mesh_size()
	var grid_resolution := get_grid_resolution()
	var x_step := mesh_size.x / float(grid_resolution.x - 1)
	var z_step := mesh_size.y / float(grid_resolution.y - 1)
	var dx := height_at(x + x_step, z) - height_at(x - x_step, z)
	var dz := height_at(x, z + z_step) - height_at(x, z - z_step)
	return Vector3(-dx / (x_step * 2.0), 1.0, -dz / (z_step * 2.0)).normalized()


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
	var mesh_size := get_mesh_size()
	var grid_resolution := get_grid_resolution()
	var x_step := mesh_size.x / float(grid_resolution.x - 1)
	var z_step := mesh_size.y / float(grid_resolution.y - 1)
	var half_size := mesh_size * 0.5
	vertices.resize(grid_resolution.x * grid_resolution.y)
	normals.resize(grid_resolution.x * grid_resolution.y)
	colors.resize(grid_resolution.x * grid_resolution.y)

	for z_index in grid_resolution.y:
		var z := -half_size.y + float(z_index) * z_step
		for x_index in grid_resolution.x:
			var x := -half_size.x + float(x_index) * x_step
			var vertex_index := z_index * grid_resolution.x + x_index
			var y := height_at(x, z)
			var normal := normal_at(x, z)
			vertices[vertex_index] = Vector3(x, y, z)
			normals[vertex_index] = normal
			colors[vertex_index] = _terrain_color(y, normal.y)

	for z_index in grid_resolution.y - 1:
		for x_index in grid_resolution.x - 1:
			var top_left := z_index * grid_resolution.x + x_index
			var bottom_left := top_left + grid_resolution.x
			# Godot treats clockwise triangles as front-facing. This winding makes
			# the generated surface (and its collision normals) face upward.
			if _uses_flipped_diagonal(x_index, z_index, grid_resolution):
				indices.append(top_left)
				indices.append(top_left + 1)
				indices.append(bottom_left + 1)
				indices.append(top_left)
				indices.append(bottom_left + 1)
				indices.append(bottom_left)
			else:
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
	_configure_material(material)
	terrain_mesh.surface_set_material(0, material)
	_mesh_instance.mesh = terrain_mesh
	_collision_shape.shape = terrain_mesh.create_trimesh_shape()


func _uses_flipped_diagonal(x_index: int, z_index: int, grid_resolution: Vector2i) -> bool:
	if map_id == "faultline_basin":
		return x_index >= (grid_resolution.x - 1) / 2
	if map_id == "cairn_steps":
		return z_index >= (grid_resolution.y - 1) / 2
	return false


func _configure_material(material: ShaderMaterial) -> void:
	var config := MapCatalog.get_map(map_id)
	var marking := config["route_marking"] as Dictionary
	var palette := config["palette"] as Dictionary
	material.set_shader_parameter("route_origin", marking["origin"])
	material.set_shader_parameter("route_axis", marking["axis"])
	material.set_shader_parameter("route_half_length", marking["half_length"])
	material.set_shader_parameter("route_width", marking["width"])
	material.set_shader_parameter("route_strength", marking["strength"])
	material.set_shader_parameter("contour_spacing", palette["contour_spacing"])
	material.set_shader_parameter("contour_strength", palette["contour_strength"])


func _terrain_color(height: float, normal_y: float) -> Color:
	var palette := MapCatalog.get_map(map_id)["palette"] as Dictionary
	var low := palette["low"] as Color
	var mid := palette["mid"] as Color
	var high := palette["high"] as Color
	var rock_low := palette["rock_low"] as Color
	var rock_high := palette["rock_high"] as Color
	var color := low.lerp(mid, smoothstep(-10.0, 15.0, height))
	color = color.lerp(high, smoothstep(18.0, 48.0, height))
	var steepness := smoothstep(0.92, 0.56, normal_y)
	var rock_color := rock_low.lerp(rock_high, smoothstep(10.0, 48.0, height))
	color = color.lerp(rock_color, steepness * 0.96)
	var contour_spacing := float(palette["contour_spacing"])
	var contour_band := int(floor((height + 96.0) / contour_spacing)) & 1
	return color.darkened(0.045 * contour_band)
