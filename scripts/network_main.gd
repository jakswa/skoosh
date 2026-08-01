extends Node3D

const DEFAULT_PORT := 9077
const MAX_CLIENTS := 16
const TEAM_RED := 0
const TEAM_BLUE := 1
const FLAG_HOME := 0
const FLAG_CARRIED := 1
const FLAG_DROPPED := 2
const CAPTURE_LIMIT := 1
const FLAG_PICKUP_RADIUS := 4.0
const FLAG_CAPTURE_RADIUS := 12.0
const FLAG_CONTACT_HEIGHT := 8.0
const FLAG_CAPTURE_HEIGHT := 80.0
const FLAG_RETURN_TICKS := 600
const ROUND_RESTART_TICKS := 300
const ARENA_CENTER := Vector2(0.0, -207.0)
const BASE_SEPARATION := 48.0
const OOB_RECOVERY_SAFE_FRAMES := 3
const VOICE_COMMAND_COOLDOWN_TICKS := 60
const VOICE_COMMANDS := [
	{"category": "SOCIAL", "label": "HELLO"},
	{"category": "SOCIAL", "label": "GOODBYE"},
	{"category": "SOCIAL", "label": "THANKS"},
	{"category": "SOCIAL", "label": "SHAZBOT"},
	{"category": "OBJECTIVE", "label": "DEFEND OUR STANDARD"},
	{"category": "OBJECTIVE", "label": "PUSH THE FAR PLATFORM"},
	{"category": "OBJECTIVE", "label": "RECOVER OUR STANDARD"},
	{"category": "OBJECTIVE", "label": "COVER MY RETURN"},
	{"category": "STATUS", "label": "YES"},
	{"category": "STATUS", "label": "NO"},
	{"category": "STATUS", "label": "I NEED SUPPORT"},
	{"category": "STATUS", "label": "ALL CLEAR"},
]

@export var player_scene: PackedScene

@onready var terrain := $Terrain
@onready var players := $Players as Node3D
@onready var lobby := $NetworkLobby as SkooshNetworkLobby
@onready var red_platform := $CompactArena/RedPlatform as StaticBody3D
@onready var blue_platform := $CompactArena/BluePlatform as StaticBody3D
@onready var center_line := $CompactArena/CenterLine as MeshInstance3D
@onready var red_flag := $CompactArena/RedFlag as SkooshNetworkFlag
@onready var blue_flag := $CompactArena/BlueFlag as SkooshNetworkFlag

# Match and objective state are written only by peer 1 and replicated by the
# root MultiplayerSynchronizer. Clients present this state but never score it.
var red_score := 0
var blue_score := 0
var red_flag_state := FLAG_HOME
var red_flag_carrier := 0
var red_flag_position := Vector3.ZERO
var red_flag_return_tick := -1
var blue_flag_state := FLAG_HOME
var blue_flag_carrier := 0
var blue_flag_position := Vector3.ZERO
var blue_flag_return_tick := -1
var round_over := false
var winner_team := -1
var round_restart_tick := -1
var round_number := 1

var avatars: Dictionary = {}
var red_home := Vector3.ZERO
var blue_home := Vector3.ZERO
var platform_surface_y := 0.0
var _bot_mode := false
var _test_seconds := 0.0
var _require_combat := false
var _require_movement := false
var _require_ctf := false
var _require_voice := false
var _test_started_at := 0
var _test_timer_started := false
var _peak_avatars := 0
var _combat_kills := 0
var _combat_deaths := 0
var _disc_impacts := 0
var _disc_damage_events := 0
var _voice_commands_relayed := 0
var _ctf_captures := 0
var _completed_rounds := 0
var _peak_server_speed := 0.0
var _server_saw_jet := false
var _peak_rollback_ticks := 0
var _peak_network_loop_ms := 0.0
var _oob_recovery_safe_frames: Dictionary = {}
var _last_voice_command_tick: Dictionary = {}
var _last_voice_request_tick: Dictionary = {}
var _last_team_voice_tick: Dictionary = {}


