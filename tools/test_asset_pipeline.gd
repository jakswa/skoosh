extends SceneTree

const SUIT_PATH := "res://assets/models/characters/runway_suit_rig.glb"
const BASE_PATH := "res://assets/models/environment/runway_base_kit.glb"
const TERRAIN_SHADER_PATH := "res://assets/materials/terrain/runway_terrain.gdshader"


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
	if suit_scene != null:
		var suit := suit_scene.instantiate()
		skeleton_count = suit.find_children("*", "Skeleton3D", true, false).size()
		for node in suit.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.skin != null:
				skinned_mesh_count += 1
		for node in suit.find_children("*", "AnimationPlayer", true, false):
			var player := node as AnimationPlayer
			animation_found = animation_found or player.has_animation("MomentumLean")
		suit.free()
	if skeleton_count != 1:
		failures.append("expected one Skeleton3D, found %d" % skeleton_count)
	if skinned_mesh_count < 1:
		failures.append("no skinned meshes found")
	if not animation_found:
		failures.append("MomentumLean animation missing")

	var base_mesh_count := 0
	if base_scene != null:
		var base := base_scene.instantiate()
		base_mesh_count = base.find_children("*", "MeshInstance3D", true, false).size()
		base.free()
	if base_mesh_count != 4:
		failures.append("expected four consolidated base meshes, found %d" % base_mesh_count)

	if not failures.is_empty():
		for failure in failures:
			push_error("ASSET_PIPELINE %s" % failure)
		quit(1)
		return
	print(
		"ACCEPT asset pipeline: skeletons=%d skinned_meshes=%d animation=MomentumLean base_meshes=%d terrain_shader=true"
		% [skeleton_count, skinned_mesh_count, base_mesh_count]
	)
	quit()
