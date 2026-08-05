extends MovementBody
class_name SkooshNetworkPlayer

const CharacterMaterialRoles = preload("res://scripts/character_material_roles.gd")
const CHARACTER_VARIANT_NAMES: Array[String] = [
	"Vector Sprinter Mk II",
	"STRATOS Foilframe",
	"Khepri Triune Salvage",
]
const CHARACTER_VARIANT_PATHS: Array[String] = [
	"res://assets/models/characters/vector_sprinter_mk2.glb",
	"res://assets/models/characters/stratos_foilframe.glb",
	"res://assets/models/characters/khepri_triune_salvage.glb",
]
const CHARACTER_VARIANT_UNRESOLVED := -1

const WEAPON_COUNT := 4
const WEAPON_SWITCH_TICKS := 15
const WEAPON_NAMES: Array[String] = [
	"INDUCTION DISC", "ARC GRENADE", "GATLING", "LONGSHOT",
]
const WEAPON_ROLES: Array[String] = [
	"INTERCEPT", "AREA CONTROL", "TRACKING", "PRECISION",
]
const WEAPON_DETAILS: Array[String] = [
	"105 IMPACT / SPLASH 5.8m",
	"90 MAX / SPLASH 7.2m",
	"10-6 DMG / 600 RPM / 90m",
	"70 DMG / 220m",
]
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
@onready var name_label := $NameLabel as Label3D
@onready var input := $Input as SkooshNetworkInput
@onready var rollback_synchronizer := $RollbackSynchronizer as RollbackSynchronizer
@onready var tick_interpolator := $TickInterpolator as TickInterpolator
@onready var hud := $NetworkHUD as SkooshNetworkHUD
@onready var weapon := $Head/DiscLauncher as SkooshDiscLauncher
@onready var weapons: Array[Node] = [
	$Head/DiscLauncher, $Head/GrenadeLauncher, $Head/GatlingGun, $Head/SniperRifle,
]
@onready var view_gun := $Head/Camera3D/ViewGun as Node3D
@onready var view_weapon_proxies: Array[Node3D] = [
	$Head/Camera3D/ViewGun/ViewDiscProxy,
	$Head/Camera3D/ViewGun/ViewGrenadeProxy,
	$Head/Camera3D/ViewGun/ViewGatlingProxy,
	$Head/Camera3D/ViewGun/ViewSniperProxy,
]
@onready var world_weapon_proxies: Array[Node3D] = [
	$WorldModel/WorldWeaponProxies/WorldDiscProxy,
	$WorldModel/WorldWeaponProxies/WorldGrenadeProxy,
	$WorldModel/WorldWeaponProxies/WorldGatlingProxy,
	$WorldModel/WorldWeaponProxies/WorldSniperProxy,
]
@onready var view_gatling_rotor := $Head/Camera3D/ViewGun/ViewGatlingProxy/ViewGatlingRotor as Node3D
@onready var world_gatling_rotor := $WorldModel/WorldWeaponProxies/WorldGatlingProxy/WorldGatlingRotor as Node3D

var peer_id := 0
var team := -1
var character_variant := CHARACTER_VARIANT_UNRESOLVED:
	set(value):
		character_variant = value if is_character_variant_valid(value) else CHARACTER_VARIANT_UNRESOLVED
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
var active_weapon_slot := 0
var weapon_switch_tick := -100000
var _local_active := false
var _presented_team := -99
var _presented_variant := -1
var _reported_variant := -1
var _model_root: Node3D
var _suit_animation: AnimationPlayer
var _presented_weapon_slot := -1
var _view_gun_rest_position := Vector3.ZERO
var _view_gun_rest_rotation := Vector3.ZERO
var _disc_rotor: Node3D
var _charge_core: Node3D
var _charge_rest_position := Vector3.ZERO
var _charge_gate_position := Vector3.ZERO
var _charge_launch_time := 0.0
var _weapon_recoil := 0.0
var _rotor_speed := 0.45
var _gatling_spin_speed := 0.0
var _gatling_rail_kick := 0.0
var _view_gatling_rotor_rest_position := Vector3.ZERO
var _world_gatling_rotor_rest_position := Vector3.ZERO
var _charge_fraction := 1.0
var _retired := false
var gameplay_admitted := false


