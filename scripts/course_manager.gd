extends Node3D

signal run_state_changed(state: int)
signal checkpoint_changed(current: int, total: int)
signal run_finished(time: float, is_best: bool)

enum RunState { READY, RUNNING, FINISHED }

const GATE_SCENE := preload("res://scenes/checkpoint_gate.tscn")
const SAVE_PATH := "user://skoosh.cfg"

var state: RunState = RunState.READY
var elapsed_time: float = 0.0
var best_time: float = INF
var expected_checkpoint: int = 0
var gates: Array[Area3D] = []
var spawn_transform := Transform3D.IDENTITY
var _terrain

# A hand-shaped route: opening descent, sweeping left turn, central jet crest,
# downhill bowl, and a fast final line.
var course_points := PackedVector2Array([
	Vector2(0.0, -165.0),
	Vector2(-42.0, -112.0),
	Vector2(-62.0, -55.0),
	Vector2(-20.0, 8.0),
	Vector2(42.0, 48.0),
	Vector2(62.0, 105.0),
	Vector2(20.0, 155.0),
	Vector2(0.0, 202.0),
])


func _ready() -> void:
	_load_best_time()


func _process(delta: float) -> void:
	if state == RunState.RUNNING:
		elapsed_time += delta


func build_course(terrain) -> void:
	_terrain = terrain
	for old_gate in gates:
		old_gate.queue_free()
	gates.clear()

	for index in course_points.size():
		var point := course_points[index]
		var gate = GATE_SCENE.instantiate()
		gate.setup(index)
		add_child(gate)
		gate.position = Vector3(point.x, terrain.height_at(point.x, point.y) + 0.25, point.y)
		var facing_point: Vector2
		if index < course_points.size() - 1:
			facing_point = course_points[index + 1]
		else:
			facing_point = point + (point - course_points[index - 1])
		gate.look_at(Vector3(facing_point.x, gate.position.y, facing_point.y), Vector3.UP)
		gate.crossed.connect(_on_gate_crossed)
		gates.append(gate)

	var spawn_xz := Vector2(0.0, -218.0)
	var first_direction := (course_points[0] - spawn_xz).normalized()
	var yaw := atan2(-first_direction.x, -first_direction.y)
	spawn_transform = Transform3D(
		Basis(Vector3.UP, yaw),
		Vector3(spawn_xz.x, terrain.height_at(spawn_xz.x, spawn_xz.y) + 0.35, spawn_xz.y)
	)
	reset_run()


func start_run() -> void:
	if state != RunState.READY:
		return
	state = RunState.RUNNING
	run_state_changed.emit(state)


func reset_run() -> void:
	state = RunState.READY
	elapsed_time = 0.0
	expected_checkpoint = 0
	for index in gates.size():
		gates[index].set_gate_state(1 if index == 0 else 0)
	run_state_changed.emit(state)
	checkpoint_changed.emit(expected_checkpoint, gates.size())


func _on_gate_crossed(index: int) -> void:
	if state == RunState.FINISHED or index != expected_checkpoint:
		return
	if state == RunState.READY:
		start_run()
	gates[index].set_gate_state(2)
	gates[index].pulse()
	expected_checkpoint += 1
	if expected_checkpoint >= gates.size():
		_finish_run()
	else:
		gates[expected_checkpoint].set_gate_state(1)
		checkpoint_changed.emit(expected_checkpoint, gates.size())


func _finish_run() -> void:
	state = RunState.FINISHED
	var is_best := elapsed_time < best_time
	if is_best:
		best_time = elapsed_time
		_save_best_time()
	run_state_changed.emit(state)
	checkpoint_changed.emit(expected_checkpoint, gates.size())
	run_finished.emit(elapsed_time, is_best)


func _load_best_time() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		var loaded_value = config.get_value("times", "best", INF)
		if loaded_value is float or loaded_value is int:
			best_time = float(loaded_value)


func _save_best_time() -> void:
	var config := ConfigFile.new()
	config.set_value("times", "best", best_time)
	config.save(SAVE_PATH)


static func format_time(seconds: float) -> String:
	if is_inf(seconds):
		return "--:--.---"
	var minutes: int = int(seconds / 60.0)
	var remainder: float = fmod(seconds, 60.0)
	return "%02d:%06.3f" % [minutes, remainder]
