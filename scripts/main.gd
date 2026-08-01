extends Node3D

@onready var terrain = $Terrain
@onready var course = $CourseManager
@onready var player = $Player
@onready var hud = $HUD


func _ready() -> void:
	course.build_course(terrain)
	player.set_spawn_transform(course.spawn_transform)
	player.action_started.connect(course.start_run)
	player.reset_requested.connect(reset_run)
	hud.bind(player, course)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.set_mouse_paused(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hud.set_mouse_paused(true)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			hud.set_mouse_paused(false)
			get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	var position: Vector3 = player.global_position
	var outside: bool = absf(position.x) > 278.0 or absf(position.z) > 278.0
	var far_below: bool = position.y < terrain.height_at(position.x, position.z) - 35.0
	if outside or far_below:
		reset_run()


func reset_run() -> void:
	course.reset_run()
	player.reset_to_spawn()
