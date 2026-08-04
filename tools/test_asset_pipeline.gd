extends SceneTree

const CHARACTER_PATHS := {
	"Vector Sprinter Mk II": "res://assets/models/characters/vector_sprinter_mk2.glb",
	"STRATOS Foilframe": "res://assets/models/characters/stratos_foilframe.glb",
	"Khepri Triune Salvage": "res://assets/models/characters/khepri_triune_salvage.glb",
}
const SELECTED_SUIT_PATH := "res://assets/models/characters/vector_expedition_runner.glb"
const BASE_PATH := "res://assets/models/environment/kestrel_relay_station.glb"
const TERRAIN_SHADER_PATH := "res://assets/materials/terrain/alpine_hardpack.gdshader"
const REQUIRED_BONES: Array[StringName] = [
	&"Root", &"Pelvis", &"Spine", &"Head",
	&"UpperArm.L", &"Forearm.L", &"Thigh.L", &"Shin.L",
	&"UpperArm.R", &"Forearm.R", &"Thigh.R", &"Shin.R",
]
const EXPECTED_ANIMATED_BONES: Array[StringName] = [
	&"Pelvis", &"Spine", &"UpperArm.L", &"UpperArm.R", &"Thigh.L", &"Thigh.R",
]
const TRANSFORM_TRACK_TYPES: Array[int] = [
	Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D,
]
const REQUIRED_CHARACTER_PARTS: Array[StringName] = [
	&"Pelvis shell", &"Chest plate", &"Helmet", &"Visor", &"Brow plane", &"Sensor",
	&"Torso frame", &"Back frame", &"Rear bib", &"Spine rail",
	&"Jet pod L", &"Jet pod R", &"Pod cowl L", &"Pod cowl R",
	&"Exhaust channel L", &"Exhaust channel R",
	&"Shoulder fin L", &"Shoulder fin R", &"Rib frame L", &"Rib frame R",
	&"Upper arm L", &"Upper arm R", &"Forearm L", &"Forearm R",
	&"Thigh armor L", &"Thigh armor R", &"Thigh signal L", &"Thigh signal R",
	&"Shin armor L", &"Shin armor R", &"Calf stabilizer L", &"Calf stabilizer R",
	&"Boot stabilizer L", &"Boot stabilizer R",
	&"Maintenance latch L", &"Maintenance latch R",
	&"Neck gaiter", &"Waist flex",
	&"Shoulder interface L", &"Shoulder interface R",
	&"Elbow interface L", &"Elbow interface R", &"Glove L", &"Glove R",
	&"Hip interface L", &"Hip interface R", &"Knee interface L", &"Knee interface R",
	&"Ankle interface L", &"Ankle interface R",
]
const SELECTED_SUIT_PARTS: Array[StringName] = [
	&"Pelvis shell", &"Chest plate", &"Helmet", &"Visor",
	&"Jet pod L", &"Jet pod R", &"Shoulder fin L", &"Shoulder fin R",
]


