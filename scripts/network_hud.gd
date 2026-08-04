extends CanvasLayer
class_name SkooshNetworkHUD

const VoiceCommandLibrary = preload("res://scripts/voice_command_library.gd")

var player: SkooshNetworkPlayer
var _stats: Label
var _status: Label
var _death: Label
var _round_notice: Label
var _score: Label
var _objective: Label
var _reticle: Label
var _weapon_status: Label
var _controls: Label
var _health_bar: ProgressBar
var _energy_bar: ProgressBar
var _reload_bar: ProgressBar
var _damage_shade: ColorRect
var _voice_panel: PanelContainer
var _voice_title: Label
var _voice_entries: Label
var _voice_toast: Label
var _voice_audio: AudioStreamPlayer
var _hit_time := 0.0
var _shot_time := 0.0
var _damage_time := 0.0
var _voice_toast_time := 0.0
var _last_health := 100
var _voice_category := -1
var _voice_scope := VoiceCommandLibrary.SCOPE_TEAM
var _debug_visible := false


func _ready() -> void:
	layer = 20
	visible = false
	_build()


func bind(target: SkooshNetworkPlayer) -> void:
	player = target
	_last_health = player.health
	visible = true


func flash_hit() -> void:
	_hit_time = 0.18


func flash_shot() -> void:
	_shot_time = 0.1


func play_voice_command(speaker_peer_id: int, command_id: int, scope: int) -> void:
	if player == null or command_id < 0 or command_id >= VoiceCommandLibrary.COMMANDS.size():
		return
	var stream := VoiceCommandLibrary.stream_for_peer(speaker_peer_id, command_id)
	if stream == null:
		return
	var command: Dictionary = VoiceCommandLibrary.COMMANDS[command_id]
	var callsign := SkooshNetworkPlayer.callsign_for_peer(speaker_peer_id)
	var scope_name := VoiceCommandLibrary.scope_name(scope)
	_voice_toast.text = "[%s] %s // %s" % [scope_name, callsign, command["label"]]
	_voice_toast.visible = true
	_voice_toast_time = 2.4
	_voice_audio.stream = stream
	_voice_audio.play()


func set_voice_menu_visible(open: bool) -> void:
	if open:
		_voice_category = -1
		_update_voice_menu()
	_voice_panel.visible = open


func close_voice_menu() -> bool:
	if not _voice_panel.visible:
		return false
	set_voice_menu_visible(false)
	return true


func is_voice_menu_visible() -> bool:
	return _voice_panel.visible


