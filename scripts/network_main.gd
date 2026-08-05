extends Node3D

const VoiceCommandLibrary = preload("res://scripts/voice_command_library.gd")
const MapCatalog = preload("res://scripts/map_catalog.gd")
const TerrainScript = preload("res://scripts/terrain.gd")
const LandmarksScript = preload("res://scripts/map_landmarks.gd")
const NetworkAcceptanceScript = preload("res://scripts/network_acceptance.gd")
const DEFAULT_PORT := 9077
const MAX_CLIENTS := 16
const TEAM_RED := 0
const TEAM_BLUE := 1
const FLAG_HOME := 0
const FLAG_CARRIED := 1
const FLAG_DROPPED := 2
const DEFAULT_SCORE_LIMIT := 3
const ALLOWED_SCORE_LIMIT_ARGUMENTS: Array[String] = ["3", "4", "5"]
const FLAG_PICKUP_RADIUS := 4.0
const FLAG_CAPTURE_RADIUS := 12.0
const FLAG_CONTACT_HEIGHT := 8.0
const FLAG_CAPTURE_HEIGHT := 80.0
const FLAG_RETURN_TICKS := 600
const OBJECTIVE_RESET_TICKS := 120
const ROUND_RESTART_TICKS := 300
const OOB_RECOVERY_SAFE_FRAMES := 3
const OOB_RECOVERY_RETRY_FRAMES := 30
const MAP_AGREEMENT_TIMEOUT_MS := 5000
const WORLD_PREPARE_TIMEOUT_MS := 4000
const WORLD_READY_TIMEOUT_MS := 8000
const WORLD_DISCONNECT_FLUSH_MS := 1000
const RETIRED_WORLD_GRACE_MS := 10000
const VOICE_COMMAND_COOLDOWN_TICKS := 60
const VOICE_CHANNEL_COOLDOWN_TICKS := 30
const TEST_SERVER_SHUTDOWN_GRACE_SECONDS := 3.0
const ACCEPTANCE_ROUTE_CONTACT_RADIUS := 24.0
const ACCEPTANCE_CAPTURE_IDLE := 0
const ACCEPTANCE_CAPTURE_PICKUP := 1
const ACCEPTANCE_CAPTURE_HOME := 2
const VOICE_COMMANDS := VoiceCommandLibrary.COMMANDS
const WORLD_ACTIVE := 0
const WORLD_PREPARING := 1
const WORLD_COMMITTING := 2
const WORLD_WAITING_FOR_READY := 3

@export var player_scene: PackedScene

@onready var terrain := $Terrain
@onready var world_environment := $WorldEnvironment as WorldEnvironment
@onready var sun := $Sun as DirectionalLight3D
@onready var players := $Players as Node3D
@onready var lobby := $NetworkLobby as SkooshNetworkLobby
@onready var red_platform := $CompactArena/RedPlatform as StaticBody3D
@onready var blue_platform := $CompactArena/BluePlatform as StaticBody3D
@onready var red_flag := $CompactArena/RedFlag as SkooshNetworkFlag
@onready var blue_flag := $CompactArena/BlueFlag as SkooshNetworkFlag
@onready var neutral_landmarks := $NeutralLandmarks
@onready var game_state := $ReplicatedGameState as SkooshNetworkMatchState
@onready var game_state_synchronizer := $ReplicatedGameState/GameStateSynchronizer as MultiplayerSynchronizer

# Match and objective state are written only by peer 1 and replicated from a
# dedicated child so its visibility cannot hide the persistent root RPC seam.
var red_score: int:
	get: return game_state.red_score
	set(value): game_state.red_score = value
var blue_score: int:
	get: return game_state.blue_score
	set(value): game_state.blue_score = value
var score_limit: int:
	get: return game_state.score_limit
	set(value): game_state.score_limit = value
var red_flag_state: int:
	get: return game_state.red_flag_state
	set(value): game_state.red_flag_state = value
var red_flag_carrier: int:
	get: return game_state.red_flag_carrier
	set(value): game_state.red_flag_carrier = value
var red_flag_position: Vector3:
	get: return game_state.red_flag_position
	set(value): game_state.red_flag_position = value
var red_flag_return_tick: int:
	get: return game_state.red_flag_return_tick
	set(value): game_state.red_flag_return_tick = value
var blue_flag_state: int:
	get: return game_state.blue_flag_state
	set(value): game_state.blue_flag_state = value
var blue_flag_carrier: int:
	get: return game_state.blue_flag_carrier
	set(value): game_state.blue_flag_carrier = value
var blue_flag_position: Vector3:
	get: return game_state.blue_flag_position
	set(value): game_state.blue_flag_position = value
var blue_flag_return_tick: int:
	get: return game_state.blue_flag_return_tick
	set(value): game_state.blue_flag_return_tick = value
var round_over: bool:
	get: return game_state.round_over
	set(value): game_state.round_over = value
var winner_team: int:
	get: return game_state.winner_team
	set(value): game_state.winner_team = value
var round_restart_tick: int:
	get: return game_state.round_restart_tick
	set(value): game_state.round_restart_tick = value
var round_number: int:
	get: return game_state.round_number
	set(value): game_state.round_number = value
var objective_reset_tick: int:
	get: return game_state.objective_reset_tick
	set(value): game_state.objective_reset_tick = value
var match_state_generation: int:
	get: return game_state.match_state_generation
	set(value): game_state.match_state_generation = value
var world_generation := 1
var world_phase := WORLD_ACTIVE
var world_activation_tick := 0

var avatars: Dictionary = {}
var red_home := Vector3.ZERO
var blue_home := Vector3.ZERO
var platform_surface_y := 0.0
var red_platform_surface_y := 0.0
var blue_platform_surface_y := 0.0
var map_id := MapCatalog.DEFAULT_MAP_ID
var map_config: Dictionary = {}
var _startup_map_id := MapCatalog.DEFAULT_MAP_ID
var _startup_map_explicit := false
var world: Node3D
var projectiles: Node3D
var effects: Node3D
var _peer_teams: Dictionary = {}
var _peer_character_variants: Dictionary = {}
var _pending_prepare_peers: Dictionary = {}
var _pending_ready_peers: Dictionary = {}
var _built_world_peers: Dictionary = {}
var _transition_disconnects_pending: Dictionary = {}
var _disconnect_flush_deadline_ms := -1
var _transition_peer_ids: Array[int] = []
var _transition_generation := -1
var _transition_map_id := ""
var _transition_definition_hash := ""
var _transition_baseline_tick := -1
var _prepare_deadline_ms := -1
var _ready_deadline_ms := -1
var _seen_world_instance_ids: Dictionary = {}
var _retired_worlds: Dictionary = {}
var _world_contract_failed := false
var _require_rotation := false
var _rotation_map_history: Array[String] = []
var _rotation_peer_ids: Array[int] = []
var _rotation_team_assignments: Dictionary = {}
var _rotation_character_assignments: Dictionary = {}
var _acceptance: SkooshNetworkAcceptance = NetworkAcceptanceScript.new()
var _bot_mode := false
var _server_mode := false
var _test_seconds := 0.0
var _require_combat := false
var _require_movement := false
var _require_ctf := false
var _require_map_baseline := false
var _require_voice := false
var _test_started_at := 0
var _test_timer_started := false
var _require_character_variants := false
var _acceptance_mode := false
var _oob_recovery_safe_frames: Dictionary = {}
var _last_voice_command_tick: Dictionary = {}
var _last_voice_request_tick: Dictionary = {}
var _last_team_voice_tick: Dictionary = {}
var _last_global_voice_tick := -100000
var _approved_map_peers: Dictionary = {}
var _bootstrap_ready_peers: Dictionary = {}
var _pending_bootstrap_peers: Dictionary = {}
var _pending_avatar_observers: Dictionary = {}
var _map_agreement_deadlines: Dictionary = {}
var _map_mismatch := false
var _acceptance_route_carrier := 0
var _acceptance_route_next_index := -1
var _acceptance_route_step := 0
var _acceptance_route_points_observed := 0
var _acceptance_route_complete := false
var _acceptance_capture_phase := ACCEPTANCE_CAPTURE_IDLE
var _acceptance_acceleration_started := false
var _bootstrap_expected_peer_ids: Array[int] = []
var _bootstrap_generation := -1
var _bootstrap_definition_hash := ""
var _bootstrap_confirmed := false
var _skip_transition_ready_for_test := false
var _admission_queue: Array[int] = []
var _admission_peer_id := 0
var _admission_baseline_ready := false
var _admission_baseline_tick := -1
var _replace_bootstrap_world := false


func _ready() -> void:
	_adopt_initial_world()
	_configure_map(true)
	_startup_map_id = map_id
	for arg in OS.get_cmdline_user_args():
		_startup_map_explicit = _startup_map_explicit or arg.begins_with("--map=")
	_rotation_map_history.append(map_id)
	_validate_and_log_world()
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


func _adopt_initial_world() -> void:
	world = Node3D.new()
	world.name = "World_%d" % world_generation
	add_child(world)
	for child in [terrain, red_platform.get_parent(), neutral_landmarks, players, $Projectiles, $Effects]:
		if child.get_parent() == self:
			child.reparent(world)
	projectiles = world.get_node("Projectiles") as Node3D
	effects = world.get_node("Effects") as Node3D


func _configure_map(select_command_line_map: bool = false) -> void:
	if select_command_line_map:
		map_id = MapCatalog.selected_id_from_args(true)
	map_config = MapCatalog.get_map(map_id)
	var base_centers := map_config["base_centers"] as Array
	var red_center := base_centers[TEAM_RED] as Vector2
	var blue_center := base_centers[TEAM_BLUE] as Vector2
	var clearance := float(map_config["platform_clearance"])
	red_platform_surface_y = terrain.height_at(red_center.x, red_center.y) + clearance
	blue_platform_surface_y = terrain.height_at(blue_center.x, blue_center.y) + clearance
	if bool(map_config["shared_platform_elevation"]):
		red_platform_surface_y = maxf(red_platform_surface_y, blue_platform_surface_y)
		blue_platform_surface_y = red_platform_surface_y
	platform_surface_y = maxf(red_platform_surface_y, blue_platform_surface_y)
	red_platform.position = Vector3(red_center.x, red_platform_surface_y - 1.0, red_center.y)
	blue_platform.position = Vector3(blue_center.x, blue_platform_surface_y - 1.0, blue_center.y)
	red_home = Vector3(red_center.x, red_platform_surface_y + 1.08, red_center.y)
	blue_home = Vector3(blue_center.x, blue_platform_surface_y + 1.08, blue_center.y)
	red_flag_position = red_home
	blue_flag_position = blue_home
	red_flag.present(red_home, false)
	blue_flag.present(blue_home, false)
	neutral_landmarks.configure(map_id, terrain)
	lobby.set_map_name(str(map_config["label"]))
	_configure_environment(map_config["environment"] as Dictionary)
	print("MAP selected id=%s label=%s status=%s" % [map_id, map_config["label"], map_config["status"]])


func _configure_environment(config: Dictionary) -> void:
	var environment := world_environment.environment.duplicate(true) as Environment
	world_environment.environment = environment
	if environment != null:
		environment.ambient_light_color = config["ambient"] as Color
		environment.ambient_light_energy = float(config["ambient_energy"])
		environment.fog_light_color = config["fog"] as Color
		environment.fog_density = float(config["fog_density"])
		if environment.sky != null:
			var sky_material := environment.sky.sky_material as ProceduralSkyMaterial
			if sky_material != null:
				sky_material.sky_top_color = config["sky_top"] as Color
				sky_material.sky_horizon_color = config["sky_horizon"] as Color
				sky_material.ground_bottom_color = config["ground_bottom"] as Color
				sky_material.ground_horizon_color = config["ground_horizon"] as Color
	sun.light_color = config["sun_color"] as Color
	sun.light_energy = float(config["sun_energy"])
	sun.rotation_degrees = config["sun_rotation"] as Vector3


