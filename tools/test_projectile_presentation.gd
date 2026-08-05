extends Node

const EPSILON := 0.0001


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	add_child(world)

	var disc_scene := load("res://scenes/disc_projectile.tscn") as PackedScene
	var disc := disc_scene.instantiate() as SkooshDiscProjectile
	world.add_child(disc)
	disc.launch(
		Vector3.ZERO,
		Vector3.FORWARD,
		Vector3.FORWARD * 60.0,
		2,
		0,
		RID(),
		null
	)
	var disc_presentation := disc.get_node("PresentationRoot") as Node3D
	if not disc_presentation.top_level:
		_fail("Disc presentation root inherits the stepped simulation transform")
		return
	if not disc.has_node("PresentationRoot/SpinRoot/DiscVisual"):
		_fail("Disc scene does not present the authored disc model")
		return

	# Several simulation ticks may execute in one loop. Presentation records only
	# the final state so the whole catch-up distance is interpolated.
	disc.global_position = Vector3(0.0, 0.0, 4.0)
	disc.global_position = Vector3(0.0, 0.0, 10.0)
	disc._record_presentation_target()
	disc._update_presentation(0.5)
	if not disc.global_position.is_equal_approx(Vector3(0.0, 0.0, 10.0)):
		_fail("Presentation interpolation changed disc simulation state")
		return
	if not disc_presentation.global_position.is_equal_approx(Vector3(0.0, 0.0, 5.0)):
		_fail("Disc presentation did not interpolate between tick states")
		return
	var launch_data := disc.get_launch_data()
	if not (launch_data.get("origin", Vector3.ZERO) as Vector3).is_equal_approx(disc.global_position):
		_fail("Disc launch serialization used presentation state")
		return
	disc.snap_presentation()
	if not disc_presentation.global_position.is_equal_approx(disc.global_position):
		_fail("Disc presentation discontinuity did not snap")
		return

	var grenade_scene := load("res://scenes/grenade_projectile.tscn") as PackedScene
	var grenade := grenade_scene.instantiate() as SkooshGrenadeProjectile
	world.add_child(grenade)
	grenade.apply_launch_data({
		"origin": Vector3(2.0, 4.0, 6.0),
		"velocity": Vector3(10.0, 5.0, 0.0),
		"direction": Vector3.RIGHT,
		"source_peer_id": 3,
		"source_team": 1,
		"spawn_tick": 0,
		"generation": 7,
	})
	grenade.fast_forward_presentation(6)
	var elapsed := 6.0 / 60.0
	var expected_position := (
		Vector3(2.0, 4.0, 6.0)
		+ Vector3(10.0, 5.0, 0.0) * elapsed
		+ Vector3.DOWN * 15.0 * elapsed * elapsed
	)
	var grenade_presentation := grenade.get_node("PresentationRoot") as Node3D
	if grenade.global_position.distance_to(expected_position) > EPSILON:
		_fail("Grenade fast-forward changed its ballistic simulation")
		return
	if not grenade_presentation.global_position.is_equal_approx(grenade.global_position):
		_fail("Grenade fast-forward left stale presentation state")
		return
	if not grenade_presentation.top_level:
		_fail("Grenade presentation root inherits the stepped simulation transform")
		return

	print("ACCEPT projectile presentation: simulation isolated, interpolation sampled, disc visual wired")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
