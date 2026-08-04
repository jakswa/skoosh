extends Node3D
class_name SkooshDiscProjectile

const MAX_LIFETIME_TICKS := 240

var velocity := Vector3.ZERO
var launch_direction := Vector3.FORWARD
var source_peer_id := 0
var source_team := -1
var spawn_tick := -1
var source_rid := RID()
var weapon: Node


func _ready() -> void:
	NetworkTime.on_tick.connect(_network_tick)


func launch(
	origin: Vector3,
	direction: Vector3,
	initial_velocity: Vector3,
	peer_id: int,
	team: int,
	shooter_rid: RID,
	owner_weapon: Node
) -> void:
	global_position = origin
	launch_direction = direction.normalized()
	global_basis = Basis.looking_at(launch_direction, Vector3.UP)
	velocity = initial_velocity
	source_peer_id = peer_id
	source_team = team
	source_rid = shooter_rid
	weapon = owner_weapon
	spawn_tick = NetworkTime.tick


func apply_launch_data(data: Dictionary, fast_forward: bool = false) -> void:
	global_position = data.get("origin", Vector3.ZERO) as Vector3
	velocity = data.get("velocity", Vector3.ZERO) as Vector3
	launch_direction = (data.get("direction", Vector3.FORWARD) as Vector3).normalized()
	global_basis = Basis.looking_at(launch_direction, Vector3.UP)
	source_peer_id = int(data.get("source_peer_id", 0))
	source_team = int(data.get("source_team", -1))
	spawn_tick = int(data.get("spawn_tick", NetworkTime.tick))
	if fast_forward:
		var elapsed_ticks := clampi(NetworkTime.tick - spawn_tick, 0, 12)
		global_position += velocity * NetworkTime.ticktime * elapsed_ticks


func get_launch_data() -> Dictionary:
	return {
		"origin": global_position,
		"velocity": velocity,
		"direction": launch_direction,
		"source_peer_id": source_peer_id,
		"source_team": source_team,
		"spawn_tick": spawn_tick,
	}


func _network_tick(delta: float, tick: int) -> void:
	if spawn_tick < 0:
		return
	if tick - spawn_tick >= MAX_LIFETIME_TICKS:
		queue_free()
		return
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
			if is_instance_valid(weapon) and weapon.has_method("resolve_disc_impact"):
				weapon.resolve_disc_impact(self, result.get("collider") as Object)
			queue_free()
			return
	global_position = destination
	rotate_object_local(Vector3.FORWARD, delta * 13.0)
