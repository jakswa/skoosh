extends SceneTree

const MapCatalog = preload("res://scripts/map_catalog.gd")
const TerrainScript = preload("res://scripts/terrain.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_require(MapCatalog.DEFAULT_MAP_ID == "kestrel_basin", "Unexpected default map")
	_require(MapCatalog.MAP_IDS.size() == 3, "Map allowlist size changed")
	var default_terrain = TerrainScript.new()
	_require(default_terrain.map_id == "kestrel_basin", "Terrain no longer defaults explicitly to Kestrel")
	_require(not default_terrain.consume_command_line_map, "Generic terrain unexpectedly consumes multiplayer CLI maps")
	default_terrain.free()
	var signatures: Dictionary = {}
	for map_id: String in MapCatalog.MAP_IDS:
		var config := MapCatalog.get_map(map_id)
		_require(not config.is_empty(), "%s has no catalog data" % map_id)
		var terrain = TerrainScript.new()
		terrain.map_id = map_id
		_require(is_equal_approx(terrain.terrain_size, 512.0), "%s terrain is not 512m" % map_id)
		_require(terrain.resolution == 129, "%s terrain resolution is not 129" % map_id)
		_validate_samples(map_id, config, terrain)
		_validate_mirrored_grid(map_id, config, terrain)
		_validate_match_contract(map_id, config, terrain)
		terrain.generate()
		_validate_generated_mesh(map_id, terrain)
		signatures[map_id] = _terrain_signature(terrain)
		terrain.free()

	for left_index in MapCatalog.MAP_IDS.size():
		for right_index in range(left_index + 1, MapCatalog.MAP_IDS.size()):
			var left_id: String = MapCatalog.MAP_IDS[left_index]
			var right_id: String = MapCatalog.MAP_IDS[right_index]
			var distance := _signature_distance(signatures[left_id], signatures[right_id])
			_require(distance > 8.0, "%s and %s terrain profiles are not distinct" % [left_id, right_id])

	if _failed:
		quit(1)
		return
	print("ACCEPT competitive map catalog, symmetry, terrain mesh, homes, spawns, and routes")
	quit(0)


func _validate_samples(map_id: String, config: Dictionary, terrain: Node) -> void:
	const SAMPLES: Array[Vector2] = [
		Vector2(17.0, -91.0), Vector2(83.0, 45.0), Vector2(151.0, 3.0),
		Vector2(-117.0, 106.0), Vector2(0.0, 0.0),
	]
	for sample in SAMPLES:
		var height: float = terrain.height_at(sample.x, sample.y)
		var normal: Vector3 = terrain.normal_at(sample.x, sample.y)
		_require(is_finite(height), "%s has a non-finite height at %s" % [map_id, sample])
		_require(
			is_finite(normal.x) and is_finite(normal.y) and is_finite(normal.z),
			"%s has a non-finite normal at %s" % [map_id, sample]
		)
		_require(normal.y > 0.0, "%s has a downward terrain normal at %s" % [map_id, sample])
		var axis := str(config["symmetry_axis"])
		if axis == "x":
			_require(
				is_equal_approx(height, terrain.height_at(-sample.x, sample.y)),
				"%s is not mirrored across X at %s" % [map_id, sample]
			)
		elif axis == "z":
			_require(
				is_equal_approx(height, terrain.height_at(sample.x, -sample.y)),
				"%s is not mirrored across Z at %s" % [map_id, sample]
			)


func _validate_mirrored_grid(map_id: String, config: Dictionary, terrain: Node) -> void:
	var axis := str(config["symmetry_axis"])
	if axis == "none":
		return
	var step: float = terrain.terrain_size / float(terrain.resolution - 1)
	var half_size: float = terrain.terrain_size * 0.5
	for z_index in terrain.resolution:
		var z := -half_size + float(z_index) * step
		for x_index in terrain.resolution:
			var x := -half_size + float(x_index) * step
			var mirrored := Vector2(-x, z) if axis == "x" else Vector2(x, -z)
			var height: float = terrain.height_at(x, z)
			var mirrored_height: float = terrain.height_at(mirrored.x, mirrored.y)
			if not is_finite(height) or not is_equal_approx(height, mirrored_height):
				_require(false, "%s grid height mismatch at (%d,%d)" % [map_id, x_index, z_index])
				return
			var normal: Vector3 = terrain.normal_at(x, z)
			var mirrored_normal: Vector3 = terrain.normal_at(mirrored.x, mirrored.y)
			var expected := Vector3(-normal.x, normal.y, normal.z)
			if axis == "z":
				expected = Vector3(normal.x, normal.y, -normal.z)
			if (
				not is_finite(normal.x) or not is_finite(normal.y) or not is_finite(normal.z)
				or not expected.is_equal_approx(mirrored_normal)
			):
				_require(false, "%s grid normal mismatch at (%d,%d)" % [map_id, x_index, z_index])
				return


func _validate_match_contract(map_id: String, config: Dictionary, terrain: Node) -> void:
	var bases := config["base_centers"] as Array
	var oob := config["oob_half_extents"] as Vector2
	var clearance := float(config["platform_clearance"])
	var surfaces: Array[float] = []
	for base_variant in bases:
		var base := base_variant as Vector2
		if map_id != MapCatalog.DEFAULT_MAP_ID:
			_require(_is_grid_aligned(base, terrain), "%s base is off the collision grid" % map_id)
		var surface: float = terrain.height_at(base.x, base.y) + clearance
		surfaces.append(surface)
		_require(absf(base.x) < oob.x and absf(base.y) < oob.y, "%s base is outside OOB" % map_id)
		_require(
			is_equal_approx(surface - terrain.height_at(base.x, base.y), clearance),
			"%s platform does not use its configured clearance" % map_id
		)
		if map_id != MapCatalog.DEFAULT_MAP_ID:
			_require(is_equal_approx(clearance, 2.0), "%s platform can leave a player-height undercroft" % map_id)
	if bool(config["shared_platform_elevation"]):
		var shared_surface := maxf(surfaces[0], surfaces[1])
		surfaces[0] = shared_surface
		surfaces[1] = shared_surface
	if str(config["symmetry_axis"]) != "none":
		_require(is_equal_approx(surfaces[0], surfaces[1]), "%s platform surfaces are asymmetric" % map_id)

	var teams := config["spawn_sockets"] as Array
	for team in teams.size():
		var flag := bases[team] as Vector2
		var sockets := teams[team] as Array
		_require(sockets.size() >= 3, "%s team %d lacks spawn sockets" % [map_id, team])
		for socket_variant in sockets:
			var socket := socket_variant as Dictionary
			var position := socket["position"] as Vector2
			var direction := socket["direction"] as Vector2
			_require(absf(position.x) < oob.x and absf(position.y) < oob.y, "%s spawn is outside OOB" % map_id)
			if map_id != MapCatalog.DEFAULT_MAP_ID:
				_require(_is_grid_aligned(position, terrain), "%s spawn is off the collision grid" % map_id)
			_require(direction.length() > 0.9, "%s spawn has no facing direction" % map_id)
			var spawn_y: float = surfaces[team] if bool(socket["on_platform"]) else terrain.height_at(position.x, position.y)
			var flag_y: float = surfaces[team] + 1.08
			var separation := Vector3(position.x - flag.x, spawn_y + 0.08 - flag_y, position.y - flag.y).length()
			_require(separation > 0.75, "%s spawn overlaps its flag" % map_id)
			if map_id != MapCatalog.DEFAULT_MAP_ID:
				_require(position.distance_to(flag) >= 20.0, "%s competitive spawn is too close to its flag" % map_id)
				_require(direction.dot(-position) > 0.0, "%s competitive spawn does not face inward" % map_id)
	if map_id != MapCatalog.DEFAULT_MAP_ID:
		var red_sockets := teams[0] as Array
		var blue_sockets := teams[1] as Array
		_require(red_sockets.size() == blue_sockets.size(), "%s team spawn counts differ" % map_id)
		for index in mini(red_sockets.size(), blue_sockets.size()):
			var red_socket := red_sockets[index] as Dictionary
			var blue_socket := blue_sockets[index] as Dictionary
			var red_position := red_socket["position"] as Vector2
			var blue_position := blue_socket["position"] as Vector2
			var red_direction := red_socket["direction"] as Vector2
			var blue_direction := blue_socket["direction"] as Vector2
			var expected_position := Vector2(-red_position.x, red_position.y)
			var expected_direction := Vector2(-red_direction.x, red_direction.y)
			if str(config["symmetry_axis"]) == "z":
				expected_position = Vector2(red_position.x, -red_position.y)
				expected_direction = Vector2(red_direction.x, -red_direction.y)
			_require(blue_position.is_equal_approx(expected_position), "%s spawn %d position is not mirrored" % [map_id, index])
			_require(blue_direction.is_equal_approx(expected_direction), "%s spawn %d facing is not mirrored" % [map_id, index])

	var route := config["route_waypoints"] as Array
	_require(route.size() >= 2, "%s has no bot route" % map_id)
	for waypoint_variant in route:
		var waypoint := waypoint_variant as Vector2
		_require(absf(waypoint.x) < oob.x and absf(waypoint.y) < oob.y, "%s route leaves OOB" % map_id)
		_require(is_finite(terrain.height_at(waypoint.x, waypoint.y)), "%s route has invalid terrain" % map_id)
	_require((route[0] as Vector2).distance_to(bases[0]) < 1.0, "%s route does not start at RED" % map_id)
	_require((route[-1] as Vector2).distance_to(bases[1]) < 1.0, "%s route does not end at BLUE" % map_id)


func _validate_generated_mesh(map_id: String, terrain: Node) -> void:
	var meshes := terrain.find_children("*", "MeshInstance3D", false, false)
	var collisions := terrain.find_children("*", "CollisionShape3D", false, false)
	_require(meshes.size() == 1, "%s did not generate exactly one terrain mesh" % map_id)
	_require(collisions.size() == 1, "%s did not generate exactly one terrain collider" % map_id)
	if meshes.size() == 1:
		var array_mesh := (meshes[0] as MeshInstance3D).mesh as ArrayMesh
		_require(array_mesh != null and array_mesh.get_surface_count() == 1, "%s terrain mesh has extra surfaces" % map_id)
		if array_mesh != null and array_mesh.get_surface_count() == 1:
			_validate_mesh_diagonals(map_id, terrain.resolution, array_mesh)
			var material := array_mesh.surface_get_material(0) as ShaderMaterial
			var marking := MapCatalog.get_map(map_id)["route_marking"] as Dictionary
			_require(material != null, "%s terrain lacks its alpine material" % map_id)
			if material != null:
				_require(material.get_shader_parameter("route_origin") == marking["origin"], "%s route origin was not configured" % map_id)
				_require(material.get_shader_parameter("route_axis") == marking["axis"], "%s route axis was not configured" % map_id)
	if collisions.size() == 1:
		_require((collisions[0] as CollisionShape3D).shape is ConcavePolygonShape3D, "%s collider is not trimesh" % map_id)


func _validate_mesh_diagonals(map_id: String, resolution: int, mesh: ArrayMesh) -> void:
	if map_id == MapCatalog.DEFAULT_MAP_ID:
		return
	var arrays := mesh.surface_get_arrays(0)
	var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	var cell_count := resolution - 1
	if map_id == "relay_divide":
		for z_index in cell_count:
			for x_index in cell_count / 2:
				var mirrored_x := cell_count - 1 - x_index
				if _mesh_cell_is_flipped(indices, resolution, x_index, z_index) == _mesh_cell_is_flipped(indices, resolution, mirrored_x, z_index):
					_require(false, "%s mesh diagonal mismatch at cell (%d,%d)" % [map_id, x_index, z_index])
					return
	else:
		for z_index in cell_count / 2:
			var mirrored_z := cell_count - 1 - z_index
			for x_index in cell_count:
				if _mesh_cell_is_flipped(indices, resolution, x_index, z_index) == _mesh_cell_is_flipped(indices, resolution, x_index, mirrored_z):
					_require(false, "%s mesh diagonal mismatch at cell (%d,%d)" % [map_id, x_index, z_index])
					return


func _mesh_cell_is_flipped(indices: PackedInt32Array, resolution: int, x_index: int, z_index: int) -> bool:
	var cell_offset := (z_index * (resolution - 1) + x_index) * 6
	var bottom_right := (z_index + 1) * resolution + x_index + 1
	return indices[cell_offset + 2] == bottom_right


func _terrain_signature(terrain: Node) -> Array[float]:
	const POINTS: Array[Vector2] = [
		Vector2(-160.0, -120.0), Vector2(-96.0, 0.0), Vector2(-48.0, 72.0),
		Vector2(0.0, 0.0), Vector2(58.0, -66.0), Vector2(128.0, 0.0), Vector2(12.0, 142.0),
	]
	var signature: Array[float] = []
	for point in POINTS:
		signature.append(terrain.height_at(point.x, point.y))
	return signature


func _is_grid_aligned(position: Vector2, terrain: Node) -> bool:
	var step: float = terrain.terrain_size / float(terrain.resolution - 1)
	var half_size: float = terrain.terrain_size * 0.5
	return (
		is_zero_approx(fposmod(position.x + half_size, step))
		and is_zero_approx(fposmod(position.y + half_size, step))
	)


func _signature_distance(left: Array, right: Array) -> float:
	var distance := 0.0
	for index in left.size():
		distance += absf(float(left[index]) - float(right[index]))
	return distance


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
