class_name SkooshNetworkAcceptance
extends RefCounted

var generation_movement: Dictionary = {}
var generation_combat: Dictionary = {}
var generation_captures: Dictionary = {}
var peak_avatars := 0
var combat_kills := 0
var combat_deaths := 0
var disc_impacts := 0
var disc_damage_events := 0
var weapon_fires: Array[int] = [0, 0, 0, 0]
var weapon_impacts: Array[int] = [0, 0, 0, 0]
var weapon_hits: Array[int] = [0, 0, 0, 0]
var voice_commands_relayed := 0
var ctf_captures := 0
var completed_rounds := 0
var non_winning_captures := 0
var limit_wins := 0
var objective_resets_completed := 0
var match_resets := 0
var duplicate_capture_checks := 0
var duplicate_capture_awards := 0
var full_route_captures := 0
var accelerated_captures := 0
var peak_server_speed := 0.0
var server_saw_jet := false
var peak_rollback_ticks := 0
var peak_network_loop_ms := 0.0
var server_assigned_character_variants: Dictionary = {}
var observed_character_variants: Dictionary = {}


func record_avatar_spawn(peer_id: int, variant_id: int, avatar_count: int, server: bool) -> void:
	if server:
		server_assigned_character_variants[peer_id] = variant_id
	peak_avatars = maxi(peak_avatars, avatar_count)


func remove_avatar(peer_id: int) -> void:
	server_assigned_character_variants.erase(peer_id)
	observed_character_variants.erase(peer_id)


func clear_character_observations() -> void:
	observed_character_variants.clear()


func record_character_observation(peer_id: int, variant_id: int) -> void:
	observed_character_variants[peer_id] = variant_id


func record_kill() -> void:
	combat_kills += 1


func record_death() -> void:
	combat_deaths += 1


func record_disc_impact(damaged_enemies: int) -> int:
	disc_impacts += 1
	disc_damage_events += damaged_enemies
	return disc_impacts


func record_weapon_fire(slot: int, generation: int) -> int:
	weapon_fires[slot] += 1
	generation_combat[generation] = true
	return weapon_fires[slot]


func record_weapon_impact(slot: int, damaged_enemies: int) -> int:
	weapon_impacts[slot] += 1
	weapon_hits[slot] += damaged_enemies
	return weapon_impacts[slot]


func record_weapon_hit(slot: int) -> int:
	weapon_hits[slot] += 1
	return weapon_hits[slot]


func record_voice_relay() -> void:
	voice_commands_relayed += 1


func sample_network(rollback_ticks: int, network_loop_ms: float) -> void:
	peak_rollback_ticks = maxi(peak_rollback_ticks, rollback_ticks)
	peak_network_loop_ms = maxf(peak_network_loop_ms, network_loop_ms)


func sample_movement(generation: int, speed: float, jet_active: bool) -> void:
	peak_server_speed = maxf(peak_server_speed, speed)
	server_saw_jet = server_saw_jet or jet_active
	if speed >= 10.0 and jet_active:
		generation_movement[generation] = true


func record_capture(generation: int, full_route: bool, accelerated: bool) -> void:
	ctf_captures += 1
	generation_captures[generation] = int(generation_captures.get(generation, 0)) + 1
	if full_route:
		full_route_captures += 1
	if accelerated:
		accelerated_captures += 1


func record_capture_outcome(won: bool) -> void:
	if won:
		limit_wins += 1
	else:
		non_winning_captures += 1


func record_duplicate_capture(rejected: bool) -> void:
	if rejected:
		duplicate_capture_checks += 1
	else:
		duplicate_capture_awards += 1


func combat_failed(required: bool, total_deaths: int, total_kills: int) -> bool:
	return required and (
		peak_avatars < 2 or total_deaths < 1 or total_kills < 1
		or disc_impacts < 1 or disc_damage_events < 1
		or weapon_fires.min() < 1 or weapon_impacts[1] < 1 or weapon_hits[1] < 1
		or weapon_hits[2] < 1 or weapon_hits[3] < 1
	)


func movement_failed(required: bool) -> bool:
	return required and (peak_server_speed < 10.0 or not server_saw_jet)


func ctf_failed(required: bool, capture_limit: int, acceptance_mode: bool, require_rotation: bool) -> bool:
	return required and (
		ctf_captures < capture_limit
		or (acceptance_mode and not require_rotation and full_route_captures != 1)
		or (acceptance_mode and not require_rotation and accelerated_captures != capture_limit - 1)
		or non_winning_captures < capture_limit - 1
		or limit_wins < 1
		or objective_resets_completed < capture_limit - 1
		or completed_rounds < 1
		or match_resets < 1
		or duplicate_capture_checks < capture_limit
		or duplicate_capture_awards > 0
	)


func map_baseline_failed(required: bool) -> bool:
	return required and (
		ctf_captures < 1
		or non_winning_captures < 1
		or objective_resets_completed < 1
		or duplicate_capture_checks < 1
		or duplicate_capture_awards > 0
	)


func voice_failed(required: bool) -> bool:
	return required and voice_commands_relayed < 1