func _parse_command_line() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := ""
	var address := "127.0.0.1"
	var port := DEFAULT_PORT
	var score_limit_option := ""
	var score_limit_option_seen := false
	var arg_index := 0
	while arg_index < args.size():
		var arg := args[arg_index]
		if arg == "--server" or arg == "--host":
			mode = "server"
		elif arg == "--join":
			if arg_index + 1 >= args.size() or args[arg_index + 1].begins_with("--"):
				_fail_startup("--join requires a server address")
				return
			arg_index += 1
			mode = "client"
			address = args[arg_index]
		elif arg == "--bot":
			_bot_mode = true
		elif arg == "--require-combat":
			_require_combat = true
		elif arg == "--require-movement":
			_require_movement = true
		elif arg == "--require-ctf":
			_require_ctf = true
		elif arg == "--require-map-baseline":
			_require_map_baseline = true
		elif arg == "--require-voice":
			_require_voice = true
		elif arg == "--require-character-variants":
			_require_character_variants = true
		elif arg == "--require-rotation":
			_require_rotation = true
		elif arg == "--acceptance-mode":
			_acceptance_mode = true
		elif arg == "--test-skip-transition-ready":
			_skip_transition_ready_for_test = true
		elif arg.begins_with("--join="):
			mode = "client"
			address = arg.trim_prefix("--join=")
		elif arg == "--port":
			if arg_index + 1 >= args.size() or args[arg_index + 1].begins_with("--"):
				_fail_startup("--port requires a value")
				return
			arg_index += 1
			port = int(args[arg_index])
		elif arg.begins_with("--port="):
			port = int(arg.trim_prefix("--port="))
		elif arg.begins_with("--test-seconds="):
			_test_seconds = float(arg.trim_prefix("--test-seconds="))
		elif arg.begins_with("--score-limit"):
			if score_limit_option_seen or not arg.begins_with("--score-limit="):
				_fail_startup("--score-limit must be supplied once as --score-limit=N")
				return
			score_limit_option_seen = true
			score_limit_option = arg.trim_prefix("--score-limit=")
		arg_index += 1

	if score_limit_option_seen:
		if mode != "server":
			_fail_startup("--score-limit is a server-only option")
			return
		if score_limit_option not in ALLOWED_SCORE_LIMIT_ARGUMENTS:
			_fail_startup("--score-limit must be one of 3, 4, or 5; received '%s'" % score_limit_option)
			return
		score_limit = score_limit_option.to_int()

	if mode == "server":
		lobby.hide_lobby()
		start_server(port)
	elif mode == "client":
		lobby.hide_lobby()
		join_server(address, port)
	else:
		lobby.set_status("START A DEDICATED SERVER OR JOIN ONE\nServer windows do not own a player.")


func _fail_startup(message: String) -> void:
	printerr("STARTUP ERROR: %s" % message)
	lobby.show_error(message)
	get_tree().quit(2)


func start_server(port: int) -> void:
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		return
	_map_mismatch = false
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		var message := "COULD NOT LISTEN ON UDP %d\n%s" % [port, error_string(error)]
		printerr("NETWORK server start failed port=%d error=%s" % [port, error_string(error)])
		lobby.show_error(message)
		if DisplayServer.get_name().contains("headless"):
			get_tree().quit(1)
		return
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer
	multiplayer.server_relay = true
	_server_mode = true
	lobby.set_status("DEDICATED CTF SERVER LISTENING ON UDP %d" % port, true)
	print("NETWORK server listening port=%d max_clients=%d" % [port, MAX_CLIENTS])
	_start_test_timer()


func join_server(address: String, port: int) -> void:
	if address.is_empty():
		lobby.show_error("ENTER A SERVER ADDRESS")
		return
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		return
	_map_mismatch = false
	_replace_bootstrap_world = true
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		lobby.show_error("COULD NOT CONNECT TO %s:%d\n%s" % [address, port, error_string(error)])
		return
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer
	_server_mode = false
	lobby.set_status("CONNECTING TO %s:%d..." % [address, port])
	print("NETWORK client connecting address=%s port=%d bot=%s" % [address, port, _bot_mode])
	_start_test_timer()


func _on_server_started() -> void:
	print("NETWORK authoritative CTF server started peer=1 score_limit=%d" % score_limit)


func _on_client_started(id: int) -> void:
	print("NETWORK client connected peer=%d" % id)
	lobby.set_status("CONNECTED AS PEER #%d\nVERIFYING SERVER MAP..." % id, true)


func _on_peer_joined(id: int) -> void:
	if id == 1:
		return
	print("NETWORK peer joined id=%d local=%d" % [id, multiplayer.get_unique_id()])
	if multiplayer.is_server():
		for avatar_variant in avatars.values():
			var avatar := avatar_variant as SkooshNetworkPlayer
			_set_avatar_peer_visibility(avatar, id, false)
		game_state_synchronizer.set_visibility_for(id, false)
		if id != _admission_peer_id and id not in _admission_queue:
			_admission_queue.append(id)
			print("MAP admission queued peer=%d phase=%d generation=%d" % [
				id, world_phase, world_generation,
			])
		_start_next_admission.call_deferred()


func _start_next_admission() -> void:
	if not multiplayer.is_server() or world_phase != WORLD_ACTIVE or _admission_peer_id != 0:
		return
	while not _admission_queue.is_empty():
		var peer_id := int(_admission_queue.pop_front())
		if peer_id not in multiplayer.get_peers() or _approved_map_peers.has(peer_id):
			continue
		_admission_peer_id = peer_id
		_admission_baseline_ready = false
		get_tree().create_timer(0.25).timeout.connect(
			_begin_map_agreement.bind(peer_id), CONNECT_ONE_SHOT
		)
		return


func _begin_map_agreement(peer_id: int) -> void:
	if (
		not multiplayer.is_server()
		or peer_id != _admission_peer_id
		or peer_id not in multiplayer.get_peers()
	):
		return
	if world_phase != WORLD_ACTIVE:
		_admission_queue.push_front(peer_id)
		_admission_peer_id = 0
		return
	_map_agreement_deadlines[peer_id] = Time.get_ticks_msec() + MAP_AGREEMENT_TIMEOUT_MS
	_offer_server_map.rpc_id(
		peer_id, map_id, world_generation, MapCatalog.get_definition_hash(map_id),
		world_phase, _approved_peer_ids()
	)
	print("MAP agreement offered peer=%d server=%s generation=%d" % [peer_id, map_id, world_generation])


@rpc("authority", "reliable", "call_remote")
func _offer_server_map(
	server_map_id: String,
	server_generation: int,
	definition_hash: String,
	server_phase: int,
	approved_peer_ids: Array[int]
) -> void:
	if multiplayer.is_server():
		return
	var local_hash := MapCatalog.get_definition_hash(server_map_id)
	var requested_map_id := _startup_map_id if _startup_map_explicit else ""
	var selection_compatible := (
		server_map_id == requested_map_id if _startup_map_explicit
		else server_map_id in MapCatalog.PRODUCTION_MAP_IDS
	)
	var definition_compatible := local_hash == definition_hash
	print("MAP agreement received server=%s client=%s policy=%s local_hash=%s" % [
		server_map_id, _startup_map_id,
		"explicit" if _startup_map_explicit else "server_authoritative", local_hash,
	])
	if selection_compatible and definition_compatible:
		var new_server_session := _replace_bootstrap_world
		if server_phase in [WORLD_ACTIVE, WORLD_PREPARING, WORLD_WAITING_FOR_READY]:
			world_phase = server_phase
		_bootstrap_expected_peer_ids.assign(approved_peer_ids)
		_bootstrap_expected_peer_ids.append(multiplayer.get_unique_id())
		_bootstrap_expected_peer_ids.sort()
		_bootstrap_generation = server_generation
		_bootstrap_definition_hash = local_hash
		_bootstrap_confirmed = false
		_approved_map_peers.clear()
		for approved_peer_id in approved_peer_ids:
			_approved_map_peers[approved_peer_id] = true
		if server_generation != world_generation or server_map_id != map_id:
			_rebuild_world(server_generation, server_map_id, [])
		else:
			_replace_bootstrap_world = false
		if new_server_session:
			_rotation_map_history.assign([server_map_id])
	_report_client_map.rpc_id(1, requested_map_id, server_generation, local_hash)
	if not selection_compatible:
		_map_mismatch = true
		print("MAP mismatch server=%s client=%s rejection=pending" % [server_map_id, _startup_map_id])
		lobby.show_error("MAP MISMATCH\nSERVER: %s\nCLIENT: %s" % [server_map_id, _startup_map_id])
	elif not definition_compatible:
		_map_mismatch = true
		print("MAP compatibility mismatch server_hash=%s client_hash=%s rejection=pending" % [
			definition_hash, local_hash,
		])
		lobby.show_error("INCOMPATIBLE MAP BUILD")


