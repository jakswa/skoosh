extends Node

const TIMED_CAPTURES := {
	"10-spawn": 0.75,
	"30-combat": 3.0,
	"50-traversal": 7.0,
	"90-late-match": 13.0,
}
const SLOT_TIMED_CAPTURES := {
	1: {"name": "24-slot-2-grenade", "earliest": 2.55},
	2: {"name": "36-slot-3-gatling", "earliest": 4.55},
	3: {"name": "48-slot-4-sniper", "earliest": 6.55},
}

var _output_dir := ""
var _lobby_only := false
var _player: SkooshNetworkPlayer
var _gameplay_started_at := 0
var _queued: Dictionary = {}
var _capture_queue: Array[String] = []
var _writing := false
var _comms_capture_started := false
var _comms_capture_closed := false


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
		_player.input.visual_qa_lock = true

	var elapsed := (Time.get_ticks_msec() - _gameplay_started_at) / 1000.0
	if elapsed >= 1.35 and not _comms_capture_started:
		_comms_capture_started = true
		_player.hud.set_voice_menu_category(0)
		_queue_capture("12-team-comms")
	if elapsed >= 2.15 and not _comms_capture_closed:
		_comms_capture_closed = true
		_player.hud.set_voice_menu_visible(false)
		_player.input.visual_qa_lock = false
	for capture_name: String in TIMED_CAPTURES:
		if elapsed >= float(TIMED_CAPTURES[capture_name]):
			_queue_capture(capture_name)
	for slot_variant in SLOT_TIMED_CAPTURES:
		var slot := int(slot_variant)
		var capture: Dictionary = SLOT_TIMED_CAPTURES[slot]
		if (
			elapsed >= float(capture["earliest"])
			and _player.active_weapon_slot == slot
			and NetworkTime.tick - _player.weapon_switch_tick >= SkooshNetworkPlayer.WEAPON_SWITCH_TICKS
		):
			_queue_capture(str(capture["name"]))

	var arena := get_parent()
	if _player.dead:
		_queue_capture("20-eliminated")
	if arena.player_carries_enemy_flag(_player):
		_queue_capture("60-flag-carrier")
	if arena.round_over:
		_queue_capture("70-round-result")
	if not _player.hud.is_voice_menu_visible() and arena.get_projectile_container().get_child_count() > 0:
		_queue_capture("32-projectile-flight")
	if arena.get_effect_container().get_child_count() > 0:
		_queue_capture("34-combat-effect")


func _queue_capture(capture_name: String) -> void:
	if _queued.has(capture_name) or not _capture_state_is_valid(capture_name):
		return
	_queued[capture_name] = true
	_capture_queue.append(capture_name)
	if not _writing:
		call_deferred("_drain_capture_queue")


func _capture_state_is_valid(capture_name: String) -> bool:
	if _lobby_only:
		return capture_name == "00-lobby"
	if _player == null:
		return false
	return _player.dead == (capture_name == "20-eliminated")


func _drain_capture_queue() -> void:
	if _writing:
		return
	_writing = true
	while not _capture_queue.is_empty():
		var capture_name: String = _capture_queue.pop_front()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if not _capture_state_is_valid(capture_name):
			_queued.erase(capture_name)
			continue
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
