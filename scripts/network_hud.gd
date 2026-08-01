extends CanvasLayer
class_name SkooshNetworkHUD

var player: SkooshNetworkPlayer
var _stats: Label
var _status: Label
var _death: Label
var _round_notice: Label
var _score: Label
var _objective: Label
var _reticle: Label
var _hit_time := 0.0
var _shot_time := 0.0
var _last_deaths := 0


func _ready() -> void:
	layer = 20
	visible = false
	_build()


func bind(target: SkooshNetworkPlayer) -> void:
	player = target
	_last_deaths = player.deaths
	visible = true


func flash_hit() -> void:
	_hit_time = 0.13


func flash_shot() -> void:
	_shot_time = 0.07


func _process(delta: float) -> void:
	if player == null:
		return
	_hit_time = maxf(0.0, _hit_time - delta)
	_shot_time = maxf(0.0, _shot_time - delta)
	var reticle_color := Color("#ffeb77") if _hit_time > 0.0 else Color("#5df4ed")
	_reticle.modulate = reticle_color
	_reticle.scale = Vector2.ONE * (1.28 if _shot_time > 0.0 else 1.0)
	var arena: Variant = player.get_parent().get_parent()
	var team_name: String = arena.get_team_name(player.team) if arena.has_method("get_team_name") else "SYNC"
	_stats.text = "%s TEAM     HEALTH  %03d     K / D  %d / %d\nSPEED   %5.1f m/s     JET  %03d" % [
		team_name, player.health, player.kills, player.deaths,
		player.horizontal_speed, roundi(player.jet_energy)
	]
	var team_color := Color("#ff776b") if player.team == 0 else Color("#62cfff")
	_stats.add_theme_color_override("font_color", team_color)
	var capture_limit: int = int(arena.get_capture_limit())
	_score.text = "RED  %d / %d  [%s]        ROUND %d        [%s]  %d / %d  BLUE" % [
		arena.red_score, capture_limit, arena.get_flag_status(0), arena.round_number,
		arena.get_flag_status(1), arena.blue_score, capture_limit
	]
	var carrying: bool = arena.player_carries_enemy_flag(player)
	_objective.visible = carrying
	_objective.text = "ENEMY FLAG ACQUIRED  //  RETURN TO YOUR PLATFORM" if carrying else ""
	_round_notice.visible = arena.round_over
	if arena.round_over:
		var won: bool = arena.winner_team == player.team
		var remaining := maxi(0, arena.round_restart_tick - NetworkTime.tick)
		_round_notice.text = ("YOUR TEAM WINS" if won else "YOUR TEAM LOSES") + "\nNEXT ROUND IN %.1f" % (remaining / 60.0)
	var rtt_ms := roundi(NetworkTimeSynchronizer.rtt * 1000.0)
	_status.text = "PULSE RIFLE  40 DMG     PEER #%d     RTT %d ms     ROLLBACK %d / %.2f ms" % [
		player.peer_id, rtt_ms, NetworkPerformance.get_rollback_ticks(),
		NetworkPerformance.get_rollback_loop_duration_ms()
	]
	_death.visible = player.dead
	if player.dead:
		var remaining := maxi(0, player.respawn_tick - NetworkTime.tick)
		_death.text = "ELIMINATED\nRESPAWN IN %.1f" % (remaining / 60.0)
	if player.deaths > _last_deaths:
		_last_deaths = player.deaths


func _build() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.5, 0.02, 0.02, 0.16)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.visible = false
	add_child(shade)

	_stats = _label(19, Color("#f0f2de"))
	_stats.position = Vector2(25, 22)
	_stats.size = Vector2(500, 62)
	add_child(_stats)

	_status = _label(14, Color(0.75, 0.91, 0.92, 0.9))
	_status.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_status.position = Vector2(-300, 62)
	_status.size = Vector2(600, 28)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_status)

	_score = _label(21, Color("#f2efda"))
	_score.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_score.position = Vector2(-390, 18)
	_score.size = Vector2(780, 34)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_score)

	_objective = _label(20, Color("#ffe46b"))
	_objective.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_objective.position = Vector2(-330, 98)
	_objective.size = Vector2(660, 34)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.visible = false
	add_child(_objective)

	_reticle = _label(28, Color("#5df4ed"))
	_reticle.text = "+"
	_reticle.set_anchors_preset(Control.PRESET_CENTER)
	_reticle.position = Vector2(-18, -22)
	_reticle.size = Vector2(36, 44)
	_reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reticle.pivot_offset = Vector2(18, 22)
	add_child(_reticle)

	var controls := _label(15, Color(0.91, 0.95, 0.87, 0.92))
	controls.text = "WASD  STEER     SPACE  SKI     SHIFT / RMB  JET     LMB  FIRE\nR  RESPAWN          ESC  RELEASE MOUSE          CLICK  RECAPTURE"
	controls.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	controls.position = Vector2(-430, -55)
	controls.size = Vector2(860, 48)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(controls)

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


func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.01, 0.03, 0.06, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