func _ready() -> void:
	configure_movement_body()
	health = max_health
	camera.current = false
	camera.fov = base_fov
	_view_gun_rest_position = view_gun.position
	_view_gun_rest_rotation = view_gun.rotation
	_view_gatling_rotor_rest_position = view_gatling_rotor.position
	_world_gatling_rotor_rest_position = world_gatling_rotor.position
	_disc_rotor = view_gun.find_child("DiscRotor", true, false) as Node3D
	_charge_core = view_gun.find_child("ChargeCore", true, false) as Node3D
	if _charge_core != null:
		_charge_rest_position = _charge_core.position
		_charge_gate_position = _charge_rest_position
		var muzzle_socket := view_gun.find_child("MuzzleSocket", true, false) as Node3D
		if muzzle_socket != null:
			_charge_gate_position = _charge_core.get_parent_node_3d().to_local(muzzle_socket.global_position)
	var all_weapon_proxies: Array[Node3D] = []
	all_weapon_proxies.append_array(view_weapon_proxies)
	all_weapon_proxies.append_array(world_weapon_proxies)
	for proxy: Node3D in all_weapon_proxies:
		for geometry_variant in proxy.find_children("*", "GeometryInstance3D", true, false):
			var geometry := geometry_variant as GeometryInstance3D
			geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for collision_variant in proxy.find_children("*", "CollisionObject3D", true, false):
			var collision := collision_variant as CollisionObject3D
			collision.collision_layer = 0
			collision.collision_mask = 0
	_update_weapon_proxy_visibility()
	NetworkTime.on_tick.connect(_network_tick)
	NetworkTime.after_tick_loop.connect(_after_tick_loop)
	call_deferred("_finish_network_setup")


func configure_peer(
	id: int,
	spawn_transform: Transform3D,
	use_bot: bool,
	assigned_team: int = -1,
	assigned_character_variant: int = -1
) -> void:
	peer_id = id
	team = assigned_team
	if is_character_variant_valid(assigned_character_variant):
		character_variant = assigned_character_variant
	name = "Player_%d" % id
	global_transform = spawn_transform
	respawn_position = spawn_transform.origin
	respawn_yaw = spawn_transform.basis.get_euler().y
	input.bot_mode = use_bot
	_update_character_presentation()
	_update_team_presentation()
	_report_character_variant()


func set_gameplay_admitted(admitted: bool) -> void:
	gameplay_admitted = admitted
	collision_layer = 1 if admitted else 0
	collision_mask = 1 if admitted else 0
	if not admitted:
		velocity = Vector3.ZERO


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
	if dead or not gameplay_admitted:
		velocity = Vector3.ZERO
		return
	var arena := get_game_root()
	if arena != null and arena.has_method("is_world_active") and not arena.is_world_active():
		velocity = Vector3.ZERO
		return
	set_requested_weapon_slot(input.weapon_slot, tick)

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
	if _presented_variant != character_variant:
		_update_character_presentation()
	if _presented_team != team:
		_update_team_presentation()
	if _presented_weapon_slot != active_weapon_slot:
		_update_weapon_proxy_visibility()
	if _suit_animation != null:
		_suit_animation.speed_scale = clampf(0.55 + horizontal_speed / 32.0, 0.55, 2.2)
	_update_gatling_presentation(delta)
	if not _local_active:
		return
	var fov_t: float = clampf(
		(horizontal_speed - fov_speed_start) / maxf(1.0, fov_speed_full - fov_speed_start),
		0.0, 1.0
	)
	fov_t = fov_t * fov_t * (3.0 - 2.0 * fov_t)
	var target_fov := lerpf(base_fov, maximum_fov, fov_t)
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-fov_smoothing * delta))
	_update_weapon_presentation(delta)


