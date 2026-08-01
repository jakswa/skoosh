extends CanvasLayer

var player
var course
var _root: Control
var _speed_label: Label
var _timer_label: Label
var _best_label: Label
var _checkpoint_label: Label
var _jet_bar: ProgressBar
var _jet_status: Label
var _controls: Label
var _controls_panel: PanelContainer
var _completion_panel: PanelContainer
var _completion_label: Label
var _pause_backdrop: ColorRect
var _pause_label: Label
var _debug_label: Label
var _jet_tint: ColorRect
var _jet_fill_style: StyleBoxFlat
var _debug_visible := false
var _controls_time := 0.0


func _ready() -> void:
	_build_interface()


func bind(new_player, new_course) -> void:
	player = new_player
	course = new_course
	course.run_state_changed.connect(_on_run_state_changed)
	course.run_finished.connect(_on_run_finished)
	_on_run_state_changed(course.state)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_debug_visible = not _debug_visible
		_debug_label.visible = _debug_visible


func _process(delta: float) -> void:
	if player == null or course == null:
		return
	_speed_label.text = "%03d\n[m/s]" % int(round(player.horizontal_speed))
	_timer_label.text = "TIME  " + course.format_time(course.elapsed_time)
	_best_label.text = "BEST  " + course.format_time(course.best_time)
	_checkpoint_label.text = "CHECKPOINT  %d / %d" % [course.expected_checkpoint, course.gates.size()]
	_jet_bar.value = player.jet_energy
	if player.jet_active:
		_jet_status.text = "JET  FIRING"
		_jet_fill_style.bg_color = Color("#37edf2")
		_jet_tint.color = Color(0.1, 0.85, 1.0, 0.055)
	elif player.jet_energy <= 0.01:
		_jet_status.text = "JET  DEPLETED"
		_jet_fill_style.bg_color = Color("#e25e77")
		_jet_tint.color = Color.TRANSPARENT
	elif player.jet_energy < player.max_jet_energy:
		_jet_status.text = "JET  RECHARGING"
		_jet_fill_style.bg_color = Color("#82d9bd")
		_jet_tint.color = Color.TRANSPARENT
	else:
		_jet_status.text = "JET  READY"
		_jet_fill_style.bg_color = Color("#78d7bc")
		_jet_tint.color = Color.TRANSPARENT

	if course.state == 1:
		_controls_time += delta
		_controls_panel.modulate.a = clamp(1.0 - (_controls_time - 3.5) / 1.5, 0.0, 1.0)
	if _debug_visible:
		var velocity: Vector3 = player.velocity
		_debug_label.text = (
			"MOVEMENT / F3\nGROUND  %s\nSKI     %s\nJET     %s\nVEL     %6.1f %6.1f %6.1f\nFLOOR   %5.1f deg\nVERT    %6.1f m/s\nENERGY  %5.1f"
			% [
				str(player.is_on_floor()), str(player.ski_held), str(player.jet_active),
				velocity.x, velocity.y, velocity.z, player.floor_angle_degrees,
				velocity.y, player.jet_energy
			]
		)


func set_mouse_paused(paused: bool) -> void:
	_pause_backdrop.visible = paused
	_pause_label.visible = paused


func _on_run_state_changed(state: int) -> void:
	if state == 0:
		_controls_time = 0.0
		_controls_panel.modulate.a = 1.0
		_completion_panel.visible = false
	elif state == 2:
		_controls_panel.modulate.a = 0.0


func _on_run_finished(time: float, is_best: bool) -> void:
	var headline := "NEW BEST LINE" if is_best else "COURSE COMPLETE"
	_completion_label.text = "%s\n\n%s\nBEST  %s\n\nR  TO RUN AGAIN" % [
		headline, course.format_time(time), course.format_time(course.best_time)
	]
	_completion_panel.visible = true


