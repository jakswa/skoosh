extends Node3D

const DEFAULT_PORT := 9077
const MAX_CLIENTS := 16
const GOLDEN_ANGLE := 2.399963229728653

@export var player_scene: PackedScene

@onready var terrain := $Terrain
@onready var players := $Players as Node3D
@onready var lobby := $NetworkLobby as SkooshNetworkLobby

var avatars: Dictionary = {}
var _bot_mode := false
var _test_seconds := 0.0
var _require_combat := false
var _require_movement := false
var _test_started_at := 0
var _test_timer_started := false
var _peak_avatars := 0
var _combat_kills := 0
var _combat_deaths := 0
var _peak_server_speed := 0.0
var _server_saw_jet := false
var _peak_rollback_ticks := 0
var _peak_network_loop_ms := 0.0


func _ready() -> void:
	$ArenaBeacon.position.y = terrain.height_at(0.0, -207.0) + 9.0
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


func _parse_command_line() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := ""
	var address := "127.0.0.1"
	var port := DEFAULT_PORT
	for arg in args:
		if arg == "--server":
			mode = "server"
		elif arg == "--host":
			mode = "server"
		elif arg == "--bot":
			_bot_mode = true
		elif arg == "--require-combat":
			_require_combat = true
		elif arg == "--require-movement":
			_require_movement = true
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
	lobby.set_status("DEDICATED SERVER LISTENING ON UDP %d" % port, true)
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
	print("NETWORK authoritative server started peer=1")


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
	lobby.show_error("CONNECTION FAILED")


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
	var local_bot := _bot_mode and id == multiplayer.get_unique_id()
	avatar.configure_peer(id, get_spawn_transform(id, 0), local_bot)
	avatars[id] = avatar
	_peak_avatars = maxi(_peak_avatars, avatars.size())
	print("NETWORK avatar spawned id=%d local_bot=%s node=%s" % [id, local_bot, avatar.get_path()])


func _remove_avatar(id: int) -> void:
	if not avatars.has(id):
		return
	var avatar := avatars[id] as Node
	avatars.erase(id)
	if is_instance_valid(avatar):
		avatar.queue_free()


func get_spawn_transform(peer_id: int, respawn_count: int = 0) -> Transform3D:
	var center := Vector2(0.0, -207.0)
	var slot := absi(peer_id) % MAX_CLIENTS
	var angle := float(slot) * GOLDEN_ANGLE + float(respawn_count % 3) * 0.42
	var radius := 12.0 + float(slot % 2) * 3.0
	var xz := center + Vector2(cos(angle), sin(angle)) * radius
	var height: float = terrain.height_at(xz.x, xz.y)
	var position := Vector3(xz.x, height + 0.08, xz.y)
	var direction := Vector3(center.x - xz.x, 0.0, center.y - xz.y).normalized()
	var yaw := atan2(-direction.x, -direction.z)
	return Transform3D(Basis(Vector3.UP, yaw), position)


func award_kill(attacker_peer_id: int, victim_peer_id: int) -> void:
	if not multiplayer.is_server() or attacker_peer_id == victim_peer_id:
		return
	var attacker := avatars.get(attacker_peer_id) as SkooshNetworkPlayer
	if attacker != null:
		attacker.add_kill()
		_combat_kills += 1
		print("COMBAT kill attacker=%d victim=%d kills=%d" % [attacker_peer_id, victim_peer_id, attacker.kills])


func record_death() -> void:
	if multiplayer.is_server():
		_combat_deaths += 1


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
		if candidate == null or candidate.dead:
			continue
		var distance := source.global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate
	return nearest


func _process(_delta: float) -> void:
	_peak_rollback_ticks = maxi(_peak_rollback_ticks, NetworkPerformance.get_rollback_ticks())
	_peak_network_loop_ms = maxf(_peak_network_loop_ms, NetworkPerformance.get_network_loop_duration_ms())


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	for avatar in avatars.values():
		var player := avatar as SkooshNetworkPlayer
		_peak_server_speed = maxf(_peak_server_speed, player.total_speed)
		_server_saw_jet = _server_saw_jet or player.jet_active
		var position: Vector3 = player.global_position
		var outside: bool = absf(position.x) > 278.0 or absf(position.z) > 278.0
		var far_below: bool = position.y < float(terrain.height_at(position.x, position.z)) - 35.0
		if outside or far_below:
			player.request_authoritative_respawn(false)


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
	var peer_id := multiplayer.get_unique_id() if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED else 0
	if multiplayer.is_server():
		total_kills = _combat_kills
		total_deaths = _combat_deaths
	print("ACCEPT multiplayer peer=%d peak_avatars=%d current_avatars=%d kills=%d deaths=%d peak_speed=%.1f jet=%s max_rollback=%d peak_net_ms=%.2f elapsed_ms=%d" % [
		peer_id, _peak_avatars, avatars.size(), total_kills, total_deaths,
		_peak_server_speed, _server_saw_jet, _peak_rollback_ticks, _peak_network_loop_ms,
		Time.get_ticks_msec() - _test_started_at
	])
	var combat_failed := _require_combat and (_peak_avatars < 2 or total_deaths < 1 or total_kills < 1)
	var movement_failed := _require_movement and (_peak_server_speed < 10.0 or not _server_saw_jet)
	get_tree().quit(1 if combat_failed or movement_failed else 0)
