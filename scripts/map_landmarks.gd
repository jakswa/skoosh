extends Node3D

var _metal := StandardMaterial3D.new()
var _signal := StandardMaterial3D.new()


func _ready() -> void:
	_metal.albedo_color = Color("#354147")
	_metal.metallic = 0.62
	_metal.roughness = 0.48
	_signal.albedo_color = Color("#9ba99f")
	_signal.emission_enabled = true
	_signal.emission = Color("#718d83")
	_signal.emission_energy_multiplier = 1.1
	_signal.roughness = 0.62


func configure(map_id: String, map_config: Dictionary, terrain: Node) -> void:
	if map_id == "relay_divide":
		_build_relay_mast(terrain)
		for marker_variant in map_config["landmark_markers"]:
			var marker := marker_variant as Vector2
			_build_route_marker(marker, terrain)
	elif map_id == "split_crown":
		_build_crown_beacon(terrain)


func _build_relay_mast(terrain: Node) -> void:
	var ground: float = terrain.height_at(0.0, 0.0)
	_add_cylinder("RelayMast", Vector3(0.0, ground + 9.0, 0.0), 0.34, 18.0, _metal)
	for index in 3:
		var angle := TAU * float(index) / 3.0
		var panel := BoxMesh.new()
		panel.size = Vector3(0.18, 3.8, 2.8)
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * 1.55
		_add_mesh("RelayVane%d" % index, panel, Vector3(0.0, ground + 13.0, 0.0) + offset, angle, _signal)
	var cap := TorusMesh.new()
	cap.inner_radius = 1.45
	cap.outer_radius = 1.62
	cap.rings = 24
	cap.ring_segments = 6
	_add_mesh("RelaySignalRing", cap, Vector3(0.0, ground + 17.0, 0.0), 0.0, _signal)


func _build_route_marker(location: Vector2, terrain: Node) -> void:
	var ground: float = terrain.height_at(location.x, location.y)
	_add_cylinder(
		"RouteMarker", Vector3(location.x, ground + 1.15, location.y), 0.14, 2.3, _signal
	)


func _build_crown_beacon(terrain: Node) -> void:
	var ground: float = terrain.height_at(0.0, 0.0)
	for index in 3:
		var angle := TAU * float(index) / 3.0 - PI * 0.5
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * 3.2
		_add_cylinder(
			"CrownPylon%d" % index,
			Vector3(0.0, ground + 6.5, 0.0) + offset,
			0.42,
			13.0,
			_metal
		)
	var crown := TorusMesh.new()
	crown.inner_radius = 3.25
	crown.outer_radius = 3.58
	crown.rings = 30
	crown.ring_segments = 7
	_add_mesh("CrownSignal", crown, Vector3(0.0, ground + 13.0, 0.0), 0.0, _signal)
	_add_cylinder("CrownBeacon", Vector3(0.0, ground + 16.0, 0.0), 0.18, 6.0, _signal)


func _add_cylinder(
	node_name: String, location: Vector3, radius: float, height: float, material: Material
) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius * 0.72
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 8
	_add_mesh(node_name, cylinder, location, 0.0, material)


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