@rpc("any_peer", "reliable", "call_remote")
func _report_client_map(requested_map_id: String, offered_generation: int, local_hash: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id <= 1 or not _is_admission_live(peer_id) or _approved_map_peers.has(peer_id):
		return
	if offered_generation != world_generation:
		return
	var server_hash := MapCatalog.get_definition_hash(map_id)
	if local_hash != server_hash:
		print("MAP compatibility mismatch peer=%d id=%s server_hash=%s client_hash=%s rejection=disconnect" % [
			peer_id, map_id, server_hash, local_hash,
		])
		_reject_admission(peer_id, "compatibility_mismatch")
		return
	var selection_compatible := (
		requested_map_id == map_id if not requested_map_id.is_empty()
		else map_id in MapCatalog.PRODUCTION_MAP_IDS
	)
	if not selection_compatible:
		print("MAP mismatch peer=%d server=%s client=%s rejection=disconnect" % [
			peer_id, map_id,
			requested_map_id if not requested_map_id.is_empty() else "server_authoritative",
		])
		_reject_admission(peer_id, "map_mismatch")
		return
	var existing_peer_ids := _approved_peer_ids()
	var assigned_team := _assign_balanced_team()
	var assigned_character_variant := _assign_balanced_character_variant(peer_id)
	_peer_teams[peer_id] = assigned_team
	_peer_character_variants[peer_id] = assigned_character_variant
	_pending_bootstrap_peers[peer_id] = existing_peer_ids.size() + 1
	_spawn_avatar(peer_id, assigned_team, assigned_character_variant)
	for approved_id in existing_peer_ids:
		_approve_map_peer.rpc_id(
			peer_id, approved_id, int(_peer_teams[approved_id]),
			int(_peer_character_variants[approved_id]), world_generation, map_id, server_hash
		)
	_approve_map_peer.rpc_id(
		peer_id, peer_id, assigned_team, assigned_character_variant,
		world_generation, map_id, server_hash
	)
	print("MAP agreement accepted peer=%d id=%s hash=%s bootstrap=pending" % [
		peer_id, map_id, server_hash,
	])


@rpc("authority", "reliable", "call_local")
func _approve_map_peer(
	peer_id: int,
	assigned_team: int,
	assigned_character_variant: int,
	server_generation: int,
	server_map_id: String,
	definition_hash: String
) -> void:
	if (
		server_generation < world_generation
		or definition_hash != MapCatalog.get_definition_hash(server_map_id)
	):
		return
	_peer_teams[peer_id] = assigned_team
	_peer_character_variants[peer_id] = assigned_character_variant
	if server_generation != world_generation or server_map_id != map_id:
		_rebuild_world(server_generation, server_map_id, _approved_peer_ids())
	_spawn_avatar(peer_id, assigned_team, assigned_character_variant)
	if not multiplayer.is_server():
		_confirm_avatar_path.rpc_id(1, server_generation, peer_id)
	if peer_id == multiplayer.get_unique_id():
		lobby.set_status("CONNECTED AS PEER #%d\nMAP: %s" % [peer_id, map_config["label"]], true)
	_maybe_confirm_map_bootstrap.call_deferred()


func _maybe_confirm_map_bootstrap() -> void:
	if multiplayer.is_server() or _bootstrap_confirmed:
		return
	if world_generation != _bootstrap_generation or _bootstrap_definition_hash.is_empty():
		return
	for peer_id in _bootstrap_expected_peer_ids:
		if not avatars.has(peer_id):
			return
	_bootstrap_confirmed = true
	_confirm_map_bootstrap.rpc_id(
		1, world_generation, MapCatalog.get_definition_hash(map_id), avatars.size()
	)


@rpc("any_peer", "reliable", "call_remote")
func _confirm_map_bootstrap(generation: int, local_hash: String, avatar_count: int) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if (
		not _is_admission_live(peer_id)
		or generation != world_generation
		or local_hash != MapCatalog.get_definition_hash(map_id)
		or avatar_count != int(_pending_bootstrap_peers.get(peer_id, -1))
	):
		return
	_pending_bootstrap_peers.erase(peer_id)
	for approved_id in _approved_peer_ids():
		_queue_avatar_path_for_observer(peer_id, approved_id)
	_admission_baseline_tick = NetworkTime.tick
	_send_rollback_baseline(peer_id, true, _admission_baseline_tick)
	print("MAP bootstrap paths ready peer=%d generation=%d map=%s avatars=%d" % [
		peer_id, generation, map_id, avatar_count,
	])


func _queue_avatar_path_for_observer(avatar_peer_id: int, observer_id: int) -> void:
	var pending_observers: Dictionary
	if _pending_avatar_observers.has(avatar_peer_id):
		pending_observers = _pending_avatar_observers[avatar_peer_id] as Dictionary
	else:
		pending_observers = {}
		_pending_avatar_observers[avatar_peer_id] = pending_observers
	if pending_observers.has(observer_id):
		return
	pending_observers[observer_id] = true
	_approve_map_peer.rpc_id(
		observer_id, avatar_peer_id, int(_peer_teams[avatar_peer_id]),
		int(_peer_character_variants[avatar_peer_id]), world_generation, map_id,
		MapCatalog.get_definition_hash(map_id)
	)


@rpc("any_peer", "reliable", "call_remote")
func _confirm_avatar_path(generation: int, avatar_peer_id: int) -> void:
	if (
		not multiplayer.is_server()
		or not _is_admission_live(_admission_peer_id)
		or generation != world_generation
		or avatar_peer_id != _admission_peer_id
	):
		return
	var observer_id := multiplayer.get_remote_sender_id()
	if not _pending_avatar_observers.has(avatar_peer_id):
		return
	var pending_observers := _pending_avatar_observers[avatar_peer_id] as Dictionary
	if not pending_observers.erase(observer_id):
		return
	if pending_observers.is_empty():
		_pending_avatar_observers.erase(avatar_peer_id)
	_maybe_finish_admission()


func _maybe_finish_admission() -> void:
	if (
		not multiplayer.is_server()
		or not _is_admission_live(_admission_peer_id)
		or not _admission_baseline_ready
		or _pending_bootstrap_peers.has(_admission_peer_id)
		or not _pending_avatar_observers.is_empty()
	):
		return
	var peer_id := _admission_peer_id
	var recipients := _approved_peer_ids()
	var avatar := avatars.get(peer_id) as SkooshNetworkPlayer
	for observer_id in recipients:
		_set_avatar_peer_visibility(avatar, observer_id, true)
	_set_peer_network_visibility(peer_id, true)
	game_state_synchronizer.set_visibility_for(peer_id, true)
	_approved_map_peers[peer_id] = true
	_bootstrap_ready_peers[peer_id] = true
	_map_agreement_deadlines.erase(peer_id)
	_admit_peer(peer_id, world_generation)
	recipients.append(peer_id)
	for recipient_id in recipients:
		_admit_peer.rpc_id(recipient_id, peer_id, world_generation)
	print("MAP bootstrap ready peer=%d generation=%d map=%s avatars=%d" % [
		peer_id, world_generation, map_id, avatars.size(),
	])
	_admission_peer_id = 0
	_admission_baseline_ready = false
	_admission_baseline_tick = -1
	_start_next_admission.call_deferred()


@rpc("authority", "reliable", "call_local")
func _admit_peer(peer_id: int, generation: int) -> void:
	if generation != world_generation or not avatars.has(peer_id):
		return
	_approved_map_peers[peer_id] = true
	var avatar := avatars.get(peer_id) as SkooshNetworkPlayer
	if avatar != null:
		avatar.set_gameplay_admitted(true)
	if peer_id == multiplayer.get_unique_id():
		lobby.set_status("CONNECTED AS PEER #%d\nMAP: %s" % [peer_id, map_config["label"]], true)


func _send_rollback_baseline(peer_id: int, admission: bool, baseline_tick: int) -> void:
	if not multiplayer.is_server() or peer_id not in multiplayer.get_peers():
		return
	var states: Dictionary = {}
	for avatar_peer_id in avatars:
		var avatar := avatars[avatar_peer_id] as SkooshNetworkPlayer
		var synchronizer := avatar.rollback_synchronizer
		var state := synchronizer.capture_authoritative_baseline()
		if state.is_empty():
			synchronizer.process_settings()
			state = synchronizer.capture_authoritative_baseline()
		states[avatar_peer_id] = state
	_apply_rollback_baseline.rpc_id(
		peer_id, world_generation, MapCatalog.get_definition_hash(map_id), baseline_tick,
		states, admission
	)


@rpc("authority", "reliable", "call_remote")
func _apply_rollback_baseline(
	generation: int,
	definition_hash: String,
	baseline_tick: int,
	states: Dictionary,
	admission: bool
) -> void:
	if (
		multiplayer.is_server()
		or generation != world_generation
		or definition_hash != MapCatalog.get_definition_hash(map_id)
		or (admission and world_phase != WORLD_ACTIVE)
		or (not admission and world_phase != WORLD_WAITING_FOR_READY)
	):
		return
	if baseline_tick < 0:
		return
	for avatar_peer_variant in states:
		var avatar_peer_id := int(avatar_peer_variant)
		var avatar := avatars.get(avatar_peer_id) as SkooshNetworkPlayer
		var state_variant: Variant = states[avatar_peer_variant]
		if typeof(state_variant) != TYPE_DICTIONARY:
			return
		var state := state_variant as Dictionary
		if avatar == null or state.is_empty():
			return
	for avatar_peer_variant in avatars.keys():
		if states.has(avatar_peer_variant):
			continue
		var stale_peer_id := int(avatar_peer_variant)
		_peer_teams.erase(stale_peer_id)
		_peer_character_variants.erase(stale_peer_id)
		_approved_map_peers.erase(stale_peer_id)
		_remove_avatar(stale_peer_id)
	if states.size() != avatars.size():
		return
	for avatar_peer_variant in states:
		var avatar_peer_id := int(avatar_peer_variant)
		var avatar := avatars.get(avatar_peer_id) as SkooshNetworkPlayer
		if avatar == null:
			return
		var synchronizer := avatar.rollback_synchronizer
		synchronizer.process_settings()
		if not synchronizer.apply_authoritative_baseline(
			baseline_tick, states[avatar_peer_variant] as Dictionary
		):
			return
		avatar.tick_interpolator.teleport()
	if admission:
		NetworkRollback.enabled = true
		_ack_admission_baseline.rpc_id(1, generation, definition_hash, baseline_tick)
	else:
		if _skip_transition_ready_for_test and generation > 1:
			return
		_ack_world_ready.rpc_id(1, generation, definition_hash, avatars.size(), baseline_tick)
	print("WORLD baseline applied peer=%d generation=%d tick=%d avatars=%d admission=%s" % [
		multiplayer.get_unique_id(), generation, baseline_tick, avatars.size(), admission,
	])


@rpc("any_peer", "reliable", "call_remote")
func _ack_admission_baseline(
	generation: int, definition_hash: String, baseline_tick: int
) -> void:
	if (
		not multiplayer.is_server()
		or not _is_admission_live(multiplayer.get_remote_sender_id())
		or generation != world_generation
		or definition_hash != MapCatalog.get_definition_hash(map_id)
		or baseline_tick != _admission_baseline_tick
	):
		return
	_admission_baseline_ready = true
	_maybe_finish_admission()


func _is_admission_live(peer_id: int) -> bool:
	return (
		peer_id > 1
		and peer_id == _admission_peer_id
		and _map_agreement_deadlines.has(peer_id)
		and Time.get_ticks_msec() <= int(_map_agreement_deadlines[peer_id])
	)


func _reject_admission(peer_id: int, reason: String) -> void:
	if peer_id != _admission_peer_id:
		return
	print("MAP admission terminal peer=%d reason=%s rejection=disconnect" % [peer_id, reason])
	_map_agreement_deadlines.erase(peer_id)
	_pending_bootstrap_peers.erase(peer_id)
	_pending_avatar_observers.clear()
	_bootstrap_ready_peers.erase(peer_id)
	_peer_teams.erase(peer_id)
	_peer_character_variants.erase(peer_id)
	_remove_avatar(peer_id)
	_admission_peer_id = 0
	_admission_baseline_ready = false
	_admission_baseline_tick = -1
	_disconnect_map_peer(peer_id)
	_start_next_admission.call_deferred()


func _disconnect_map_peer(peer_id: int) -> void:
	if multiplayer.is_server() and peer_id in multiplayer.get_peers():
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)


func _on_peer_left(id: int) -> void:
	print("NETWORK peer left id=%d" % id)
	var forced_transition_disconnect := _transition_disconnects_pending.has(id)
	var was_transition_peer := id in _transition_peer_ids
	var interrupted_admission := (
		_admission_peer_id
		if multiplayer.is_server() and _approved_map_peers.has(id) and id != _admission_peer_id
		else 0
	)
	_approved_map_peers.erase(id)
	_bootstrap_ready_peers.erase(id)
	_pending_bootstrap_peers.erase(id)
	_pending_avatar_observers.erase(id)
	for avatar_peer_variant in _pending_avatar_observers.keys():
		var pending_observers := _pending_avatar_observers[avatar_peer_variant] as Dictionary
		pending_observers.erase(id)
		if pending_observers.is_empty():
			_pending_avatar_observers.erase(avatar_peer_variant)
	_map_agreement_deadlines.erase(id)
	_last_voice_command_tick.erase(id)
	_last_voice_request_tick.erase(id)
	_peer_teams.erase(id)
	_peer_character_variants.erase(id)
	_pending_prepare_peers.erase(id)
	_pending_ready_peers.erase(id)
	_built_world_peers.erase(id)
	_transition_disconnects_pending.erase(id)
	_transition_peer_ids.erase(id)
	_admission_queue.erase(id)
	if id == _admission_peer_id:
		_admission_peer_id = 0
		_admission_baseline_ready = false
		_admission_baseline_tick = -1
	if multiplayer.is_server():
		_drop_flags_carried_by(id)
	_remove_avatar(id)
	if multiplayer.is_server():
		if interrupted_admission != 0:
			_reject_admission(interrupted_admission, "admitted_peer_set_changed")
		if (
			world_phase == WORLD_WAITING_FOR_READY
			and was_transition_peer
			and not forced_transition_disconnect
		):
			for peer_id in _transition_peer_ids:
				_pending_ready_peers[peer_id] = true
				_built_world_peers.erase(peer_id)
		if (
			world_phase == WORLD_WAITING_FOR_READY
			and _pending_ready_peers.is_empty()
			and _transition_disconnects_pending.is_empty()
		):
			_activate_world_for_ready_peers(world_generation)
		_start_next_admission.call_deferred()
	elif (
		id != 1
		and world_phase == WORLD_WAITING_FOR_READY
		and multiplayer.multiplayer_peer.get_connection_status()
		== MultiplayerPeer.CONNECTION_CONNECTED
	):
		_send_world_built.call_deferred(
			world_generation, MapCatalog.get_definition_hash(map_id)
		)


func _on_connection_stopped() -> void:
	var was_server := _server_mode
	_reset_connection_state()
	if was_server:
		_reset_server_session()
	call_deferred("_reset_multiplayer_peer")
	if not DisplayServer.get_name().contains("headless") and not _map_mismatch:
		lobby.show_lobby()
		lobby.show_error("DISCONNECTED")


