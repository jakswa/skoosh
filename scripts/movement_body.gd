extends CharacterBody3D
class_name MovementBody

@export_category("Walking")
@export var walk_speed: float = 9.0
@export var walk_acceleration: float = 9.0
@export var ground_friction: float = 17.0

@export_category("Skiing")
@export var ski_wish_speed: float = 15.0
@export var ski_acceleration: float = 1.4
@export var ski_drag: float = 0.025
@export_range(0.0, 1.0) var landing_transfer: float = 0.68

@export_category("Air")
@export var gravity: float = 30.0
@export var air_wish_speed: float = 12.0
@export var air_acceleration: float = 0.55

@export_category("Jets")
@export var max_jet_energy: float = 100.0
@export var jet_drain: float = 30.0
@export var jet_recharge: float = 20.0
@export var jet_recharge_delay: float = 0.4
@export var jet_vertical_acceleration: float = 42.0
@export var jet_forward_acceleration: float = 8.0
@export var jet_lateral_acceleration: float = 5.0
@export var jet_ground_pop_max_speed: float = 11.0
@export var jet_ground_pop_velocity: float = 7.5
@export var jet_ground_pop_energy_cost: float = 6.0

@export_category("Safety")
@export var emergency_speed_cap: float = 120.0
@export var maximum_fall_speed: float = 100.0

var jet_energy: float = 100.0
var ski_held := false
var jet_active := false
var horizontal_speed := 0.0
var total_speed := 0.0
var floor_angle_degrees := 0.0
var recharge_wait := 0.0
var jet_ground_pop_latched := false


func configure_movement_body() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_stop_on_slope = false
	floor_constant_speed = false
	floor_max_angle = deg_to_rad(53.0)
	floor_snap_length = 0.8
	up_direction = Vector3.UP
	jet_energy = max_jet_energy


func simulate_movement(input_vector: Vector2, skiing: bool, jet_requested: bool, delta: float, network_factor: float = 1.0) -> void:
	var was_grounded := is_on_floor()
	ski_held = skiing
	var wish_direction := movement_wish_direction(input_vector)
	var floor_normal := get_floor_normal() if was_grounded else Vector3.UP

	if was_grounded and not ski_held:
		floor_snap_length = 0.8
		velocity = velocity.slide(floor_normal)
		velocity = apply_movement_friction(velocity, ground_friction, delta)
		var floor_wish := wish_direction.slide(floor_normal).normalized()
		accelerate_movement(floor_wish, walk_speed, walk_acceleration, delta)
		velocity += Vector3.DOWN * gravity * delta
	elif was_grounded and ski_held:
		floor_snap_length = 0.02
		velocity = velocity.slide(floor_normal)
		velocity *= max(0.0, 1.0 - ski_drag * delta)
		var ski_wish := wish_direction.slide(floor_normal).normalized()
		accelerate_movement(ski_wish, ski_wish_speed, ski_acceleration, delta)
		velocity += Vector3.DOWN.slide(floor_normal) * gravity * delta
		velocity += Vector3.DOWN * gravity * delta
	else:
		floor_snap_length = 0.0
		velocity += Vector3.DOWN * gravity * delta
		accelerate_movement(wish_direction, air_wish_speed, air_acceleration, delta)

	update_movement_jets(jet_requested, input_vector, wish_direction, was_grounded, delta)
	velocity.y = max(velocity.y, -maximum_fall_speed)
	if velocity.length() > emergency_speed_cap:
		velocity = velocity.normalized() * emergency_speed_cap

	var incoming_velocity := velocity
	velocity *= network_factor
	move_and_slide()
	velocity /= network_factor
	var grounded_now := is_on_floor()
	if not was_grounded and grounded_now and ski_held:
		transfer_landing_momentum(incoming_velocity, get_floor_normal())
	if grounded_now:
		# CharacterBody removes the vertical tangent component while grounded.
		# Reconstruct it so skiing does not bleed momentum on the next tick.
		var new_floor_normal := get_floor_normal()
		if new_floor_normal.y > 0.1:
			velocity.y = -(
				velocity.x * new_floor_normal.x + velocity.z * new_floor_normal.z
			) / new_floor_normal.y

	horizontal_speed = Vector2(velocity.x, velocity.z).length()
	total_speed = velocity.length()
	if grounded_now:
		floor_angle_degrees = rad_to_deg(acos(clamp(get_floor_normal().dot(Vector3.UP), -1.0, 1.0)))
	else:
		floor_angle_degrees = 0.0


