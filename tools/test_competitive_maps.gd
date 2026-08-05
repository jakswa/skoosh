extends SceneTree

const MapCatalog = preload("res://scripts/map_catalog.gd")
const TerrainScript = preload("res://scripts/terrain.gd")

var _failed := false
var _terrains: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_catalog()
	for map_id: String in MapCatalog.PRODUCTION_MAP_IDS:
		var terrain = TerrainScript.new()
		terrain.map_id = map_id
		_terrains[map_id] = terrain
		var config := MapCatalog.get_map(map_id)
		_validate_footprint(map_id, config, terrain)
		_validate_symmetry(map_id, config, terrain)
		_validate_bases_and_spawns(map_id, config, terrain)
		_validate_routes(map_id, config, terrain)
		_validate_landform_contract(map_id, terrain)
		terrain.generate()
		_validate_generated_terrain(map_id, config, terrain)

	_validate_pair_distinction()
	for terrain in _terrains.values():
		terrain.free()
	if _failed:
		quit(1)
		return
	print("ACCEPT two production maps: authored topology, routes, footprints, recovery, profiles, and terrain mesh")
	quit()


func _validate_catalog() -> void:
	_require(MapCatalog.DEFAULT_MAP_ID == "faultline_basin", "Faultline is not the multiplayer default")
	_require(MapCatalog.PRODUCTION_MAP_IDS.size() == 2, "Production map count is not exactly two")
	_require(MapCatalog.ROTATION_MAP_IDS == MapCatalog.PRODUCTION_MAP_IDS, "Rotation differs from production catalog")
	_require(MapCatalog.LEGACY_MAP_ID not in MapCatalog.ROTATION_MAP_IDS, "Kestrel entered production rotation")
	_require(MapCatalog.LEGACY_MAP_ID in MapCatalog.SELECTABLE_MAP_IDS, "Kestrel is not explicitly selectable")
	_require(str(MapCatalog.get_map(MapCatalog.LEGACY_MAP_ID)["status"]) == "legacy_test", "Kestrel lost legacy status")
	var default_terrain = TerrainScript.new()
	_require(default_terrain.map_id == MapCatalog.LEGACY_MAP_ID, "Generic/solo terrain no longer defaults to Kestrel")
	_require(not default_terrain.consume_command_line_map, "Generic terrain unexpectedly consumes multiplayer map arguments")
	default_terrain.free()


func _validate_footprint(map_id: String, config: Dictionary, terrain: Node) -> void:
	var mesh_size := config["mesh_size"] as Vector2
	var grid_resolution := config["grid_resolution"] as Vector2i
	_require(is_equal_approx(mesh_size.x / float(grid_resolution.x - 1), 4.0), "%s X grid is not 4m" % map_id)
	_require(is_equal_approx(mesh_size.y / float(grid_resolution.y - 1), 4.0), "%s Z grid is not 4m" % map_id)
	var aspect := mesh_size.x / mesh_size.y
	if map_id == "faultline_basin":
		_require(aspect > 1.5, "Faultline is not a longitudinal mesh")
		_require(not terrain.is_within_playable_boundary(Vector2(315.0, 120.0)), "Faultline retained a box corner")
	else:
		_require(aspect < 0.75, "Cairn is not a transverse mesh")
		_require(not terrain.is_within_playable_boundary(Vector2(170.0, 270.0)), "Cairn retained a box corner")

	var half_size := mesh_size * 0.5
	for edge in [Vector2(half_size.x, 0.0), Vector2(-half_size.x, 0.0), Vector2(0.0, half_size.y), Vector2(0.0, -half_size.y)]:
		_require(terrain.boundary_ratio(edge.x, edge.y) > 1.14, "%s mesh lacks visible terrain beyond OOB" % map_id)

	var boundary := config["boundary"] as Dictionary
	var inner_points: Array[Vector2] = []
	var outer_points: Array[Vector2] = []
	if str(boundary["type"]) == "capsule_x":
		var segment := float(boundary["segment_half_length"])
		var radius := float(boundary["radius"])
		inner_points = [Vector2(segment + radius * 0.76, 0.0), Vector2(0.0, radius * 0.76)]
		outer_points = [Vector2(segment + radius * 0.98, 0.0), Vector2(0.0, radius * 0.98)]
	else:
		var extents := boundary["half_extents"] as Vector2
		inner_points = [Vector2(extents.x * 0.76, 0.0), Vector2(0.0, extents.y * 0.76)]
		outer_points = [Vector2(extents.x * 0.98, 0.0), Vector2(0.0, extents.y * 0.98)]
	for index in inner_points.size():
		var inner := inner_points[index]
		var outer := outer_points[index]
		_require(terrain.is_within_playable_boundary(inner), "%s recovery band starts outside OOB" % map_id)
		_require(terrain.is_within_playable_boundary(outer), "%s near rim is not recoverable" % map_id)
		_require(
			terrain.height_at(outer.x, outer.y) - terrain.height_at(inner.x, inner.y) > 14.0,
			"%s perimeter does not rise enough to discourage casual exit" % map_id
		)