func _reset_multiplayer_peer() -> void:
	if not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _on_connection_failed() -> void:
	print("NETWORK connection failed")
	_reset_connection_state()
	call_deferred("_reset_multiplayer_peer")
	lobby.show_error("CONNECTION FAILED\nCHECK THE ADDRESS, UDP PORT, AND SERVER STATUS")


func _reset_connection_state() -> void:
	NetworkRollback.enabled = false
	game_state_synchronizer.public_visibility = false
	_approved_map_peers.clear()
	_bootstrap_ready_peers.clear()
	_pending_bootstrap_peers.clear()
	_pending_avatar_observers.clear()
	_map_agreement_deadlines.clear()
	_peer_teams.clear()
	_peer_character_variants.clear()
	_pending_prepare_peers.clear()
	_pending_ready_peers.clear()
	_built_world_peers.clear()
	_transition_disconnects_pending.clear()
	_transition_peer_ids.clear()
	_admission_queue.clear()
	_admission_peer_id = 0
	_admission_baseline_ready = false
	_admission_baseline_tick = -1
	_bootstrap_expected_peer_ids.clear()
	_bootstrap_generation = -1
	_bootstrap_definition_hash = ""
	_bootstrap_confirmed = false
	_transition_generation = -1
	_transition_map_id = ""
	_transition_definition_hash = ""
	_transition_baseline_tick = -1
	_prepare_deadline_ms = -1
	_ready_deadline_ms = -1
	_disconnect_flush_deadline_ms = -1
	_rotation_map_history.clear()
	_rotation_peer_ids.clear()
	_rotation_team_assignments.clear()
	_rotation_character_assignments.clear()
	world_generation = 0
	match_state_generation = 0
	world_phase = WORLD_COMMITTING
	_replace_bootstrap_world = true
	for id in avatars.keys():
		_remove_avatar(id, true)
	for retired_world_variant in _retired_worlds.keys():
		var retired_world := retired_world_variant as Node3D
		_retired_worlds.erase(retired_world)
		if is_instance_valid(retired_world):
			retired_world.free()


func _reset_server_session() -> void:
	var no_peers: Array[int] = []
	_rebuild_world(1, _startup_map_id, no_peers)
	red_score = 0
	blue_score = 0
	red_flag_state = FLAG_HOME
	red_flag_carrier = 0
	red_flag_position = red_home
	red_flag_return_tick = -1
	blue_flag_state = FLAG_HOME
	blue_flag_carrier = 0
	blue_flag_position = blue_home
	blue_flag_return_tick = -1
	round_over = false
	winner_team = -1
	round_restart_tick = -1
	round_number = 1
	objective_reset_tick = -1
	match_state_generation = 1
	world_phase = WORLD_ACTIVE
	world_activation_tick = NetworkTime.tick
	_rotation_map_history.assign([map_id])
	NetworkRollback.enabled = true


func _spawn_avatar(id: int, assigned_team: int = -1, assigned_character_variant: int = -1) -> void:
	if id <= 1 or avatars.has(id):
		return
	var avatar := player_scene.instantiate() as SkooshNetworkPlayer
	avatar.name = "Player_%d" % id
	avatar.peer_id = id
	avatar.set_multiplayer_authority(1)
	var avatar_input := avatar.get_node("Input") as SkooshNetworkInput
	avatar_input.set_multiplayer_authority(id)
	var state_sync := avatar.get_node("MultiplayerSynchronizer") as MultiplayerSynchronizer
	state_sync.public_visibility = false
	var rollback := avatar.get_node("RollbackSynchronizer") as RollbackSynchronizer
	rollback.visibility_filter.default_visibility = false
	players.add_child(avatar)
	avatars[id] = avatar
	if assigned_team < 0:
		assigned_team = int(_peer_teams.get(id, id % 2))
	if assigned_character_variant < 0:
		assigned_character_variant = int(_peer_character_variants.get(id, -1))
	var local_bot := _bot_mode and id == multiplayer.get_unique_id()
	avatar.configure_peer(
		id,
		get_team_spawn_transform(assigned_team, id, 0),
		local_bot,
		assigned_team,
		assigned_character_variant
	)
	avatar.set_gameplay_admitted(_approved_map_peers.has(id))
	if multiplayer.is_server():
		avatar.rollback_synchronizer.visibility_filter.update_visibility()
	_acceptance.record_avatar_spawn(id, assigned_character_variant, avatars.size(), multiplayer.is_server())
	print("NETWORK avatar spawned id=%d team=%s variant=%d variant_name=%s local_bot=%s node=%s" % [
		id, get_team_name(assigned_team), avatar.character_variant,
		SkooshNetworkPlayer.character_variant_name(avatar.character_variant), local_bot, avatar.get_path()
	])


func _set_peer_network_visibility(peer_id: int, visible: bool) -> void:
	if not multiplayer.is_server():
		return
	for avatar_variant in avatars.values():
		var avatar := avatar_variant as SkooshNetworkPlayer
		_set_avatar_peer_visibility(avatar, peer_id, visible)


func _set_game_state_visibility(peer_ids: Array[int], visible: bool) -> void:
	game_state_synchronizer.public_visibility = false
	for peer_id in peer_ids:
		game_state_synchronizer.set_visibility_for(peer_id, visible)


func _set_avatar_peer_visibility(
	avatar: SkooshNetworkPlayer, peer_id: int, visible: bool
) -> void:
	if avatar == null:
		return
	var state_sync := avatar.get_node("MultiplayerSynchronizer") as MultiplayerSynchronizer
	state_sync.set_visibility_for(peer_id, visible)
	var rollback := avatar.get_node("RollbackSynchronizer") as RollbackSynchronizer
	rollback.visibility_filter.set_visibility_for(peer_id, visible)
	rollback.visibility_filter.update_visibility()


func _assign_balanced_team() -> int:
	var red_count := 0
	var blue_count := 0
	for team_variant in _peer_teams.values():
		var team := int(team_variant)
		if team == TEAM_RED:
			red_count += 1
		elif team == TEAM_BLUE:
			blue_count += 1
	return TEAM_RED if red_count <= blue_count else TEAM_BLUE


func _assign_balanced_character_variant(new_peer_id: int) -> int:
	var counts: Array[int] = [0, 0, 0]
	for candidate_id in _peer_character_variants:
		if int(candidate_id) == new_peer_id:
			continue
		var variant := int(_peer_character_variants[candidate_id])
		if SkooshNetworkPlayer.is_character_variant_valid(variant):
			counts[variant] += 1
	var selected_variant := 0
	for variant_id in range(1, counts.size()):
		if counts[variant_id] < counts[selected_variant]:
			selected_variant = variant_id
	return selected_variant


func record_character_variant_observation(observed_peer_id: int, variant_id: int) -> void:
	var player := avatars.get(observed_peer_id) as SkooshNetworkPlayer
	if (
		player != null
		and player.character_variant == variant_id
		and SkooshNetworkPlayer.is_character_variant_valid(variant_id)
	):
		_acceptance.record_character_observation(observed_peer_id, variant_id)


func _remove_avatar(id: int, immediate: bool = false) -> void:
	_oob_recovery_safe_frames.erase(id)
	_acceptance.remove_avatar(id)
	if not avatars.has(id):
		return
	var avatar := avatars[id] as Node
	avatars.erase(id)
	if is_instance_valid(avatar):
		if immediate:
			avatar.free()
		else:
			avatar.queue_free()


func _approved_peer_ids() -> Array[int]:
	var result: Array[int] = []
	for peer_variant in _approved_map_peers.keys():
		var peer_id := int(peer_variant)
		if multiplayer.is_server() and peer_id not in multiplayer.get_peers():
			continue
		result.append(peer_id)
	result.sort()
	return result


func get_gameplay_peer_ids() -> Array[int]:
	return _approved_peer_ids()


func is_peer_gameplay_admitted(peer_id: int) -> bool:
	return world_phase == WORLD_ACTIVE and _approved_map_peers.has(peer_id)


func _rebuild_world(generation: int, next_map_id: String, peer_ids: Array[int]) -> void:
	if generation < world_generation or next_map_id not in MapCatalog.SELECTABLE_MAP_IDS:
		return
	var old_world := world
	var old_arena := red_platform.get_parent()
	var next_world := Node3D.new()
	next_world.name = "World_%d" % generation

	var next_terrain := TerrainScript.new()
	next_terrain.name = "Terrain"
	next_terrain.map_id = next_map_id
	next_world.add_child(next_terrain)
	var next_arena := old_arena.duplicate()
	next_arena.name = "CompactArena"
	next_world.add_child(next_arena)
	var next_landmarks := LandmarksScript.new()
	next_landmarks.name = "NeutralLandmarks"
	next_world.add_child(next_landmarks)
	for container_name in ["Players", "Projectiles", "Effects"]:
		var container := Node3D.new()
		container.name = container_name
		next_world.add_child(container)

	if is_instance_valid(old_world):
		_retire_world(old_world)
		if _replace_bootstrap_world:
			_retired_worlds.erase(old_world)
			old_world.free()
	_replace_bootstrap_world = false
	avatars.clear()
	_oob_recovery_safe_frames.clear()
	_acceptance.clear_character_observations()
	add_child(next_world)
	world = next_world
	terrain = world.get_node("Terrain")
	players = world.get_node("Players") as Node3D
	projectiles = world.get_node("Projectiles") as Node3D
	effects = world.get_node("Effects") as Node3D
	red_platform = world.get_node("CompactArena/RedPlatform") as StaticBody3D
	blue_platform = world.get_node("CompactArena/BluePlatform") as StaticBody3D
	red_flag = world.get_node("CompactArena/RedFlag") as SkooshNetworkFlag
	blue_flag = world.get_node("CompactArena/BlueFlag") as SkooshNetworkFlag
	neutral_landmarks = world.get_node("NeutralLandmarks")
	world_generation = generation
	map_id = next_map_id
	_configure_map()
	for peer_id in peer_ids:
		if _peer_teams.has(peer_id) and _peer_character_variants.has(peer_id):
			_spawn_avatar(
				peer_id, int(_peer_teams[peer_id]), int(_peer_character_variants[peer_id])
			)
	_validate_and_log_world()


func _retire_world(retired_world: Node3D) -> void:
	retired_world.visible = false
	for avatar_variant in avatars.values():
		var avatar := avatar_variant as SkooshNetworkPlayer
		if avatar != null:
			avatar.retire_for_rotation()
	for collision_variant in retired_world.find_children("*", "CollisionObject3D", true, false):
		var collision := collision_variant as CollisionObject3D
		collision.collision_layer = 0
		collision.collision_mask = 0
	for container_name in ["Projectiles", "Effects"]:
		var container := retired_world.get_node(container_name)
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	retired_world.process_mode = Node.PROCESS_MODE_DISABLED
	_retired_worlds[retired_world] = Time.get_ticks_msec() + RETIRED_WORLD_GRACE_MS
	print("WORLD retired generation_path=%s grace_ms=%d" % [
		retired_world.get_path(), RETIRED_WORLD_GRACE_MS,
	])


