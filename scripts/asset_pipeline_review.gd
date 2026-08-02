extends Node3D

@onready var suit := $RunwaySuitRig
@onready var animation_player := $RunwaySuitRig/AnimationPlayer as AnimationPlayer


func _ready() -> void:
	var animation := animation_player.get_animation("MomentumLean")
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR
	animation_player.play("MomentumLean")
	if not OS.get_environment("SKOOSH_ASSET_REVIEW_CAPTURE").is_empty():
		_capture_review.call_deferred()


func _capture_review() -> void:
	for _frame in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("SKOOSH_ASSET_REVIEW_CAPTURE")
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not save asset review: %s" % error_string(error))
	get_tree().quit(error)


func _process(delta: float) -> void:
	# Slow turntable motion makes skin deformation and silhouette easy to inspect.
	suit.rotate_y(delta * 0.32)
