extends Node3D

var _dark_material := StandardMaterial3D.new()
var _signal_material := StandardMaterial3D.new()


func configure(map_id: String, terrain: Node) -> void:
	if map_id == "faultline_basin":
		_dark_material.albedo_color = Color("#0b0c12")
		_dark_material.roughness = 0.88
		_signal_material.albedo_color = Color("#6f668e")
		_signal_material.emission_enabled = true
		_signal_material.emission = Color("#594c83")
		_signal_material.emission_energy_multiplier = 0.75
		_build_fault_spires(terrain)
	elif map_id == "cairn_steps":
		_dark_material.albedo_color = Color("#292b2c")
		_dark_material.roughness = 0.76
		_signal_material.albedo_color = Color("#d8cfaa")
		_signal_material.emission_enabled = true
		_signal_material.emission = Color("#9d956f")
		_signal_material.emission_energy_multiplier = 0.42
		_build_survey_cairns(terrain)


func _build_fault_spires(terrain: Node) -> void:
	for side_variant in [-1.0, 1.0]:
		var side := float(side_variant)
		var x: float = side * 18.0
		var z := -82.0
		var ground: float = terrain.height_at(x, z)
		var spire := PrismMesh.new()
		spire.size = Vector3(5.0, 25.0, 4.0)
		_add_mesh("FaultSpire", spire, Vector3(x, ground + 12.5, z), side * 0.14, _dark_material)
	var bridge := BoxMesh.new()
	bridge.size = Vector3(31.0, 0.55, 1.1)
	var bridge_ground: float = terrain.height_at(0.0, -82.0)
	_add_mesh("FaultSurveyBeam", bridge, Vector3(0.0, bridge_ground + 18.0, -82.0), 0.0, _signal_material)


func _build_survey_cairns(terrain: Node) -> void:
	for x in [-34.0, 0.0, 34.0]:
		var ground: float = terrain.height_at(x, 0.0)
		for level in 4:
			var block := BoxMesh.new()
			block.size = Vector3(7.0 - level * 1.15, 2.0, 5.8 - level * 0.9)
			_add_mesh(
				"CairnStone", block, Vector3(x, ground + 1.0 + level * 1.85, 0.0),
				(level & 1) * 0.3 - 0.15, _dark_material
			)
		var blade := PrismMesh.new()
		blade.size = Vector3(1.1, 8.0, 0.8)
		_add_mesh("SurveyBlade", blade, Vector3(x, ground + 11.0, 0.0), 0.0, _signal_material)


func _add_mesh(
	node_name: String, mesh: PrimitiveMesh, location: Vector3, yaw: float, material: Material
) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = location
	instance.rotation.y = yaw
	add_child(instance)