func _validate_and_log_world() -> void:
	var mesh_instance := terrain.get_node("TerrainMesh") as MeshInstance3D
	var collision_shape := terrain.get_node("TerrainCollision") as CollisionShape3D
	var expected_landmarks := 19 if map_id == "faultline_basin" else 31 if map_id == "cairn_steps" else 0
	var instance_ids: Array[int] = [
		world.get_instance_id(), terrain.get_instance_id(), mesh_instance.get_instance_id(),
		collision_shape.get_instance_id(), red_platform.get_instance_id(), blue_platform.get_instance_id(),
		red_flag.get_instance_id(), blue_flag.get_instance_id(), neutral_landmarks.get_instance_id(),
	]
	var contract_ok := (
		mesh_instance.mesh != null
		and collision_shape.shape != null
		and neutral_landmarks.get_child_count() == expected_landmarks
		and projectiles.get_child_count() == 0
		and effects.get_child_count() == 0
	)
	for instance_id in instance_ids:
		if _seen_world_instance_ids.has(instance_id):
			contract_ok = false
		_seen_world_instance_ids[instance_id] = true
	_world_contract_failed = _world_contract_failed or not contract_ok
	var mesh_size: Vector2 = terrain.get_mesh_size()
	var resolution: Vector2i = terrain.get_grid_resolution()
	var red_spawn := _world_contract_spawn_position(TEAM_RED)
	var blue_spawn := _world_contract_spawn_position(TEAM_BLUE)
	var signature := "%sx%s/%sx%s/%.3f,%.3f,%.3f/%s/%.2f,%.2f,%.2f/%.2f,%.2f,%.2f/%.2f,%.2f,%.2f/%.2f,%.2f,%.2f" % [
		int(mesh_size.x), int(mesh_size.y), resolution.x, resolution.y,
		terrain.height_at(0.0, 0.0), terrain.height_at(mesh_size.x * 0.2, 0.0),
		terrain.height_at(0.0, mesh_size.y * 0.2), map_config["landmark"],
		red_home.x, red_home.y, red_home.z, blue_home.x, blue_home.y, blue_home.z,
		red_spawn.x, red_spawn.y, red_spawn.z, blue_spawn.x, blue_spawn.y, blue_spawn.z,
	]
	print("WORLD built generation=%d map=%s hash=%s signature=%s landmarks=%d contract=%s" % [
		world_generation, map_id, MapCatalog.get_definition_hash(map_id), signature,
		neutral_landmarks.get_child_count(), "PASS" if contract_ok else "FAIL",
	])


func _world_contract_spawn_position(team: int) -> Vector3:
	var socket := ((map_config["spawn_sockets"] as Array)[team] as Array)[0] as Dictionary
	var planar := socket["position"] as Vector2
	var surface_y := red_platform_surface_y if team == TEAM_RED else blue_platform_surface_y
	if not bool(socket.get("on_platform", false)):
		surface_y = terrain.height_at(planar.x, planar.y)
	return Vector3(planar.x, surface_y + 0.08, planar.y)


func get_projectile_container() -> Node3D:
	return projectiles


func get_effect_container() -> Node3D:
	return effects


func is_world_active() -> bool:
	return world_phase == WORLD_ACTIVE


func is_node_in_active_world(node: Node) -> bool:
	return is_world_active() and is_instance_valid(world) and world.is_ancestor_of(node)


func get_spawn_transform(peer_id: int, respawn_count: int = 0) -> Transform3D:
	var player := avatars.get(peer_id) as SkooshNetworkPlayer
	var spawn_team := player.team if player != null and player.team >= 0 else peer_id % 2
	return get_team_spawn_transform(spawn_team, peer_id, respawn_count)


func get_team_spawn_transform(team: int, peer_id: int, respawn_count: int) -> Transform3D:
	if _acceptance_mode:
		var acceptance_center := map_config["acceptance_center"] as Vector2
		var acceptance_axis := map_config["acceptance_axis"] as Vector2
		var planar := acceptance_center + acceptance_axis * (-24.0 if team == TEAM_RED else 24.0)
		var position := Vector3(planar.x, terrain.height_at(planar.x, planar.y) + 0.08, planar.y)
		var direction := acceptance_axis if team == TEAM_RED else -acceptance_axis
		var yaw := atan2(-direction.x, -direction.y)
		return Transform3D(Basis(Vector3.UP, yaw), position)
	var team_sockets := (map_config["spawn_sockets"] as Array)[team] as Array
	var socket := team_sockets[absi(peer_id + respawn_count) % team_sockets.size()] as Dictionary
	var planar := socket["position"] as Vector2
	var surface_y := red_platform_surface_y if team == TEAM_RED else blue_platform_surface_y
	if not bool(socket.get("on_platform", false)):
		surface_y = terrain.height_at(planar.x, planar.y)
	var position := Vector3(planar.x, surface_y + 0.08, planar.y)
	var planar_direction := (socket["direction"] as Vector2).normalized()
	var direction := Vector3(planar_direction.x, 0.0, planar_direction.y)
	var yaw := atan2(-direction.x, -direction.z)
	return Transform3D(Basis(Vector3.UP, yaw), position)


func award_kill(attacker_peer_id: int, victim_peer_id: int) -> void:
	if not multiplayer.is_server() or attacker_peer_id == victim_peer_id:
		return
	var attacker := avatars.get(attacker_peer_id) as SkooshNetworkPlayer
	var victim := avatars.get(victim_peer_id) as SkooshNetworkPlayer
	if attacker != null and victim != null and attacker.team != victim.team:
		attacker.add_kill()
		_acceptance.record_kill()
		print("COMBAT kill attacker=%d victim=%d kills=%d" % [attacker_peer_id, victim_peer_id, attacker.kills])


func record_death() -> void:
	if multiplayer.is_server():
		_acceptance.record_death()


func record_disc_impact(damaged_enemies: int) -> void:
	if not multiplayer.is_server():
		return
	var impact_count := _acceptance.record_disc_impact(damaged_enemies)
	print("COMBAT disc impact=%d damaged=%d" % [impact_count, damaged_enemies])


func record_weapon_fire(slot: int) -> void:
	if not multiplayer.is_server() or slot < 0 or slot >= _acceptance.weapon_fires.size():
		return
	var fire_count := _acceptance.record_weapon_fire(slot, world_generation)
	print("COMBAT weapon fire slot=%d count=%d" % [slot + 1, fire_count])


func record_weapon_impact(slot: int, damaged_enemies: int) -> void:
	if not multiplayer.is_server() or slot < 0 or slot >= _acceptance.weapon_impacts.size():
		return
	var impact_count := _acceptance.record_weapon_impact(slot, damaged_enemies)
	print("COMBAT weapon impact slot=%d count=%d damaged=%d" % [
		slot + 1, impact_count, damaged_enemies,
	])


func record_weapon_hit(slot: int) -> void:
	if not multiplayer.is_server() or slot < 0 or slot >= _acceptance.weapon_hits.size():
		return
	var hit_count := _acceptance.record_weapon_hit(slot)
	print("COMBAT weapon hit slot=%d count=%d" % [slot + 1, hit_count])


func find_target_for(peer_id: int) -> SkooshNetworkPlayer:
	var nearest: SkooshNetworkPlayer
	var nearest_distance := INF
	var source := avatars.get(peer_id) as SkooshNetworkPlayer
	if source == null or not _approved_map_peers.has(peer_id):
		return null
	for id in avatars:
		if id == peer_id or not _approved_map_peers.has(id):
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
		return (red_home + blue_home) * 0.5
	var enemy_team := TEAM_BLUE if player.team == TEAM_RED else TEAM_RED
	var own_carrier := _get_flag_carrier(player.team)
	if _get_flag_carrier(enemy_team) == peer_id:
		if own_carrier != 0:
			var enemy := avatars.get(own_carrier) as SkooshNetworkPlayer
			if enemy != null:
				return enemy.global_position
		var home := red_home if player.team == TEAM_RED else blue_home
		return _route_bot_toward(player.global_position, home)
	if _get_flag_state(enemy_team) == FLAG_CARRIED:
		var carrier := avatars.get(_get_flag_carrier(enemy_team)) as SkooshNetworkPlayer
		if carrier != null:
			return carrier.global_position
	var objective := _get_flag_position(enemy_team)
	if _get_flag_state(enemy_team) == FLAG_HOME:
		return _route_bot_toward(player.global_position, objective)
	return objective


func _route_bot_toward(player_position: Vector3, objective: Vector3) -> Vector3:
	var route := MapCatalog.get_route(map_config, str(map_config["bot_route"]))
	var waypoints := route["waypoints"] as Array
	var player_planar := Vector2(player_position.x, player_position.z)
	var objective_planar := Vector2(objective.x, objective.z)
	var objective_distance := player_planar.distance_to(objective_planar)
	var best := objective_planar
	var best_player_distance := INF
	for waypoint_variant in waypoints:
		var waypoint := waypoint_variant as Vector2
		if waypoint.distance_to(objective_planar) + 6.0 >= objective_distance:
			continue
		var player_distance := player_planar.distance_to(waypoint)
		if player_distance < best_player_distance:
			best = waypoint
			best_player_distance = player_distance
	var height: float = terrain.height_at(best.x, best.y)
	if best.distance_to(objective_planar) < 0.1:
		height = objective.y
	return Vector3(best.x, height, best.y)


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
	return world_phase == WORLD_ACTIVE and not round_over


func player_carries_enemy_flag(player: SkooshNetworkPlayer) -> bool:
	if player == null:
		return false
	var enemy_team := TEAM_BLUE if player.team == TEAM_RED else TEAM_RED
	return _get_flag_state(enemy_team) == FLAG_CARRIED and _get_flag_carrier(enemy_team) == player.peer_id


func get_team_name(team: int) -> String:
	return "RED" if team == TEAM_RED else "BLUE"


func get_capture_limit() -> int:
	return score_limit


func is_objective_resetting() -> bool:
	return objective_reset_tick >= 0 and NetworkTime.tick < objective_reset_tick


func get_flag_status(team: int) -> String:
	var state := _get_flag_state(team)
	if state == FLAG_HOME:
		return "HOME"
	if state == FLAG_DROPPED:
		return "DROPPED"
	return "TAKEN"


func get_voice_commands() -> Array:
	return VOICE_COMMANDS


func send_voice_command(command_id: int, scope: int = VoiceCommandLibrary.SCOPE_TEAM) -> void:
	if not is_peer_gameplay_admitted(multiplayer.get_unique_id()):
		return
	if multiplayer.is_server():
		_broadcast_voice_command(multiplayer.get_unique_id(), command_id, scope)
	else:
		_request_voice_command.rpc_id(1, world_generation, command_id, scope)


@rpc("any_peer", "reliable", "call_remote")
func _request_voice_command(generation: int, command_id: int, scope: int) -> void:
	if (
		not multiplayer.is_server()
		or generation != world_generation
		or not is_world_active()
		or not _approved_map_peers.has(multiplayer.get_remote_sender_id())
		or command_id < 0
		or command_id >= VOICE_COMMANDS.size()
		or scope not in [VoiceCommandLibrary.SCOPE_TEAM, VoiceCommandLibrary.SCOPE_GLOBAL]
	):
		return
	var sender := multiplayer.get_remote_sender_id()
	var previous_request_tick := int(_last_voice_request_tick.get(sender, -100000))
	if NetworkTime.tick - previous_request_tick < 15:
		return
	_last_voice_request_tick[sender] = NetworkTime.tick
	_broadcast_voice_command(sender, command_id, scope)


func _broadcast_voice_command(speaker_peer_id: int, command_id: int, scope: int) -> void:
	if (
		not multiplayer.is_server()
		or command_id < 0
		or command_id >= VOICE_COMMANDS.size()
		or scope not in [VoiceCommandLibrary.SCOPE_TEAM, VoiceCommandLibrary.SCOPE_GLOBAL]
	):
		return
	var speaker := avatars.get(speaker_peer_id) as SkooshNetworkPlayer
	if speaker == null or not speaker.gameplay_admitted:
		return
	var previous_tick := int(_last_voice_command_tick.get(speaker_peer_id, -100000))
	if NetworkTime.tick - previous_tick < VOICE_COMMAND_COOLDOWN_TICKS:
		return
	if scope == VoiceCommandLibrary.SCOPE_GLOBAL:
		if NetworkTime.tick - _last_global_voice_tick < VOICE_CHANNEL_COOLDOWN_TICKS:
			return
		_last_global_voice_tick = NetworkTime.tick
	else:
		var previous_team_tick := int(_last_team_voice_tick.get(speaker.team, -100000))
		if NetworkTime.tick - previous_team_tick < VOICE_CHANNEL_COOLDOWN_TICKS:
			return
		_last_team_voice_tick[speaker.team] = NetworkTime.tick
	_last_voice_command_tick[speaker_peer_id] = NetworkTime.tick
	_acceptance.record_voice_relay()
	for avatar_variant in avatars.values():
		var listener := avatar_variant as SkooshNetworkPlayer
		if (
			listener != null
			and listener.gameplay_admitted
			and (scope == VoiceCommandLibrary.SCOPE_GLOBAL or listener.team == speaker.team)
		):
			_receive_voice_command.rpc_id(
				listener.peer_id, world_generation, speaker_peer_id, command_id, scope
			)
	print("VOICE speaker=%d team=%s scope=%s voice=%s command=%s" % [
		speaker_peer_id,
		get_team_name(speaker.team),
		VoiceCommandLibrary.scope_name(scope),
		VoiceCommandLibrary.pack_name_for_peer(speaker_peer_id),
		VOICE_COMMANDS[command_id]["label"],
	])