func _ready() -> void:
	_configure_compact_arena()
	NetworkEvents.on_server_start.connect(_on_server_started)
	NetworkEvents.on_client_start.connect(_on_client_started)
	NetworkEvents.on_peer_join.connect(_on_peer_joined)
	NetworkEvents.on_peer_leave.connect(_on_peer_left)
	NetworkEvents.on_client_stop.connect(_on_connection_stopped)
	NetworkEvents.on_server_stop.connect(_on_connection_stopped)
	multiplayer.connection_failed.connect(_on_connection_failed)
	lobby.server_requested.connect(start_server)
	lobby.join_requested.connect(join_server)
	_parse_command_line()


func _configure_compact_arena() -> void:
	var red_x := ARENA_CENTER.x - BASE_SEPARATION * 0.5
	var blue_x := ARENA_CENTER.x + BASE_SEPARATION * 0.5
	var red_ground: float = terrain.height_at(red_x, ARENA_CENTER.y)
	var blue_ground: float = terrain.height_at(blue_x, ARENA_CENTER.y)
	platform_surface_y = maxf(red_ground, blue_ground) + 4.5
	red_platform.position = Vector3(red_x, platform_surface_y - 1.0, ARENA_CENTER.y)
	blue_platform.position = Vector3(blue_x, platform_surface_y - 1.0, ARENA_CENTER.y)
	center_line.position = Vector3(
		ARENA_CENTER.x,
		terrain.height_at(ARENA_CENTER.x, ARENA_CENTER.y) + 0.08,
		ARENA_CENTER.y
	)
	red_home = Vector3(red_x, platform_surface_y + 1.08, ARENA_CENTER.y)
	blue_home = Vector3(blue_x, platform_surface_y + 1.08, ARENA_CENTER.y)
	red_flag_position = red_home
	blue_flag_position = blue_home
	red_flag.present(red_home, false)
	blue_flag.present(blue_home, false)


func _parse_command_line() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := ""
	var address := "127.0.0.1"
	var port := DEFAULT_PORT
	for arg in args:
		if arg == "--server" or arg == "--host":
			mode = "server"
		elif arg == "--bot":
			_bot_mode = true
		elif arg == "--require-combat":
			_require_combat = true
		elif arg == "--require-movement":
			_require_movement = true
		elif arg == "--require-ctf":
			_require_ctf = true
		elif arg == "--require-voice":
			_require_voice = true
		elif arg.begins_with("--join="):
			mode = "client"
			address = arg.trim_prefix("--join=")
		elif arg.begins_with("--port="):
			port = int(arg.trim_prefix("--port="))
		elif arg.begins_with("--test-seconds="):
			_test_seconds = float(arg.trim_prefix("--test-seconds="))

	if mode == "server":
		lobby.hide_lobby()
		start_server(port)
	elif mode == "client":
		lobby.hide_lobby()
		join_server(address, port)
	else:
		lobby.set_status("START A DEDICATED SERVER OR JOIN ONE\nServer windows do not own a player.")


func start_server(port: int) -> void:
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		lobby.show_error("COULD NOT LISTEN ON UDP %d\n%s" % [port, error_string(error)])
		return
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer
	multiplayer.server_relay = true
	lobby.set_status("DEDICATED CTF SERVER LISTENING ON UDP %d" % port, true)
	print("NETWORK server listening port=%d max_clients=%d" % [port, MAX_CLIENTS])
	_start_test_timer()


func join_server(address: String, port: int) -> void:
	if address.is_empty():
		lobby.show_error("ENTER A SERVER ADDRESS")
		return
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		lobby.show_error("COULD NOT CONNECT TO %s:%d\n%s" % [address, port, error_string(error)])
		return
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer
	lobby.set_status("CONNECTING TO %s:%d..." % [address, port])
	print("NETWORK client connecting address=%s port=%d bot=%s" % [address, port, _bot_mode])
	_start_test_timer()


func _on_server_started() -> void:
	print("NETWORK authoritative CTF server started peer=1 capture_limit=%d" % CAPTURE_LIMIT)


func _on_client_started(id: int) -> void:
	print("NETWORK client connected peer=%d" % id)
	lobby.set_status("CONNECTED AS PEER #%d" % id, true)
	_spawn_avatar(id)


func _on_peer_joined(id: int) -> void:
	if id == 1:
		return
	print("NETWORK peer joined id=%d local=%d" % [id, multiplayer.get_unique_id()])
	_spawn_avatar(id)


