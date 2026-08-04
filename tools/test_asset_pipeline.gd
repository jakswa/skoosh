extends SceneTree

const CharacterMaterialRoles = preload("res://scripts/character_material_roles.gd")
const CHARACTER_PATHS := {
	"Vector Sprinter Mk II": "res://assets/models/characters/vector_sprinter_mk2.glb",
	"STRATOS Foilframe": "res://assets/models/characters/stratos_foilframe.glb",
	"Khepri Triune Salvage": "res://assets/models/characters/khepri_triune_salvage.glb",
}
const SELECTED_SUIT_PATH := "res://assets/models/characters/vector_expedition_runner.glb"
const BASE_PATH := "res://assets/models/environment/kestrel_relay_station.glb"
const TERRAIN_SHADER_PATH := "res://assets/materials/terrain/alpine_hardpack.gdshader"
const CHARACTER_MANIFEST_PATH := "res://assets/manifests/character_shell_variants.json"
const REQUIRED_BONES: Array[StringName] = [
	&"Root", &"Pelvis", &"Spine", &"Head",
	&"UpperArm.L", &"Forearm.L", &"Thigh.L", &"Shin.L",
	&"UpperArm.R", &"Forearm.R", &"Thigh.R", &"Shin.R",
]
const EXPECTED_ANIMATED_BONES: Array[StringName] = [
	&"Pelvis", &"Spine", &"UpperArm.L", &"UpperArm.R", &"Thigh.L", &"Thigh.R",
]
const REQUIRED_BONE_PARENTS := {
	&"Root": &"", &"Pelvis": &"Root", &"Spine": &"Pelvis", &"Head": &"Spine",
	&"UpperArm.L": &"Spine", &"Forearm.L": &"UpperArm.L",
	&"Thigh.L": &"Pelvis", &"Shin.L": &"Thigh.L",
	&"UpperArm.R": &"Spine", &"Forearm.R": &"UpperArm.R",
	&"Thigh.R": &"Pelvis", &"Shin.R": &"Thigh.R",
}
const TRANSFORM_TRACK_TYPES: Array[int] = [
	Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D,
]
const COMMON_RUNTIME_ROLE_MATERIALS := {
	&"Graphite": &"Graphite weave",
	&"Hardware": &"Graphite mechanism",
	CharacterMaterialRoles.PRIMARY_TEAM_ROLE: CharacterMaterialRoles.PRIMARY_TEAM_SEED_MATERIAL,
	CharacterMaterialRoles.SECONDARY_TEAM_ROLE: CharacterMaterialRoles.SECONDARY_TEAM_SEED_MATERIAL,
	&"Mint": &"Active mint channel",
	&"Orange": &"Expedition orange latch",
}
const ACCENT_RUNTIME_ROLE_MATERIALS := {
	"Vector Sprinter Mk II": {&"Ceramic": &"Weathered glacier ceramic"},
	"STRATOS Foilframe": {&"Ceramic": &"Weathered glacier ceramic"},
	"Khepri Triune Salvage": {&"Bronze": &"Oxidized salvage bronze"},
}
const SOURCE_GENERATION_STATS := {
	"Vector Sprinter Mk II": {"source_vertices": 5112, "source_triangles": 10032},
	"STRATOS Foilframe": {"source_vertices": 5104, "source_triangles": 10016},
	"Khepri Triune Salvage": {"source_vertices": 5296, "source_triangles": 10400},
}
const SOURCE_SEMANTIC_MESH_COUNT := 50
const RUNTIME_MESH_COUNT := 7
const SELECTED_SUIT_PARTS: Array[StringName] = [
	&"Pelvis shell", &"Chest plate", &"Helmet", &"Visor",
	&"Jet pod L", &"Jet pod R", &"Shoulder fin L", &"Shoulder fin R",
]