@rpc("authority", "reliable", "call_remote")
func _receive_voice_command(
	generation: int, speaker_peer_id: int, command_id: int, scope: int
) -> void:
	if (
		generation != world_generation
		or not is_world_active()
		or command_id < 0
		or command_id >= VOICE_COMMANDS.size()
		or scope not in [VoiceCommandLibrary.SCOPE_TEAM, VoiceCommandLibrary.SCOPE_GLOBAL]
	):
		return
	var local_player := avatars.get(multiplayer.get_unique_id()) as SkooshNetworkPlayer
	if local_player != null:
		local_player.hud.play_voice_command(speaker_peer_id, command_id, scope)
		print("VOICE received listener=%d speaker=%d scope=%s voice=%s command=%s" % [
			local_player.peer_id,
			speaker_peer_id,
			VoiceCommandLibrary.scope_name(scope),
			VoiceCommandLibrary.pack_name_for_peer(speaker_peer_id),
			VOICE_COMMANDS[command_id]["label"],
		])


func _process(_delta: float) -> void:
	_collect_retired_worlds()
	if multiplayer.is_server() and not _map_agreement_deadlines.is_empty():
		var now := Time.get_ticks_msec()
		for peer_variant in _map_agreement_deadlines.keys():
			var peer_id := int(peer_variant)
			if now < int(_map_agreement_deadlines[peer_id]):
				continue
			print("MAP agreement timeout peer=%d server=%s rejection=disconnect" % [peer_id, map_id])
			_reject_admission(peer_id, "deadline")
	if multiplayer.is_server() and world_phase == WORLD_PREPARING:
		_check_prepare_timeout()
	elif multiplayer.is_server() and world_phase == WORLD_WAITING_FOR_READY:
		_check_ready_barrier()
	_acceptance.sample_network(
		NetworkPerformance.get_rollback_ticks(),
		NetworkPerformance.get_network_loop_duration_ms()
	)
	_present_flags()


func _collect_retired_worlds() -> void:
	var now := Time.get_ticks_msec()
	for world_variant in _retired_worlds.keys():
		var retired_world := world_variant as Node3D
		if now < int(_retired_worlds[retired_world]):
			continue
		_retired_worlds.erase(retired_world)
		if is_instance_valid(retired_world):
			print("WORLD tombstone freed path=%s" % retired_world.get_path())
			retired_world.queue_free()


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
	if world_phase == WORLD_PREPARING:
		if NetworkTime.tick >= round_restart_tick:
			_commit_rotation()
		return
	if world_phase != WORLD_ACTIVE:
		return
	for avatar in avatars.values():
		var player := avatar as SkooshNetworkPlayer
		if not player.gameplay_admitted:
			continue
		_acceptance.sample_movement(world_generation, player.total_speed, player.jet_active)
		var position: Vector3 = player.global_position
		var outside: bool = not terrain.is_within_playable_boundary(Vector2(position.x, position.z))
		var far_below := position.y < float(terrain.height_at(position.x, position.z)) - 35.0
		var needs_recovery: bool = outside or far_below
		if needs_recovery:
			var first_recovery := not _oob_recovery_safe_frames.has(player.peer_id)
			var recovery_state := _oob_recovery_safe_frames.get(player.peer_id, {
				"safe_frames": 0,
				"unsafe_frames": 0,
			}) as Dictionary
			recovery_state["safe_frames"] = 0
			var unsafe_frames := int(recovery_state["unsafe_frames"]) + 1
			# Rollback may briefly restore a pre-teleport OOB snapshot. Suppress
			# per-frame respawns, but retry if the authoritative body remains unsafe.
			if first_recovery or unsafe_frames >= OOB_RECOVERY_RETRY_FRAMES:
				player.request_authoritative_respawn(false, true)
				unsafe_frames = 0
			recovery_state["unsafe_frames"] = unsafe_frames
			_oob_recovery_safe_frames[player.peer_id] = recovery_state
		elif _oob_recovery_safe_frames.has(player.peer_id):
			var recovery_state := _oob_recovery_safe_frames[player.peer_id] as Dictionary
			recovery_state["unsafe_frames"] = 0
			var safe_frames := int(recovery_state["safe_frames"]) + 1
			if safe_frames >= OOB_RECOVERY_SAFE_FRAMES:
				_oob_recovery_safe_frames.erase(player.peer_id)
			else:
				recovery_state["safe_frames"] = safe_frames
				_oob_recovery_safe_frames[player.peer_id] = recovery_state
	if round_over:
		if NetworkTime.tick >= round_restart_tick:
			_start_new_round()
		return
	if objective_reset_tick >= 0:
		if NetworkTime.tick >= objective_reset_tick:
			_finish_objective_reset()
		return
	if _require_rotation and _drive_rotation_acceptance():
		return
	_advance_acceptance_capture_contacts()
	_update_ctf_state()


func _drive_rotation_acceptance() -> bool:
	if (
		not bool(_acceptance.generation_movement.get(world_generation, false))
		or not bool(_acceptance.generation_combat.get(world_generation, false))
		or (
			world_generation >= 3
			and int(_acceptance.generation_captures.get(world_generation, 0)) >= 1
		)
	):
		return false
	var red_player: SkooshNetworkPlayer
	for avatar_variant in avatars.values():
		var candidate := avatar_variant as SkooshNetworkPlayer
		if candidate != null and candidate.team == TEAM_RED and not candidate.dead:
			red_player = candidate
			break
	if red_player == null:
		return false
	# The acceptance driver uses the same authoritative spatial contact path as a
	# live capture; it only removes route traversal time from the rotation test.
	red_player.global_position = blue_home
	_process_player_flag_contact(red_player)
	red_player.global_position = red_home
	_process_player_flag_contact(red_player)
	return true


func _update_ctf_state() -> void:
	_validate_flag_carrier(TEAM_RED)
	_validate_flag_carrier(TEAM_BLUE)
	_return_expired_flag(TEAM_RED)
	_return_expired_flag(TEAM_BLUE)
	_observe_acceptance_full_route()
	for avatar in avatars.values():
		var player := avatar as SkooshNetworkPlayer
		if player.dead or player.team < 0 or not _approved_map_peers.has(player.peer_id):
			continue
		_process_player_flag_contact(player)
		if round_over or objective_reset_tick >= 0:
			return


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
	if _acceptance_mode and _require_ctf and _acceptance.ctf_captures == 0:
		var route := MapCatalog.get_route(map_config, str(map_config["bot_route"]))
		var waypoints := route["waypoints"] as Array
		_acceptance_route_carrier = player.peer_id
		_acceptance_route_step = -1 if player.team == TEAM_RED else 1
		_acceptance_route_next_index = waypoints.size() - 2 if player.team == TEAM_RED else 1
		_acceptance_route_points_observed = 1
		_acceptance_route_complete = false
		print("ACCEPT CTF full-route tracking player=%d map=%s route=%s waypoint=pickup points=1/%d" % [
			player.peer_id, map_id, route["id"], waypoints.size(),
		])


func _observe_acceptance_full_route() -> void:
	if (
		not _acceptance_mode
		or not _require_ctf
		or _acceptance.full_route_captures > 0
		or _acceptance_route_complete
		or _acceptance_route_carrier == 0
	):
		return
	var player := avatars.get(_acceptance_route_carrier) as SkooshNetworkPlayer
	if player == null:
		return
	var enemy_team := TEAM_BLUE if player.team == TEAM_RED else TEAM_RED
	if (
		_get_flag_state(enemy_team) != FLAG_CARRIED
		or _get_flag_carrier(enemy_team) != player.peer_id
	):
		return
	var route := MapCatalog.get_route(map_config, str(map_config["bot_route"]))
	var waypoints := route["waypoints"] as Array
	if _acceptance_route_next_index < 0 or _acceptance_route_next_index >= waypoints.size():
		return
	var waypoint := waypoints[_acceptance_route_next_index] as Vector2
	var player_planar := Vector2(player.global_position.x, player.global_position.z)
	if player_planar.distance_to(waypoint) > ACCEPTANCE_ROUTE_CONTACT_RADIUS:
		return
	_acceptance_route_points_observed += 1
	print("ACCEPT CTF full-route waypoint player=%d map=%s route=%s index=%d points=%d/%d" % [
		player.peer_id, map_id, route["id"], _acceptance_route_next_index,
		_acceptance_route_points_observed, waypoints.size(),
	])
	_acceptance_route_next_index += _acceptance_route_step
	if _acceptance_route_next_index < 0 or _acceptance_route_next_index >= waypoints.size():
		_acceptance_route_complete = true
		print("ACCEPT CTF full-route validated player=%d map=%s route=%s points=%d/%d" % [
			player.peer_id, map_id, route["id"], _acceptance_route_points_observed, waypoints.size(),
		])


func _advance_acceptance_capture_contacts() -> void:
	if (
		not _acceptance_mode
		or not _require_ctf
		or _acceptance.full_route_captures != 1
		or _acceptance.ctf_captures < 1
		or _acceptance.ctf_captures >= score_limit
		or round_over
	):
		return
	var player := avatars.get(_acceptance_route_carrier) as SkooshNetworkPlayer
	if player == null or player.dead:
		return
	var enemy_team := TEAM_BLUE if player.team == TEAM_RED else TEAM_RED
	if _acceptance_capture_phase == ACCEPTANCE_CAPTURE_IDLE:
		if _get_flag_state(enemy_team) != FLAG_HOME or _get_flag_state(player.team) != FLAG_HOME:
			return
		if not _acceptance_acceleration_started:
			_acceptance_acceleration_started = true
			print("ACCEPT CTF acceleration enabled player=%d after_full_route_captures=%d" % [
				player.peer_id, _acceptance.full_route_captures,
			])
		player.apply_acceptance_contact_position(_acceptance_contact_position(enemy_team))
		_acceptance_capture_phase = ACCEPTANCE_CAPTURE_PICKUP
		print("ACCEPT CTF contact positioned player=%d contact=pickup capture_target=%d" % [
			player.peer_id, _acceptance.ctf_captures + 1,
		])
	elif (
		_acceptance_capture_phase == ACCEPTANCE_CAPTURE_PICKUP
		and _get_flag_state(enemy_team) == FLAG_CARRIED
		and _get_flag_carrier(enemy_team) == player.peer_id
	):
		player.apply_acceptance_contact_position(_acceptance_contact_position(player.team))
		_acceptance_capture_phase = ACCEPTANCE_CAPTURE_HOME
		print("ACCEPT CTF contact positioned player=%d contact=capture capture_target=%d" % [
			player.peer_id, _acceptance.ctf_captures + 1,
		])


func _acceptance_contact_position(team: int) -> Vector3:
	var home := red_home if team == TEAM_RED else blue_home
	var surface_y := red_platform_surface_y if team == TEAM_RED else blue_platform_surface_y
	return Vector3(home.x, surface_y + 0.08, home.z)