func _build_interface() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_jet_tint = ColorRect.new()
	_jet_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_jet_tint.color = Color.TRANSPARENT
	_jet_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_jet_tint)

	var timing_panel := Panel.new()
	timing_panel.position = Vector2(18, 16)
	timing_panel.size = Vector2(265, 102)
	timing_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.025, 0.07, 0.12, 0.63)))
	timing_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(timing_panel)

	_timer_label = _make_label(23, Color("#f0f2de"))
	_timer_label.position = Vector2(28, 24)
	_root.add_child(_timer_label)
	_best_label = _make_label(16, Color("#b7c5c0"))
	_best_label.position = Vector2(29, 55)
	_root.add_child(_best_label)
	var title := _make_label(17, Color("#62eee9"))
	title.text = "S K O O S H"
	title.position = Vector2(29, 86)
	_root.add_child(title)

	var checkpoint_panel := Panel.new()
	checkpoint_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	checkpoint_panel.position = Vector2(-190, 16)
	checkpoint_panel.size = Vector2(380, 48)
	checkpoint_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.025, 0.07, 0.12, 0.58)))
	checkpoint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(checkpoint_panel)
	_checkpoint_label = _make_label(20, Color("#5df4ed"))
	_checkpoint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_checkpoint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_checkpoint_label.position = Vector2(-170, 24)
	_checkpoint_label.size = Vector2(340, 32)
	_root.add_child(_checkpoint_label)

	var crosshair := _make_label(24, Color(0.88, 1.0, 0.96, 0.9))
	crosshair.text = "+"
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-14, -17)
	crosshair.size = Vector2(28, 28)
	_root.add_child(crosshair)

	_speed_label = _make_label(35, Color("#eff9e8"))
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_speed_label.position = Vector2(-100, -145)
	_speed_label.size = Vector2(200, 90)
	_root.add_child(_speed_label)

	var jet_panel := Panel.new()
	jet_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	jet_panel.position = Vector2(18, -101)
	jet_panel.size = Vector2(380, 88)
	jet_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.025, 0.07, 0.12, 0.66)))
	jet_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(jet_panel)

	_jet_bar = ProgressBar.new()
	_jet_bar.min_value = 0.0
	_jet_bar.max_value = 100.0
	_jet_bar.value = 100.0
	_jet_bar.show_percentage = false
	_jet_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_jet_bar.position = Vector2(28, -62)
	_jet_bar.size = Vector2(260, 16)
	var jet_background := StyleBoxFlat.new()
	jet_background.bg_color = Color(0.04, 0.10, 0.15, 0.82)
	jet_background.corner_radius_top_left = 4
	jet_background.corner_radius_top_right = 4
	jet_background.corner_radius_bottom_left = 4
	jet_background.corner_radius_bottom_right = 4
	_jet_bar.add_theme_stylebox_override("background", jet_background)
	_jet_fill_style = StyleBoxFlat.new()
	_jet_fill_style.bg_color = Color("#78d7bc")
	_jet_fill_style.corner_radius_top_left = 4
	_jet_fill_style.corner_radius_top_right = 4
	_jet_fill_style.corner_radius_bottom_left = 4
	_jet_fill_style.corner_radius_bottom_right = 4
	_jet_bar.add_theme_stylebox_override("fill", _jet_fill_style)
	_root.add_child(_jet_bar)

	_jet_status = _make_label(14, Color("#d6e8df"))
	_jet_status.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_jet_status.position = Vector2(28, -87)
	_jet_status.size = Vector2(260, 24)
	_root.add_child(_jet_status)

	_controls_panel = PanelContainer.new()
	_controls_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_controls_panel.position = Vector2(-405, -57)
	_controls_panel.size = Vector2(810, 54)
	_controls_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.025, 0.07, 0.12, 0.7)))
	_controls_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_controls_panel)
	_controls = _make_label(16, Color(0.91, 0.95, 0.87, 0.92))
	_controls.text = "WASD  STEER     SPACE  SKI     SHIFT / RMB  JET\nR  RESET          ESC  RELEASE MOUSE          F3  DEBUG"
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_controls_panel.add_child(_controls)

	_debug_label = _make_label(14, Color("#c6fff4"))
	_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_debug_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_debug_label.position = Vector2(-285, 24)
	_debug_label.size = Vector2(260, 190)
	_debug_label.visible = false
	_root.add_child(_debug_label)

	_completion_panel = PanelContainer.new()
	_completion_panel.set_anchors_preset(Control.PRESET_CENTER)
	_completion_panel.position = Vector2(-220, -135)
	_completion_panel.size = Vector2(440, 270)
	var completion_style := StyleBoxFlat.new()
	completion_style.bg_color = Color(0.035, 0.08, 0.13, 0.94)
	completion_style.border_width_left = 2
	completion_style.border_width_top = 2
	completion_style.border_width_right = 2
	completion_style.border_width_bottom = 2
	completion_style.border_color = Color("#49e8e7")
	completion_style.corner_radius_top_left = 10
	completion_style.corner_radius_top_right = 10
	completion_style.corner_radius_bottom_left = 10
	completion_style.corner_radius_bottom_right = 10
	_completion_panel.add_theme_stylebox_override("panel", completion_style)
	_root.add_child(_completion_panel)
	_completion_label = _make_label(25, Color("#eaf8e9"))
	_completion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_completion_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_completion_panel.add_child(_completion_label)
	_completion_panel.visible = false

	_pause_backdrop = ColorRect.new()
	_pause_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_backdrop.color = Color(0.015, 0.035, 0.06, 0.48)
	_pause_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_backdrop.visible = false
	_root.add_child(_pause_backdrop)
	_pause_label = _make_label(24, Color("#f1f4df"))
	_pause_label.text = "MOUSE RELEASED\nCLICK TO RESUME"
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pause_label.set_anchors_preset(Control.PRESET_CENTER)
	_pause_label.position = Vector2(-180, -55)
	_pause_label.size = Vector2(360, 110)
	_pause_label.visible = false
	_root.add_child(_pause_label)


func _make_panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