func force_update_floor_state() -> void:
	var saved_velocity := velocity
	velocity = Vector3.ZERO
	move_and_slide()
	velocity = saved_velocity


func movement_wish_direction(input_vector: Vector2) -> Vector3:
	var direction := global_transform.basis.x * input_vector.x + global_transform.basis.z * input_vector.y
	direction.y = 0.0
	return direction.normalized()


func accelerate_movement(direction: Vector3, wish_speed: float, acceleration: float, delta: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	var current_along_wish := velocity.dot(direction)
	var available := wish_speed - current_along_wish
	if available <= 0.0:
		return
	var added: float = minf(acceleration * wish_speed * delta, available)
	velocity += direction * added


func apply_movement_friction(source_velocity: Vector3, amount: float, delta: float) -> Vector3:
	var speed := source_velocity.length()
	if speed < 0.001:
		return Vector3.ZERO
	var new_speed: float = maxf(0.0, speed - amount * delta)
	return source_velocity * (new_speed / speed)


func update_movement_jets(requested: bool, input_vector: Vector2, wish_direction: Vector3, grounded: bool, delta: float) -> void:
	jet_active = requested and jet_energy > 0.0
	if jet_active:
		jet_energy = max(0.0, jet_energy - jet_drain * delta)
		recharge_wait = jet_recharge_delay
		var planar_speed := Vector2(velocity.x, velocity.z).length()
		if grounded and not jet_ground_pop_latched and planar_speed <= jet_ground_pop_max_speed:
			# A restrained Tribes-style hop: enough to clear the floor snap, but with
			# a fixed fuel cost so repeated low-speed pops remain a deliberate choice.
			floor_snap_length = 0.0
			velocity.y = maxf(velocity.y, jet_ground_pop_velocity)
			jet_energy = maxf(0.0, jet_energy - jet_ground_pop_energy_cost)
			jet_ground_pop_latched = true
		velocity += Vector3.UP * jet_vertical_acceleration * delta
		var forward := wish_direction
		if forward.length_squared() < 0.001:
			forward = -global_transform.basis.z
			forward.y = 0.0
			forward = forward.normalized()
		velocity += forward * jet_forward_acceleration * delta
		# A/D adds a small airborne correction without rotating existing momentum.
		velocity += global_transform.basis.x * input_vector.x * jet_lateral_acceleration * delta
	else:
		if not requested:
			jet_ground_pop_latched = false
		recharge_wait = max(0.0, recharge_wait - delta)
		if not requested and recharge_wait <= 0.0:
			jet_energy = min(max_jet_energy, jet_energy + jet_recharge * delta)


func transfer_landing_momentum(incoming: Vector3, normal: Vector3) -> void:
	if incoming.dot(normal) >= 0.0:
		return
	var tangent := incoming.slide(normal)
	if tangent.length_squared() < 0.01:
		return
	var transferred_speed: float = lerpf(tangent.length(), incoming.length(), landing_transfer)
	velocity = tangent.normalized() * transferred_speed


func reset_movement_state() -> void:
	velocity = Vector3.ZERO
	jet_energy = max_jet_energy
	recharge_wait = 0.0
	jet_active = false
	jet_ground_pop_latched = false
	ski_held = false
	horizontal_speed = 0.0
	total_speed = 0.0
	floor_angle_degrees = 0.0


func get_movement_telemetry() -> Dictionary:
	return {
		"grounded": is_on_floor(),
		"skiing": ski_held,
		"jetting": jet_active,
		"jet_energy": jet_energy,
		"speed": horizontal_speed,
		"velocity": velocity,
		"floor_angle": floor_angle_degrees,
	}