func _capture_flag(player: SkooshNetworkPlayer, enemy_flag_team: int) -> bool:
	if (
		not multiplayer.is_server()
		or round_over
		or objective_reset_tick >= 0
		or player == null
		or player.dead
		or enemy_flag_team == player.team
		or _get_flag_state(enemy_flag_team) != FLAG_CARRIED
		or _get_flag_carrier(enemy_flag_team) != player.peer_id
	):
		return false
	var full_route_capture := (
		_acceptance.ctf_captures == 0
		and player.peer_id == _acceptance_route_carrier
		and _acceptance_route_complete
	)
	var accelerated_capture := (
		_acceptance_capture_phase == ACCEPTANCE_CAPTURE_HOME
		and player.peer_id == _acceptance_route_carrier
	)
	if player.team == TEAM_RED:
		red_score += 1
	else:
		blue_score += 1
	_acceptance.record_capture(world_generation, full_route_capture, accelerated_capture)
	var route_evidence := "full" if full_route_capture else ("acceptance_contacts" if accelerated_capture else "standard")
	print("CTF capture player=%d team=%s score=%d-%d route=%s" % [
		player.peer_id, get_team_name(player.team), red_score, blue_score, route_evidence,
	])
	_acceptance_capture_phase = ACCEPTANCE_CAPTURE_IDLE
	if red_score >= score_limit or blue_score >= score_limit:
		_acceptance.record_capture_outcome(true)
		_reset_objectives("match won")
		_end_round(player.team)
	else:
		_acceptance.record_capture_outcome(false)
		_start_objective_reset()
	if _require_ctf or _require_map_baseline:
		# Replay the just-consumed contact once to prove stale delivery cannot score.
		var score_after_award := Vector2i(red_score, blue_score)
		var duplicate_rejected := (
			not _capture_flag(player, enemy_flag_team)
			and Vector2i(red_score, blue_score) == score_after_award
		)
		_acceptance.record_duplicate_capture(duplicate_rejected)
	return true


func _start_objective_reset() -> void:
	_reset_objectives("capture reset")
	objective_reset_tick = NetworkTime.tick + OBJECTIVE_RESET_TICKS
	print("CTF objective reset score=%d-%d ready_tick=%d" % [
		red_score, blue_score, objective_reset_tick,
	])


func _finish_objective_reset() -> void:
	objective_reset_tick = -1
	_reset_objectives("objective ready")
	_acceptance.objective_resets_completed += 1
	print("CTF objective ready score=%d-%d" % [red_score, blue_score])


func _reset_objectives(reason: String) -> void:
	_return_flag_home(TEAM_RED, reason)
	_return_flag_home(TEAM_BLUE, reason)


func _end_round(team: int) -> void:
	round_over = true
	winner_team = team
	round_restart_tick = NetworkTime.tick + ROUND_RESTART_TICKS
	_acceptance.completed_rounds += 1
	print("CTF win team=%s round=%d score=%d-%d restart_tick=%d" % [
		get_team_name(team), round_number, red_score, blue_score, round_restart_tick
	])
	if map_id in MapCatalog.ROTATION_MAP_IDS and not _require_map_baseline:
		_begin_rotation()


func _begin_rotation() -> void:
	if not multiplayer.is_server() or world_phase != WORLD_ACTIVE:
		return
	if _admission_peer_id != 0:
		var interrupted_peer := _admission_peer_id
		print("MAP admission interrupted peer=%d reason=world_transition rejection=disconnect" % interrupted_peer)
		_reject_admission(interrupted_peer, "world_transition")
	_transition_generation = world_generation + 1
	_transition_map_id = MapCatalog.get_next_rotation_id(map_id)
	_transition_definition_hash = MapCatalog.get_definition_hash(_transition_map_id)
	world_phase = WORLD_PREPARING
	NetworkRollback.enabled = false
	_set_game_state_visibility(multiplayer.get_peers(), false)
	if _rotation_peer_ids.is_empty():
		_rotation_peer_ids = _approved_peer_ids()
		_rotation_team_assignments = _peer_teams.duplicate()
		_rotation_character_assignments = _peer_character_variants.duplicate()
	_transition_peer_ids = _approved_peer_ids()
	_pending_prepare_peers.clear()
	for peer_id in _transition_peer_ids:
		_pending_prepare_peers[peer_id] = true
	_prepare_deadline_ms = Time.get_ticks_msec() + WORLD_PREPARE_TIMEOUT_MS
	for peer_id in _transition_peer_ids:
		_prepare_world.rpc_id(
			peer_id, _transition_generation, _transition_map_id,
			_transition_definition_hash, round_restart_tick
		)
	print("WORLD prepare generation=%d map=%s peers=%s deadline_ms=%d" % [
		_transition_generation, _transition_map_id, _transition_peer_ids, _prepare_deadline_ms,
	])


@rpc("authority", "reliable", "call_remote")
func _prepare_world(
	generation: int, next_map_id: String, definition_hash: String, commit_tick: int
) -> void:
	if multiplayer.is_server() or generation <= world_generation:
		return
	if (
		generation != world_generation + 1
		or next_map_id not in MapCatalog.ROTATION_MAP_IDS
		or definition_hash != MapCatalog.get_definition_hash(next_map_id)
	):
		return
	_transition_generation = generation
	_transition_map_id = next_map_id
	_transition_definition_hash = definition_hash
	round_restart_tick = commit_tick
	world_phase = WORLD_PREPARING
	NetworkRollback.enabled = false
	_ack_world_prepared.rpc_id(1, generation, definition_hash)
	print("WORLD prepared peer=%d generation=%d map=%s" % [
		multiplayer.get_unique_id(), generation, next_map_id,
	])


@rpc("any_peer", "reliable", "call_remote")
func _ack_world_prepared(generation: int, definition_hash: String) -> void:
	if (
		not multiplayer.is_server()
		or world_phase != WORLD_PREPARING
		or generation != _transition_generation
		or definition_hash != _transition_definition_hash
	):
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if _pending_prepare_peers.erase(peer_id):
		print("WORLD prepare acknowledged peer=%d generation=%d" % [peer_id, generation])


func _check_prepare_timeout() -> void:
	if _pending_prepare_peers.is_empty() or Time.get_ticks_msec() < _prepare_deadline_ms:
		return
	for peer_variant in _pending_prepare_peers.keys():
		var peer_id := int(peer_variant)
		print("WORLD prepare timeout peer=%d generation=%d rejection=disconnect" % [
			peer_id, _transition_generation,
		])
		_disconnect_transition_peer(peer_id)
	_pending_prepare_peers.clear()


func _commit_rotation() -> void:
	if not multiplayer.is_server() or world_phase != WORLD_PREPARING:
		return
	for peer_variant in _pending_prepare_peers.keys():
		_disconnect_transition_peer(int(peer_variant))
	_pending_prepare_peers.clear()
	var peer_ids: Array[int] = []
	for peer_id in _transition_peer_ids:
		if peer_id in multiplayer.get_peers() and _approved_map_peers.has(peer_id):
			peer_ids.append(peer_id)
	var team_assignments: Dictionary = {}
	var character_assignments: Dictionary = {}
	for peer_id in peer_ids:
		team_assignments[peer_id] = _peer_teams[peer_id]
		character_assignments[peer_id] = _peer_character_variants[peer_id]
	_pending_ready_peers.clear()
	_built_world_peers.clear()
	for peer_id in peer_ids:
		_pending_ready_peers[peer_id] = true
	world_phase = WORLD_COMMITTING
	_commit_world(
		_transition_generation, _transition_map_id, _transition_definition_hash,
		peer_ids, team_assignments, character_assignments
	)
	_transition_baseline_tick = -1
	_ready_deadline_ms = Time.get_ticks_msec() + WORLD_READY_TIMEOUT_MS
	for peer_id in peer_ids:
		_commit_world.rpc_id(
			peer_id, _transition_generation, _transition_map_id, _transition_definition_hash,
			peer_ids, team_assignments, character_assignments
		)
	if _pending_ready_peers.is_empty():
		_activate_world_for_ready_peers(_transition_generation)


@rpc("authority", "reliable", "call_local")
func _commit_world(
	generation: int,
	next_map_id: String,
	definition_hash: String,
	peer_ids: Array[int],
	team_assignments: Dictionary,
	character_assignments: Dictionary
) -> void:
	if (
		generation != world_generation + 1
		or next_map_id not in MapCatalog.ROTATION_MAP_IDS
		or definition_hash != MapCatalog.get_definition_hash(next_map_id)
	):
		return
	NetworkRollback.enabled = false
	world_phase = WORLD_COMMITTING
	_approved_map_peers.clear()
	_peer_teams.clear()
	_peer_character_variants.clear()
	for peer_id in peer_ids:
		_approved_map_peers[peer_id] = true
		_peer_teams[peer_id] = int(team_assignments[peer_id])
		_peer_character_variants[peer_id] = int(character_assignments[peer_id])
	_rebuild_world(generation, next_map_id, peer_ids)
	world_phase = WORLD_WAITING_FOR_READY
	print("WORLD committed peer=%d generation=%d map=%s avatars=%d" % [
		multiplayer.get_unique_id(), world_generation, map_id, avatars.size(),
	])
	if not multiplayer.is_server():
		_send_world_built.call_deferred(generation, definition_hash)


func _seed_server_rollback_baseline(baseline_tick: int) -> void:
	for avatar_variant in avatars.values():
		var avatar := avatar_variant as SkooshNetworkPlayer
		var synchronizer := avatar.rollback_synchronizer
		synchronizer.process_settings()
		synchronizer.apply_authoritative_baseline(
			baseline_tick, synchronizer.capture_authoritative_baseline()
		)


func _send_world_built(generation: int, definition_hash: String) -> void:
	if (
		multiplayer.is_server()
		or generation != world_generation
		or definition_hash != MapCatalog.get_definition_hash(map_id)
	):
		return
	if _skip_transition_ready_for_test and generation > 1:
		print("WORLD ready intentionally skipped peer=%d generation=%d" % [
			multiplayer.get_unique_id(), generation,
		])
	_ack_world_built.rpc_id(1, generation, definition_hash, avatars.size())


@rpc("any_peer", "reliable", "call_remote")
func _ack_world_built(
	generation: int, definition_hash: String, avatar_count: int
) -> void:
	if (
		not multiplayer.is_server()
		or world_phase != WORLD_WAITING_FOR_READY
		or generation != world_generation
		or definition_hash != MapCatalog.get_definition_hash(map_id)
		or avatar_count != avatars.size()
	):
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _pending_ready_peers.has(peer_id) or _built_world_peers.has(peer_id):
		return
	if _transition_baseline_tick < 0:
		_transition_baseline_tick = NetworkTime.tick
		_seed_server_rollback_baseline(_transition_baseline_tick)
	_built_world_peers[peer_id] = true
	_send_rollback_baseline(peer_id, false, _transition_baseline_tick)
	print("WORLD built acknowledged peer=%d generation=%d baseline_tick=%d" % [
		peer_id, generation, _transition_baseline_tick,
	])


@rpc("any_peer", "reliable", "call_remote")
func _ack_world_ready(
	generation: int, definition_hash: String, avatar_count: int, baseline_tick: int
) -> void:
	if (
		not multiplayer.is_server()
		or world_phase != WORLD_WAITING_FOR_READY
		or generation != world_generation
		or definition_hash != MapCatalog.get_definition_hash(map_id)
		or avatar_count != avatars.size()
		or baseline_tick != _transition_baseline_tick
	):
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _built_world_peers.has(peer_id):
		return
	if _pending_ready_peers.erase(peer_id):
		_set_peer_network_visibility(peer_id, true)
		print("WORLD ready acknowledged peer=%d generation=%d baseline_tick=%d" % [
			peer_id, generation, baseline_tick,
		])


func _check_ready_barrier() -> void:
	if _pending_ready_peers.is_empty():
		if (
			_transition_disconnects_pending.is_empty()
			or Time.get_ticks_msec() >= _disconnect_flush_deadline_ms
		):
			_activate_world_for_ready_peers(world_generation)
		return
	if Time.get_ticks_msec() < _ready_deadline_ms:
		return
	for peer_variant in _pending_ready_peers.keys():
		var peer_id := int(peer_variant)
		print("WORLD ready timeout peer=%d generation=%d rejection=disconnect" % [
			peer_id, world_generation,
		])
		_disconnect_transition_peer(peer_id)
	if _pending_ready_peers.is_empty() and _transition_disconnects_pending.is_empty():
		_activate_world_for_ready_peers(world_generation)