func _on_peer_left(id: int) -> void:
	print("NETWORK peer left id=%d" % id)
	_last_voice_command_tick.erase(id)
	_last_voice_request_tick.erase(id)
	if multiplayer.is_server():
		_drop_flags_carried_by(id)
	_remove_avatar(id)


func _on_connection_stopped() -> void:
	for id in avatars.keys():
		_remove_avatar(id)
	call_deferred("_reset_multiplayer_peer")
	if not DisplayServer.get_name().contains("headless"):
		lobby.show_lobby()
		lobby.show_error("DISCONNECTED")


func _reset_multiplayer_peer() -> void:
	if not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _on_connection_failed() -> void:
	print("NETWORK connection failed")
	for id in avatars.keys():
		_remove_avatar(id)
	call_deferred("_reset_multiplayer_peer")
	lobby.show_error("CONNECTION FAILED\nCHECK THE ADDRESS, UDP PORT, AND SERVER STATUS")


func _spawn_avatar(id: int) -> void:
	if id <= 1 or avatars.has(id):
		return
	var avatar := player_scene.instantiate() as SkooshNetworkPlayer
	avatar.name = "Player_%d" % id
	avatar.peer_id = id
	avatar.set_multiplayer_authority(1)
	var avatar_input := avatar.get_node("Input") as SkooshNetworkInput
	avatar_input.set_multiplayer_authority(id)
	players.add_child(avatar)
	avatars[id] = avatar
	var assigned_team := _assign_balanced_team() if multiplayer.is_server() else id % 2
	var local_bot := _bot_mode and id == multiplayer.get_unique_id()
	avatar.configure_peer(id, get_team_spawn_transform(assigned_team, id, 0), local_bot, assigned_team)
	_peak_avatars = maxi(_peak_avatars, avatars.size())
	print("NETWORK avatar spawned id=%d team=%s local_bot=%s node=%s" % [
		id, get_team_name(assigned_team), local_bot, avatar.get_path()
	])


func _assign_balanced_team() -> int:
	var red_count := 0
	var blue_count := 0
	for candidate in avatars.values():
		var player := candidate as SkooshNetworkPlayer
		if player.team == TEAM_RED:
			red_count += 1
		elif player.team == TEAM_BLUE:
			blue_count += 1
	# The new avatar is already in the dictionary with team -1.
	return TEAM_RED if red_count <= blue_count else TEAM_BLUE


func _remove_avatar(id: int) -> void:
	_oob_recovery_safe_frames.erase(id)
	if not avatars.has(id):
		return
	var avatar := avatars[id] as Node
	avatars.erase(id)
	if is_instance_valid(avatar):
		avatar.queue_free()


func get_spawn_transform(peer_id: int, respawn_count: int = 0) -> Transform3D:
	var player := avatars.get(peer_id) as SkooshNetworkPlayer
	var spawn_team := player.team if player != null and player.team >= 0 else peer_id % 2
	return get_team_spawn_transform(spawn_team, peer_id, respawn_count)


func get_team_spawn_transform(team: int, peer_id: int, respawn_count: int) -> Transform3D:
	var home := red_home if team == TEAM_RED else blue_home
	var z_offset := (float(absi(peer_id + respawn_count) % 3) - 1.0) * 2.2
	var position := Vector3(home.x, platform_surface_y + 0.08, home.z + z_offset)
	var direction := Vector3(-1.0, 0.0, 0.0) if team == TEAM_BLUE else Vector3(1.0, 0.0, 0.0)
	var yaw := atan2(-direction.x, -direction.z)
	return Transform3D(Basis(Vector3.UP, yaw), position)


func award_kill(attacker_peer_id: int, victim_peer_id: int) -> void:
	if not multiplayer.is_server() or attacker_peer_id == victim_peer_id:
		return
	var attacker := avatars.get(attacker_peer_id) as SkooshNetworkPlayer
	var victim := avatars.get(victim_peer_id) as SkooshNetworkPlayer
	if attacker != null and victim != null and attacker.team != victim.team:
		attacker.add_kill()
		_combat_kills += 1
		print("COMBAT kill attacker=%d victim=%d kills=%d" % [attacker_peer_id, victim_peer_id, attacker.kills])


func record_death() -> void:
	if multiplayer.is_server():
		_combat_deaths += 1


