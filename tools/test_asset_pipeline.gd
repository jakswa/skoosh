extends SceneTree

const SUIT_PATH := "res://assets/models/characters/vector_expedition_runner.glb"
const BASE_PATH := "res://assets/models/environment/kestrel_relay_station.glb"
const TERRAIN_SHADER_PATH := "res://assets/materials/terrain/alpine_hardpack.gdshader"
const REQUIRED_CHARACTER_PARTS: Array[StringName] = [
	&"Pelvis shell", &"Chest plate", &"Helmet", &"Visor",
	&"Jet pod L", &"Jet pod R", &"Shoulder fin L", &"Shoulder fin R",
]


func _initialize() -> void:
	var failures: Array[String] = []
	var suit_scene := load(SUIT_PATH) as PackedScene
	var base_scene := load(BASE_PATH) as PackedScene
	var terrain_shader := load(TERRAIN_SHADER_PATH) as Shader
	if suit_scene == null:
		failures.append("suit GLB did not load")
	if base_scene == null:
		failures.append("base GLB did not load")
	if terrain_shader == null:
		failures.append("terrain shader did not load")

	var skeleton_count := 0
	var skinned_mesh_count := 0
	var animation_found := false
	var animation_track_count := 0
	var found_character_parts: Array[StringName] = []
	var imported_collision_count := 0
	if suit_scene != null:
		var suit := suit_scene.instantiate()
		skeleton_count = suit.find_children("*", "Skeleton3D", true, false).size()
		for node in suit.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.skin != null:
				skinned_mesh_count += 1
			if mesh_instance.name in REQUIRED_CHARACTER_PARTS:
				found_character_parts.append(mesh_instance.name)
		for node in suit.find_children("*", "AnimationPlayer", true, false):
			var player := node as AnimationPlayer
			if player.has_animation("MomentumLean"):
				animation_found = true
				var animation := player.get_animation("MomentumLean")
				animation_track_count = animation.get_track_count() if animation != null else 0
		imported_collision_count = suit.find_children("*", "CollisionObject3D", true, false).size()
		suit.free()
	if skeleton_count != 1:
		failures.append("expected one Skeleton3D, found %d" % skeleton_count)
	if skinned_mesh_count < 1:
		failures.append("no skinned meshes found")
	if not animation_found:
		failures.append("MomentumLean animation missing")
	elif animation_track_count < 6:
		failures.append("MomentumLean expected at least 6 tracks, found %d" % animation_track_count)
	for part_name in REQUIRED_CHARACTER_PARTS:
		if part_name not in found_character_parts:
			failures.append("required character part missing: %s" % part_name)
	if imported_collision_count != 0:
		failures.append("character asset imported %d collision objects" % imported_collision_count)

	var base_mesh_count := 0
	if base_scene != null:
		var base := base_scene.instantiate()
		base_mesh_count = base.find_children("*", "MeshInstance3D", true, false).size()
		base.free()
	if base_mesh_count != 5:
		failures.append("expected five consolidated base meshes, found %d" % base_mesh_count)

	if not failures.is_empty():
		for failure in failures:
			push_error("ASSET_PIPELINE %s" % failure)
		quit(1)
		return
	print(
		"ACCEPT asset pipeline: skeletons=%d skinned_meshes=%d animation=MomentumLean tracks=%d base_meshes=%d terrain_shader=true"
		% [skeleton_count, skinned_mesh_count, animation_track_count, base_mesh_count]
	)
	quit()
