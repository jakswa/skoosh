extends Area3D

signal crossed(index: int)

enum GateState { INACTIVE, NEXT, COMPLETED }

@export var course_index: int = 0
var gate_state: GateState = GateState.INACTIVE
var _base_scale := Vector3.ONE
var _pulse_time := 0.0
var _material: StandardMaterial3D

@onready var frame: Node3D = $Frame


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	_base_scale = frame.scale
	_material = StandardMaterial3D.new()
	_material.roughness = 0.38
	_material.emission_enabled = true
	for child in frame.get_children():
		if child is MeshInstance3D:
			child.material_override = _material
	set_gate_state(gate_state)


func setup(index: int) -> void:
	course_index = index


func set_gate_state(new_state: GateState) -> void:
	gate_state = new_state
	if _material == null:
		return
	var color: Color
	var energy: float
	match gate_state:
		GateState.NEXT:
			color = Color("#31f0f4")
			energy = 3.0
		GateState.COMPLETED:
			color = Color("#786b9c")
			energy = 0.55
		_:
			color = Color("#725ca8")
			energy = 0.9
	_material.albedo_color = color
	_material.emission = color
	_material.emission_energy_multiplier = energy


func pulse() -> void:
	_pulse_time = 0.42


func _process(delta: float) -> void:
	if _pulse_time > 0.0:
		_pulse_time = max(0.0, _pulse_time - delta)
		var progress := 1.0 - _pulse_time / 0.42
		var amount := sin(progress * PI) * 0.18
		frame.scale = _base_scale * (1.0 + amount)
	else:
		frame.scale = _base_scale


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		crossed.emit(course_index)
