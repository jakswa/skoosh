extends RefCounted
class_name SkooshVoiceCommandLibrary

const SCOPE_TEAM := 0
const SCOPE_GLOBAL := 1
const COMMANDS := [
	{"category": "SOCIAL", "label": "HELLO"},
	{"category": "SOCIAL", "label": "GOODBYE"},
	{"category": "SOCIAL", "label": "THANKS"},
	{"category": "SOCIAL", "label": "SHAZBOT"},
	{"category": "OBJECTIVE", "label": "DEFEND OUR FLAG"},
	{"category": "OBJECTIVE", "label": "PUSH THE FAR PLATFORM"},
	{"category": "OBJECTIVE", "label": "RECOVER OUR FLAG"},
	{"category": "OBJECTIVE", "label": "COVER MY RETURN"},
	{"category": "STATUS", "label": "YES"},
	{"category": "STATUS", "label": "NO"},
	{"category": "STATUS", "label": "I NEED SUPPORT"},
	{"category": "STATUS", "label": "ALL CLEAR"},
]
const PACK_NAMES := ["ZACK", "RENEE", "CLINT", "BRITTANY", "JASPER"]
const VOICE_PACKS := [
	[
		preload("res://audio/voice/zack/hello.wav"),
		preload("res://audio/voice/zack/goodbye.wav"),
		preload("res://audio/voice/zack/thanks.wav"),
		preload("res://audio/voice/zack/shazbot.wav"),
		preload("res://audio/voice/zack/defend_our_flag.wav"),
		preload("res://audio/voice/zack/push_far_platform.wav"),
		preload("res://audio/voice/zack/recover_our_flag.wav"),
		preload("res://audio/voice/zack/cover_my_return.wav"),
		preload("res://audio/voice/zack/yes.wav"),
		preload("res://audio/voice/zack/no.wav"),
		preload("res://audio/voice/zack/need_support.wav"),
		preload("res://audio/voice/zack/all_clear.wav"),
	],
	[
		preload("res://audio/voice/renee/hello.wav"),
		preload("res://audio/voice/renee/goodbye.wav"),
		preload("res://audio/voice/renee/thanks.wav"),
		preload("res://audio/voice/renee/shazbot.wav"),
		preload("res://audio/voice/renee/defend_our_flag.wav"),
		preload("res://audio/voice/renee/push_far_platform.wav"),
		preload("res://audio/voice/renee/recover_our_flag.wav"),
		preload("res://audio/voice/renee/cover_my_return.wav"),
		preload("res://audio/voice/renee/yes.wav"),
		preload("res://audio/voice/renee/no.wav"),
		preload("res://audio/voice/renee/need_support.wav"),
		preload("res://audio/voice/renee/all_clear.wav"),
	],
	[
		preload("res://audio/voice/clint/hello.wav"),
		preload("res://audio/voice/clint/goodbye.wav"),
		preload("res://audio/voice/clint/thanks.wav"),
		preload("res://audio/voice/clint/shazbot.wav"),
		preload("res://audio/voice/clint/defend_our_flag.wav"),
		preload("res://audio/voice/clint/push_far_platform.wav"),
		preload("res://audio/voice/clint/recover_our_flag.wav"),
		preload("res://audio/voice/clint/cover_my_return.wav"),
		preload("res://audio/voice/clint/yes.wav"),
		preload("res://audio/voice/clint/no.wav"),
		preload("res://audio/voice/clint/need_support.wav"),
		preload("res://audio/voice/clint/all_clear.wav"),
	],
	[
		preload("res://audio/voice/brittany/hello.wav"),
		preload("res://audio/voice/brittany/goodbye.wav"),
		preload("res://audio/voice/brittany/thanks.wav"),
		preload("res://audio/voice/brittany/shazbot.wav"),
		preload("res://audio/voice/brittany/defend_our_flag.wav"),
		preload("res://audio/voice/brittany/push_far_platform.wav"),
		preload("res://audio/voice/brittany/recover_our_flag.wav"),
		preload("res://audio/voice/brittany/cover_my_return.wav"),
		preload("res://audio/voice/brittany/yes.wav"),
		preload("res://audio/voice/brittany/no.wav"),
		preload("res://audio/voice/brittany/need_support.wav"),
		preload("res://audio/voice/brittany/all_clear.wav"),
	],
	[
		preload("res://audio/voice/jasper/hello.wav"),
		preload("res://audio/voice/jasper/goodbye.wav"),
		preload("res://audio/voice/jasper/thanks.wav"),
		preload("res://audio/voice/jasper/shazbot.wav"),
		preload("res://audio/voice/jasper/defend_our_flag.wav"),
		preload("res://audio/voice/jasper/push_far_platform.wav"),
		preload("res://audio/voice/jasper/recover_our_flag.wav"),
		preload("res://audio/voice/jasper/cover_my_return.wav"),
		preload("res://audio/voice/jasper/yes.wav"),
		preload("res://audio/voice/jasper/no.wav"),
		preload("res://audio/voice/jasper/need_support.wav"),
		preload("res://audio/voice/jasper/all_clear.wav"),
	],
]


static func stream_for_peer(peer_id: int, command_id: int) -> AudioStream:
	if command_id < 0 or command_id >= COMMANDS.size():
		return null
	return VOICE_PACKS[pack_index_for_peer(peer_id)][command_id] as AudioStream


static func pack_index_for_peer(peer_id: int) -> int:
	# ENet peer IDs are randomized for each connection, so this is a shared,
	# deterministic random assignment without another replicated property.
	return posmod(peer_id, VOICE_PACKS.size())


static func pack_name_for_peer(peer_id: int) -> String:
	return PACK_NAMES[pack_index_for_peer(peer_id)]


static func scope_name(scope: int) -> String:
	return "GLOBAL" if scope == SCOPE_GLOBAL else "TEAM"