func set_voice_menu_category(category: int) -> void:
	_voice_category = clampi(category, 0, 2)
	_update_voice_menu()
	_voice_panel.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return
	if event.is_action_pressed("toggle_debug"):
		_debug_visible = not _debug_visible
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("voice_menu"):
		set_voice_menu_visible(not _voice_panel.visible)
		get_viewport().set_input_as_handled()
		return
	if not _voice_panel.visible or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode == KEY_G:
		_voice_scope = VoiceCommandLibrary.SCOPE_GLOBAL
		_update_voice_menu()
		get_viewport().set_input_as_handled()
		return
	if key_event.physical_keycode == KEY_T:
		_voice_scope = VoiceCommandLibrary.SCOPE_TEAM
		_update_voice_menu()
		get_viewport().set_input_as_handled()
		return
	var selection := _number_key_index(key_event.physical_keycode)
	if selection < 0:
		if key_event.keycode == KEY_ESCAPE:
			set_voice_menu_visible(false)
		return
	if _voice_category < 0:
		if selection < 3:
			_voice_category = selection
			_update_voice_menu()
	else:
		if selection < 4:
			var command_id := _voice_category * 4 + selection
			var arena := player.get_parent().get_parent()
			arena.send_voice_command(command_id, _voice_scope)
			set_voice_menu_visible(false)
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if player == null:
		return
	_hit_time = maxf(0.0, _hit_time - delta)
	_shot_time = maxf(0.0, _shot_time - delta)
	_damage_time = maxf(0.0, _damage_time - delta)
	_voice_toast_time = maxf(0.0, _voice_toast_time - delta)
	_voice_toast.visible = _voice_toast_time > 0.0
	_damage_shade.color.a = 0.2 * clampf(_damage_time / 0.22, 0.0, 1.0)
	if player.health < _last_health:
		_damage_time = 0.22
	_last_health = player.health

	_reticle.text = "x" if _hit_time > 0.0 else "+"
	_reticle.modulate = Color("#fff08a") if _hit_time > 0.0 else Color("#69f5c5")
	_reticle.scale = Vector2.ONE * (1.35 if _shot_time > 0.0 else 1.0)
	var arena := player.get_parent().get_parent()
	var team_name: String = arena.get_team_name(player.team)
	var callsign := SkooshNetworkPlayer.callsign_for_peer(player.peer_id)
	var team_color := Color("#ff6a5d") if player.team == 0 else Color("#55caff")
	_stats.text = "%s // %s\nHP  %03d        K/D  %d/%d\nSPEED  %5.1f m/s\nJET    %03d" % [
		team_name, callsign, player.health, player.kills, player.deaths,
		player.horizontal_speed, roundi(player.jet_energy)
	]
	_stats.add_theme_color_override("font_color", team_color)
	_health_bar.value = player.health
	_energy_bar.value = player.jet_energy
	var capture_limit: int = int(arena.get_capture_limit())
	_score.text = "RED  %d/%d  [%s]       MATCH %d       [%s]  %d/%d  BLUE" % [
		arena.red_score, capture_limit, arena.get_flag_status(0), arena.round_number,
		arena.get_flag_status(1), arena.blue_score, capture_limit
	]
	var carrying: bool = arena.player_carries_enemy_flag(player)
	_objective.text = (
		"OBJECTIVES REARMING // SCORE HOLDS"
		if arena.is_objective_resetting()
		else
		"RELAY KEY SECURED // RETURN TO YOUR STATION"
		if carrying
		else "ENEMY RELAY: %s     //     OUR RELAY: %s" % [
			arena.get_flag_status(1 if player.team == 0 else 0),
			arena.get_flag_status(player.team),
		]
	)
	_objective.add_theme_color_override(
		"font_color", Color("#ffe36d") if carrying else Color(0.75, 0.88, 0.86, 0.9)
	)
	var reload_fraction: float = player.get_weapon_readiness()
	_reload_bar.value = reload_fraction * 100.0
	_weapon_status.text = player.get_weapon_status()
	_round_notice.visible = arena.round_over
	if arena.round_over:
		var won: bool = arena.winner_team == player.team
		var round_remaining := maxi(0, arena.round_restart_tick - NetworkTime.tick)
		_round_notice.text = ("MATCH SECURED" if won else "MATCH LOST") + "\nNEXT MATCH IN %.1f" % (round_remaining / 60.0)
	_death.visible = player.dead
	if player.dead:
		var respawn_remaining := maxi(0, player.respawn_tick - NetworkTime.tick)
		_death.text = "SUIT OFFLINE\nREBOOT IN %.1f" % (respawn_remaining / 60.0)
	var rtt_ms := roundi(NetworkTimeSynchronizer.rtt * 1000.0)
	_status.visible = _debug_visible
	_status.text = "NET // PEER %d  RTT %dms  ROLLBACK %d ticks / %.2fms" % [
		player.peer_id, rtt_ms, NetworkPerformance.get_rollback_ticks(),
		NetworkPerformance.get_rollback_loop_duration_ms()
	]
	_controls.text = (
		"CLICK TO RECAPTURE POINTER"
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not player.input.bot_mode
		else "WASD STEER  SPACE SKI  SHIFT/RMB JET  LMB FIRE  1-4 WEAPONS  R RESPAWN  V COMMS  F3 NET  ESC POINTER"
	)


