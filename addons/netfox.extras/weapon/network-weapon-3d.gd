extends Node3D
class_name NetworkWeapon3D

## A 3D-specific implementation of [NetworkWeapon].

## Distance to consider too large during reconciliation checks.
@export var distance_threshold: float = 1.0

var _weapon: _NetworkWeaponProxy

func can_fire() -> bool:
	return _weapon.can_fire()

func fire() -> Node3D:
	return _weapon.fire()

func get_fired_tick() -> int:
	return _weapon.get_fired_tick()

func get_projectile_id(projectile: Node3D) -> String:
	return _weapon.get_projectile_id(projectile)

func despawn_projectile(id: String):
	_weapon.despawn_projectile(id)

func deactivate() -> void:
	_weapon.deactivate()

func _init():
	_weapon = _NetworkWeaponProxy.new()
	add_child(_weapon, true, INTERNAL_MODE_BACK)
	_weapon.owner = self
	
	_weapon.c_can_fire = _can_fire
	_weapon.c_can_peer_use = _can_peer_use
	_weapon.c_after_fire = _after_fire
	_weapon.c_spawn = _spawn
	_weapon.c_get_data = _get_data
	_weapon.c_apply_data = _apply_data
	_weapon.c_is_reconcilable = _is_reconcilable
	_weapon.c_reconcile = _reconcile
	_weapon.c_is_network_data_current = _is_network_data_current
	_weapon.c_is_expected_request_decline = _is_expected_request_decline
	_weapon.c_is_expected_use_decline = _is_expected_use_decline
	_weapon.c_get_projectile_rpc_target_peers = _get_projectile_rpc_target_peers


## See [NetworkWeapon]
func _can_fire() -> bool:
	return false

## See [NetworkWeapon]
func _can_peer_use(peer_id: int) -> bool:
	return true

## See [NetworkWeapon]
func _after_fire(projectile: Node3D):
	pass

## See [NetworkWeapon]
func _spawn() -> Node3D:
	return null

func _get_data(projectile: Node3D) -> Dictionary:
	return {
		"global_transform": projectile.global_transform
	}

func _apply_data(projectile: Node3D, data: Dictionary):
	projectile.global_transform = data["global_transform"]

func _is_reconcilable(projectile: Node3D, request_data: Dictionary, local_data: Dictionary) -> bool:
	var req_transform = request_data["global_transform"] as Transform3D
	var loc_transform = local_data["global_transform"] as Transform3D
	
	var request_pos = req_transform.origin
	var local_pos = loc_transform.origin
	
	return request_pos.distance_to(local_pos) < distance_threshold

func _reconcile(projectile: Node3D, local_data: Dictionary, remote_data: Dictionary):
	var local_transform = local_data["global_transform"] as Transform3D
	var remote_transform = remote_data["global_transform"] as Transform3D

	var relative_transform = projectile.global_transform * local_transform.inverse()
	var final_transform = remote_transform * relative_transform
	
	projectile.global_transform = final_transform

func _is_network_data_current(_data: Dictionary) -> bool:
	return true

func _is_expected_request_decline(_data: Dictionary) -> bool:
	return false

func _is_expected_use_decline(_data: Dictionary, _sender: int) -> bool:
	return false

func _get_projectile_rpc_target_peers() -> Array[int]:
	var peers: Array[int] = []
	for peer_id in multiplayer.get_peers():
		peers.append(peer_id)
	return peers
