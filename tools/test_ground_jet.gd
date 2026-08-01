extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)

	var floor := StaticBody3D.new()
	floor.collision_layer = 1
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 1.0, 20.0)
	floor_shape.shape = box
	floor_shape.position.y = -0.5
	floor.add_child(floor_shape)
	world.add_child(floor)

	var body := MovementBody.new()
	var body_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.48
	capsule.height = 2.2
	body_shape.shape = capsule
	body_shape.position.y = 1.1
	body.add_child(body_shape)
	world.add_child(body)
	body.configure_movement_body()
	body.global_position = Vector3(0.0, 0.001, 0.0)

	await physics_frame
	await physics_frame
	body.velocity = Vector3.DOWN * 5.0
	body.move_and_slide()
	body.velocity = Vector3.ZERO
	if not body.is_on_floor():
		push_error("Ground-jet test body did not settle on the floor")
		quit(1)
		return

	var initial_energy := body.jet_energy
	body.simulate_movement(Vector2.ZERO, false, true, 1.0 / 60.0)
	var pop_velocity := body.velocity.y
	var energy_spent := initial_energy - body.jet_energy
	if pop_velocity < body.jet_ground_pop_velocity:
		push_error("Ground jet did not pop: velocity %.2f" % pop_velocity)
		quit(1)
		return
	if energy_spent < body.jet_ground_pop_energy_cost:
		push_error("Ground jet pop did not charge its fixed fuel cost: %.2f" % energy_spent)
		quit(1)
		return

	body.global_position = Vector3(0.0, 0.001, 0.0)
	body.reset_movement_state()
	body.velocity = Vector3.DOWN * 5.0
	body.move_and_slide()
	body.velocity = Vector3(20.0, 0.0, 0.0)
	body.simulate_movement(Vector2.ZERO, false, true, 1.0 / 60.0)
	if body.velocity.y >= body.jet_ground_pop_velocity:
		push_error("High-speed jet incorrectly received the low-speed pop")
		quit(1)
		return

	print("ACCEPT ground jet: pop=%.2f m/s fuel=%.2f high_speed_y=%.2f" % [
		pop_velocity, energy_spent, body.velocity.y
	])
	quit(0)