func _validate_symmetry(map_id: String, config: Dictionary, terrain: Node) -> void:
	var axis := str(config["symmetry_axis"])
	var mesh_size := config["mesh_size"] as Vector2
	for z_index in 17:
		var z := lerpf(-mesh_size.y * 0.45, mesh_size.y * 0.45, z_index / 16.0)
		for x_index in 17:
			var x := lerpf(-mesh_size.x * 0.45, mesh_size.x * 0.45, x_index / 16.0)
			var mirror := Vector2(-x, z) if axis == "x" else Vector2(x, -z)
			_require(
				is_equal_approx(terrain.height_at(x, z), terrain.height_at(mirror.x, mirror.y)),
				"%s height symmetry failed at %s" % [map_id, Vector2(x, z)]
			)


func _validate_bases_and_spawns(map_id: String, config: Dictionary, terrain: Node) -> void:
	var bases := config["base_centers"] as Array
	var red_base := bases[0] as Vector2
	var blue_base := bases[1] as Vector2
	_require(red_base.distance_to(blue_base) >= 430.0, "%s base separation is still compact" % map_id)
	for base in [red_base, blue_base]:
		_require(terrain.is_within_playable_boundary(base), "%s base is outside playable terrain" % map_id)
		_require(terrain.normal_at(base.x, base.y).y > 0.88, "%s base platform is not on a stable landing" % map_id)
	var teams := config["spawn_sockets"] as Array
	_require((teams[0] as Array).size() == (teams[1] as Array).size(), "%s team spawn counts differ" % map_id)
	for team in 2:
		var sockets := teams[team] as Array
		_require(sockets.size() >= 5, "%s lacks production spawn spread" % map_id)
		for socket_variant in sockets:
			var socket := socket_variant as Dictionary
			var position := socket["position"] as Vector2
			var direction := socket["direction"] as Vector2
			_require(terrain.is_within_playable_boundary(position), "%s spawn leaves the authored footprint" % map_id)
			_require(position.distance_to(bases[team] as Vector2) >= 30.0, "%s spawn overlaps flag defense" % map_id)
			_require(direction.normalized().dot((bases[1 - team] as Vector2) - position) > 0.72, "%s spawn does not face inward" % map_id)
	for index in (teams[0] as Array).size():
		var red := ((teams[0] as Array)[index] as Dictionary)["position"] as Vector2
		var blue := ((teams[1] as Array)[index] as Dictionary)["position"] as Vector2
		var expected := Vector2(-red.x, red.y) if str(config["symmetry_axis"]) == "x" else Vector2(red.x, -red.y)
		_require(blue.is_equal_approx(expected), "%s spawn pair %d is not mirrored" % [map_id, index])