func present_weapon_fire(slot: int = 0) -> void:
	if not _local_active:
		return
	_weapon_recoil = 1.0
	if slot == 0:
		_rotor_speed += 16.0
		_charge_fraction = 0.0
		_charge_launch_time = 0.12
	elif slot == 2:
		_gatling_spin_speed = minf(42.0, _gatling_spin_speed + 18.0)
		_gatling_rail_kick = 1.0


func _update_weapon_presentation(delta: float) -> void:
	_weapon_recoil = move_toward(_weapon_recoil, 0.0, delta * 6.5)
	_charge_fraction = minf(1.0, _charge_fraction + delta / maxf(weapon.fire_cooldown, 0.01))
	_rotor_speed = lerpf(_rotor_speed, 0.45, 1.0 - exp(-4.0 * delta))
	var time := Time.get_ticks_msec() * 0.001
	var idle_offset := Vector3(sin(time * 1.3), cos(time * 1.7), 0.0) * 0.002
	var recoil_curve := _weapon_recoil * _weapon_recoil
	view_gun.position = (
		_view_gun_rest_position
		+ idle_offset
		+ Vector3(-0.012, 0.018, 0.105) * recoil_curve
	)
	view_gun.rotation = (
		_view_gun_rest_rotation
		+ Vector3(deg_to_rad(4.2), 0.0, deg_to_rad(-1.6)) * recoil_curve
	)
	if _disc_rotor != null:
		_disc_rotor.rotate_y(_rotor_speed * delta)
	if _charge_core != null:
		_charge_core.visible = active_weapon_slot == 0
		if _charge_launch_time > 0.0:
			_charge_launch_time = maxf(0.0, _charge_launch_time - delta)
			var launch_fraction := 1.0 - _charge_launch_time / 0.12
			launch_fraction = launch_fraction * launch_fraction * (3.0 - 2.0 * launch_fraction)
			_charge_core.position = _charge_rest_position.lerp(_charge_gate_position, launch_fraction)
			_charge_core.scale = Vector3.ONE * lerpf(1.0, 0.05, smoothstep(0.68, 1.0, launch_fraction))
		else:
			_charge_core.position = _charge_rest_position
			var eased_charge := _charge_fraction * _charge_fraction * (3.0 - 2.0 * _charge_fraction)
			_charge_core.scale = Vector3.ONE * lerpf(0.08, 1.0, eased_charge)


func _update_gatling_presentation(delta: float) -> void:
	var idle_speed := 1.4 if active_weapon_slot == 2 else 0.0
	_gatling_spin_speed = lerpf(
		_gatling_spin_speed, idle_speed, 1.0 - exp(-5.5 * delta)
	)
	_gatling_rail_kick = move_toward(_gatling_rail_kick, 0.0, delta * 8.0)
	var rotation_step := _gatling_spin_speed * delta
	view_gatling_rotor.rotate_z(rotation_step)
	world_gatling_rotor.rotate_z(rotation_step)
	var rail_travel := sin(Time.get_ticks_msec() * 0.052) * 0.035 * _gatling_rail_kick
	view_gatling_rotor.position = _view_gatling_rotor_rest_position + Vector3(0, 0, rail_travel)
	world_gatling_rotor.position = _world_gatling_rotor_rest_position + Vector3(0, 0, rail_travel)


func set_requested_weapon_slot(requested_slot: int, tick: int) -> void:
	var validated_slot := clampi(requested_slot, 0, WEAPON_COUNT - 1)
	if validated_slot == active_weapon_slot:
		return
	active_weapon_slot = validated_slot
	weapon_switch_tick = tick


func can_fire_weapon(slot: int) -> bool:
	return (
		slot == active_weapon_slot
		and NetworkTime.tick - weapon_switch_tick >= WEAPON_SWITCH_TICKS
	)


func get_selected_weapon() -> Node:
	return weapons[clampi(active_weapon_slot, 0, weapons.size() - 1)]


