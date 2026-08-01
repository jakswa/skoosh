extends MovementBody

signal action_started
signal reset_requested
signal telemetry_updated(data: Dictionary)

@export_category("Camera")
@export var mouse_sensitivity: float = 0.0023
@export var base_fov: float = 80.0
@export var maximum_fov: float = 102.0
@export var fov_speed_start: float = 12.0
@export var fov_speed_full: float = 72.0
@export var fov_smoothing: float = 6.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var _spawn_transform := Transform3D.IDENTITY
var _has_spawn := false
var _action_announced := false


func _ready() -> void:
	configure_movement_body()
	camera.fov = base_fov


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotation.x = clamp(
			head.rotation.x - event.relative.y * mouse_sensitivity,
			deg_to_rad(-85.0), deg_to_rad(85.0)
		)
	if event.is_action_pressed("reset_run"):
		reset_requested.emit()


func _physics_process(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var skiing := Input.is_action_pressed("ski")
	var jet_requested := Input.is_action_pressed("jet")
	if not _action_announced and (input_vector.length_squared() > 0.01 or skiing or jet_requested):
		_action_announced = true
		action_started.emit()

	simulate_movement(input_vector, skiing, jet_requested, delta)
	telemetry_updated.emit(get_telemetry())


func _process(delta: float) -> void:
	var fov_t: float = clampf(
		(horizontal_speed - fov_speed_start) / maxf(1.0, fov_speed_full - fov_speed_start),
		0.0, 1.0
	)
	fov_t = fov_t * fov_t * (3.0 - 2.0 * fov_t)
	var target_fov: float = lerpf(base_fov, maximum_fov, fov_t)
	camera.fov = lerp(camera.fov, target_fov, 1.0 - exp(-fov_smoothing * delta))


func set_spawn_transform(new_spawn: Transform3D) -> void:
	_spawn_transform = new_spawn
	_has_spawn = true
	reset_to_spawn()


func reset_to_spawn() -> void:
	if not _has_spawn:
		return
	global_transform = _spawn_transform
	reset_movement_state()
	_action_announced = false
	head.rotation.x = 0.0
	camera.fov = base_fov


func get_telemetry() -> Dictionary:
	return get_movement_telemetry()