func record_disc_impact(damaged_enemies: int) -> void:
	if not multiplayer.is_server():
		return
	_disc_impacts += 1
	_disc_damage_events += damaged_enemies
	print("COMBAT disc impact=%d damaged=%d" % [_disc_impacts, damaged_enemies])


func find_target_for(peer_id: int) -> SkooshNetworkPlayer:
	var nearest: SkooshNetworkPlayer
	var nearest_distance := INF
	var source := avatars.get(peer_id) as SkooshNetworkPlayer
	if source == null:
		return null
	for id in avatars:
		if id == peer_id:
			continue
		var candidate := avatars[id] as SkooshNetworkPlayer
		if candidate == null or candidate.dead or candidate.team == source.team:
			continue
		var distance := source.global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate
	return nearest


func get_bot_objective_position(peer_id: int) -> Vector3:
	var player := avatars.get(peer_id) as SkooshNetworkPlayer
	if player == null:
		return Vector3(ARENA_CENTER.x, platform_surface_y, ARENA_CENTER.y)
	var enemy_team := TEAM_BLUE if player.team == TEAM_RED else TEAM_RED
	var own_carrier := _get_flag_carrier(player.team)
	if _get_flag_carrier(enemy_team) == peer_id:
		if own_carrier != 0:
			var enemy := avatars.get(own_carrier) as SkooshNetworkPlayer
			if enemy != null:
				return enemy.global_position
		return red_home if player.team == TEAM_RED else blue_home
	if _get_flag_state(enemy_team) == FLAG_CARRIED:
		var carrier := avatars.get(_get_flag_carrier(enemy_team)) as SkooshNetworkPlayer
		if carrier != null:
			return carrier.global_position
	return _get_flag_position(enemy_team)


func should_bot_fire(peer_id: int) -> bool:
	var player := avatars.get(peer_id) as SkooshNetworkPlayer
	var target := find_target_for(peer_id)
	if player == null or target == null:
		return false
	var flags_contested := (
		red_flag_state == FLAG_CARRIED or blue_flag_state == FLAG_CARRIED
		or red_flag_state == FLAG_DROPPED or blue_flag_state == FLAG_DROPPED
	)
	return flags_contested and player.global_position.distance_to(target.global_position) < 65.0


func is_round_active() -> bool:
	return not round_over


func player_carries_enemy_flag(player: SkooshNetworkPlayer) -> bool:
	if player == null:
		return false
	var enemy_team := TEAM_BLUE if player.team == TEAM_RED else TEAM_RED
	return _get_flag_state(enemy_team) == FLAG_CARRIED and _get_flag_carrier(enemy_team) == player.peer_id


func get_team_name(team: int) -> String:
	return "RED" if team == TEAM_RED else "BLUE"


func get_capture_limit() -> int:
	return CAPTURE_LIMIT


func get_flag_status(team: int) -> String:
	var state := _get_flag_state(team)
	if state == FLAG_HOME:
		return "HOME"
	if state == FLAG_DROPPED:
		return "DROPPED"
	return "TAKEN"


func get_voice_commands() -> Array:
	return VOICE_COMMANDS


func send_voice_command(command_id: int) -> void:
	if multiplayer.is_server():
		_broadcast_voice_command(multiplayer.get_unique_id(), command_id)
	else:
		_request_voice_command.rpc_id(1, command_id)