func _build() -> void:
	_damage_shade = ColorRect.new()
	_damage_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_shade.color = Color(0.85, 0.04, 0.02, 0.0)
	_damage_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_damage_shade)

	var score_panel := _panel(Color(0.025, 0.03, 0.031, 0.92), Color(0.28, 0.64, 0.55, 0.62))
	score_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	score_panel.position = Vector2(-335, 14)
	score_panel.size = Vector2(670, 78)
	add_child(score_panel)
	var score_layout := VBoxContainer.new()
	score_layout.add_theme_constant_override("separation", 0)
	score_panel.add_child(score_layout)
	_score = _label(22, Color("#f4f0d8"))
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_layout.add_child(_score)
	_objective = _label(14, Color(0.75, 0.88, 0.86, 0.9))
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_layout.add_child(_objective)

	var stats_panel := _panel(Color(0.025, 0.03, 0.031, 0.9), Color(0.3, 0.46, 0.43, 0.62))
	stats_panel.position = Vector2(22, 22)
	stats_panel.size = Vector2(265, 152)
	add_child(stats_panel)
	var stats_layout := VBoxContainer.new()
	stats_layout.add_theme_constant_override("separation", 2)
	stats_panel.add_child(stats_layout)
	_stats = _label(17, Color("#f0f2de"))
	stats_layout.add_child(_stats)
	_health_bar = _bar(Color("#ff6658"))
	stats_layout.add_child(_health_bar)
	_energy_bar = _bar(Color("#58e0d4"))
	stats_layout.add_child(_energy_bar)

	var weapon_panel := _panel(Color(0.025, 0.03, 0.031, 0.9), Color(0.38, 0.78, 0.62, 0.62))
	weapon_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon_panel.position = Vector2(-358, -138)
	weapon_panel.size = Vector2(336, 84)
	add_child(weapon_panel)
	var weapon_layout := VBoxContainer.new()
	weapon_layout.add_theme_constant_override("separation", 3)
	weapon_panel.add_child(weapon_layout)
	_weapon_status = _label(15, Color("#adf8d1"))
	weapon_layout.add_child(_weapon_status)
	_reload_bar = _bar(Color("#73f2af"))
	weapon_layout.add_child(_reload_bar)

	_reticle = _label(30, Color("#69f5c5"))
	_reticle.text = "+"
	_reticle.set_anchors_preset(Control.PRESET_CENTER)
	_reticle.position = Vector2(-18, -22)
	_reticle.size = Vector2(36, 44)
	_reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reticle.pivot_offset = Vector2(18, 22)
	add_child(_reticle)

	_controls = _label(14, Color(0.82, 0.9, 0.84, 0.88))
	_controls.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_controls.position = Vector2(-430, -34)
	_controls.size = Vector2(860, 24)
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_controls)

	_status = _label(13, Color(0.62, 0.82, 0.84, 0.9))
	_status.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_status.position = Vector2(22, -62)
	_status.size = Vector2(500, 24)
	_status.visible = false
	add_child(_status)

	_voice_toast = _label(20, Color("#fff1a8"))
	_voice_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_voice_toast.position = Vector2(-310, 110)
	_voice_toast.size = Vector2(620, 38)
	_voice_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_voice_toast.visible = false
	add_child(_voice_toast)

	_build_voice_panel()

	_death = _label(34, Color("#ff9b87"))
	_death.set_anchors_preset(Control.PRESET_CENTER)
	_death.position = Vector2(-220, -75)
	_death.size = Vector2(440, 150)
	_death.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death.visible = false
	add_child(_death)

	_round_notice = _label(40, Color("#ffe46b"))
	_round_notice.set_anchors_preset(Control.PRESET_CENTER)
	_round_notice.position = Vector2(-300, -100)
	_round_notice.size = Vector2(600, 200)
	_round_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_round_notice.visible = false
	add_child(_round_notice)

	_voice_audio = AudioStreamPlayer.new()
	_voice_audio.name = "VoiceCommandAudio"
	_voice_audio.volume_db = -1.5
	add_child(_voice_audio)


func _build_voice_panel() -> void:
	_voice_panel = _panel(Color(0.02, 0.025, 0.026, 0.97), Color(0.37, 0.78, 0.62, 0.88))
	_voice_panel.position = Vector2(24, 210)
	_voice_panel.size = Vector2(350, 270)
	_voice_panel.visible = false
	add_child(_voice_panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	_voice_panel.add_child(layout)
	_voice_title = _label(20, Color("#72f1bd"))
	layout.add_child(_voice_title)
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.3, 0.9, 0.68, 0.65)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(divider)
	_voice_entries = _label(17, Color("#edf3dc"))
	_voice_entries.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_voice_entries)
	var hint := _label(13, Color(0.62, 0.76, 0.74, 0.92))
	hint.text = "T TEAM  //  G GLOBAL  //  V CLOSE"
	layout.add_child(hint)
	_update_voice_menu()


func _update_voice_menu() -> void:
	if _voice_title == null:
		return
	var scope_name := VoiceCommandLibrary.scope_name(_voice_scope)
	if _voice_category < 0:
		_voice_title.text = "%s COMMS // SELECT CHANNEL" % scope_name
		_voice_entries.text = "1   SOCIAL\n2   OBJECTIVE\n3   STATUS"
		return
	var arena := player.get_parent().get_parent() if player != null else null
	var commands: Array = arena.get_voice_commands() if arena != null else []
	var category_names := ["SOCIAL", "OBJECTIVE", "STATUS"]
	_voice_title.text = "%s COMMS // %s" % [scope_name, category_names[_voice_category]]
	var lines: Array[String] = []
	for index in 4:
		var command_id := _voice_category * 4 + index
		var command_label := "COMMAND %d" % (index + 1)
		if command_id < commands.size():
			command_label = str(commands[command_id]["label"])
		lines.append("%d   %s" % [index + 1, command_label])
	_voice_entries.text = "\n".join(lines)


func _number_key_index(keycode: Key) -> int:
	match keycode:
		KEY_1:
			return 0
		KEY_2:
			return 1
		KEY_3:
			return 2
		KEY_4:
			return 3
	return -1


func _panel(background: Color, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 1
	style.corner_radius_top_right = 1
	style.corner_radius_bottom_left = 1
	style.corner_radius_bottom_right = 1
	style.content_margin_left = 14.0
	style.content_margin_top = 10.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 5)
	bar.max_value = 100.0
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.02, 0.08, 0.1, 0.9)
	background.corner_radius_top_left = 2
	background.corner_radius_top_right = 2
	background.corner_radius_bottom_left = 2
	background.corner_radius_bottom_right = 2
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.corner_radius_top_left = 2
	fill.corner_radius_top_right = 2
	fill.corner_radius_bottom_left = 2
	fill.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.01, 0.03, 0.06, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