func _validate_routes(map_id: String, config: Dictionary, terrain: Node) -> void:
	var routes := config["routes"] as Array
	var bases := config["base_centers"] as Array
	_require(routes.size() == 3, "%s does not expose exactly three authored route families" % map_id)
	var midpoint_positions: Array[Vector2] = []
	var route_lengths: Array[float] = []
	for route_variant in routes:
		var route := route_variant as Dictionary
		var points := route["waypoints"] as Array
		_require(points.size() >= 7, "%s route %s is prop-only or underspecified" % [map_id, route["id"]])
		_require((points[0] as Vector2).is_equal_approx(bases[0] as Vector2), "%s route does not start at RED" % map_id)
		_require((points[-1] as Vector2).is_equal_approx(bases[1] as Vector2), "%s route does not end at BLUE" % map_id)
		midpoint_positions.append(points[points.size() / 2] as Vector2)
		var route_length := 0.0
		for index in points.size() - 1:
			var start := points[index] as Vector2
			var finish := points[index + 1] as Vector2
			_require(terrain.is_within_playable_boundary(start), "%s route %s leaves OOB" % [map_id, route["id"]])
			route_length += start.distance_to(finish)
			var samples := maxi(1, ceili(start.distance_to(finish) / 4.0))
			for sample_index in samples:
				var a := start.lerp(finish, sample_index / float(samples))
				var b := start.lerp(finish, (sample_index + 1) / float(samples))
				var grade := absf(terrain.height_at(b.x, b.y) - terrain.height_at(a.x, a.y)) / a.distance_to(b)
				_require(grade < 0.72, "%s route %s exceeds ski/jet grade at %s" % [map_id, route["id"], a])
		route_lengths.append(route_length)
		for landing_variant in route["landings"]:
			var landing := landing_variant as Vector2
			_require(terrain.normal_at(landing.x, landing.y).y > 0.78, "%s route %s lacks a stable authored landing" % [map_id, route["id"]])
	for left in midpoint_positions.size():
		for right in range(left + 1, midpoint_positions.size()):
			_require(midpoint_positions[left].distance_to(midpoint_positions[right]) > 50.0, "%s routes collapse into one lane" % map_id)
	_require(route_lengths.max() - route_lengths.min() > 18.0, "%s routes have formulaic equal lengths" % map_id)


func _validate_landform_contract(map_id: String, terrain: Node) -> void:
	if map_id == "faultline_basin":
		_require(terrain.height_at(0.0, -80.0) - terrain.height_at(0.0, 0.0) > 24.0, "Faultline lacks its high basalt spine")
		_require(terrain.height_at(0.0, 54.0) - terrain.height_at(0.0, 103.0) > 18.0, "Faultline gully is not terrain-screened")
	else:
		_require(terrain.height_at(0.0, 0.0) - terrain.height_at(0.0, 110.0) > 10.0, "Cairn lacks its transverse escarpment")
		_require(terrain.height_at(0.0, 0.0) - terrain.height_at(94.0, 0.0) > 13.0, "Cairn east chute is not exposed below the saddle")
		_require(terrain.height_at(-48.0, 0.0) - terrain.height_at(-112.0, 0.0) > 18.0, "Cairn switchback is not terrain-screened")


func _validate_generated_terrain(map_id: String, config: Dictionary, terrain: Node) -> void:
	var meshes := terrain.find_children("*", "MeshInstance3D", false, false)
	var collisions := terrain.find_children("*", "CollisionShape3D", false, false)
	_require(meshes.size() == 1, "%s does not have exactly one terrain mesh" % map_id)
	_require(collisions.size() == 1, "%s does not have exactly one terrain collider" % map_id)
	if meshes.size() != 1:
		return
	var mesh := (meshes[0] as MeshInstance3D).mesh as ArrayMesh
	_require(mesh != null and mesh.get_surface_count() == 1, "%s terrain has extra surfaces" % map_id)
	var resolution := config["grid_resolution"] as Vector2i
	var arrays := mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	_require(vertices.size() == resolution.x * resolution.y, "%s mesh resolution changed" % map_id)
	_require(indices.size() == (resolution.x - 1) * (resolution.y - 1) * 6, "%s triangle budget changed" % map_id)
	_require((collisions[0] as CollisionShape3D).shape is ConcavePolygonShape3D, "%s collider is not a trimesh" % map_id)
	var material := mesh.surface_get_material(0) as ShaderMaterial
	var marking := config["route_marking"] as Dictionary
	_require(material != null, "%s lacks its terrain material" % map_id)
	if material != null:
		_require(material.get_shader_parameter("route_axis") == marking["axis"], "%s route marking axis is wrong" % map_id)
		_require(is_equal_approx(float(material.get_shader_parameter("contour_spacing")), float((config["palette"] as Dictionary)["contour_spacing"])), "%s contour profile is wrong" % map_id)