func _initialize() -> void:
	var failures: Array[String] = []
	var manifest_by_name := _load_character_manifest(failures)
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
					continue
				var bone_index := skeleton.find_bone(bone_name)
				var parent_index := skeleton.get_bone_parent(bone_index)
				var parent_name: StringName = skeleton.get_bone_name(parent_index) if parent_index >= 0 else &""
				if parent_name != REQUIRED_BONE_PARENTS[bone_name]:
					failures.append("%s bone %s parent=%s, expected=%s" % [character_name, bone_name, parent_name, REQUIRED_BONE_PARENTS[bone_name]])

		var skinned_mesh_count := 0
		var runtime_vertex_count := 0
		var runtime_triangle_count := 0
		var runtime_materials: Dictionary = {}
		for node in meshes:
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.skin != null:
				skinned_mesh_count += 1
			if mesh_instance.mesh != null:
				for surface_index in mesh_instance.mesh.get_surface_count():
					var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
					runtime_vertex_count += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
					var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
					runtime_triangle_count += int(indices.size() / 3)
					var runtime_material := mesh_instance.mesh.surface_get_material(surface_index)
					if runtime_material != null:
						runtime_materials[runtime_material.resource_name] = true
		total_skinned_meshes += skinned_mesh_count
		if meshes.size() != RUNTIME_MESH_COUNT or skinned_mesh_count != RUNTIME_MESH_COUNT:
			failures.append("%s expected %d consolidated skinned meshes, found %d meshes/%d skinned" % [character_name, RUNTIME_MESH_COUNT, meshes.size(), skinned_mesh_count])

		_validate_runtime_material_roles(character_name, character, failures)
		var manifest_entry: Dictionary = manifest_by_name.get(character_name, {})
		if manifest_entry.is_empty():
			failures.append("%s manifest entry missing" % character_name)
		else:
			_validate_manifest_stat(character_name, manifest_entry, "source_meshes", SOURCE_SEMANTIC_MESH_COUNT, failures)
			for source_field: String in SOURCE_GENERATION_STATS[character_name]:
				_validate_manifest_stat(character_name, manifest_entry, source_field, int(SOURCE_GENERATION_STATS[character_name][source_field]), failures)
			_validate_manifest_stat(character_name, manifest_entry, "source_materials", RUNTIME_MESH_COUNT, failures)
			_validate_manifest_stat(character_name, manifest_entry, "runtime_meshes", meshes.size(), failures)
			if int(manifest_entry.get("runtime_vertices", -1)) != runtime_vertex_count:
				failures.append("%s manifest runtime_vertices=%s, imported=%d" % [character_name, manifest_entry.get("runtime_vertices"), runtime_vertex_count])
			_validate_manifest_stat(character_name, manifest_entry, "runtime_triangles", runtime_triangle_count, failures)
			if int(manifest_entry.get("runtime_materials", -1)) != runtime_materials.size():
				failures.append("%s manifest runtime_materials=%s, imported=%d" % [character_name, manifest_entry.get("runtime_materials"), runtime_materials.size()])
			_validate_file_size(character_name, str(manifest_entry.get("source", "")), int(manifest_entry.get("source_bytes", -1)), failures)
			var runtime_path := str(manifest_entry.get("runtime", ""))
			_validate_file_size(character_name, runtime_path, int(manifest_entry.get("runtime_bytes", -1)), failures)
			var runtime_sha256 := FileAccess.get_sha256("res://%s" % runtime_path)
			if runtime_sha256 != str(manifest_entry.get("runtime_sha256", "")):
				failures.append("%s manifest runtime_sha256=%s, actual=%s" % [character_name, manifest_entry.get("runtime_sha256"), runtime_sha256])

		var animation_track_count := -1
		var momentum_lean_count := 0
		var root_track_count := 0
		var changing_bones: Dictionary = {}
		for node in animation_players:
			var player := node as AnimationPlayer
			if not player.has_animation("MomentumLean"):
				continue
			var animation := player.get_animation("MomentumLean")
			if animation == null:
				continue
			momentum_lean_count += 1
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
		if momentum_lean_count != 1:
			failures.append("%s expected one MomentumLean animation, found %d" % [character_name, momentum_lean_count])
		for bone_name in changing_bones:
			if bone_name not in EXPECTED_ANIMATED_BONES:
				failures.append("%s MomentumLean unexpectedly animates non-root bone: %s" % [character_name, bone_name])

		var collision_count := character.find_children("*", "CollisionObject3D", true, false).size()
		if collision_count != 0:
			failures.append("%s imported %d collision objects" % [character_name, collision_count])
		var bone_count := (skeletons[0] as Skeleton3D).get_bone_count() if skeletons.size() == 1 else 0
		character_results.append("%s(meshes=%d,vertices=%d,triangles=%d,materials=%d,bones=%d,tracks=%d,root_tracks=%d,team_roles=RED+BLUE)" % [character_name, skinned_mesh_count, runtime_vertex_count, runtime_triangle_count, runtime_materials.size(), bone_count, animation_track_count, root_track_count])
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


