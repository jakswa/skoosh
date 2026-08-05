extends BaseNetInput
class_name SkooshNetworkInput

const VoiceCommandLibrary = preload("res://scripts/voice_command_library.gd")
const BOT_AIM_SETTLE_TICKS := 6

@export var mouse_sensitivity: float = 0.0023

var movement := Vector2.ZERO
var ski := false
var jet := false
var fire := false
var weapon_slot := 0
var reset := false
var look_delta := Vector2.ZERO
var bot_mode := false

var _pending_look := Vector2.ZERO
var _pending_weapon_slot := 0
var _reset_buffered := false
var _configured := false
var _bot_start_tick := -1
var _bot_voice_sent := false
<<<<<<< HEAD
var _bot_aim_settled_ticks := 0
=======
var _visual_qa_bot := false
>>>>>>> 2b57ccf (feat: add proper competitive CTF maps)
var visual_qa_lock := false


func _ready() -> void:
	super()
	_visual_qa_bot = "--visual-qa-bot" in OS.get_cmdline_user_args()
	call_deferred("_configure_if_local")


func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or bot_mode:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_pending_look.x -= event.relative.x * mouse_sensitivity
		_pending_look.y -= event.relative.y * mouse_sensitivity
	elif event.is_action_pressed("ui_cancel"):
		var player := get_parent() as SkooshNetworkPlayer
		if player == null or not player.hud.close_voice_menu():
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var player := get_parent() as SkooshNetworkPlayer
			if player == null or not player.hud.is_voice_menu_visible():
				var selection := _weapon_key_index(key_event.physical_keycode)
				if selection >= 0:
					_pending_weapon_slot = selection
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
	weapon_slot = _pending_weapon_slot
	reset = _reset_buffered
	_reset_buffered = false
	look_delta = _pending_look
	_pending_look = Vector2.ZERO


func _gather_bot() -> void:
	var arena := get_parent().get_parent().get_parent()
	if not "avatars" in arena or arena.avatars.size() < 2:
		_bot_start_tick = NetworkTime.tick
		_set_bot_idle()
		return
	if _bot_start_tick < 0:
		_bot_start_tick = NetworkTime.tick
	var bot_age := NetworkTime.tick - _bot_start_tick
	if bot_age >= 90 and not _bot_voice_sent:
		_bot_voice_sent = true
		if arena.has_method("send_voice_command"):
			arena.send_voice_command(0, VoiceCommandLibrary.SCOPE_GLOBAL)
	if visual_qa_lock or (_visual_qa_bot and bot_age < 132):
		_set_bot_idle()
		return
	var movement_phase := bot_age >= 540
	movement = Vector2.ZERO
	ski = false
	jet = false
	# Settle the final weapon before movement so a late predicted shot cannot
	# cross the phase boundary.
	fire = bot_age < 450
	weapon_slot = clampi(floori(float(bot_age) / 120.0), 0, 3)
	reset = false
	look_delta = Vector2.ZERO
	var player := get_parent() as SkooshNetworkPlayer
	if player == null or player.dead:
		fire = false
		_bot_aim_settled_ticks = 0
		return
	var target := player.find_bot_target()
	if movement_phase:
		# Acceptance bots become asymmetric after proving combat: RED runs the
		# flag while BLUE holds its platform. This avoids a two-player flag
		# standoff and gives the authoritative capture/win/restart loop a stable test.
		fire = false
	var target_position := player.get_bot_objective_position()
	if movement_phase and player.team == 0:
		var planar_distance := Vector2(
			target_position.x - player.global_position.x,
			target_position.z - player.global_position.z
		).length()
		movement = Vector2(0.0, -1.0) if planar_distance > 2.0 else Vector2.ZERO
		# Keep CTF automation deliberately slower than a player. A short opening
		# pop proves jet replication, then walking friction gives the bot a stable
		# approach. Jet again only when it must climb onto a raised flag platform.
		var opening_pop := bot_age < 550
		var platform_above := target_position.y - player.global_position.y > 1.5
		var climbing_platform := planar_distance < 13.0 and platform_above
		jet = opening_pop or climbing_platform
	if (fire or not movement_phase) and target != null and not target.dead:
		target_position = target.global_position + Vector3.UP * 1.1
	var origin := player.head.global_position
	var direction := origin.direction_to(target_position)
	if fire and weapon_slot == 1:
		direction = _grenade_launch_direction(origin, target_position)
	var desired_yaw := atan2(-direction.x, -direction.z)
	var desired_pitch := asin(clampf(direction.y, -1.0, 1.0)) if fire else 0.0
	look_delta.x = clampf(angle_difference(player.rotation.y, desired_yaw), -0.2, 0.2)
	look_delta.y = clampf(desired_pitch - player.head.rotation.x, -0.15, 0.15)
	var aim_settled := absf(look_delta.x) <= 0.1 and absf(look_delta.y) <= 0.1
	_bot_aim_settled_ticks = _bot_aim_settled_ticks + 1 if aim_settled else 0
	# Cover the measured four-tick request skew after the local aim converges.
	if fire and _bot_aim_settled_ticks < BOT_AIM_SETTLE_TICKS:
		fire = false


func _set_bot_idle() -> void:
	movement = Vector2.ZERO
	ski = false
	jet = false
	fire = false
	weapon_slot = 0
	reset = false
	look_delta = Vector2.ZERO
	_bot_aim_settled_ticks = 0


func _weapon_key_index(keycode: Key) -> int:
	match keycode:
		KEY_1:
			return 0
		KEY_2:
			return 1
		KEY_3:
			return 2
		KEY_4:
			return 3
	return -1


func _grenade_launch_direction(origin: Vector3, target: Vector3) -> Vector3:
	const SPEED := 50.0
	const GRAVITY := 30.0
	var offset := target - origin
	var planar := Vector2(offset.x, offset.z)
	var distance := planar.length()
	if distance < 0.01:
		return origin.direction_to(target)
	var speed_squared := SPEED * SPEED
	var discriminant := speed_squared * speed_squared - GRAVITY * (
		GRAVITY * distance * distance + 2.0 * offset.y * speed_squared
	)
	if discriminant <= 0.0:
		return origin.direction_to(target)
	var launch_angle := atan((speed_squared - sqrt(discriminant)) / (GRAVITY * distance))
	var planar_direction := Vector3(offset.x, 0.0, offset.z).normalized()
	return (planar_direction * cos(launch_angle) + Vector3.UP * sin(launch_angle)).normalized()


func _configure_if_local() -> void:
	if _configured or not is_multiplayer_authority():
		return
	_configured = true
	var player := get_parent() as SkooshNetworkPlayer
	if player != null:
		player.activate_local_player()
	if not bot_mode and not DisplayServer.get_name().contains("headless"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
