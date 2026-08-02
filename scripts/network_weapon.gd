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
@onready var muzzle_origin := $MuzzleOrigin as Node3D
@onready var muzzle_flash := $MuzzleOrigin/MuzzleFlash as MeshInstance3D
@onready var pressure_ring := $MuzzleOrigin/PressureRing as MeshInstance3D
@onready var muzzle_light := $MuzzleLight as OmniLight3D

var last_fire_tick := -100000
var _muzzle_time := 0.0
var _client_fire_ready_tick := -1
var _last_request_tick_by_peer: Dictionary = {}


func _ready() -> void:
	NetworkTime.on_tick.connect(_network_tick)


func _process(delta: float) -> void:
	_muzzle_time = maxf(0.0, _muzzle_time - delta)
	var flash_fraction := clampf(_muzzle_time / 0.08, 0.0, 1.0)
	muzzle_flash.visible = flash_fraction > 0.0
	muzzle_flash.scale = Vector3(1.0, 1.0, 3.0) * lerpf(0.4, 1.25, flash_fraction)
	pressure_ring.visible = flash_fraction > 0.0
	pressure_ring.scale = Vector3.ONE * lerpf(2.8, 0.45, flash_fraction)
	muzzle_light.light_energy = 4.8 if _muzzle_time > 0.0 else 0.0


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
	# Preserve center-reticle aiming while making the physical disc visibly leave
	# the authored muzzle. The authoritative server uses this same convergence.
	var aim_direction := -global_basis.z.normalized()
	var aim_point := global_position + aim_direction * 120.0
	var origin := muzzle_origin.global_position
	var direction := origin.direction_to(aim_point)
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
	local_data: Dictionary
) -> bool:
	if (
		typeof(request_data.get("origin")) != TYPE_VECTOR3
		or typeof(request_data.get("velocity")) != TYPE_VECTOR3
		or typeof(request_data.get("direction")) != TYPE_VECTOR3
		or typeof(request_data.get("source_peer_id")) != TYPE_INT
		or typeof(request_data.get("source_team")) != TYPE_INT
		or typeof(request_data.get("spawn_tick")) != TYPE_INT
	):
		return false
	var requested_origin := request_data.get("origin", Vector3.ZERO) as Vector3
	var requested_velocity := request_data.get("velocity", Vector3.ZERO) as Vector3
	var requested_direction := request_data.get("direction", Vector3.FORWARD) as Vector3
	var local_origin := local_data.get("origin", Vector3.ZERO) as Vector3
	var local_velocity := local_data.get("velocity", Vector3.ZERO) as Vector3
	var local_direction := local_data.get("direction", Vector3.FORWARD) as Vector3
	var request_tick := int(request_data.get("spawn_tick", NetworkTime.tick))
	var request_age := NetworkTime.tick - request_tick
	# Rendered software clients can trail the server by more than 30 ticks. Keep
	# the wider window authority-safe by requiring close agreement with the
	# server-built launch state before netfox may reconcile the prediction.
	return (
		int(request_data.get("source_peer_id", -1)) == player.peer_id
		and int(request_data.get("source_team", -1)) == player.team
		and requested_origin.is_finite()
		and requested_velocity.is_finite()
		and requested_direction.is_normalized()
		and requested_origin.distance_to(local_origin) <= 1.5
		and requested_velocity.distance_to(local_velocity) <= 8.0
		and requested_direction.dot(local_direction) >= 0.985
		and request_age >= -2
		and request_age <= 60
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
		player.present_weapon_fire()
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
	var effect := Node3D.new()
	effect.name = "DiscImpact"
	var color := Color("#ffbc55") if source_team == 0 else Color("#56d9ff")
	if hit_enemy:
		color = Color("#fff08a")
	arena.get_node("Effects").add_child(effect)
	effect.global_position = position

	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.18
	core_mesh.height = 0.36
	core_mesh.radial_segments = 12
	core_mesh.rings = 6
	core.mesh = core_mesh
	var core_material := _impact_material(Color(color, 0.72), 4.2)
	core.material_override = core_material
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effect.add_child(core)

	var pressure_ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.73
	ring_mesh.outer_radius = 0.79
	ring_mesh.rings = 28
	ring_mesh.ring_segments = 6
	pressure_ring.mesh = ring_mesh
	pressure_ring.material_override = _impact_material(Color("#8fffd5"), 3.8)
	pressure_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effect.add_child(pressure_ring)

	var fragment_material := _impact_material(color.lerp(Color.WHITE, 0.35), 2.6)
	var fragments: Array[MeshInstance3D] = []
	for index in 10:
		var fragment := MeshInstance3D.new()
		var fragment_mesh := BoxMesh.new()
		fragment_mesh.size = Vector3(0.08, 0.045, 0.42 + float(index % 3) * 0.12)
		fragment.mesh = fragment_mesh
		fragment.material_override = fragment_material
		fragment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle := TAU * float(index) / 10.0
		fragment.rotation = Vector3(angle * 0.17, angle, angle * 0.31)
		fragment.position = Vector3(cos(angle), 0.18 + 0.05 * float(index % 2), sin(angle)) * 0.28
		effect.add_child(fragment)
		fragments.append(fragment)

	var impact_light := OmniLight3D.new()
	impact_light.light_color = color
	impact_light.light_energy = 7.0
	impact_light.omni_range = 7.5
	impact_light.shadow_enabled = false
	effect.add_child(impact_light)

	var tween := effect.create_tween()
	tween.set_parallel(true)
	tween.tween_property(core, "scale", Vector3.ONE * 3.2, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(core_material, "albedo_color", Color(color, 0.0), 0.26)
	tween.tween_property(pressure_ring, "scale", Vector3.ONE * 3.8, 0.34).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(pressure_ring.material_override, "albedo_color", Color(0.56, 1.0, 0.84, 0.0), 0.34)
	tween.tween_property(fragment_material, "albedo_color", Color(color, 0.0), 0.42)
	tween.tween_property(impact_light, "light_energy", 0.0, 0.22)
	for index in fragments.size():
		var angle := TAU * float(index) / float(fragments.size())
		var destination := Vector3(cos(angle) * 3.8, 1.1 + float(index % 3) * 0.45, sin(angle) * 3.8)
		tween.tween_property(fragments[index], "position", destination, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(effect.queue_free)
	if hit_enemy and input.is_multiplayer_authority():
		player.hud.flash_hit()


func _impact_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
