extends NetworkWeapon3D
class_name SkooshDiscLauncher

@export var projectile_scene: PackedScene
@export var fire_cooldown := 0.82
@export var projectile_speed := 82.0
@export_range(0.0, 1.0) var velocity_inheritance := 0.55
@export var splash_radius := 5.8
@export var maximum_damage := 105
@export var minimum_damage := 28

@onready var player := get_parent().get_parent() as SkooshNetworkPlayer
@onready var input := player.get_node("Input") as SkooshNetworkInput
@onready var muzzle_light := $MuzzleLight as OmniLight3D

var last_fire_tick := -100000
var _muzzle_time := 0.0
var _client_fire_ready_tick := -1
var _last_request_tick_by_peer: Dictionary = {}


func _ready() -> void:
	NetworkTime.on_tick.connect(_network_tick)


func _process(delta: float) -> void:
	_muzzle_time = maxf(0.0, _muzzle_time - delta)
	muzzle_light.light_energy = 3.4 if _muzzle_time > 0.0 else 0.0


func _network_tick(_delta: float, _tick: int) -> void:
	if not input.is_multiplayer_authority():
		return
	if not NetworkTime.is_initial_sync_done():
		return
	if _client_fire_ready_tick < 0:
		_client_fire_ready_tick = NetworkTime.tick + 30
		return
	if NetworkTime.tick >= _client_fire_ready_tick and input.fire and not player.dead:
		fire()


func _can_fire() -> bool:
	var arena := player.get_parent().get_parent()
	var round_active: bool = not arena.has_method("is_round_active") or bool(arena.is_round_active())
	var cooldown := fire_cooldown + (0.08 if input.is_multiplayer_authority() else 0.0)
	return (
		not player.dead
		and round_active
		and NetworkTime.tick - player.teleport_tick >= 15
		and NetworkTime.seconds_between(last_fire_tick, NetworkTime.tick) >= cooldown
	)


func _can_peer_use(peer_id: int) -> bool:
	if peer_id != player.peer_id:
		return false
	var previous_tick := int(_last_request_tick_by_peer.get(peer_id, -100000))
	if NetworkTime.tick - previous_tick < 6:
		return false
	_last_request_tick_by_peer[peer_id] = NetworkTime.tick
	return true


func _spawn() -> Node3D:
	var projectile := projectile_scene.instantiate() as SkooshDiscProjectile
	var arena := player.get_parent().get_parent()
	var container := arena.get_node("Projectiles") as Node3D
	container.add_child(projectile)
	var direction := -global_basis.z.normalized()
	var origin := global_position + direction * 0.85
	var inherited_velocity := player.velocity * velocity_inheritance
	projectile.launch(
		origin,
		direction,
		direction * projectile_speed + inherited_velocity,
		player.peer_id,
		player.team,
		player.get_rid(),
		self
	)
	return projectile


func _get_data(projectile: Node3D) -> Dictionary:
	return (projectile as SkooshDiscProjectile).get_launch_data()


func _apply_data(projectile: Node3D, data: Dictionary) -> void:
	var disc := projectile as SkooshDiscProjectile
	disc.source_rid = player.get_rid()
	disc.weapon = self
	disc.apply_launch_data(data, true)


func _is_reconcilable(
	_projectile: Node3D,
	request_data: Dictionary,
	_local_data: Dictionary
) -> bool:
	if (
		typeof(request_data.get("origin")) != TYPE_VECTOR3
		or typeof(request_data.get("source_peer_id")) != TYPE_INT
		or typeof(request_data.get("source_team")) != TYPE_INT
		or typeof(request_data.get("spawn_tick")) != TYPE_INT
	):
		return false
	var requested_origin := request_data.get("origin", Vector3.ZERO) as Vector3
	var request_tick := int(request_data.get("spawn_tick", NetworkTime.tick))
	var request_age := NetworkTime.tick - request_tick
	return (
		int(request_data.get("source_peer_id", -1)) == player.peer_id
		and int(request_data.get("source_team", -1)) == player.team
		and requested_origin.is_finite()
		and request_age >= -2
		and request_age <= 30
	)


func _reconcile(projectile: Node3D, local_data: Dictionary, remote_data: Dictionary) -> void:
	var disc := projectile as SkooshDiscProjectile
	var local_origin := local_data.get("origin", disc.global_position) as Vector3
	var traveled := local_origin.distance_to(disc.global_position)
	disc.apply_launch_data(remote_data)
	disc.global_position += disc.velocity.normalized() * traveled


func _after_fire(_projectile: Node3D) -> void:
	last_fire_tick = NetworkTime.tick
	_muzzle_time = 0.08
	if input.is_multiplayer_authority():
		player.hud.flash_shot()


func get_reload_fraction() -> float:
	var elapsed := NetworkTime.seconds_between(last_fire_tick, NetworkTime.tick)
	return clampf(elapsed / fire_cooldown, 0.0, 1.0)


func resolve_disc_impact(projectile: SkooshDiscProjectile, collider: Object) -> void:
	if not multiplayer.is_server():
		return
	var arena := player.get_parent().get_parent()
	var impact_position := projectile.global_position
	var projectile_id := get_projectile_id(projectile)
	var direct_target := collider as SkooshNetworkPlayer
	var damaged_enemies := 0
	for avatar_variant in arena.avatars.values():
		var target := avatar_variant as SkooshNetworkPlayer
		if target == null or target.dead or target.team == projectile.source_team:
			continue
		var target_center := target.global_position + Vector3.UP * 1.1
		var distance := target_center.distance_to(impact_position)
		if distance > splash_radius and target != direct_target:
			continue
		if target != direct_target and _world_blocks_splash(impact_position, target_center):
			continue
		var falloff := 1.0 - clampf(distance / splash_radius, 0.0, 1.0)
		var amount := roundi(lerpf(float(minimum_damage), float(maximum_damage), falloff))
		if target == direct_target:
			amount = maximum_damage
		target.apply_damage(amount, projectile.source_peer_id)
		damaged_enemies += 1
	if arena.has_method("record_disc_impact"):
		arena.record_disc_impact(damaged_enemies)
	_present_disc_impact.rpc(projectile_id, impact_position, projectile.source_team, damaged_enemies > 0)


func _world_blocks_splash(impact_position: Vector3, target_position: Vector3) -> bool:
	var direction := impact_position.direction_to(target_position)
	var query := PhysicsRayQueryParameters3D.create(
		impact_position + direction * 0.12,
		target_position,
		1
	)
	query.collide_with_areas = false
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


@rpc("authority", "reliable", "call_local")
func _present_disc_impact(
	projectile_id: String,
	position: Vector3,
	source_team: int,
	hit_enemy: bool
) -> void:
	if not projectile_id.is_empty():
		despawn_projectile(projectile_id)
	var arena := player.get_parent().get_parent()
	var effect := MeshInstance3D.new()
	effect.name = "DiscImpact"
	var mesh := SphereMesh.new()
	mesh.radius = 0.45
	mesh.height = 0.9
	mesh.radial_segments = 12
	mesh.rings = 6
	effect.mesh = mesh
	var color := Color("#ffbc55") if source_team == 0 else Color("#56d9ff")
	if hit_enemy:
		color = Color("#fff08a")
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	effect.material_override = material
	arena.get_node("Effects").add_child(effect)
	effect.global_position = position
	var tween := effect.create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector3.ONE * 5.5, 0.24)
	tween.tween_property(material, "albedo_color", Color(color, 0.0), 0.24)
	tween.chain().tween_callback(effect.queue_free)
	if hit_enemy and input.is_multiplayer_authority():
		player.hud.flash_hit()
