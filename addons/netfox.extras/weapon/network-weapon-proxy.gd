extends NetworkWeapon
class_name _NetworkWeaponProxy

var c_can_fire: Callable
var c_can_peer_use: Callable
var c_after_fire: Callable
var c_spawn: Callable
var c_get_data: Callable
var c_apply_data: Callable
var c_is_reconcilable: Callable
var c_reconcile: Callable
var c_is_network_data_current: Callable
var c_is_expected_request_decline: Callable
var c_is_expected_use_decline: Callable
var c_get_projectile_rpc_target_peers: Callable

func _can_fire() -> bool:
	return c_can_fire.call()

func _can_peer_use(peer_id: int) -> bool:
	return c_can_peer_use.call(peer_id)

func _after_fire(projectile: Node):
	c_after_fire.call(projectile)

func _spawn() -> Node:
	return c_spawn.call()

func _get_data(projectile: Node) -> Dictionary:
	return c_get_data.call(projectile)

func _apply_data(projectile: Node, data: Dictionary):
	c_apply_data.call(projectile, data)

func _is_reconcilable(projectile: Node, request_data: Dictionary, local_data: Dictionary) -> bool:
	return c_is_reconcilable.call(projectile, request_data, local_data)

func _reconcile(projectile: Node, local_data: Dictionary, remote_data: Dictionary):
	c_reconcile.call(projectile, local_data, remote_data)

func _is_network_data_current(data: Dictionary) -> bool:
	return c_is_network_data_current.call(data)

func _is_expected_request_decline(data: Dictionary) -> bool:
	return c_is_expected_request_decline.call(data)

func _is_expected_use_decline(data: Dictionary, sender: int) -> bool:
	return c_is_expected_use_decline.call(data, sender)

func _get_projectile_rpc_target_peers() -> Array[int]:
	var peers: Array[int] = []
	peers.assign(c_get_projectile_rpc_target_peers.call())
	return peers