@rpc("any_peer", "reliable", "call_remote")
func _request_voice_command(command_id: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var previous_request_tick := int(_last_voice_request_tick.get(sender, -100000))
	if NetworkTime.tick - previous_request_tick < 15:
		return
	_last_voice_request_tick[sender] = NetworkTime.tick
	_broadcast_voice_command(sender, command_id)


func _broadcast_voice_command(speaker_peer_id: int, command_id: int) -> void:
	if not multiplayer.is_server() or command_id < 0 or command_id >= VOICE_COMMANDS.size():
		return
	var speaker := avatars.get(speaker_peer_id) as SkooshNetworkPlayer
	if speaker == null:
		return
	var previous_tick := int(_last_voice_command_tick.get(speaker_peer_id, -100000))
	if NetworkTime.tick - previous_tick < VOICE_COMMAND_COOLDOWN_TICKS:
		return
	var previous_team_tick := int(_last_team_voice_tick.get(speaker.team, -100000))
	if NetworkTime.tick - previous_team_tick < 30:
		return
	_last_voice_command_tick[speaker_peer_id] = NetworkTime.tick
	_last_team_voice_tick[speaker.team] = NetworkTime.tick
	_voice_commands_relayed += 1
	for avatar_variant in avatars.values():
		var listener := avatar_variant as SkooshNetworkPlayer
		if listener != null and listener.team == speaker.team:
			_receive_voice_command.rpc_id(listener.peer_id, speaker_peer_id, command_id)
	print("VOICE speaker=%d team=%s command=%s" % [
		speaker_peer_id, get_team_name(speaker.team), VOICE_COMMANDS[command_id]["label"]
	])


@rpc("authority", "reliable", "call_remote")
func _receive_voice_command(speaker_peer_id: int, command_id: int) -> void:
	if command_id < 0 or command_id >= VOICE_COMMANDS.size():
		return
	var local_player := avatars.get(multiplayer.get_unique_id()) as SkooshNetworkPlayer
	if local_player != null:
		local_player.hud.play_voice_command(speaker_peer_id, command_id)
		print("VOICE received listener=%d speaker=%d command=%s" % [
			local_player.peer_id, speaker_peer_id, VOICE_COMMANDS[command_id]["label"]
		])


func _process(_delta: float) -> void:
	_peak_rollback_ticks = maxi(_peak_rollback_ticks, NetworkPerformance.get_rollback_ticks())
	_peak_network_loop_ms = maxf(_peak_network_loop_ms, NetworkPerformance.get_network_loop_duration_ms())
	_present_flags()


func _present_flags() -> void:
	red_flag.present(_presented_flag_position(TEAM_RED), red_flag_state == FLAG_CARRIED)
	blue_flag.present(_presented_flag_position(TEAM_BLUE), blue_flag_state == FLAG_CARRIED)


func _presented_flag_position(team: int) -> Vector3:
	if _get_flag_state(team) == FLAG_CARRIED:
		var carrier := avatars.get(_get_flag_carrier(team)) as SkooshNetworkPlayer
		if carrier != null:
			return carrier.global_position + Vector3(0.0, 1.0, 0.0)
	return _get_flag_position(team)


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	for avatar in avatars.values():
		var player := avatar as SkooshNetworkPlayer
		_peak_server_speed = maxf(_peak_server_speed, player.total_speed)
		_server_saw_jet = _server_saw_jet or player.jet_active
		var position: Vector3 = player.global_position
		var outside := absf(position.x) > 278.0 or absf(position.z) > 278.0
		var far_below := position.y < float(terrain.height_at(position.x, position.z)) - 35.0
		var needs_recovery := outside or far_below
		if needs_recovery:
			# Rollback may briefly restore the pre-teleport OOB snapshot. Latch the
			# recovery until several consecutive safe frames prevent repeated
			# respawns and log bursts during that reconciliation window.
			if not _oob_recovery_safe_frames.has(player.peer_id):
				_oob_recovery_safe_frames[player.peer_id] = 0
				player.request_authoritative_respawn(false, true)
			else:
				_oob_recovery_safe_frames[player.peer_id] = 0
		elif _oob_recovery_safe_frames.has(player.peer_id):
			var safe_frames := int(_oob_recovery_safe_frames[player.peer_id]) + 1
			if safe_frames >= OOB_RECOVERY_SAFE_FRAMES:
				_oob_recovery_safe_frames.erase(player.peer_id)
			else:
				_oob_recovery_safe_frames[player.peer_id] = safe_frames
	if round_over:
		if NetworkTime.tick >= round_restart_tick:
			_start_new_round()
		return
	_update_ctf_state()


func _update_ctf_state() -> void:
	_validate_flag_carrier(TEAM_RED)
	_validate_flag_carrier(TEAM_BLUE)
	_return_expired_flag(TEAM_RED)
	_return_expired_flag(TEAM_BLUE)
	for avatar in avatars.values():
		var player := avatar as SkooshNetworkPlayer
		if player.dead or player.team < 0:
			continue
		_process_player_flag_contact(player)


func _process_player_flag_contact(player: SkooshNetworkPlayer) -> void:
	var own_team := player.team
	var enemy_team := TEAM_BLUE if own_team == TEAM_RED else TEAM_RED
	var own_home := red_home if own_team == TEAM_RED else blue_home
	if _get_flag_state(own_team) == FLAG_DROPPED:
		if _is_flag_contact(player.global_position, _get_flag_position(own_team), FLAG_PICKUP_RADIUS):
			_return_flag_home(own_team, "touched by teammate %d" % player.peer_id)
	if _get_flag_state(enemy_team) != FLAG_CARRIED:
		if _is_flag_contact(player.global_position, _get_flag_position(enemy_team), FLAG_PICKUP_RADIUS):
			_take_flag(enemy_team, player)
	if (
		_get_flag_state(enemy_team) == FLAG_CARRIED
		and _get_flag_carrier(enemy_team) == player.peer_id
		and _get_flag_state(own_team) == FLAG_HOME
		and _is_flag_contact(player.global_position, own_home, FLAG_CAPTURE_RADIUS, FLAG_CAPTURE_HEIGHT)
	):
		_capture_flag(player, enemy_team)


func _is_flag_contact(player_position: Vector3, flag_position: Vector3, radius: float, height: float = FLAG_CONTACT_HEIGHT) -> bool:
	var planar := Vector2(player_position.x - flag_position.x, player_position.z - flag_position.z)
	return planar.length() <= radius and absf(player_position.y - flag_position.y) <= height


func _take_flag(flag_team: int, player: SkooshNetworkPlayer) -> void:
	_set_flag_state(flag_team, FLAG_CARRIED)
	_set_flag_carrier(flag_team, player.peer_id)
	_set_flag_return_tick(flag_team, -1)
	print("CTF pickup player=%d team=%s flag=%s" % [
		player.peer_id, get_team_name(player.team), get_team_name(flag_team)
	])


func _capture_flag(player: SkooshNetworkPlayer, enemy_flag_team: int) -> void:
	if player.team == TEAM_RED:
		red_score += 1
	else:
		blue_score += 1
	_ctf_captures += 1
	_return_flag_home(enemy_flag_team, "captured")
	print("CTF capture player=%d team=%s score=%d-%d" % [
		player.peer_id, get_team_name(player.team), red_score, blue_score
	])
	if red_score >= CAPTURE_LIMIT or blue_score >= CAPTURE_LIMIT:
		_end_round(player.team)


func _end_round(team: int) -> void:
	round_over = true
	winner_team = team
	round_restart_tick = NetworkTime.tick + ROUND_RESTART_TICKS
	_completed_rounds += 1
	print("CTF win team=%s round=%d score=%d-%d restart_tick=%d" % [
		get_team_name(team), round_number, red_score, blue_score, round_restart_tick
	])


func _start_new_round() -> void:
	red_score = 0
	blue_score = 0
	round_over = false
	winner_team = -1
	round_restart_tick = -1
	round_number += 1
	_return_flag_home(TEAM_RED, "new round")
	_return_flag_home(TEAM_BLUE, "new round")
	for avatar in avatars.values():
		(avatar as SkooshNetworkPlayer).request_authoritative_respawn(false)
	print("CTF round started round=%d" % round_number)


func _validate_flag_carrier(team: int) -> void:
	if _get_flag_state(team) != FLAG_CARRIED:
		return
	var carrier_id := _get_flag_carrier(team)
	var carrier := avatars.get(carrier_id) as SkooshNetworkPlayer
	if carrier == null:
		_return_flag_home(team, "carrier disconnected")
	elif carrier.dead:
		_drop_flag(team, carrier.global_position)


func prepare_player_respawn(peer_id: int, return_carried_flags_home: bool = false) -> void:
	for team in [TEAM_RED, TEAM_BLUE]:
		if _get_flag_state(team) != FLAG_CARRIED or _get_flag_carrier(team) != peer_id:
			continue
		if return_carried_flags_home:
			_return_flag_home(team, "carrier out of bounds")
			continue
		var carrier := avatars.get(peer_id) as SkooshNetworkPlayer
		if carrier != null:
			_drop_flag(team, carrier.global_position)
		else:
			_return_flag_home(team, "carrier left")


func _drop_flags_carried_by(peer_id: int) -> void:
	prepare_player_respawn(peer_id)


func _drop_flag(team: int, position: Vector3) -> void:
	_set_flag_state(team, FLAG_DROPPED)
	_set_flag_carrier(team, 0)
	_set_flag_position(team, position + Vector3.UP * 0.1)
	_set_flag_return_tick(team, NetworkTime.tick + FLAG_RETURN_TICKS)
	print("CTF drop flag=%s position=%s return_tick=%d" % [
		get_team_name(team), position, _get_flag_return_tick(team)
	])


func _return_expired_flag(team: int) -> void:
	if (
		_get_flag_state(team) == FLAG_DROPPED
		and _get_flag_return_tick(team) >= 0
		and NetworkTime.tick >= _get_flag_return_tick(team)
	):
		_return_flag_home(team, "timeout")


func _return_flag_home(team: int, reason: String) -> void:
	_set_flag_state(team, FLAG_HOME)
	_set_flag_carrier(team, 0)
	_set_flag_position(team, red_home if team == TEAM_RED else blue_home)
	_set_flag_return_tick(team, -1)
	print("CTF return flag=%s reason=%s" % [get_team_name(team), reason])


func _get_flag_state(team: int) -> int:
	return red_flag_state if team == TEAM_RED else blue_flag_state


func _set_flag_state(team: int, value: int) -> void:
	if team == TEAM_RED:
		red_flag_state = value
	else:
		blue_flag_state = value


func _get_flag_carrier(team: int) -> int:
	return red_flag_carrier if team == TEAM_RED else blue_flag_carrier


func _set_flag_carrier(team: int, value: int) -> void:
	if team == TEAM_RED:
		red_flag_carrier = value
	else:
		blue_flag_carrier = value


func _get_flag_position(team: int) -> Vector3:
	return red_flag_position if team == TEAM_RED else blue_flag_position


func _set_flag_position(team: int, value: Vector3) -> void:
	if team == TEAM_RED:
		red_flag_position = value
	else:
		blue_flag_position = value


func _get_flag_return_tick(team: int) -> int:
	return red_flag_return_tick if team == TEAM_RED else blue_flag_return_tick


func _set_flag_return_tick(team: int, value: int) -> void:
	if team == TEAM_RED:
		red_flag_return_tick = value
	else:
		blue_flag_return_tick = value


func _start_test_timer() -> void:
	if _test_seconds <= 0.0 or _test_timer_started:
		return
	_test_timer_started = true
	_test_started_at = Time.get_ticks_msec()
	get_tree().create_timer(_test_seconds).timeout.connect(_finish_automated_test)


func _finish_automated_test() -> void:
	var total_deaths := 0
	var total_kills := 0
	for avatar in avatars.values():
		var player := avatar as SkooshNetworkPlayer
		total_deaths += player.deaths
		total_kills += player.kills
		if multiplayer.is_server():
			print("ACCEPT player peer=%d team=%s position=%s speed=%.1f" % [
				player.peer_id, get_team_name(player.team), player.global_position, player.total_speed
			])
	var status := multiplayer.multiplayer_peer.get_connection_status()
	var peer_id := multiplayer.get_unique_id() if status == MultiplayerPeer.CONNECTION_CONNECTED else 0
	if multiplayer.is_server():
		total_kills = _combat_kills
		total_deaths = _combat_deaths
	print("ACCEPT multiplayer peer=%d peak_avatars=%d current_avatars=%d kills=%d deaths=%d disc_impacts=%d disc_damage=%d voice=%d captures=%d rounds=%d peak_speed=%.1f jet=%s max_rollback=%d peak_net_ms=%.2f elapsed_ms=%d" % [
		peer_id, _peak_avatars, avatars.size(), total_kills, total_deaths,
		_disc_impacts, _disc_damage_events, _voice_commands_relayed,
		_ctf_captures, _completed_rounds,
		_peak_server_speed, _server_saw_jet,
		_peak_rollback_ticks, _peak_network_loop_ms, Time.get_ticks_msec() - _test_started_at
	])
	var combat_failed := _require_combat and (
		_peak_avatars < 2 or total_deaths < 1 or total_kills < 1
		or _disc_impacts < 1 or _disc_damage_events < 1
	)
	var movement_failed := _require_movement and (_peak_server_speed < 10.0 or not _server_saw_jet)
	var ctf_failed := _require_ctf and (_ctf_captures < 1 or _completed_rounds < 1)
	var voice_failed := _require_voice and _voice_commands_relayed < 1
	get_tree().quit(1 if combat_failed or movement_failed or ctf_failed or voice_failed else 0)
