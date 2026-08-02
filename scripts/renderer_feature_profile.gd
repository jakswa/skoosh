extends Node

## Renderer qualification profiles. These only alter client presentation and
## deliberately leave authoritative simulation, collision, and networking alone.
const PROFILE_LEAN := "lean"
const PROFILE_BALANCED := "balanced"
const PROFILE_SHOWCASE := "showcase"

@export var world_environment_path: NodePath
@export var local_volume_paths: Array[NodePath] = []


func _ready() -> void:
	if DisplayServer.get_name().contains("headless"):
		return
	var world := get_node(world_environment_path) as WorldEnvironment
	if world == null or world.environment == null:
		push_error("Renderer profile requires a WorldEnvironment")
		return
	var profile := OS.get_environment("SKOOSH_RENDERER_PROFILE").to_lower()
	if profile.is_empty():
		profile = PROFILE_BALANCED
	_apply_profile(world.environment, profile)
	print("RENDERER profile=%s method=%s driver=%s" % [
		profile,
		RenderingServer.get_current_rendering_method(),
		RenderingServer.get_current_rendering_driver_name(),
	])


func _apply_profile(environment: Environment, profile: String) -> void:
	var enable_ssao := profile != PROFILE_LEAN
	var enable_volumetrics := profile != PROFILE_LEAN
	var enable_expensive := profile == PROFILE_SHOWCASE

	environment.ssao_enabled = enable_ssao
	environment.volumetric_fog_enabled = enable_volumetrics
	environment.ssil_enabled = enable_expensive
	environment.ssr_enabled = enable_expensive
	environment.sdfgi_enabled = enable_expensive
	for path in local_volume_paths:
		var volume := get_node(path) as FogVolume
		if volume != null:
			volume.visible = enable_volumetrics

	var viewport := get_viewport()
	viewport.use_taa = enable_expensive
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if enable_expensive else Viewport.SCREEN_SPACE_AA_FXAA
