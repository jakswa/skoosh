extends SceneTree

const TEST_PEER_ID := 42
const OTHER_PEER_ID := 43
const QUEUED_PEER_ID := 99


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/network_demo.tscn") as PackedScene
	var arena = scene.instantiate()
	root.add_child(arena)
	arena.set_process(false)
	arena.set_physics_process(false)
	await process_frame
	var network_time := root.get_node("NetworkTime")
	var network_rollback := root.get_node("NetworkRollback")
	var no_peers: Array[int] = []

	if not _require(not arena.game_state_synchronizer.public_visibility, "Match state started public"):
		return

	# A server-authoritative generation-1 map replacement must preserve the exact
	# RPC path rather than leaving a same-name tombstone for Godot to suffix.
	arena._replace_bootstrap_world = true
	arena._rebuild_world(1, "cairn_steps", no_peers)
	await process_frame
	if not _require(arena.world.name == "World_1", "Bootstrap world path was renamed"):
		return
	if not _require(arena.map_id == "cairn_steps", "Bootstrap world selected the wrong map"):
		return
	if not _require(_world_count(arena, "World_1") == 1, "Bootstrap left duplicate World_1 nodes"):
		return
	if not _require(arena._retired_worlds.is_empty(), "Bootstrap retained a same-generation tombstone"):
		return

	arena._peer_teams[TEST_PEER_ID] = 0
	arena._peer_character_variants[TEST_PEER_ID] = 0
	arena._approved_map_peers[TEST_PEER_ID] = true
	arena._spawn_avatar(TEST_PEER_ID, 0, 0)
	await process_frame
	var retired_player = arena.avatars[TEST_PEER_ID]
	var input_callback := Callable(retired_player.input, "_before_tick_loop")
	if not _require(
		network_time.before_tick_loop.is_connected(input_callback),
		"Live input callback was not connected"
	):
		return
	retired_player.retire_for_rotation()
	if not _require(
		not network_time.before_tick_loop.is_connected(input_callback),
		"Retired input callback remained connected"
	):
		return

	# A fresh transport session owns a fresh generation namespace and must not
	# inherit disabled rollback or transition barriers from the prior server.
	arena.world_generation = 3
	arena.world_phase = arena.WORLD_WAITING_FOR_READY
	arena._transition_generation = 4
	arena._bootstrap_generation = 3
	arena._pending_ready_peers[TEST_PEER_ID] = true
	network_rollback.enabled = true
	arena._reset_connection_state()
	if not _require(arena.world_generation == 0, "Disconnect retained the old generation"):
		return
	if not _require(arena.world_phase == arena.WORLD_COMMITTING, "Disconnect retained the old phase"):
		return
	if not _require(not network_rollback.enabled, "Disconnect retained rollback state"):
		return
	arena._enable_rollback_after_world_build(3)
	if not _require(
		not network_rollback.enabled and arena.world_phase == arena.WORLD_COMMITTING,
		"Stale warmup timer reactivated the disconnected session"
	):
		return
	if not _require(
		arena._transition_generation == -1
		and arena._bootstrap_generation == -1
		and arena._pending_ready_peers.is_empty(),
		"Disconnect retained transition barriers"
	):
		return
	arena._rebuild_world(1, "faultline_basin", no_peers)
	await process_frame
	if not _require(arena.world.name == "World_1", "Reconnect world path was renamed"):
		return
	if not _require(_world_count(arena, "World_1") == 1, "Reconnect left duplicate World_1 nodes"):
		return

	# A queued peer is outside the immutable transition set and cannot invalidate
	# readiness already completed by the match peers.
	arena.world_phase = arena.WORLD_WAITING_FOR_READY
	arena._transition_peer_ids.assign([TEST_PEER_ID, OTHER_PEER_ID])
	arena._built_world_peers[TEST_PEER_ID] = true
	arena._built_world_peers[OTHER_PEER_ID] = true
	arena._transition_disconnects_pending[777] = true
	arena._admission_queue.append(QUEUED_PEER_ID)
	arena._on_peer_left(QUEUED_PEER_ID)
	if not _require(arena._pending_ready_peers.is_empty(), "Queued departure reset readiness"):
		return
	if not _require(
		arena._built_world_peers.has(TEST_PEER_ID)
		and arena._built_world_peers.has(OTHER_PEER_ID),
		"Queued departure erased completed builds"
	):
		return

	# Timeout rejection changes authoritative gameplay state before transport
	# teardown, so the final baseline cannot contain a collidable ghost.
	arena._transition_disconnects_pending.clear()
	arena._peer_teams[TEST_PEER_ID] = 0
	arena._peer_character_variants[TEST_PEER_ID] = 0
	arena._approved_map_peers[TEST_PEER_ID] = true
	arena._transition_peer_ids.assign([TEST_PEER_ID])
	arena._pending_ready_peers[TEST_PEER_ID] = true
	arena._spawn_avatar(TEST_PEER_ID, 0, 0)
	await process_frame
	var timed_out_player = arena.avatars[TEST_PEER_ID]
	arena._disconnect_transition_peer(TEST_PEER_ID)
	if not _require(not arena.avatars.has(TEST_PEER_ID), "Timed-out avatar remained authoritative"):
		return
	if not _require(
		not timed_out_player.gameplay_admitted
		and timed_out_player.collision_layer == 0
		and timed_out_player.collision_mask == 0,
		"Timed-out avatar remained admitted or collidable"
	):
		return
	if not _require(
		not arena._peer_teams.has(TEST_PEER_ID)
		and not arena._peer_character_variants.has(TEST_PEER_ID),
		"Timed-out avatar retained persistent assignments"
	):
		return

	print("ACCEPT rotation lifecycle bootstrap=true reconnect=true queued=true ghost=true visibility=true input=true")
	quit()


func _world_count(arena: Node, world_name: String) -> int:
	var count := 0
	for child in arena.get_children():
		if child.name == world_name:
			count += 1
	return count


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
