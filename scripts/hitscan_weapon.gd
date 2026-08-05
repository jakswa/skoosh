extends Node3D
class_name SkooshHitscanWeapon

const REQUEST_ATTEMPT_INTERVAL_TICKS := 3

@export_range(0, 3) var weapon_slot := 2
@export var fire_cooldown := 0.1
@export var maximum_damage := 10
@export var minimum_damage := 6
@export var full_damage_range := 35.0
@export var maximum_range := 90.0
@export_range(0.0, 5.0) var spread_degrees := 0.6
@export var weapon_color := Color("#55caff")

@onready var player := get_parent().get_parent() as SkooshNetworkPlayer
@onready var input := player.get_node("Input") as SkooshNetworkInput
@onready var muzzle_origin := $MuzzleOrigin as Node3D

var last_fire_tick := -100000
var _client_fire_ready_tick := -1
var _muzzle_time := 0.0
var _shot_sequence := 0
var _last_request_attempt_tick := -100000
var _muzzle_flash: MeshInstance3D
var _muzzle_light: OmniLight3D


func _ready() -> void:
	var view_gun := player.get_node("Head/Camera3D/ViewGun") as Node3D
	var authored_socket := view_gun.find_child("MuzzleSocket", true, false) as Node3D
	if authored_socket != null:
		muzzle_origin.global_position = authored_socket.global_position
	_build_muzzle_presentation()
	NetworkTime.on_tick.connect(_network_tick)


func _process(delta: float) -> void:
	_muzzle_time = maxf(0.0, _muzzle_time - delta)
	_muzzle_flash.visible = _muzzle_time > 0.0
	_muzzle_light.light_energy = 4.0 if _muzzle_time > 0.0 else 0.0


func _network_tick(_delta: float, _tick: int) -> void:
	if not input.is_multiplayer_authority() or not NetworkTime.is_initial_sync_done():
		return
	if _client_fire_ready_tick < 0:
		_client_fire_ready_tick = NetworkTime.tick + 30
		return
	if not input.fire or not _can_fire():
		return
	last_fire_tick = NetworkTime.tick
	_muzzle_time = 0.06
	player.present_weapon_fire(weapon_slot)
	player.hud.flash_shot()
	_request_fire.rpc_id(1, player.get_game_root().world_generation, NetworkTime.tick)


func _can_fire() -> bool:
	var arena := player.get_game_root()
	var round_active: bool = not arena.has_method("is_round_active") or bool(arena.is_round_active())
	return (
		not player.dead
		and arena.is_node_in_active_world(player)
		and arena.is_peer_gameplay_admitted(player.peer_id)
		and round_active
		and player.can_fire_weapon(weapon_slot)
		and NetworkTime.tick - player.teleport_tick >= 15
		and NetworkTime.tick - last_fire_tick >= _cooldown_ticks()
	)


@rpc("any_peer", "reliable", "call_remote")
func _request_fire(generation: int, request_tick: int) -> void:
	var arena := player.get_game_root()
	if (
		not multiplayer.is_server()
		or generation != arena.world_generation
		or not arena.is_node_in_active_world(player)
		or multiplayer.get_remote_sender_id() != player.peer_id
		or not arena.is_peer_gameplay_admitted(player.peer_id)
	):
		return
	if NetworkTime.tick - _last_request_attempt_tick < REQUEST_ATTEMPT_INTERVAL_TICKS:
		return
	_last_request_attempt_tick = NetworkTime.tick
	var request_age := NetworkTime.tick - request_tick
	if request_age < -2 or request_age > 60 or not _can_fire():
		return
	last_fire_tick = NetworkTime.tick
	_shot_sequence += 1
	var ray_origin := player.head.global_position
	var direction := _spread_direction(-global_basis.z.normalized(), _shot_sequence)
	var query := PhysicsRayQueryParameters3D.create(
		ray_origin, ray_origin + direction * maximum_range, 3, [player.get_rid()]
	)
	query.collide_with_areas = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	var end_position := ray_origin + direction * maximum_range
	var hit_enemy := false
	if not result.is_empty():
		end_position = result.get("position", end_position) as Vector3
		var target := result.get("collider") as SkooshNetworkPlayer
		if (
			target != null
			and target.gameplay_admitted
			and not target.dead
			and target.team != player.team
		):
			var distance := ray_origin.distance_to(end_position)
			target.apply_damage(_damage_at_distance(distance), player.peer_id)
			hit_enemy = true
	if arena.has_method("record_weapon_fire"):
		arena.record_weapon_fire(weapon_slot)
	if hit_enemy and arena.has_method("record_weapon_hit"):
		arena.record_weapon_hit(weapon_slot)
	_present_fire(generation, muzzle_origin.global_position, end_position, hit_enemy)
	for peer_id in arena.get_gameplay_peer_ids():
		_present_fire.rpc_id(
			peer_id, generation, muzzle_origin.global_position, end_position, hit_enemy
		)


