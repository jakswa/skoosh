extends SceneTree

const MapCatalog = preload("res://scripts/map_catalog.gd")
const TEST_PORT := 19080
const TEST_PEER_ID := 42
const TEAM_BLUE := 1
const FLAG_HOME := 0
const FLAG_DROPPED := 2
const BOUNDARY_DIRECTIONS: Array[Vector2] = [
	Vector2.RIGHT,
	Vector2(1.0, 1.0),
	Vector2.DOWN,
	Vector2(-1.0, 1.0),
	Vector2.LEFT,
	Vector2(-1.0, -1.0),
	Vector2.UP,
	Vector2(1.0, -1.0),
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/network_demo.tscn") as PackedScene
	var arena := scene.instantiate()
	root.add_child(arena)
	await process_frame
	var expected_map_id := MapCatalog.selected_id_from_args()
	if not _require(arena.map_id == expected_map_id, "Scene selected the wrong map"):
		return
	if not _require(arena.terrain.map_id == expected_map_id, "Terrain selected the wrong map"):
		return
	arena.start_server(TEST_PORT)
	await process_frame
	arena._spawn_avatar(TEST_PEER_ID)
	await process_frame
	var player = arena.avatars[TEST_PEER_ID]

	# Exercise cardinal and diagonal exits against each map's actual curved
	# boundary. A point just inside the rim must remain playable, while a point
	# just outside must recover to a valid team spawn.
	for direction_index in BOUNDARY_DIRECTIONS.size():
		var boundary_point := _boundary_point(arena.terrain, BOUNDARY_DIRECTIONS[direction_index])
		var inner := boundary_point * 0.96
		var outer := boundary_point * 1.04
		if not _require(arena.terrain.is_within_playable_boundary(inner), "Near-rim point classified OOB"):
			return
		if not _require(not arena.terrain.is_within_playable_boundary(outer), "Exit point classified playable"):
			return
		player.global_position = Vector3(inner.x, arena.terrain.height_at(inner.x, inner.y) + 2.0, inner.y)
		arena._physics_process(1.0 / 60.0)
		if not _require(Vector2(player.global_position.x, player.global_position.z).distance_to(inner) < 0.01, "Near-rim player recovered early"):
			return

		if direction_index == 0:
			arena._take_flag(TEAM_BLUE, player)
		# Recreate several rollback frames restoring the same unsafe snapshot.
		# The latch must suppress per-frame respawn spam during this burst.
		var rollback_frames := 5 if direction_index == 0 else 1
		for _frame in rollback_frames:
			player.global_position = Vector3(outer.x, arena.terrain.height_at(outer.x, outer.y) + 2.0, outer.y)
			arena._physics_process(1.0 / 60.0)
		if direction_index == 0:
			# The forced rollback burst overwrote the first teleport. Persistent OOB
			# must trigger one bounded retry instead of leaving the player stranded.
			for _frame in 26:
				arena._physics_process(1.0 / 60.0)
		if not _require(arena.terrain.is_within_playable_boundary(Vector2(player.global_position.x, player.global_position.z)), "OOB recovery spawn is outside"):
			return
		if not _require(player.global_position.y >= arena.terrain.height_at(player.global_position.x, player.global_position.z), "OOB recovery spawn is below terrain"):
			return
		if direction_index == 0:
			if not _require(arena.blue_flag_state == FLAG_HOME, "OOB flag did not return home"):
				return
			if not _require(arena.red_score == 0 and not arena.round_over, "OOB carrier scored"):
				return
		_clear_recovery_latch(arena, player)

	# Falling through terrain while still inside the curved footprint uses the
	# same authoritative recovery path.
	var center := Vector2((arena.red_home.x + arena.blue_home.x) * 0.5, (arena.red_home.z + arena.blue_home.z) * 0.5)
	player.global_position = Vector3(center.x, arena.terrain.height_at(center.x, center.y) - 36.0, center.y)
	arena._physics_process(1.0 / 60.0)
	if not _require(arena.terrain.is_within_playable_boundary(Vector2(player.global_position.x, player.global_position.z)), "Below-terrain recovery spawn is outside"):
		return
	_clear_recovery_latch(arena, player)

	# Any other authoritative respawn must drop a carried flag before moving the
	# player home, preventing reset-to-capture ordering bugs.
	player.global_position = (arena.red_home + arena.blue_home) * 0.5
	arena._take_flag(TEAM_BLUE, player)
	player.request_authoritative_respawn(false)
	arena._update_ctf_state()
	if not _require(arena.blue_flag_state == FLAG_DROPPED, "Respawn did not drop carried flag"):
		return
	if not _require(arena.red_score == 0 and not arena.round_over, "Respawn carrier scored"):
		return

	print("ACCEPT OOB recovery map=%s exits=%d below=1 manual=1 carried_flag_safe=true" % [
		expected_map_id, BOUNDARY_DIRECTIONS.size(),
	])
	quit()


func _boundary_point(terrain: Node, direction: Vector2) -> Vector2:
	direction = direction.normalized()
	var low := 0.0
	var mesh_size: Vector2 = terrain.get_mesh_size()
	var high: float = mesh_size.length()
	for _iteration in 32:
		var midpoint: float = (low + high) * 0.5
		var point: Vector2 = direction * midpoint
		if terrain.boundary_ratio(point.x, point.y) <= 1.0:
			low = midpoint
		else:
			high = midpoint
	return direction * low


func _clear_recovery_latch(arena: Node, player: Node3D) -> void:
	for _frame in range(4):
		arena._physics_process(1.0 / 60.0)


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
