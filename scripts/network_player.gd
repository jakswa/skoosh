extends MovementBody
class_name SkooshNetworkPlayer

@export_category("Combat")
@export var max_health := 100
@export var respawn_delay_ticks := 60

@export_category("Camera")
@export var base_fov := 80.0
@export var maximum_fov := 102.0
@export var fov_speed_start := 12.0
@export var fov_speed_full := 72.0
@export var fov_smoothing := 6.0

@onready var head := $Head as Node3D
@onready var camera := $Head/Camera3D as Camera3D
@onready var world_model := $WorldModel as Node3D
@onready var body_mesh := $WorldModel/BodyMesh as MeshInstance3D
@onready var name_label := $NameLabel as Label3D
@onready var input := $Input as SkooshNetworkInput
@onready var rollback_synchronizer := $RollbackSynchronizer as RollbackSynchronizer
@onready var tick_interpolator := $TickInterpolator as TickInterpolator
@onready var hud := $NetworkHUD as SkooshNetworkHUD
@onready var weapon := $Head/DiscLauncher as SkooshDiscLauncher

var peer_id := 0
var team := -1
var health := 100
var dead := false
var kills := 0
var deaths := 0
var respawn_tick := -1
var respawn_position := Vector3.ZERO
var respawn_yaw := 0.0
var teleport_tick := -1
var last_attacker := 0
var did_teleport := false
var _local_active := false
var _presented_team := -99


func _ready() -> void:
	configure_movement_body()
	health = max_health
	camera.current = false
	camera.fov = base_fov
	NetworkTime.on_tick.connect(_network_tick)
	NetworkTime.after_tick_loop.connect(_after_tick_loop)
	call_deferred("_finish_network_setup")


func configure_peer(id: int, spawn_transform: Transform3D, use_bot: bool, assigned_team: int = -1) -> void:
	peer_id = id
	team = assigned_team
	name = "Player_%d" % id
	global_transform = spawn_transform
	respawn_position = spawn_transform.origin
	respawn_yaw = spawn_transform.basis.get_euler().y
	input.bot_mode = use_bot
	_update_team_presentation()


func _finish_network_setup() -> void:
	set_multiplayer_authority(1)
	input.set_multiplayer_authority(peer_id)
	rollback_synchronizer.process_settings()
	if input.is_multiplayer_authority():
		activate_local_player()


func activate_local_player() -> void:
	if _local_active:
		return
	_local_active = true
	camera.current = true
	world_model.visible = false
	name_label.visible = false
	$Head/Camera3D/ViewGun.visible = true
	hud.bind(self)


func _rollback_tick(delta: float, tick: int, _is_fresh: bool) -> void:
	did_teleport = tick == teleport_tick
	if did_teleport:
		global_position = respawn_position
		rotation = Vector3(0.0, respawn_yaw, 0.0)
		head.rotation = Vector3.ZERO
		reset_movement_state()
	if dead:
		velocity = Vector3.ZERO
		return

	force_update_floor_state()
	rotate_y(input.look_delta.x)
	head.rotation.x = clampf(head.rotation.x + input.look_delta.y, deg_to_rad(-85.0), deg_to_rad(85.0))
	head.rotation.y = 0.0
	head.rotation.z = 0.0
	simulate_movement(input.movement, input.ski, input.jet, delta, NetworkTime.physics_factor)

	if input.reset and multiplayer.is_server():
		request_authoritative_respawn(false)


func _network_tick(_delta: float, tick: int) -> void:
	if multiplayer.is_server() and dead and tick >= respawn_tick:
		request_authoritative_respawn(false)


func _after_tick_loop() -> void:
	if did_teleport:
		tick_interpolator.teleport()


func _process(delta: float) -> void:
	if _presented_team != team:
		_update_team_presentation()
	if not _local_active:
		return
	var fov_t: float = clampf(
		(horizontal_speed - fov_speed_start) / maxf(1.0, fov_speed_full - fov_speed_start),
		0.0, 1.0
	)
	fov_t = fov_t * fov_t * (3.0 - 2.0 * fov_t)
	var target_fov := lerpf(base_fov, maximum_fov, fov_t)
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-fov_smoothing * delta))