func _validate_pair_distinction() -> void:
	var fault = _terrains["faultline_basin"]
	var cairn = _terrains["cairn_steps"]
	var fault_config := MapCatalog.get_map("faultline_basin")
	var cairn_config := MapCatalog.get_map("cairn_steps")
	var fault_size := fault_config["mesh_size"] as Vector2
	var cairn_size := cairn_config["mesh_size"] as Vector2
	var swapped_distance := 0.0
	var sample_count := 0
	var fault_center: float = fault.height_at(0.0, 0.0)
	var cairn_center: float = cairn.height_at(0.0, 0.0)
	for team_index in 13:
		var team_t := lerpf(-0.68, 0.68, team_index / 12.0)
		for cross_index in 9:
			var cross_t := lerpf(-0.62, 0.62, cross_index / 8.0)
			var fault_height: float = fault.height_at(team_t * fault_size.x * 0.5, cross_t * fault_size.y * 0.5) - fault_center
			var cairn_height: float = cairn.height_at(cross_t * cairn_size.x * 0.5, team_t * cairn_size.y * 0.5) - cairn_center
			swapped_distance += absf(fault_height - cairn_height)
			sample_count += 1
	var mean_swapped_distance := swapped_distance / sample_count
	_require(mean_swapped_distance > 8.0, "Production terrain is still an axis-rotated clone pair")
	var fault_clear: bool = _has_direct_sightline(fault_config, fault)
	var cairn_clear: bool = _has_direct_sightline(cairn_config, cairn)
	_require(fault_clear and not cairn_clear, "Maps do not have distinct base sightline contracts")
	var fault_palette := fault_config["palette"] as Dictionary
	var cairn_palette := cairn_config["palette"] as Dictionary
	_require((fault_palette["mid"] as Color).get_luminance() < 0.3, "Faultline lost its basalt/night value profile")
	_require((cairn_palette["mid"] as Color).get_luminance() > 0.5, "Cairn lost its chalk/day value profile")
	var fault_environment := fault_config["environment"] as Dictionary
	var cairn_environment := cairn_config["environment"] as Dictionary
	_require((fault_environment["sky_top"] as Color).get_luminance() + 0.2 < (cairn_environment["sky_top"] as Color).get_luminance(), "Map atmospheres are not visibly distinct")
	print("MAP CONTRACT swapped_profile_distance=%.2f faultline_direct_los=%s cairn_direct_los=%s" % [mean_swapped_distance, fault_clear, cairn_clear])


func _has_direct_sightline(config: Dictionary, terrain: Node) -> bool:
	var bases := config["base_centers"] as Array
	var start := bases[0] as Vector2
	var finish := bases[1] as Vector2
	var clearance := float(config["platform_clearance"]) + 2.0
	var start_y: float = terrain.height_at(start.x, start.y) + clearance
	var finish_y: float = terrain.height_at(finish.x, finish.y) + clearance
	for index in range(1, 80):
		var t := index / 80.0
		var point := start.lerp(finish, t)
		var sightline_y := lerpf(start_y, finish_y, t)
		if terrain.height_at(point.x, point.y) + 1.0 > sightline_y:
			return false
	return true


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
