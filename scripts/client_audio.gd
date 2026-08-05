extends Node
class_name SkooshClientAudio

const FLAG_HOME := 0
const FLAG_CARRIED := 1
const FLAG_DROPPED := 2
const SILENT_DB := -60.0
const LOOP_FADE_DB_PER_SECOND := 42.0
const MAX_POSITIONAL_PLAYERS := 32

const AMBIENCE_PATHS := {
	"faultline_basin": "res://audio/generated/ambience/faultline_basin.ogg",
	"cairn_steps": "res://audio/generated/ambience/cairn_steps.ogg",
}
const MOVEMENT_PATHS := {
	"wind": "res://audio/generated/movement/wind_loop.ogg",
	"ski": "res://audio/generated/movement/ski_loop.ogg",
	"jet": "res://audio/generated/movement/jet_loop.ogg",
	"land": "res://audio/generated/movement/land.wav",
	"jet_empty": "res://audio/generated/movement/jet_empty.wav",
}
const MUSIC_PATHS := {
	"exploration": "res://audio/generated/music/exploration.ogg",
	"combat": "res://audio/generated/music/combat.ogg",
	"objective": "res://audio/generated/music/objective.ogg",
}
const WEAPON_FIRE_PATHS: Array[String] = [
	"res://audio/generated/weapons/disc_fire.wav",
	"res://audio/generated/weapons/grenade_fire.wav",
	"res://audio/generated/weapons/gatling_fire.wav",
	"res://audio/generated/weapons/sniper_fire.wav",
]
const WEAPON_IMPACT_PATHS: Array[String] = [
	"res://audio/generated/weapons/disc_impact.wav",
	"res://audio/generated/weapons/grenade_impact.wav",
	"res://audio/generated/weapons/hitscan_impact.wav",
	"res://audio/generated/weapons/hitscan_impact.wav",
]
const UI_PATHS := {
	"hit": "res://audio/generated/ui/hit_confirm.wav",
	"damage": "res://audio/generated/ui/damage.wav",
	"death": "res://audio/generated/ui/death.wav",
	"respawn": "res://audio/generated/ui/respawn.wav",
	"switch": "res://audio/generated/ui/weapon_switch.wav",
}
const OBJECTIVE_PATHS := {
	"pickup": "res://audio/generated/objective/flag_pickup.wav",
	"drop": "res://audio/generated/objective/flag_drop.wav",
	"return": "res://audio/generated/objective/flag_return.wav",
	"capture": "res://audio/generated/objective/capture.wav",
	"victory": "res://audio/generated/objective/victory.wav",
	"defeat": "res://audio/generated/objective/defeat.wav",
	"start": "res://audio/generated/objective/match_start.wav",
}

var _enabled := false
var _streams: Dictionary = {}
var _wind: AudioStreamPlayer
var _ski: AudioStreamPlayer
var _jet: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _music: AudioStreamPlayer
var _music_stream: AudioStreamSynchronized
var _exploration_music_db := -16.0
var _combat_music_db := SILENT_DB
var _objective_music_db := SILENT_DB
var _positional_players: Array[AudioStreamPlayer3D] = []
var _local_player: SkooshNetworkPlayer
var _loops_started := false
var _combat_heat := 0.0
var _last_generation := -1
var _last_map_id := ""
var _last_health := -1
var _last_dead := false
var _last_weapon_slot := -1
var _last_grounded := false
var _last_velocity_y := 0.0
var _last_jet_active := false
var _last_red_score := -1
var _last_blue_score := -1
var _last_red_flag_state := -1
var _last_blue_flag_state := -1
var _last_round_over := false


func _ready() -> void:
	_enabled = not _is_headless_or_server()
	if not _enabled:
		set_process(false)
		return
	_build_loop_players()


func _process(delta: float) -> void:
	var arena := get_parent()
	var player := arena.avatars.get(multiplayer.get_unique_id()) as SkooshNetworkPlayer
	if player != _local_player:
		_bind_local_player(player)
	if (
		_local_player == null
		or not _local_player.gameplay_admitted
		or not arena.is_world_active()
		or arena.match_state_generation != arena.world_generation
	):
		_fade_continuous_audio(delta)
		return
	if not _loops_started:
		_start_loops()
	if arena.world_generation != _last_generation:
		_reset_match_snapshot(arena)
	_update_map_ambience(str(arena.map_id))
	_ambience.volume_db = move_toward(
		_ambience.volume_db, -19.0, delta * LOOP_FADE_DB_PER_SECOND * 0.35
	)
	_update_movement(delta)
	_update_local_feedback()
	_update_objective_feedback(arena)
	_update_music(delta, arena)
	_combat_heat = move_toward(_combat_heat, 0.0, delta * 0.085)


