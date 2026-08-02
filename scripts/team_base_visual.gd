extends StaticBody3D

## Presentation-only team material variant for the shared base architecture GLB.
## Collision and authoritative base placement remain owned by the existing scene.

@export_enum("RED", "BLUE") var team: int = 0


func _ready() -> void:
	var accent := StandardMaterial3D.new()
	accent.metallic = 0.08
	accent.roughness = 0.72
	if team == 0:
		accent.albedo_color = Color("#9f2d24")
	else:
		accent.albedo_color = Color("#246e94")
	for child in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var part_name := mesh_instance.name.to_lower()
		if "teammarkings" in part_name:
			mesh_instance.material_override = accent