func _load_character_manifest(failures: Array[String]) -> Dictionary:
	var file := FileAccess.open(CHARACTER_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		failures.append("character shell manifest did not open")
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		failures.append("character shell manifest is not valid JSON")
		return {}
	var entries: Dictionary = {}
	var variants := (parsed as Dictionary).get("variants", []) as Array
	if variants.size() != CHARACTER_PATHS.size():
		failures.append("character shell manifest expected %d variants, found %d" % [CHARACTER_PATHS.size(), variants.size()])
	for entry_variant in variants:
		var entry := entry_variant as Dictionary
		var entry_name := str(entry.get("name", ""))
		if entries.has(entry_name):
			failures.append("character shell manifest duplicate variant: %s" % entry_name)
		entries[entry_name] = entry
	return entries


func _validate_runtime_material_roles(
	character_name: String, character: Node, failures: Array[String]
) -> void:
	var expected_roles := COMMON_RUNTIME_ROLE_MATERIALS.duplicate()
	expected_roles.merge(ACCENT_RUNTIME_ROLE_MATERIALS[character_name])
	var role_meshes: Dictionary = {}
	for node in character.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		role_meshes[mesh_instance.name] = mesh_instance
		if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() != 1:
			failures.append("%s runtime role %s does not have exactly one surface" % [character_name, mesh_instance.name])
			continue
		var source_material := mesh_instance.get_active_material(0)
		var expected_material: StringName = expected_roles.get(mesh_instance.name, &"")
		if expected_material == &"":
			failures.append("%s unexpected runtime material role: %s" % [character_name, mesh_instance.name])
		elif source_material == null or source_material.resource_name != expected_material:
			failures.append("%s runtime role %s material=%s, expected=%s" % [character_name, mesh_instance.name, source_material.resource_name if source_material != null else &"<null>", expected_material])

	if role_meshes.size() != expected_roles.size():
		failures.append("%s expected %d runtime material roles, found %d" % [character_name, expected_roles.size(), role_meshes.size()])
	for role_name in expected_roles:
		if not role_meshes.has(role_name):
			failures.append("%s runtime material role missing: %s" % [character_name, role_name])

	for team_color in [Color("#c84a3d"), Color("#3b8fbd")]:
		var primary := StandardMaterial3D.new()
		primary.albedo_color = team_color
		var secondary := StandardMaterial3D.new()
		secondary.albedo_color = team_color.darkened(0.28)
		if not CharacterMaterialRoles.apply(character, primary, secondary):
			failures.append("%s consolidated team roles were not both found" % character_name)
		var primary_mesh := role_meshes.get(CharacterMaterialRoles.PRIMARY_TEAM_ROLE) as MeshInstance3D
		var secondary_mesh := role_meshes.get(CharacterMaterialRoles.SECONDARY_TEAM_ROLE) as MeshInstance3D
		if primary_mesh == null or primary_mesh.material_override != primary:
			failures.append("%s primary team role override failed" % character_name)
		if secondary_mesh == null or secondary_mesh.material_override != secondary:
			failures.append("%s secondary team role override failed" % character_name)


func _validate_manifest_stat(
	character_name: String,
	entry: Dictionary,
	field: String,
	actual: int,
	failures: Array[String]
) -> void:
	if int(entry.get(field, -1)) != actual:
		failures.append("%s manifest %s=%s, actual=%d" % [character_name, field, entry.get(field), actual])


func _validate_file_size(
	character_name: String,
	project_path: String,
	expected_bytes: int,
	failures: Array[String]
) -> void:
	var file := FileAccess.open("res://%s" % project_path, FileAccess.READ)
	if file == null:
		failures.append("%s manifest output missing: %s" % [character_name, project_path])
	elif file.get_length() != expected_bytes:
		failures.append("%s manifest bytes=%d for %s, actual=%d" % [character_name, expected_bytes, project_path, file.get_length()])


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