func weapon_fired(slot: int, position: Vector3, local_shooter: bool, generation: int) -> void:
	if not _event_is_current(generation):
		return
	var index := clampi(slot, 0, WEAPON_FIRE_PATHS.size() - 1)
	_combat_heat = minf(1.0, _combat_heat + (0.11 if index == 2 else 0.24))
	if local_shooter:
		_play_2d(WEAPON_FIRE_PATHS[index], &"SFX", -2.0)
	else:
		_play_3d(WEAPON_FIRE_PATHS[index], position, -1.0, 95.0)


func weapon_impact(slot: int, position: Vector3, hit_enemy: bool, generation: int) -> void:
	if not _event_is_current(generation):
		return
	var index := clampi(slot, 0, WEAPON_IMPACT_PATHS.size() - 1)
	_play_3d(WEAPON_IMPACT_PATHS[index], position, 1.0 if hit_enemy else -2.5, 115.0)
	if _local_player != null and _local_player.global_position.distance_to(position) < 45.0:
		_combat_heat = minf(1.0, _combat_heat + 0.14)


func confirm_hit() -> void:
	if not _enabled:
		return
	_combat_heat = minf(1.0, _combat_heat + 0.24)
	_play_2d(UI_PATHS["hit"], &"UI", -2.0)


static func required_asset_paths() -> Array[String]:
	var paths: Array[String] = []
	for path_variant in AMBIENCE_PATHS.values():
		paths.append(str(path_variant))
	for path_variant in MOVEMENT_PATHS.values():
		paths.append(str(path_variant))
	for path_variant in MUSIC_PATHS.values():
		paths.append(str(path_variant))
	paths.append_array(WEAPON_FIRE_PATHS)
	for path in WEAPON_IMPACT_PATHS:
		if not paths.has(path):
			paths.append(path)
	for path_variant in UI_PATHS.values():
		paths.append(str(path_variant))
	for path_variant in OBJECTIVE_PATHS.values():
		paths.append(str(path_variant))
	return paths


static func combat_layer_volume_db(heat: float) -> float:
	return lerpf(SILENT_DB, -8.0, smoothstep(0.08, 0.9, clampf(heat, 0.0, 1.0)))


func _build_loop_players() -> void:
	_wind = _create_loop_player("Wind", &"Movement", MOVEMENT_PATHS["wind"], SILENT_DB)
	_ski = _create_loop_player("Ski", &"Movement", MOVEMENT_PATHS["ski"], SILENT_DB)
	_jet = _create_loop_player("Jet", &"Movement", MOVEMENT_PATHS["jet"], SILENT_DB)
	_ambience = _create_loop_player("MapAmbience", &"Ambience", "", SILENT_DB)
	_music_stream = AudioStreamSynchronized.new()
	_music_stream.stream_count = 3
	_music_stream.set_sync_stream(0, _loop_stream(MUSIC_PATHS["exploration"]))
	_music_stream.set_sync_stream(1, _loop_stream(MUSIC_PATHS["combat"]))
	_music_stream.set_sync_stream(2, _loop_stream(MUSIC_PATHS["objective"]))
	_music_stream.set_sync_stream_volume(0, -16.0)
	_music_stream.set_sync_stream_volume(1, SILENT_DB)
	_music_stream.set_sync_stream_volume(2, SILENT_DB)
	_music = AudioStreamPlayer.new()
	_music.name = "AdaptiveMusic"
	_music.bus = &"Music"
	_music.stream = _music_stream
	add_child(_music)


func _create_loop_player(
	player_name: String, bus_name: StringName, path: String, volume_db: float
) -> AudioStreamPlayer:
	var audio_player := AudioStreamPlayer.new()
	audio_player.name = player_name
	audio_player.bus = bus_name
	audio_player.volume_db = volume_db
	if not path.is_empty():
		audio_player.stream = _loop_stream(path)
	add_child(audio_player)
	return audio_player


func _bind_local_player(player: SkooshNetworkPlayer) -> void:
	_local_player = player
	_last_generation = -1
	_combat_heat = 0.0
	_last_health = player.health if player != null else -1
	_last_dead = player.dead if player != null else false
	_last_weapon_slot = player.active_weapon_slot if player != null else -1
	_last_grounded = player.is_on_floor() if player != null else false
	_last_velocity_y = player.velocity.y if player != null else 0.0
	_last_jet_active = player.jet_active if player != null else false


