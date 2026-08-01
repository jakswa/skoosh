extends BaseNetInput
class_name SkooshNetworkInput

@export var mouse_sensitivity: float = 0.0023

var movement := Vector2.ZERO
var ski := false
var jet := false
var fire := false
var reset := false
var look_delta := Vector2.ZERO
var bot_mode := false

var _pending_look := Vector2.ZERO
var _reset_buffered := false
var _configured := false
var _bot_start_tick := -1


func _ready() -> void:
	super()
	call_deferred("_configure_if_local")


func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or bot_mode:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_pending_look.x -= event.relative.x * mouse_sensitivity
		_pending_look.y -= event.relative.y * mouse_sensitivity
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
	if event.is_action_pressed("reset_run"):
		_reset_buffered = true


func _gather() -> void:
	_configure_if_local()
	if bot_mode:
		_gather_bot()
		return
	movement = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	ski = Input.is_action_pressed("ski")
	jet = Input.is_action_pressed("jet")
	fire = Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	reset = _reset_buffered
	_reset_buffered = false
	look_delta = _pending_look
	_pending_look = Vector2.ZERO


func _gather_bot() -> void:
	if _bot_start_tick < 0:
		_bot_start_tick = NetworkTime.tick
	var bot_age := NetworkTime.tick - _bot_start_tick
	var movement_phase := bot_age >= 240
	movement = Vector2.ZERO
	ski = false
	jet = false
	fire = not movement_phase
	reset = false
	look_delta = Vector2.ZERO
	var player := get_parent() as SkooshNetworkPlayer
	if player == null or player.dead:
		fire = false
		return
	var target := player.find_bot_target()
	if movement_phase:
		# Acceptance bots become asymmetric after proving combat: RED runs the
		# flag while BLUE holds its platform. This avoids a two-player flag
		# standoff and gives the authoritative capture/win/restart loop a stable test.
		fire = false
	var target_position := player.get_bot_objective_position()
	if movement_phase and player.team == 0:
		# Hold the spawn lane while crossing the compact arena. Chasing the
		# flag's exact Z near a platform edge can flip steering after an
		# overshoot and leave a high-momentum acceptance bot circling the base.
		target_position.z = player.global_position.z
		var planar_distance := Vector2(
			target_position.x - player.global_position.x,
			target_position.z - player.global_position.z
		).length()
		movement = Vector2(0.0, -1.0) if planar_distance > 2.0 else Vector2.ZERO
		# Keep CTF automation deliberately slower than a player. A short opening
		# pop proves jet replication, then walking friction gives the bot a stable
		# approach. Jet again only when it must climb onto a raised flag platform.
		var opening_pop := bot_age < 250
		var platform_above := target_position.y - player.global_position.y > 1.5
		var climbing_platform := planar_distance < 13.0 and platform_above
		jet = opening_pop or climbing_platform
	if (fire or not movement_phase) and target != null and not target.dead:
		target_position = target.global_position + Vector3.UP * 1.1
	var origin := player.head.global_position
	var direction := origin.direction_to(target_position)
	var desired_yaw := atan2(-direction.x, -direction.z)
	var desired_pitch := asin(clampf(direction.y, -1.0, 1.0)) if fire else 0.0
	look_delta.x = clampf(angle_difference(player.rotation.y, desired_yaw), -0.2, 0.2)
	look_delta.y = clampf(desired_pitch - player.head.rotation.x, -0.15, 0.15)


func _configure_if_local() -> void:
	if _configured or not is_multiplayer_authority():
		return
	_configured = true
	var player := get_parent() as SkooshNetworkPlayer
	if player != null:
		player.activate_local_player()
	if not bot_mode and not DisplayServer.get_name().contains("headless"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
