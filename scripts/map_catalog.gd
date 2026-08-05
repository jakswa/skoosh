extends RefCounted
class_name SkooshMapCatalog

const DEFAULT_MAP_ID := "faultline_basin"
const LEGACY_MAP_ID := "kestrel_basin"
const PRODUCTION_MAP_IDS: Array[String] = [
	"faultline_basin",
	"cairn_steps",
]
const ROTATION_MAP_IDS: Array[String] = PRODUCTION_MAP_IDS
const SELECTABLE_MAP_IDS: Array[String] = [
	"faultline_basin",
	"cairn_steps",
	LEGACY_MAP_ID,
]

const MAPS := {
	"faultline_basin": {
		"label": "Faultline Basin",
		"status": "production",
		"symmetry_axis": "x",
		"mesh_size": Vector2(704.0, 448.0),
		"grid_resolution": Vector2i(177, 113),
		"boundary": {"type": "capsule_x", "segment_half_length": 190.0, "radius": 136.0},
		"base_centers": [Vector2(-238.0, -4.0), Vector2(238.0, -4.0)],
		"acceptance_center": Vector2(0.0, -4.0),
		"acceptance_axis": Vector2(1.0, 0.0),
		"platform_clearance": 2.0,
		"shared_platform_elevation": false,
		"spawn_sockets": [
			[
				{"position": Vector2(-278.0, -36.0), "direction": Vector2(1.0, 0.12)},
				{"position": Vector2(-286.0, -16.0), "direction": Vector2(1.0, 0.05)},
				{"position": Vector2(-288.0, 8.0), "direction": Vector2(1.0, -0.03)},
				{"position": Vector2(-280.0, 32.0), "direction": Vector2(1.0, -0.11)},
				{"position": Vector2(-264.0, 52.0), "direction": Vector2(1.0, -0.18)},
			],
			[
				{"position": Vector2(278.0, -36.0), "direction": Vector2(-1.0, 0.12)},
				{"position": Vector2(286.0, -16.0), "direction": Vector2(-1.0, 0.05)},
				{"position": Vector2(288.0, 8.0), "direction": Vector2(-1.0, -0.03)},
				{"position": Vector2(280.0, 32.0), "direction": Vector2(-1.0, -0.11)},
				{"position": Vector2(264.0, 52.0), "direction": Vector2(-1.0, -0.18)},
			],
		],
		"routes": [
			{
				"id": "fault_trench", "role": "exposed_speed",
				"waypoints": [
					Vector2(-238.0, -4.0), Vector2(-178.0, 0.0), Vector2(-108.0, 2.0),
					Vector2(0.0, 0.0), Vector2(108.0, 2.0), Vector2(178.0, 0.0), Vector2(238.0, -4.0),
				],
				"landings": [Vector2(-108.0, 2.0), Vector2(108.0, 2.0)],
			},
			{
				"id": "basalt_spine", "role": "high_visibility",
				"waypoints": [
					Vector2(-238.0, -4.0), Vector2(-196.0, -48.0), Vector2(-124.0, -78.0),
					Vector2(0.0, -82.0), Vector2(124.0, -78.0), Vector2(196.0, -48.0), Vector2(238.0, -4.0),
				],
				"landings": [Vector2(-124.0, -78.0), Vector2(124.0, -78.0)],
			},
			{
				"id": "recovery_gully", "role": "screened_return",
				"waypoints": [
					Vector2(-238.0, -4.0), Vector2(-200.0, 48.0), Vector2(-132.0, 96.0),
					Vector2(0.0, 104.0), Vector2(132.0, 96.0), Vector2(200.0, 48.0), Vector2(238.0, -4.0),
				],
				"landings": [Vector2(-132.0, 96.0), Vector2(132.0, 96.0)],
			},
		],
		"bot_route": "fault_trench",
		"route_marking": {
			"origin": Vector2(0.0, 0.0), "axis": Vector2(1.0, 0.0),
			"half_length": 252.0, "width": 3.2, "strength": 0.24,
		},
		"palette": {
			"low": Color("#222432"), "mid": Color("#353849"), "high": Color("#545873"),
			"rock_low": Color("#11131c"), "rock_high": Color("#2b3042"),
			"contour_spacing": 5.5, "contour_strength": 0.13,
		},
		"environment": {
			"sky_top": Color("#080817"), "sky_horizon": Color("#29243d"),
			"ground_bottom": Color("#05050a"), "ground_horizon": Color("#151624"),
			"ambient": Color("#5b607f"), "ambient_energy": 0.58,
			"fog": Color("#403b59"), "fog_density": 0.00155,
			"sun_color": Color("#aebbe8"), "sun_energy": 1.02,
			"sun_rotation": Vector3(-24.0, -72.0, 0.0),
		},
		"landmark": "fault_spires",
	},
	"cairn_steps": {
		"label": "Cairn Steps",
		"status": "production",
		"symmetry_axis": "z",
		"mesh_size": Vector2(480.0, 672.0),
		"grid_resolution": Vector2i(121, 169),
		"boundary": {"type": "superellipse", "half_extents": Vector2(176.0, 276.0), "exponent": 3.0},
		"base_centers": [Vector2(0.0, -220.0), Vector2(0.0, 220.0)],
		"acceptance_center": Vector2(94.0, 0.0),
		"acceptance_axis": Vector2(1.0, 0.0),
		"platform_clearance": 2.0,
		"shared_platform_elevation": false,
		"spawn_sockets": [
			[
				{"position": Vector2(-48.0, -244.0), "direction": Vector2(0.13, 1.0)},
				{"position": Vector2(-24.0, -260.0), "direction": Vector2(0.06, 1.0)},
				{"position": Vector2(0.0, -264.0), "direction": Vector2(0.0, 1.0)},
				{"position": Vector2(24.0, -260.0), "direction": Vector2(-0.06, 1.0)},
				{"position": Vector2(48.0, -244.0), "direction": Vector2(-0.13, 1.0)},
			],
			[
				{"position": Vector2(-48.0, 244.0), "direction": Vector2(0.13, -1.0)},
				{"position": Vector2(-24.0, 260.0), "direction": Vector2(0.06, -1.0)},
				{"position": Vector2(0.0, 264.0), "direction": Vector2(0.0, -1.0)},
				{"position": Vector2(24.0, 260.0), "direction": Vector2(-0.06, -1.0)},
				{"position": Vector2(48.0, 244.0), "direction": Vector2(-0.13, -1.0)},
			],
		],
		"routes": [
			{
				"id": "east_chute", "role": "exposed_speed",
				"waypoints": [
					Vector2(0.0, -220.0), Vector2(50.0, -174.0), Vector2(88.0, -108.0),
					Vector2(94.0, -44.0), Vector2(94.0, 0.0), Vector2(94.0, 44.0),
					Vector2(88.0, 108.0), Vector2(50.0, 174.0), Vector2(0.0, 220.0),
				],
				"landings": [Vector2(94.0, -44.0), Vector2(94.0, 44.0)],
			},
			{
				"id": "west_switchback", "role": "screened_control",
				"waypoints": [
					Vector2(0.0, -220.0), Vector2(-56.0, -176.0), Vector2(-112.0, -124.0),
					Vector2(-72.0, -72.0), Vector2(-112.0, -28.0), Vector2(-112.0, 28.0),
					Vector2(-72.0, 72.0), Vector2(-112.0, 124.0), Vector2(-56.0, 176.0), Vector2(0.0, 220.0),
				],
				"landings": [Vector2(-112.0, -28.0), Vector2(-112.0, 28.0)],
			},
			{
				"id": "jet_saddle", "role": "energy_shortcut",
				"waypoints": [
					Vector2(0.0, -220.0), Vector2(0.0, -148.0), Vector2(0.0, -76.0),
					Vector2(0.0, 0.0), Vector2(0.0, 76.0), Vector2(0.0, 148.0), Vector2(0.0, 220.0),
				],
				"landings": [Vector2(0.0, -76.0), Vector2(0.0, 76.0)],
			},
		],
		"bot_route": "east_chute",
		"route_marking": {
			"origin": Vector2(0.0, 0.0), "axis": Vector2(0.0, 1.0),
			"half_length": 232.0, "width": 3.8, "strength": 0.18,
		},
		"palette": {
			"low": Color("#aaa895"), "mid": Color("#cbc6ad"), "high": Color("#e3ddc2"),
			"rock_low": Color("#24272b"), "rock_high": Color("#4a4b49"),
			"contour_spacing": 3.0, "contour_strength": 0.19,
		},
		"environment": {
			"sky_top": Color("#637584"), "sky_horizon": Color("#d8caa9"),
			"ground_bottom": Color("#292b2c"), "ground_horizon": Color("#77766e"),
			"ambient": Color("#c3c0b4"), "ambient_energy": 0.45,
			"fog": Color("#c4bfae"), "fog_density": 0.00075,
			"sun_color": Color("#f6e8c4"), "sun_energy": 1.04,
			"sun_rotation": Vector3(-38.0, 34.0, 0.0),
		},
		"landmark": "survey_cairns",
	},
	"kestrel_basin": {
		"label": "Kestrel Basin (Legacy Test)",
		"status": "legacy_test",
		"symmetry_axis": "none",
		"mesh_size": Vector2(512.0, 512.0),
		"grid_resolution": Vector2i(129, 129),
		"boundary": {"type": "rectangle", "half_extents": Vector2(278.0, 278.0)},
		"base_centers": [Vector2(-24.0, -207.0), Vector2(24.0, -207.0)],
		"acceptance_center": Vector2(0.0, -207.0),
		"acceptance_axis": Vector2(1.0, 0.0),
		"platform_clearance": 4.5,
		"shared_platform_elevation": true,
		"spawn_sockets": [
			[
				{"position": Vector2(-24.0, -209.2), "direction": Vector2(1.0, 0.0), "on_platform": true},
				{"position": Vector2(-24.0, -207.0), "direction": Vector2(1.0, 0.0), "on_platform": true},
				{"position": Vector2(-24.0, -204.8), "direction": Vector2(1.0, 0.0), "on_platform": true},
			],
			[
				{"position": Vector2(24.0, -209.2), "direction": Vector2(-1.0, 0.0), "on_platform": true},
				{"position": Vector2(24.0, -207.0), "direction": Vector2(-1.0, 0.0), "on_platform": true},
				{"position": Vector2(24.0, -204.8), "direction": Vector2(-1.0, 0.0), "on_platform": true},
			],
		],
		"routes": [{"id": "compact", "role": "legacy_test", "waypoints": [Vector2(-24.0, -207.0), Vector2(24.0, -207.0)], "landings": []}],
		"bot_route": "compact",
		"route_marking": {"origin": Vector2(0.0, -207.0), "axis": Vector2(1.0, 0.0), "half_length": 42.0, "width": 3.25, "strength": 0.38},
		"palette": {
			"low": Color("#a8b8bd"), "mid": Color("#c6d2d3"), "high": Color("#d8dfdd"),
			"rock_low": Color("#262e32"), "rock_high": Color("#41484a"),
			"contour_spacing": 3.25, "contour_strength": 0.16,
		},
		"environment": {
			"sky_top": Color("#0e1b2b"), "sky_horizon": Color("#61788c"),
			"ground_bottom": Color("#090b0d"), "ground_horizon": Color("#33454f"),
			"ambient": Color("#4d6178"), "ambient_energy": 0.48,
			"fog": Color("#6b7a82"), "fog_density": 0.00115,
			"sun_color": Color("#ffdbb8"), "sun_energy": 1.18,
			"sun_rotation": Vector3(-31.0, -58.0, 0.0),
		},
		"landmark": "",
	},
}


static func selected_id_from_args(log_rejection: bool = false) -> String:
	var requested := DEFAULT_MAP_ID
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			requested = arg.trim_prefix("--map=")
	if requested in SELECTABLE_MAP_IDS:
		return requested
	if log_rejection:
		print("MAP rejected id=%s allowed=%s fallback=%s" % [
			requested, ",".join(SELECTABLE_MAP_IDS), DEFAULT_MAP_ID,
		])
	return DEFAULT_MAP_ID


static func get_map(map_id: String) -> Dictionary:
	var resolved := map_id if map_id in SELECTABLE_MAP_IDS else DEFAULT_MAP_ID
	return (MAPS[resolved] as Dictionary).duplicate(true)


static func get_label(map_id: String) -> String:
	return str(get_map(map_id)["label"])


static func get_route(map_config: Dictionary, route_id: String) -> Dictionary:
	for route_variant in map_config["routes"]:
		var route := route_variant as Dictionary
		if str(route["id"]) == route_id:
			return route
	return (map_config["routes"] as Array)[0] as Dictionary
