extends Node

const ClientAudioScript = preload("res://scripts/client_audio.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	for bus_name in [&"Master", &"Music", &"Ambience", &"SFX", &"Movement", &"UI", &"Voice"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			_fail("Missing audio bus: %s" % bus_name)
			return
	var master_index := AudioServer.get_bus_index(&"Master")
	if AudioServer.get_bus_effect_count(master_index) < 1:
		_fail("Master bus has no output limiter")
		return
	if not AudioServer.get_bus_effect(master_index, 0) is AudioEffectLimiter:
		_fail("Master output effect is not a limiter")
		return
	var music_index := AudioServer.get_bus_index(&"Music")
	if not AudioServer.get_bus_effect(music_index, 0) is AudioEffectCompressor:
		_fail("Music bus has no voice-ducking compressor")
		return

	var paths: Array[String] = ClientAudioScript.required_asset_paths()
	if paths.size() != 29:
		_fail("Expected 29 runtime audio assets, found %d" % paths.size())
		return
	var music_lengths: Array[float] = []
	for path in paths:
		if not ResourceLoader.exists(path):
			_fail("Missing audio asset: %s" % path)
			return
		var stream := load(path) as AudioStream
		if stream == null or stream.get_length() <= 0.05:
			_fail("Audio asset is empty or unreadable: %s" % path)
			return
		if stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			if wav.mix_rate != 48000 or wav.stereo or wav.data.is_empty():
				_fail("WAV contract failed for %s" % path)
				return
		if path.contains("/music/"):
			music_lengths.append(stream.get_length())
	if music_lengths.size() != 3:
		_fail("Adaptive score does not contain exactly three stems")
		return
	for length in music_lengths:
		if absf(length - music_lengths[0]) > 0.02:
			_fail("Adaptive score stems are not phase-aligned")
			return
	if not ResourceLoader.exists("res://audio/generated/preview/audio_foundation_sampler.ogg"):
		_fail("Audio audition montage is missing")
		return

	var quiet := ClientAudioScript.combat_layer_volume_db(0.0)
	var engaged := ClientAudioScript.combat_layer_volume_db(0.55)
	var intense := ClientAudioScript.combat_layer_volume_db(1.0)
	if quiet > -59.0 or engaged <= quiet or intense <= engaged or intense > -7.9:
		_fail("Combat music response is not bounded and monotonic")
		return

	var director := ClientAudioScript.new() as SkooshClientAudio
	add_child(director)
	await get_tree().process_frame
	if director.is_processing():
		_fail("Client audio director processes in a headless run")
		return
	var scene := load("res://scenes/network_demo.tscn") as PackedScene
	var root := scene.instantiate()
	if root.get_node_or_null("ClientAudio") == null:
		_fail("Persistent multiplayer root has no client audio director")
		return
	root.free()

	print("ACCEPT client audio: 29 assets, 7 buses, aligned adaptive stems, headless no-op")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
