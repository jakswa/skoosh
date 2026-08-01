extends Node

const TIMED_CAPTURES := {
	"10-spawn": 0.75,
	"30-combat": 3.0,
	"50-traversal": 7.0,
	"90-late-match": 13.0,
}

var _output_dir := ""
var _lobby_only := false
var _player: SkooshNetworkPlayer
var _gameplay_started_at := 0
var _queued: Dictionary = {}
var _capture_queue: Array[String] = []
var _writing := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-qa-dir="):
			_output_dir = arg.trim_prefix("--visual-qa-dir=")
		elif arg == "--visual-qa-lobby":
			_lobby_only = true
	if _output_dir.is_empty():
		set_process(false)
		return
	var error := DirAccess.make_dir_recursive_absolute(_output_dir)
	if error != OK:
		push_error("VISUAL_QA could not create output directory: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("VISUAL_QA capture enabled output=%s lobby_only=%s" % [_output_dir, _lobby_only])
	if _lobby_only:
		get_tree().create_timer(0.75).timeout.connect(func(): _queue_capture("00-lobby"))


func _process(_delta: float) -> void:
	if _lobby_only or _output_dir.is_empty():
		return
	if _player == null:
		var peer_id := multiplayer.get_unique_id()
		var arena := get_parent()
		if peer_id <= 1 or not "avatars" in arena:
			return
		_player = arena.avatars.get(peer_id) as SkooshNetworkPlayer
		if _player == null:
			return
		_gameplay_started_at = Time.get_ticks_msec()

	var elapsed := (Time.get_ticks_msec() - _gameplay_started_at) / 1000.0
	for capture_name: String in TIMED_CAPTURES:
		if elapsed >= float(TIMED_CAPTURES[capture_name]):
			_queue_capture(capture_name)

	var arena := get_parent()
	if _player.dead:
		_queue_capture("20-eliminated")
	if arena.player_carries_enemy_flag(_player):
		_queue_capture("60-flag-carrier")
	if arena.round_over:
		_queue_capture("70-round-result")


func _queue_capture(capture_name: String) -> void:
	if _queued.has(capture_name):
		return
	_queued[capture_name] = true
	_capture_queue.append(capture_name)
	if not _writing:
		call_deferred("_drain_capture_queue")


func _drain_capture_queue() -> void:
	if _writing:
		return
	_writing = true
	while not _capture_queue.is_empty():
		var capture_name: String = _capture_queue.pop_front()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := _output_dir.path_join(capture_name + ".png")
		var error := image.save_png(path)
		if error != OK:
			push_error("VISUAL_QA could not save %s: %s" % [path, error_string(error)])
		else:
			print("VISUAL_QA captured %s" % path)
	_writing = false
	if _lobby_only:
		get_tree().quit()
