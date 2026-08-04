extends SkooshDiscLauncher
class_name SkooshGrenadeLauncher


func _reconcile(projectile: Node3D, local_data: Dictionary, remote_data: Dictionary) -> void:
	var grenade := projectile as SkooshGrenadeProjectile
	var local_spawn_tick := int(local_data.get("spawn_tick", NetworkTime.tick))
	var presentation_age := clampi(NetworkTime.tick - local_spawn_tick, 0, 12)
	grenade.apply_launch_data(remote_data)
	grenade.fast_forward_presentation(presentation_age)


func resolve_disc_impact(projectile: SkooshDiscProjectile, collider: Object) -> void:
	if not multiplayer.is_server():
		return
	var arena := player.get_parent().get_parent()
	var impact_position := projectile.global_position
	var projectile_id := get_projectile_id(projectile)
	var direct_target := collider as SkooshNetworkPlayer
	var damaged_enemies := 0
	for avatar_variant in arena.avatars.values():
		var target := avatar_variant as SkooshNetworkPlayer
		if target == null or target.dead:
			continue
		var is_self := target.peer_id == projectile.source_peer_id
		if target.team == projectile.source_team and not is_self:
			continue
		var target_center := target.global_position + Vector3.UP * 1.1
		var distance := target_center.distance_to(impact_position)
		if distance > splash_radius and target != direct_target:
			continue
		if (
			target != direct_target
			and _world_blocks_splash(impact_position, target_center, target.get_rid())
		):
			continue
		var falloff := 1.0 - clampf(distance / splash_radius, 0.0, 1.0)
		var amount := roundi(lerpf(float(minimum_damage), float(maximum_damage), falloff))
		if target == direct_target:
			amount = maximum_damage
		if is_self:
			amount = roundi(float(amount) * 0.5)
		else:
			damaged_enemies += 1
		target.apply_damage(amount, projectile.source_peer_id)
	if arena.has_method("record_weapon_impact"):
		arena.record_weapon_impact(weapon_slot, damaged_enemies)
	_present_disc_impact.rpc(
		projectile_id, impact_position, projectile.source_team, damaged_enemies > 0
	)