func _initialize() -> void:
	var failures: Array[String] = []
	var total_skeletons := 0
	var total_skinned_meshes := 0
	var character_results: Array[String] = []

	for character_name: String in CHARACTER_PATHS:
		var path: String = CHARACTER_PATHS[character_name]
		var scene := load(path) as PackedScene
		if scene == null:
			failures.append("%s GLB did not load" % character_name)
			continue
		var character := scene.instantiate()
		var skeletons := character.find_children("*", "Skeleton3D", true, false)
		var meshes := character.find_children("*", "MeshInstance3D", true, false)
		var animation_players := character.find_children("*", "AnimationPlayer", true, false)
		total_skeletons += skeletons.size()
		if skeletons.size() != 1:
			failures.append("%s expected one Skeleton3D, found %d" % [character_name, skeletons.size()])
		else:
			var skeleton := skeletons[0] as Skeleton3D
			var found_bones: Array[StringName] = []
			for bone_index in skeleton.get_bone_count():
				found_bones.append(skeleton.get_bone_name(bone_index))
			if found_bones.size() != REQUIRED_BONES.size():
				failures.append("%s expected %d bones, found %d" % [character_name, REQUIRED_BONES.size(), found_bones.size()])
			for bone_name in REQUIRED_BONES:
				if bone_name not in found_bones:
					failures.append("%s required bone missing: %s" % [character_name, bone_name])

		var found_parts: Array[StringName] = []
		var skinned_mesh_count := 0
		for node in meshes:
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.skin != null:
				skinned_mesh_count += 1
			if mesh_instance.name in REQUIRED_CHARACTER_PARTS:
				found_parts.append(mesh_instance.name)
		total_skinned_meshes += skinned_mesh_count
		if skinned_mesh_count != REQUIRED_CHARACTER_PARTS.size():
			failures.append("%s expected %d skinned semantic meshes, found %d" % [character_name, REQUIRED_CHARACTER_PARTS.size(), skinned_mesh_count])
		for part_name in REQUIRED_CHARACTER_PARTS:
			if part_name not in found_parts:
				failures.append("%s required character part missing: %s" % [character_name, part_name])

		var animation_track_count := -1
		var root_track_count := 0
		var changing_bones: Dictionary = {}
		for node in animation_players:
			var player := node as AnimationPlayer
			if not player.has_animation("MomentumLean"):
				continue
			var animation := player.get_animation("MomentumLean")
			if animation == null:
				continue
			animation_track_count = animation.get_track_count()
			for track_index in animation_track_count:
				var track_path := animation.track_get_path(track_index)
				var track_type := animation.track_get_type(track_index)
				var bone_name := track_path.get_subname(0) if track_path.get_subname_count() > 0 else &""
				var is_constant := _animation_track_is_constant(animation, track_index)
				if bone_name == &"Root" and track_type in TRANSFORM_TRACK_TYPES:
					root_track_count += 1
					if not is_constant:
						failures.append("%s MomentumLean changes Root transform track %s" % [character_name, track_path])
				elif not is_constant:
					changing_bones[bone_name] = true
		for bone_name in EXPECTED_ANIMATED_BONES:
			if not changing_bones.has(bone_name):
				failures.append("%s MomentumLean animated bone missing: %s" % [character_name, bone_name])
		for bone_name in changing_bones:
			if bone_name not in EXPECTED_ANIMATED_BONES:
				failures.append("%s MomentumLean unexpectedly animates non-root bone: %s" % [character_name, bone_name])

		var collision_count := character.find_children("*", "CollisionObject3D", true, false).size()
		if collision_count != 0:
			failures.append("%s imported %d collision objects" % [character_name, collision_count])
		var bone_count := (skeletons[0] as Skeleton3D).get_bone_count() if skeletons.size() == 1 else 0
		character_results.append("%s(meshes=%d,bones=%d,tracks=%d,root_tracks=%d)" % [character_name, skinned_mesh_count, bone_count, animation_track_count, root_track_count])
		character.free()

	# Keep the selected production prototype under its original lighter contract.
	var selected_mesh_count := 0
	var selected_scene := load(SELECTED_SUIT_PATH) as PackedScene
	if selected_scene == null:
		failures.append("selected Vector Expedition Runner GLB did not load")
	else:
		var selected := selected_scene.instantiate()
		var selected_skeletons := selected.find_children("*", "Skeleton3D", true, false)
		if selected_skeletons.size() != 1:
			failures.append("selected Vector Expedition Runner expected one Skeleton3D, found %d" % selected_skeletons.size())
		var selected_parts: Array[StringName] = []
		for node in selected.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.skin != null:
				selected_mesh_count += 1
			if mesh_instance.name in SELECTED_SUIT_PARTS:
				selected_parts.append(mesh_instance.name)
		for part_name in SELECTED_SUIT_PARTS:
			if part_name not in selected_parts:
				failures.append("selected Vector Expedition Runner part missing: %s" % part_name)
		var selected_animation_found := false
		for node in selected.find_children("*", "AnimationPlayer", true, false):
			var player := node as AnimationPlayer
			if player.has_animation("MomentumLean"):
				var animation := player.get_animation("MomentumLean")
				selected_animation_found = animation != null and animation.get_track_count() >= 6
		if not selected_animation_found:
			failures.append("selected Vector Expedition Runner MomentumLean contract missing")
		if selected.find_children("*", "CollisionObject3D", true, false).size() != 0:
			failures.append("selected Vector Expedition Runner imported collision")
		selected.free()

	var base_scene := load(BASE_PATH) as PackedScene
	var base_mesh_count := 0
	if base_scene == null:
		failures.append("base GLB did not load")
	else:
		var base := base_scene.instantiate()
		base_mesh_count = base.find_children("*", "MeshInstance3D", true, false).size()
		base.free()
	if base_mesh_count != 5:
		failures.append("expected five consolidated base meshes, found %d" % base_mesh_count)

	var terrain_shader := load(TERRAIN_SHADER_PATH) as Shader
	if terrain_shader == null:
		failures.append("terrain shader did not load")

	if not failures.is_empty():
		for failure in failures:
			push_error("ASSET_PIPELINE %s" % failure)
		quit(1)
		return
	print(
		"ACCEPT asset pipeline: variants=3 skeletons=%d skinned_meshes=%d contract=[%s] selected_vector_meshes=%d base_meshes=%d terrain_shader=true"
		% [total_skeletons, total_skinned_meshes, "; ".join(character_results), selected_mesh_count, base_mesh_count]
	)
	quit()


func _animation_track_is_constant(animation: Animation, track_index: int) -> bool:
	var key_count := animation.track_get_key_count(track_index)
	if key_count < 2:
		return true
	var first_value: Variant = animation.track_get_key_value(track_index, 0)
	for key_index in range(1, key_count):
		if not _animation_values_equal_approx(
			first_value, animation.track_get_key_value(track_index, key_index)
		):
			return false
	return true


func _animation_values_equal_approx(first: Variant, second: Variant) -> bool:
	if typeof(first) != typeof(second):
		return false
	match typeof(first):
		TYPE_FLOAT:
			return is_equal_approx(float(first), float(second))
		TYPE_VECTOR3:
			var first_vector: Vector3 = first
			var second_vector: Vector3 = second
			return first_vector.is_equal_approx(second_vector)
		TYPE_QUATERNION:
			var first_quaternion: Quaternion = first
			var second_quaternion: Quaternion = second
			return first_quaternion.is_equal_approx(second_quaternion)
		_:
			return first == second
