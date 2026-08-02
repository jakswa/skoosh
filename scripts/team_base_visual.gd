extends StaticBody3D

## Presentation-only team material variant for the shared base architecture GLB.
## Collision and authoritative base placement remain owned by the existing scene.

@export_enum("RED", "BLUE") var team: int = 0


func _ready() -> void:
	var accent := StandardMaterial3D.new()
	accent.metallic = 0.12
	accent.roughness = 0.34
	accent.emission_enabled = true
	if team == 0:
		accent.albedo_color = Color("#d73525")
		accent.emission = Color("#ff351d")
	else:
		accent.albedo_color = Color("#1688d4")
		accent.emission = Color("#139cf4")
	accent.emission_energy_multiplier = 3.0
	for child in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var part_name := mesh_instance.name.to_lower()
		if "signal" in part_name or "pylon face" in part_name:
			mesh_instance.material_override = accent