func _start_loops() -> void:
	_loops_started = true
	for player in [_wind, _ski, _jet, _music]:
		player.play()


func _update_map_ambience(map_id: String) -> void:
	if map_id == _last_map_id or not AMBIENCE_PATHS.has(map_id):
		return
	_last_map_id = map_id
	_ambience.stop()
	_ambience.stream = _loop_stream(str(AMBIENCE_PATHS[map_id]))
	_ambience.volume_db = SILENT_DB
	_ambience.play()


func _update_movement(delta: float) -> void:
	var speed_fraction := clampf((_local_player.horizontal_speed - 7.0) / 75.0, 0.0, 1.0)
	var wind_target := lerpf(SILENT_DB, -7.5, sqrt(speed_fraction))
	var grounded := _local_player.is_on_floor()
	var ski_fraction := clampf((_local_player.horizontal_speed - 3.0) / 38.0, 0.0, 1.0)
	var ski_target := lerpf(SILENT_DB, -9.0, ski_fraction) if grounded and _local_player.ski_held else SILENT_DB
	var jet_target := -7.0 if _local_player.jet_active else SILENT_DB
	_wind.volume_db = move_toward(_wind.volume_db, wind_target, delta * LOOP_FADE_DB_PER_SECOND)
	_ski.volume_db = move_toward(_ski.volume_db, ski_target, delta * LOOP_FADE_DB_PER_SECOND)
	_jet.volume_db = move_toward(_jet.volume_db, jet_target, delta * LOOP_FADE_DB_PER_SECOND * 1.5)
	_wind.pitch_scale = lerpf(0.78, 1.34, speed_fraction)
	_ski.pitch_scale = lerpf(0.86, 1.16, ski_fraction)
	_jet.pitch_scale = lerpf(0.88, 1.08, _local_player.jet_energy / _local_player.max_jet_energy)
	if grounded and not _last_grounded and _last_velocity_y < -6.0:
		var landing_db := lerpf(-14.0, -3.0, clampf((-_last_velocity_y - 6.0) / 30.0, 0.0, 1.0))
		_play_2d(MOVEMENT_PATHS["land"], &"Movement", landing_db)
	if _last_jet_active and not _local_player.jet_active and _local_player.jet_energy <= 0.05:
		_play_2d(MOVEMENT_PATHS["jet_empty"], &"UI", -5.0)
	_last_grounded = grounded
	_last_velocity_y = _local_player.velocity.y
	_last_jet_active = _local_player.jet_active


func _fade_continuous_audio(delta: float) -> void:
	if not _loops_started:
		return
	for player in [_wind, _ski, _jet]:
		player.volume_db = move_toward(player.volume_db, SILENT_DB, delta * LOOP_FADE_DB_PER_SECOND)
	_ambience.volume_db = move_toward(
		_ambience.volume_db, SILENT_DB, delta * LOOP_FADE_DB_PER_SECOND * 0.5
	)
	_exploration_music_db = move_toward(
		_exploration_music_db, SILENT_DB, delta * LOOP_FADE_DB_PER_SECOND * 0.5
	)
	_combat_music_db = move_toward(
		_combat_music_db, SILENT_DB, delta * LOOP_FADE_DB_PER_SECOND
	)
	_objective_music_db = move_toward(
		_objective_music_db, SILENT_DB, delta * LOOP_FADE_DB_PER_SECOND
	)
	_music_stream.set_sync_stream_volume(0, _exploration_music_db)
	_music_stream.set_sync_stream_volume(1, _combat_music_db)
	_music_stream.set_sync_stream_volume(2, _objective_music_db)


func _update_local_feedback() -> void:
	if _local_player.health < _last_health:
		_combat_heat = minf(1.0, _combat_heat + 0.34)
		_play_2d(UI_PATHS["damage"], &"UI", -2.0)
	if _local_player.dead and not _last_dead:
		_play_2d(UI_PATHS["death"], &"UI", -1.0)
	elif not _local_player.dead and _last_dead:
		_play_2d(UI_PATHS["respawn"], &"UI", -3.0)
	if _last_weapon_slot >= 0 and _local_player.active_weapon_slot != _last_weapon_slot:
		_play_2d(UI_PATHS["switch"], &"UI", -7.0)
	_last_health = _local_player.health
	_last_dead = _local_player.dead
	_last_weapon_slot = _local_player.active_weapon_slot


