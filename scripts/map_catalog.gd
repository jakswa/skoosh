extends RefCounted
class_name SkooshMapCatalog

const DEFAULT_MAP_ID := "kestrel_basin"
const MAP_IDS: Array[String] = [
	"kestrel_basin",
	"relay_divide",
	"split_crown",
]

const MAPS := {
	"kestrel_basin": {
		"label": "Kestrel Basin",
		"symmetry_axis": "none",
		"base_centers": [Vector2(-24.0, -207.0), Vector2(24.0, -207.0)],
		"base_yaw": 0.0,
		"platform_clearance": 4.5,
		"shared_platform_elevation": true,
		"oob_half_extents": Vector2(278.0, 278.0),
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
		"route_waypoints": [Vector2(-24.0, -207.0), Vector2(24.0, -207.0)],
		"route_marking": {
			"origin": Vector2(0.0, -207.0), "axis": Vector2(1.0, 0.0),
			"half_length": 42.0, "bend": 0.0, "bend_extent": 42.0, "strength": 0.38,
		},
		"landmark": "",
		"landmark_markers": [],
	},
	"relay_divide": {
		"label": "Relay Divide",
		"symmetry_axis": "x",
		"base_centers": [Vector2(-132.0, 0.0), Vector2(132.0, 0.0)],
		"base_yaw": 0.0,
		"platform_clearance": 2.0,
		"shared_platform_elevation": false,
		"oob_half_extents": Vector2(250.0, 250.0),
		"spawn_sockets": [
			[
				{"position": Vector2(-160.0, -36.0), "direction": Vector2(1.0, 0.16), "on_platform": false},
				{"position": Vector2(-164.0, -24.0), "direction": Vector2(1.0, 0.11), "on_platform": false},
				{"position": Vector2(-168.0, -8.0), "direction": Vector2(1.0, 0.04), "on_platform": false},
				{"position": Vector2(-172.0, 0.0), "direction": Vector2(1.0, 0.0), "on_platform": false},
				{"position": Vector2(-168.0, 8.0), "direction": Vector2(1.0, -0.04), "on_platform": false},
				{"position": Vector2(-164.0, 24.0), "direction": Vector2(1.0, -0.11), "on_platform": false},
				{"position": Vector2(-160.0, 36.0), "direction": Vector2(1.0, -0.16), "on_platform": false},
			],
			[
				{"position": Vector2(160.0, -36.0), "direction": Vector2(-1.0, 0.16), "on_platform": false},
				{"position": Vector2(164.0, -24.0), "direction": Vector2(-1.0, 0.11), "on_platform": false},
				{"position": Vector2(168.0, -8.0), "direction": Vector2(-1.0, 0.04), "on_platform": false},
				{"position": Vector2(172.0, 0.0), "direction": Vector2(-1.0, 0.0), "on_platform": false},
				{"position": Vector2(168.0, 8.0), "direction": Vector2(-1.0, -0.04), "on_platform": false},
				{"position": Vector2(164.0, 24.0), "direction": Vector2(-1.0, -0.11), "on_platform": false},
				{"position": Vector2(160.0, 36.0), "direction": Vector2(-1.0, -0.16), "on_platform": false},
			],
		],
		"route_waypoints": [
			Vector2(-132.0, 0.0), Vector2(-82.0, 2.0), Vector2(-36.0, 0.0),
			Vector2(0.0, 0.0), Vector2(36.0, 0.0), Vector2(82.0, 2.0), Vector2(132.0, 0.0),
		],
		"route_marking": {
			"origin": Vector2(0.0, 0.0), "axis": Vector2(1.0, 0.0),
			"half_length": 150.0, "bend": 0.0, "bend_extent": 132.0, "strength": 0.31,
		},
		"landmark": "relay_mast",
		"landmark_markers": [
			Vector2(-88.0, -54.0), Vector2(88.0, -54.0),
			Vector2(-92.0, 65.0), Vector2(92.0, 65.0),
		],
	},
	"split_crown": {
		"label": "Split Crown",
		"symmetry_axis": "z",
		"base_centers": [Vector2(0.0, -120.0), Vector2(0.0, 120.0)],
		"base_yaw": -PI * 0.5,
		"platform_clearance": 2.0,
		"shared_platform_elevation": false,
		"oob_half_extents": Vector2(250.0, 250.0),
		"spawn_sockets": [
			[
				{"position": Vector2(-40.0, -152.0), "direction": Vector2(0.16, 1.0), "on_platform": false},
				{"position": Vector2(-28.0, -156.0), "direction": Vector2(0.11, 1.0), "on_platform": false},
				{"position": Vector2(-8.0, -160.0), "direction": Vector2(0.04, 1.0), "on_platform": false},
				{"position": Vector2(0.0, -164.0), "direction": Vector2(0.0, 1.0), "on_platform": false},
				{"position": Vector2(8.0, -160.0), "direction": Vector2(-0.04, 1.0), "on_platform": false},
				{"position": Vector2(28.0, -156.0), "direction": Vector2(-0.11, 1.0), "on_platform": false},
				{"position": Vector2(40.0, -152.0), "direction": Vector2(-0.16, 1.0), "on_platform": false},
			],
			[
				{"position": Vector2(-40.0, 152.0), "direction": Vector2(0.16, -1.0), "on_platform": false},
				{"position": Vector2(-28.0, 156.0), "direction": Vector2(0.11, -1.0), "on_platform": false},
				{"position": Vector2(-8.0, 160.0), "direction": Vector2(0.04, -1.0), "on_platform": false},
				{"position": Vector2(0.0, 164.0), "direction": Vector2(0.0, -1.0), "on_platform": false},
				{"position": Vector2(8.0, 160.0), "direction": Vector2(-0.04, -1.0), "on_platform": false},
				{"position": Vector2(28.0, 156.0), "direction": Vector2(-0.11, -1.0), "on_platform": false},
				{"position": Vector2(40.0, 152.0), "direction": Vector2(-0.16, -1.0), "on_platform": false},
			],
		],
		"route_waypoints": [
			Vector2(0.0, -120.0), Vector2(42.0, -82.0), Vector2(72.0, -38.0),
			Vector2(76.0, 0.0), Vector2(72.0, 38.0), Vector2(42.0, 82.0), Vector2(0.0, 120.0),
		],
		"route_marking": {
			"origin": Vector2(0.0, 0.0), "axis": Vector2(0.0, 1.0),
			"half_length": 136.0, "bend": -76.0, "bend_extent": 120.0, "strength": 0.29,
		},
		"landmark": "crown_beacon",
		"landmark_markers": [],
	},
}


static func selected_id_from_args(log_rejection: bool = false) -> String:
	var requested := DEFAULT_MAP_ID
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			requested = arg.trim_prefix("--map=")
	if requested in MAP_IDS:
		return requested
	if log_rejection:
		print("MAP rejected id=%s allowed=%s fallback=%s" % [
			requested, ",".join(MAP_IDS), DEFAULT_MAP_ID,
		])
	return DEFAULT_MAP_ID


static func get_map(map_id: String) -> Dictionary:
	var resolved := map_id if map_id in MAP_IDS else DEFAULT_MAP_ID
	return (MAPS[resolved] as Dictionary).duplicate(true)


static func get_label(map_id: String) -> String:
	return str((MAPS[map_id if map_id in MAP_IDS else DEFAULT_MAP_ID] as Dictionary)["label"])
