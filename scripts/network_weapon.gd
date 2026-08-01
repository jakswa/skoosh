extends NetworkWeaponHitscan3D
class_name SkooshPulseRifle

@export var fire_cooldown: float = 0.32
@export var damage: int = 40

@onready var player := get_parent().get_parent() as SkooshNetworkPlayer
@onready var input := player.get_node("Input") as SkooshNetworkInput
@onready var muzzle_light := $MuzzleLight as OmniLight3D

var last_fire_tick := -100000
var _muzzle_time := 0.0


func _ready() -> void:
	collision_mask = 2
	max_distance = 500.0
	exclude = [player.get_rid()]
	NetworkTime.on_tick.connect(_network_tick)


func _process(delta: float) -> void:
	_muzzle_time = maxf(0.0, _muzzle_time - delta)
	muzzle_light.light_energy = 2.4 if _muzzle_time > 0.0 else 0.0


func _network_tick(_delta: float, _tick: int) -> void:
	if input.fire and not player.dead:
		fire()


func _can_fire() -> bool:
	var arena := player.get_parent().get_parent()
	var round_active: bool = not arena.has_method("is_round_active") or bool(arena.is_round_active())
	return not player.dead and round_active and NetworkTime.seconds_between(last_fire_tick, NetworkTime.tick) >= fire_cooldown


func _can_peer_use(peer_id: int) -> bool:
	return peer_id == player.peer_id


func _is_reconcilable(request_data: Dictionary, local_data: Dictionary) -> bool:
	var requested_origin := request_data.get("origin", Vector3.ZERO) as Vector3
	var server_origin := local_data.get("origin", Vector3.ZERO) as Vector3
	var requested_direction := (request_data.get("direction", Vector3.FORWARD) as Vector3).normalized()
	var server_direction := (local_data.get("direction", Vector3.FORWARD) as Vector3).normalized()
	return requested_origin.distance_to(server_origin) <= 2.0 and requested_direction.dot(server_direction) >= cos(deg_to_rad(18.0))


func _after_fire() -> void:
	last_fire_tick = NetworkTime.tick
	_muzzle_time = 0.06
	if input.is_multiplayer_authority():
		player.hud.flash_shot()


func _on_hit(result: Dictionary) -> void:
	var collider := result.get("collider") as Node
	if collider is SkooshNetworkPlayer:
		var target := collider as SkooshNetworkPlayer
		if target.team == player.team:
			return
		if input.is_multiplayer_authority():
			player.hud.flash_hit()
		if multiplayer.is_server():
			target.apply_damage(damage, player.peer_id)