func _update_objective_feedback(arena: Node) -> void:
	if arena.match_state_generation != arena.world_generation or not arena.is_world_active():
		return
	var captured: bool = arena.red_score > _last_red_score or arena.blue_score > _last_blue_score
	if captured:
		_play_2d(OBJECTIVE_PATHS["capture"], &"UI", -1.0)
		_combat_heat = maxf(_combat_heat, 0.72)
	if arena.round_over and not _last_round_over:
		var result := "victory" if arena.winner_team == _local_player.team else "defeat"
		_play_2d(OBJECTIVE_PATHS[result], &"UI", 0.0)
	elif not arena.round_over and _last_round_over:
		_play_2d(OBJECTIVE_PATHS["start"], &"UI", -2.0)
	if not captured:
		_present_flag_transition(_last_red_flag_state, arena.red_flag_state, arena.red_flag_carrier)
		_present_flag_transition(_last_blue_flag_state, arena.blue_flag_state, arena.blue_flag_carrier)
	_last_red_score = arena.red_score
	_last_blue_score = arena.blue_score
	_last_red_flag_state = arena.red_flag_state
	_last_blue_flag_state = arena.blue_flag_state
	_last_round_over = arena.round_over


func _present_flag_transition(previous: int, current: int, carrier: int) -> void:
	if previous < 0 or previous == current:
		return
	if current == FLAG_CARRIED:
		_play_2d(OBJECTIVE_PATHS["pickup"], &"UI", 0.0 if carrier == _local_player.peer_id else -5.0)
	elif current == FLAG_DROPPED:
		_play_2d(OBJECTIVE_PATHS["drop"], &"UI", -4.0)
	elif current == FLAG_HOME and previous == FLAG_DROPPED:
		_play_2d(OBJECTIVE_PATHS["return"], &"UI", -3.0)


func _update_music(delta: float, arena: Node) -> void:
	var local_carrying: bool = arena.player_carries_enemy_flag(_local_player)
	var objective_pressure := 1.0 if local_carrying else 0.38 if (
		arena.red_flag_state == FLAG_CARRIED or arena.blue_flag_state == FLAG_CARRIED
	) else 0.0
	var combat_target := combat_layer_volume_db(_combat_heat)
	var objective_target := lerpf(SILENT_DB, -9.5, objective_pressure)
	_exploration_music_db = move_toward(_exploration_music_db, -16.0, delta * 12.0)
	_combat_music_db = move_toward(_combat_music_db, combat_target, delta * 18.0)
	_objective_music_db = move_toward(_objective_music_db, objective_target, delta * 16.0)
	_music_stream.set_sync_stream_volume(0, _exploration_music_db)
	_music_stream.set_sync_stream_volume(1, _combat_music_db)
	_music_stream.set_sync_stream_volume(2, _objective_music_db)


func _reset_match_snapshot(arena: Node) -> void:
	_last_generation = arena.world_generation
	_last_red_score = arena.red_score
	_last_blue_score = arena.blue_score
	_last_red_flag_state = arena.red_flag_state
	_last_blue_flag_state = arena.blue_flag_state
	_last_round_over = arena.round_over
	_last_map_id = ""
	_combat_heat = 0.0
	_exploration_music_db = SILENT_DB
	_combat_music_db = SILENT_DB
	_objective_music_db = SILENT_DB


func _event_is_current(generation: int) -> bool:
	if not _enabled or _local_player == null:
		return false
	var arena := get_parent()
	return generation == arena.world_generation and arena.is_world_active()


func _play_2d(path: String, bus_name: StringName, volume_db: float) -> void:
	if not _enabled:
		return
	var player := AudioStreamPlayer.new()
	player.bus = bus_name
	player.stream = _stream(path)
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _play_3d(path: String, position: Vector3, volume_db: float, max_distance: float) -> void:
	if not _enabled:
		return
	while _positional_players.size() >= MAX_POSITIONAL_PLAYERS:
		var oldest: AudioStreamPlayer3D = _positional_players.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var player := AudioStreamPlayer3D.new()
	player.bus = &"SFX"
	player.stream = _stream(path)
	player.volume_db = volume_db
	player.max_distance = max_distance
	player.unit_size = 8.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	add_child(player)
	_positional_players.append(player)
	player.global_position = position
	player.finished.connect(_release_positional_player.bind(player))
	player.play()


func _release_positional_player(player: AudioStreamPlayer3D) -> void:
	_positional_players.erase(player)
	player.queue_free()


func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) as AudioStream
	return _streams[path] as AudioStream


func _loop_stream(path: String) -> AudioStream:
	var stream := (_stream(path) as AudioStream).duplicate() as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream


func _is_headless_or_server() -> bool:
	if DisplayServer.get_name().to_lower().contains("headless"):
		return true
	for argument in OS.get_cmdline_user_args():
		if argument == "--server":
			return true
	return false
