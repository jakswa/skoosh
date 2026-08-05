extends SkooshDiscProjectile
class_name SkooshGrenadeProjectile

const GRAVITY := 30.0
const FUSE_TICKS := 144
const CLIENT_FALLBACK_TICKS := 156


func apply_launch_data(data: Dictionary, fast_forward: bool = false) -> void:
	super.apply_launch_data(data, false)
	if not fast_forward:
		return
	var elapsed_ticks := clampi(NetworkTime.tick - spawn_tick, 0, 12)
	fast_forward_presentation(elapsed_ticks)


func fast_forward_presentation(elapsed_ticks: int) -> void:
	var elapsed := float(elapsed_ticks) * NetworkTime.ticktime
	global_position += velocity * elapsed + Vector3.DOWN * 0.5 * GRAVITY * elapsed * elapsed
	velocity += Vector3.DOWN * GRAVITY * elapsed


func _network_tick(delta: float, tick: int) -> void:
	if spawn_tick < 0 or not is_generation_active():
		return
	var age := tick - spawn_tick
	if age >= FUSE_TICKS:
		if multiplayer.is_server() and is_instance_valid(weapon):
			weapon.resolve_disc_impact(self, null)
			queue_free()
		elif age >= CLIENT_FALLBACK_TICKS:
			queue_free()
		return
	velocity += Vector3.DOWN * GRAVITY * delta
	var start := global_position
	var destination := start + velocity * delta
	if multiplayer.is_server():
		var excludes: Array[RID] = []
		if source_rid.is_valid():
			excludes.append(source_rid)
		var query := PhysicsRayQueryParameters3D.create(start, destination, 3, excludes)
		query.collide_with_areas = false
		query.hit_from_inside = true
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		if not result.is_empty():
			global_position = result.get("position", destination) as Vector3
			if is_instance_valid(weapon):
				weapon.resolve_disc_impact(self, result.get("collider") as Object)
			queue_free()
			return
	global_position = destination
	if velocity.length_squared() > 0.001:
		global_basis = Basis.looking_at(velocity.normalized(), Vector3.UP)
	rotate_object_local(Vector3.FORWARD, delta * 9.0)
