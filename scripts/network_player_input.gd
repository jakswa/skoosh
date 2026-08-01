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
	movement = Vector2(0.0, -1.0) if movement_phase else Vector2.ZERO
	ski = movement_phase
	jet = movement_phase and (bot_age % 180) < 75
	fire = not movement_phase
	reset = false
	look_delta = Vector2.ZERO
	var player := get_parent() as SkooshNetworkPlayer
	if player == null or player.dead:
		fire = false
		return
	var target: SkooshNetworkPlayer = player.find_bot_target()
	if target == null or target.dead:
		return
	var origin := player.head.global_position
	var target_position := target.global_position + Vector3.UP * 1.1
	var direction := origin.direction_to(target_position)
	var desired_yaw := atan2(-direction.x, -direction.z)
	var desired_pitch := asin(clampf(direction.y, -1.0, 1.0))
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
