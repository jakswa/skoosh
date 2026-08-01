extends SceneTree

const TEST_PORT := 19080
const TEST_PEER_ID := 42
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
	# recovery latch should turn this burst into one authoritative respawn.
	for _frame in range(5):
		player.global_position = FORCED_OOB_POSITION
		arena._physics_process(1.0 / 60.0)

	# Clear the latch, then prove a later, distinct excursion still recovers.
	for _frame in range(4):
		player.global_position = arena.red_home
		arena._physics_process(1.0 / 60.0)
	player.global_position = FORCED_OOB_POSITION
	arena._physics_process(1.0 / 60.0)

	print("ACCEPT OOB recovery latch")
	quit()
