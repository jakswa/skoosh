extends Node3D
class_name SkooshNetworkFlag

@export_enum("RED", "BLUE") var team := 0

@onready var banner := $Banner as MeshInstance3D
@onready var glow := $Glow as OmniLight3D
@onready var orbit_a := $OrbitA as MeshInstance3D
@onready var orbit_b := $OrbitB as MeshInstance3D
@onready var orbit_c := $OrbitC as MeshInstance3D

var _base_position := Vector3.ZERO
var _carried := false


func _ready() -> void:
	_apply_team_color()


func present(world_position: Vector3, carried: bool, active: bool = true) -> void:
	visible = active
	_base_position = world_position
	_carried = carried


func _process(delta: float) -> void:
	if not visible:
		return
	var bob := 0.0 if _carried else sin(Time.get_ticks_msec() * 0.004) * 0.12
	global_position = _base_position + Vector3.UP * bob
	banner.rotate_y(delta * (1.4 if _carried else 0.55))
	var speed := 1.7 if _carried else 0.62
	orbit_a.rotate_y(delta * speed)
	orbit_b.rotate_x(delta * speed * 0.83)
	orbit_c.rotate_z(-delta * speed * 1.12)


func _apply_team_color() -> void:
	var color := Color("#ff594d") if team == 0 else Color("#36bfff")
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.35
	material.roughness = 0.58
	banner.material_override = material
	orbit_a.material_override = material
	orbit_b.material_override = material
	orbit_c.material_override = material
	glow.light_color = color