func _activate_world_for_ready_peers(generation: int) -> void:
	if generation != world_generation or world_phase != WORLD_WAITING_FOR_READY:
		return
	_transition_baseline_tick = NetworkTime.tick
	_seed_server_rollback_baseline(_transition_baseline_tick)
	for peer_id in _transition_peer_ids:
		if not _approved_map_peers.has(peer_id):
			continue
		_send_rollback_baseline(peer_id, false, _transition_baseline_tick)
		_activate_world.rpc_id(peer_id, generation)
	_activate_world(generation)


@rpc("authority", "reliable", "call_local")
func _activate_world(generation: int) -> void:
	if generation != world_generation or world_phase != WORLD_WAITING_FOR_READY:
		return
	red_score = 0
	blue_score = 0
	objective_reset_tick = -1
	round_over = false
	winner_team = -1
	round_restart_tick = -1
	round_number += 1
	_acceptance.match_resets += 1
	match_state_generation = world_generation
	_return_flag_home(TEAM_RED, "rotated world")
	_return_flag_home(TEAM_BLUE, "rotated world")
	world_phase = WORLD_COMMITTING
	get_tree().create_timer(1.0).timeout.connect(
		_enable_rollback_after_world_build.bind(generation), CONNECT_ONE_SHOT
	)


func _enable_rollback_after_world_build(generation: int) -> void:
	if generation == world_generation and world_phase == WORLD_COMMITTING:
		NetworkRollback.enabled = true
		world_phase = WORLD_ACTIVE
		world_activation_tick = NetworkTime.tick
		if multiplayer.is_server():
			_set_game_state_visibility(_approved_peer_ids(), true)
		if _rotation_map_history.is_empty() or _rotation_map_history.back() != map_id:
			_rotation_map_history.append(map_id)
		print("WORLD active peer=%d generation=%d map=%s hash=%s avatars=%d" % [
			multiplayer.get_unique_id(), world_generation, map_id,
			MapCatalog.get_definition_hash(map_id), avatars.size(),
		])
		if multiplayer.is_server():
			_start_next_admission.call_deferred()


func _disconnect_transition_peer(peer_id: int) -> void:
	_pending_prepare_peers.erase(peer_id)
	_pending_ready_peers.erase(peer_id)
	_built_world_peers.erase(peer_id)
	_transition_peer_ids.erase(peer_id)
	_approved_map_peers.erase(peer_id)
	_bootstrap_ready_peers.erase(peer_id)
	_peer_teams.erase(peer_id)
	_peer_character_variants.erase(peer_id)
	_drop_flags_carried_by(peer_id)
	var avatar := avatars.get(peer_id) as SkooshNetworkPlayer
	if avatar != null:
		avatar.set_gameplay_admitted(false)
		_set_peer_network_visibility(peer_id, false)
	_remove_avatar(peer_id)
	if peer_id in multiplayer.get_peers():
		_transition_disconnects_pending[peer_id] = true
		_disconnect_flush_deadline_ms = Time.get_ticks_msec() + WORLD_DISCONNECT_FLUSH_MS
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)


func _start_new_round() -> void:
	red_score = 0
	blue_score = 0
	objective_reset_tick = -1
	round_over = false
	winner_team = -1
	round_restart_tick = -1
	round_number += 1
	_acceptance.match_resets += 1
	_return_flag_home(TEAM_RED, "new round")
	_return_flag_home(TEAM_BLUE, "new round")
	for avatar in avatars.values():
		(avatar as SkooshNetworkPlayer).request_authoritative_respawn(false)
	print("CTF match started match=%d score=%d-%d" % [round_number, red_score, blue_score])


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
		if _server_mode:
			print("ACCEPT player peer=%d team=%s position=%s speed=%.1f" % [
				player.peer_id, get_team_name(player.team), player.global_position, player.total_speed
			])
	var status := multiplayer.multiplayer_peer.get_connection_status()
	var peer_id := multiplayer.get_unique_id() if status == MultiplayerPeer.CONNECTION_CONNECTED else 0
	if _server_mode:
		total_kills = _acceptance.combat_kills
		total_deaths = _acceptance.combat_deaths
	var current_character_variants: Dictionary = {}
	for id in avatars:
		var player := avatars[id] as SkooshNetworkPlayer
		if SkooshNetworkPlayer.is_character_variant_valid(player.character_variant):
			current_character_variants[id] = player.character_variant
	var assigned_variant_ids: Dictionary = {}
	for variant_id in _acceptance.server_assigned_character_variants.values():
		assigned_variant_ids[int(variant_id)] = true
	var observed_variant_ids: Dictionary = {}
	for variant_id in _acceptance.observed_character_variants.values():
		observed_variant_ids[int(variant_id)] = true
	var current_variant_ids: Dictionary = {}
	for variant_id in current_character_variants.values():
		current_variant_ids[int(variant_id)] = true
	var character_visual_shells := 0
	for avatar in avatars.values():
		if (avatar as SkooshNetworkPlayer).has_character_visual_shell():
			character_visual_shells += 1
	var character_resources_cached := SkooshNetworkPlayer.character_variant_resources_cached()
	print("ACCEPT multiplayer peer=%d peak_avatars=%d current_avatars=%d kills=%d deaths=%d disc_impacts=%d disc_damage=%d weapon_fires=%s weapon_impacts=%s weapon_hits=%s voice=%d captures=%d full_route_captures=%d accelerated_captures=%d non_winning_captures=%d limit_wins=%d objective_resets=%d completed_matches=%d match_resets=%d duplicate_checks=%d duplicate_awards=%d score_limit=%d current_variant_peers=%d current_variants=%d assigned_variant_peers=%d assigned_variants=%d observed_variant_peers=%d observed_variants=%d peak_speed=%.1f jet=%s max_rollback=%d peak_net_ms=%.2f elapsed_ms=%d" % [
		peer_id, _acceptance.peak_avatars, avatars.size(), total_kills, total_deaths,
		_acceptance.disc_impacts, _acceptance.disc_damage_events,
		_acceptance.weapon_fires, _acceptance.weapon_impacts, _acceptance.weapon_hits,
		_acceptance.voice_commands_relayed,
		_acceptance.ctf_captures, _acceptance.full_route_captures,
		_acceptance.accelerated_captures, _acceptance.non_winning_captures,
		_acceptance.limit_wins, _acceptance.objective_resets_completed,
		_acceptance.completed_rounds, _acceptance.match_resets,
		_acceptance.duplicate_capture_checks, _acceptance.duplicate_capture_awards,
		score_limit,
		current_character_variants.size(), current_variant_ids.size(),
		_acceptance.server_assigned_character_variants.size(), assigned_variant_ids.size(),
		_acceptance.observed_character_variants.size(), observed_variant_ids.size(),
		_acceptance.peak_server_speed, _acceptance.server_saw_jet,
		_acceptance.peak_rollback_ticks, _acceptance.peak_network_loop_ms,
		Time.get_ticks_msec() - _test_started_at
	])
	var combat_failed := _acceptance.combat_failed(_require_combat, total_deaths, total_kills)
	var movement_failed := _acceptance.movement_failed(_require_movement)
	var ctf_failed := _acceptance.ctf_failed(
		_require_ctf, score_limit, _acceptance_mode, _require_rotation
	)
	var map_baseline_failed := _acceptance.map_baseline_failed(_require_map_baseline)
	var voice_failed := _acceptance.voice_failed(_require_voice)
	var variants_failed := false
	if _require_character_variants:
		if _server_mode:
			variants_failed = (
				current_character_variants.size() != avatars.size()
				or current_character_variants.size() < 2
				or current_variant_ids.size() < 2
				or _acceptance.server_assigned_character_variants != current_character_variants
				or not _acceptance.observed_character_variants.is_empty()
				or character_visual_shells != 0
				or character_resources_cached
			)
			print("ACCEPT character variants role=server result=%s current=%s assigned=%s observed=%s visual_shells=%d resources_cached=%s" % [
				"FAIL" if variants_failed else "PASS", current_character_variants,
				_acceptance.server_assigned_character_variants,
				_acceptance.observed_character_variants,
				character_visual_shells, character_resources_cached,
			])
		else:
			variants_failed = (
				current_character_variants.size() != avatars.size()
				or current_character_variants.size() < 2
				or current_variant_ids.size() < 2
				or _acceptance.observed_character_variants != current_character_variants
			)
			print("ACCEPT character variants role=client result=%s current=%s observed=%s" % [
				"FAIL" if variants_failed else "PASS", current_character_variants,
				_acceptance.observed_character_variants,
			])
	var rotation_failed := false
	if _require_rotation:
		var initial_rotation_map := (
			_rotation_map_history[0] if not _rotation_map_history.is_empty() else ""
		)
		var expected_rotation_history: Array[String] = [
			initial_rotation_map,
			MapCatalog.get_next_rotation_id(initial_rotation_map),
			initial_rotation_map,
		]
		if _server_mode:
			rotation_failed = (
				world_generation < 3
				or world_phase != WORLD_ACTIVE
				or map_id != initial_rotation_map
				or match_state_generation != world_generation
				or _rotation_map_history.slice(0, 3) != expected_rotation_history
				or _rotation_peer_ids != _approved_peer_ids()
				or _rotation_team_assignments != _peer_teams
				or _rotation_character_assignments != _peer_character_variants
				or avatars.size() != _approved_peer_ids().size()
				or avatars.size() != 2
				or int(_acceptance.generation_captures.get(1, 0)) < score_limit
				or int(_acceptance.generation_captures.get(2, 0)) < score_limit
				or int(_acceptance.generation_captures.get(3, 0)) < 1
				or not bool(_acceptance.generation_movement.get(1, false))
				or not bool(_acceptance.generation_movement.get(2, false))
				or not bool(_acceptance.generation_movement.get(3, false))
				or not bool(_acceptance.generation_combat.get(1, false))
				or not bool(_acceptance.generation_combat.get(2, false))
				or not bool(_acceptance.generation_combat.get(3, false))
				or _world_contract_failed
				or not _retired_worlds.is_empty()
				or get_node_or_null("World_1") != null
				or get_node_or_null("World_2") != null
			)
		else:
			rotation_failed = (
				world_generation < 3
				or world_phase != WORLD_ACTIVE
				or map_id != initial_rotation_map
				or match_state_generation != world_generation
				or avatars.size() != 2
				or _world_contract_failed
			)
		print("ACCEPT rotation role=%s result=%s generation=%d map=%s state_generation=%d history=%s peers=%s avatars=%d movement=%s combat=%s captures=%s" % [
			"server" if _server_mode else "client", "FAIL" if rotation_failed else "PASS",
			world_generation, map_id, match_state_generation, _rotation_map_history,
			_approved_peer_ids(), avatars.size(),
			_acceptance.generation_movement, _acceptance.generation_combat,
			_acceptance.generation_captures,
		])
	var test_failed := (
		combat_failed or movement_failed or ctf_failed or map_baseline_failed
		or voice_failed or variants_failed or rotation_failed
	)
	if test_failed:
		get_tree().quit(1)
	elif _server_mode and _require_character_variants:
		print("ACCEPT server shutdown grace=%.1fs for client variant validation" % TEST_SERVER_SHUTDOWN_GRACE_SECONDS)
		get_tree().create_timer(TEST_SERVER_SHUTDOWN_GRACE_SECONDS).timeout.connect(_finish_server_automated_test)
	elif _require_character_variants:
		print("ACCEPT client awaiting coordinated shutdown")
	else:
		get_tree().quit()


func _finish_server_automated_test() -> void:
	_finish_client_automated_test.rpc()
	get_tree().quit()


@rpc("authority", "reliable", "call_remote")
func _finish_client_automated_test() -> void:
	_on_connection_stopped()
	get_tree().create_timer(0.25).timeout.connect(get_tree().quit)