func get_weapon_readiness() -> float:
	var selected := get_selected_weapon()
	var cooldown_fraction := 1.0
	if selected.has_method("get_reload_fraction"):
		cooldown_fraction = float(selected.call("get_reload_fraction"))
	var switch_fraction := clampf(
		float(NetworkTime.tick - weapon_switch_tick) / float(WEAPON_SWITCH_TICKS), 0.0, 1.0
	)
	return minf(cooldown_fraction, switch_fraction)


func get_weapon_status() -> String:
	var slot := clampi(active_weapon_slot, 0, WEAPON_COUNT - 1)
	var readiness := get_weapon_readiness()
	var switch_settled := NetworkTime.tick - weapon_switch_tick >= WEAPON_SWITCH_TICKS
	var state := "SWITCHING" if not switch_settled else "READY" if readiness >= 1.0 else "CHARGING"
	return "%d %s // %s\n%s // %s" % [
		slot + 1,
		WEAPON_NAMES[slot],
		state,
		WEAPON_ROLES[slot],
		WEAPON_DETAILS[slot],
	]


func _update_weapon_proxy_visibility() -> void:
	_presented_weapon_slot = active_weapon_slot
	var slot := clampi(active_weapon_slot, 0, WEAPON_COUNT - 1)
	for index in WEAPON_COUNT:
		view_weapon_proxies[index].visible = index == slot
		world_weapon_proxies[index].visible = index == slot


func apply_damage(amount: int, attacker_peer_id: int) -> void:
	if not multiplayer.is_server() or dead or not gameplay_admitted:
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
	var arena := get_game_root()
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
	var arena := get_game_root()
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


func apply_acceptance_contact_position(world_position: Vector3) -> void:
	if not multiplayer.is_server():
		return
	respawn_position = world_position
	teleport_tick = NetworkTime.tick
	global_position = world_position
	head.rotation = Vector3.ZERO
	reset_movement_state()
	tick_interpolator.teleport()


func add_kill() -> void:
	if multiplayer.is_server():
		kills += 1


func find_bot_target() -> SkooshNetworkPlayer:
	var arena := get_game_root()
	if arena.has_method("find_target_for"):
		return arena.find_target_for(peer_id)
	return null


func get_bot_objective_position() -> Vector3:
	var arena := get_game_root()
	if arena.has_method("get_bot_objective_position"):
		return arena.get_bot_objective_position(peer_id)
	return global_position - global_transform.basis.z * 20.0


func should_bot_fire() -> bool:
	var arena := get_game_root()
	return arena.has_method("should_bot_fire") and arena.should_bot_fire(peer_id)


func carries_enemy_flag() -> bool:
	var arena := get_game_root()
	return arena.has_method("player_carries_enemy_flag") and arena.player_carries_enemy_flag(self)


func get_telemetry() -> Dictionary:
	return get_movement_telemetry()


func _update_character_presentation() -> void:
	if (
		not is_node_ready()
		or _presented_variant == character_variant
		or not is_character_variant_valid(character_variant)
	):
		return
	if multiplayer.is_server():
		_presented_variant = character_variant
		return
	if is_instance_valid(_model_root):
		world_model.remove_child(_model_root)
		_model_root.queue_free()
	var scene := load(CHARACTER_VARIANT_PATHS[character_variant]) as PackedScene
	if scene == null:
		push_error("Character variant %d did not load" % character_variant)
		return
	_model_root = scene.instantiate() as Node3D
	_suit_animation = null
	if _model_root == null:
		push_error("Character variant %d did not instantiate as Node3D" % character_variant)
		return
	_model_root.rotation = Vector3(0.0, PI, 0.0)
	world_model.add_child(_model_root)
	for node in _model_root.find_children("*", "AnimationPlayer", true, false):
		var animation_player := node as AnimationPlayer
		if animation_player.has_animation("MomentumLean"):
			_suit_animation = animation_player
			break
	if _suit_animation != null:
		var momentum_lean := _suit_animation.get_animation("MomentumLean")
		momentum_lean.loop_mode = Animation.LOOP_LINEAR
		_suit_animation.play("MomentumLean")
	else:
		push_warning("Character variant %d has no MomentumLean AnimationPlayer" % character_variant)
	_presented_variant = character_variant
	_presented_team = -99
	_update_team_presentation()
	_report_character_variant()