func apply_damage(amount: int, attacker_peer_id: int) -> void:
	if not multiplayer.is_server() or dead:
		return
	health = maxi(0, health - clampi(amount, 0, max_health))
	last_attacker = attacker_peer_id
	print("COMBAT hit attacker=%d victim=%d health=%d" % [attacker_peer_id, peer_id, health])
	if health <= 0:
		_die()


func _die() -> void:
	if dead:
		return
	dead = true
	deaths += 1
	respawn_tick = NetworkTime.tick + respawn_delay_ticks
	velocity = Vector3.ZERO
	var arena := get_parent().get_parent()
	if arena.has_method("award_kill"):
		arena.award_kill(last_attacker, peer_id)
	if arena.has_method("record_death"):
		arena.record_death()
	print("COMBAT death victim=%d attacker=%d deaths=%d respawn_tick=%d" % [
		peer_id, last_attacker, deaths, respawn_tick
	])


func request_authoritative_respawn(
	count_death: bool = false,
	return_carried_flags_home: bool = false
) -> void:
	if not multiplayer.is_server():
		return
	if count_death:
		deaths += 1
	var arena := get_parent().get_parent()
	# Resolve carried objectives before moving the body. Otherwise a reset or
	# recovery can briefly put a carrier at their own base and satisfy capture.
	if arena.has_method("prepare_player_respawn"):
		arena.prepare_player_respawn(peer_id, return_carried_flags_home)
	var spawn_transform := Transform3D.IDENTITY
	if arena.has_method("get_spawn_transform"):
		spawn_transform = arena.get_spawn_transform(peer_id, deaths)
	respawn_position = spawn_transform.origin
	respawn_yaw = spawn_transform.basis.get_euler().y
	teleport_tick = NetworkTime.tick
	global_transform = spawn_transform
	head.rotation = Vector3.ZERO
	reset_movement_state()
	health = max_health
	dead = false
	respawn_tick = -1
	last_attacker = 0
	tick_interpolator.teleport()
	print("COMBAT respawn peer=%d position=%s" % [peer_id, respawn_position])


func add_kill() -> void:
	if multiplayer.is_server():
		kills += 1


func find_bot_target() -> SkooshNetworkPlayer:
	var arena := get_parent().get_parent()
	if arena.has_method("find_target_for"):
		return arena.find_target_for(peer_id)
	return null


func get_bot_objective_position() -> Vector3:
	var arena := get_parent().get_parent()
	if arena.has_method("get_bot_objective_position"):
		return arena.get_bot_objective_position(peer_id)
	return global_position - global_transform.basis.z * 20.0


func should_bot_fire() -> bool:
	var arena := get_parent().get_parent()
	return arena.has_method("should_bot_fire") and arena.should_bot_fire(peer_id)


func carries_enemy_flag() -> bool:
	var arena := get_parent().get_parent()
	return arena.has_method("player_carries_enemy_flag") and arena.player_carries_enemy_flag(self)


func get_telemetry() -> Dictionary:
	return get_movement_telemetry()


func _update_team_presentation() -> void:
	if not is_node_ready():
		return
	_presented_team = team
	var team_name := "RED" if team == 0 else "BLUE"
	var color := Color("#ff594d") if team == 0 else Color("#36bfff")
	if team < 0:
		team_name = "SYNCING"
		color = Color("#d8e0d2")
	name_label.text = "%s // %s" % [team_name, callsign_for_peer(peer_id)]
	name_label.modulate = color.lightened(0.25)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.32
	material.roughness = 0.68
	for mesh in get_tree().get_nodes_in_group("player_team_color"):
		if mesh is MeshInstance3D and world_model.is_ancestor_of(mesh):
			(mesh as MeshInstance3D).material_override = material


static func callsign_for_peer(id: int) -> String:
	const CALLSIGNS: Array[String] = [
		"KITE", "NOVA", "ROOK", "EMBER", "VAULT", "ORBIT", "RIFT", "COMET",
		"MICA", "VEX", "HALO", "PIKE", "ECHO", "BOLT", "WREN", "FLINT",
	]
	return CALLSIGNS[absi(id) % CALLSIGNS.size()]
