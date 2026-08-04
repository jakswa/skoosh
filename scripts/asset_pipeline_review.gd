extends Node3D

@onready var suits: Array[Node3D] = [
	$VectorSprinterMk2,
	$StratosFoilframe,
	$KhepriTriuneSalvage,
]


func _ready() -> void:
	for suit in suits:
		for node in suit.find_children("*", "AnimationPlayer", true, false):
			var animation_player := node as AnimationPlayer
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
	for suit in suits:
		suit.rotate_y(delta * 0.22)