func _damage_at_distance(distance: float) -> int:
	if distance <= full_damage_range or maximum_range <= full_damage_range:
		return maximum_damage
	var fraction := clampf(
		(distance - full_damage_range) / (maximum_range - full_damage_range), 0.0, 1.0
	)
	return roundi(lerpf(float(maximum_damage), float(minimum_damage), fraction))


func _spread_direction(direction: Vector3, sequence: int) -> Vector3:
	if spread_degrees <= 0.0:
		return direction
	var seed := absi(player.peer_id * 73856093 + sequence * 19349663)
	var angle := TAU * float(seed % 10000) / 10000.0
	var radial_seed := absi(player.peer_id * 83492791 + sequence * 2971215073)
	var radius_fraction := sqrt(float(radial_seed % 10000) / 9999.0)
	var radius := tan(deg_to_rad(spread_degrees) * radius_fraction)
	var right := direction.cross(Vector3.UP)
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	right = right.normalized()
	var up := right.cross(direction).normalized()
	return (direction + right * cos(angle) * radius + up * sin(angle) * radius).normalized()


@rpc("authority", "reliable", "call_local")
func _present_fire(
	generation: int, origin: Vector3, end_position: Vector3, hit_enemy: bool
) -> void:
	var arena := player.get_game_root()
	if generation != arena.world_generation or not arena.is_node_in_active_world(player):
		return
	_muzzle_time = 0.06
	var tracer := MeshInstance3D.new()
	tracer.name = "WeaponTracer"
	var mesh := BoxMesh.new()
	var distance := origin.distance_to(end_position)
	mesh.size = Vector3(0.025, 0.025, distance)
	tracer.mesh = mesh
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(weapon_color, 0.82)
	material.emission_enabled = true
	material.emission = weapon_color
	material.emission_energy_multiplier = 4.0
	tracer.material_override = material
	arena.get_effect_container().add_child(tracer)
	tracer.global_position = origin.lerp(end_position, 0.5)
	tracer.global_basis = Basis.looking_at(origin.direction_to(end_position), Vector3.UP)
	var tween := tracer.create_tween()
	tween.tween_property(material, "albedo_color", Color(weapon_color, 0.0), 0.12)
	tween.tween_callback(tracer.queue_free)
	if hit_enemy and input.is_multiplayer_authority():
		player.hud.flash_hit()


func get_reload_fraction() -> float:
	return clampf(
		float(NetworkTime.tick - last_fire_tick) / float(_cooldown_ticks()), 0.0, 1.0
	)


func _cooldown_ticks() -> int:
	return maxi(1, ceili(fire_cooldown / NetworkTime.ticktime - 0.0001))


func _build_muzzle_presentation() -> void:
	_muzzle_flash = MeshInstance3D.new()
	_muzzle_flash.name = "MuzzleFlash"
	var flash_mesh := BoxMesh.new()
	flash_mesh.size = Vector3(0.12, 0.12, 0.55)
	_muzzle_flash.mesh = flash_mesh
	_muzzle_flash.position = Vector3(0.0, 0.0, -0.24)
	_muzzle_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var flash_material := StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_color = weapon_color
	flash_material.emission_enabled = true
	flash_material.emission = weapon_color
	flash_material.emission_energy_multiplier = 5.0
	_muzzle_flash.material_override = flash_material
	_muzzle_flash.visible = false
	muzzle_origin.add_child(_muzzle_flash)
	_muzzle_light = OmniLight3D.new()
	_muzzle_light.light_color = weapon_color
	_muzzle_light.light_energy = 0.0
	_muzzle_light.omni_range = 4.5
	_muzzle_light.shadow_enabled = false
	muzzle_origin.add_child(_muzzle_light)