func _report_character_variant() -> void:
	if (
		peer_id <= 1
		or _reported_variant == _presented_variant
		or not is_character_variant_valid(_presented_variant)
		or not is_instance_valid(_model_root)
	):
		return
	_reported_variant = _presented_variant
	print("CHARACTER observed observer=%d peer=%d variant=%d name=%s model=%s" % [
		multiplayer.get_unique_id(), peer_id, _presented_variant,
		character_variant_name(_presented_variant), _model_root.name,
	])
	var arena := get_game_root()
	if arena.has_method("record_character_variant_observation"):
		arena.record_character_variant_observation(peer_id, _presented_variant)


func get_game_root() -> Node:
	var candidate := get_parent()
	while candidate != null:
		if candidate.has_method("is_world_active"):
			return candidate
		candidate = candidate.get_parent()
	return null


func retire_for_rotation() -> void:
	if _retired:
		return
	_retired = true
	gameplay_admitted = false
	collision_layer = 0
	collision_mask = 0
	camera.current = false
	world_model.visible = false
	view_gun.visible = false
	hud.visible = false
	input.deactivate()
	rollback_synchronizer.deactivate()
	tick_interpolator.deactivate()
	var state_sync := get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if state_sync != null:
		state_sync.public_visibility = false
	if NetworkTime.on_tick.is_connected(_network_tick):
		NetworkTime.on_tick.disconnect(_network_tick)
	if NetworkTime.after_tick_loop.is_connected(_after_tick_loop):
		NetworkTime.after_tick_loop.disconnect(_after_tick_loop)
	for weapon_node in weapons:
		if weapon_node.has_method("deactivate"):
			weapon_node.deactivate()
		var tick_callable := Callable(weapon_node, "_network_tick")
		if NetworkTime.on_tick.is_connected(tick_callable):
			NetworkTime.on_tick.disconnect(tick_callable)


func _update_team_presentation() -> void:
	if not is_node_ready():
		return
	_presented_team = team
	var color := Color("#c84a3d") if team == 0 else Color("#3b8fbd")
	if team < 0:
		color = Color("#d8e0d2")
	name_label.text = "SYNCING" if team < 0 else callsign_for_peer(peer_id)
	name_label.modulate = color.lightened(0.25)
	var primary_material := StandardMaterial3D.new()
	primary_material.albedo_color = color
	primary_material.roughness = 0.82
	var secondary_material := StandardMaterial3D.new()
	secondary_material.albedo_color = color.darkened(0.28)
	secondary_material.metallic = 0.18
	secondary_material.roughness = 0.72
	CharacterMaterialRoles.apply(world_model, primary_material, secondary_material)


static func character_variant_name(id: int) -> String:
	return CHARACTER_VARIANT_NAMES[id] if is_character_variant_valid(id) else "UNRESOLVED"


static func is_character_variant_valid(id: int) -> bool:
	return id >= 0 and id < CHARACTER_VARIANT_PATHS.size()


static func character_variant_resources_cached() -> bool:
	for path in CHARACTER_VARIANT_PATHS:
		if ResourceLoader.has_cached(path):
			return true
	return false


func has_character_visual_shell() -> bool:
	return is_instance_valid(_model_root)


static func callsign_for_peer(id: int) -> String:
	const CALLSIGNS: Array[String] = [
		"KITE", "NOVA", "ROOK", "EMBER", "VAULT", "ORBIT", "RIFT", "COMET",
		"MICA", "VEX", "HALO", "PIKE", "ECHO", "BOLT", "WREN", "FLINT",
	]
	return CALLSIGNS[absi(id) % CALLSIGNS.size()]
