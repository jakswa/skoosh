extends SceneTree

const TEST_PORT := 19080
const TEST_PEER_ID := 42
const TEAM_BLUE := 1
const FLAG_HOME := 0
const FLAG_DROPPED := 2
const FORCED_OOB_POSITION := Vector3(300.0, 0.0, 0.0)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/network_demo.tscn") as PackedScene
	var arena := scene.instantiate()
	root.add_child(arena)
	await process_frame
	arena.start_server(TEST_PORT)
	await process_frame
	arena._spawn_avatar(TEST_PEER_ID)
	await process_frame
	var player = arena.avatars[TEST_PEER_ID]

	# Recreate several frames of rollback restoring one unsafe snapshot. The
	# recovery latch should turn this burst into one authoritative respawn, and
	# an enemy flag carried OOB must return home without scoring.
	arena._take_flag(TEAM_BLUE, player)
	for _frame in range(5):
		player.global_position = FORCED_OOB_POSITION
		arena._physics_process(1.0 / 60.0)
	if not _require(arena.blue_flag_state == FLAG_HOME, "OOB flag did not return home"):
		return
	if not _require(arena.red_score == 0 and not arena.round_over, "OOB carrier scored"):
		return

	# Clear the latch, then prove a later, distinct excursion still recovers.
	for _frame in range(4):
		player.global_position = arena.red_home
		arena._physics_process(1.0 / 60.0)
	player.global_position = FORCED_OOB_POSITION
	arena._physics_process(1.0 / 60.0)

	# Any other authoritative respawn must drop a carried flag before moving the
	# player home, preventing reset-to-capture ordering bugs.
	player.global_position = Vector3(0.0, arena.platform_surface_y, -207.0)
	arena._take_flag(TEAM_BLUE, player)
	player.request_authoritative_respawn(false)
	arena._update_ctf_state()
	if not _require(arena.blue_flag_state == FLAG_DROPPED, "Respawn did not drop carried flag"):
		return
	if not _require(arena.red_score == 0 and not arena.round_over, "Respawn carrier scored"):
		return

	print("ACCEPT OOB recovery and carried-flag safety")
	quit()


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
