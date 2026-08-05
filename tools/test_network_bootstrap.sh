#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
BASE_PORT="${SKOOSH_BOOTSTRAP_TEST_PORT:-19720}"
LOG_DIR="${SKOOSH_BOOTSTRAP_LOG_DIR:-$ROOT/.tmp/skoosh-network-bootstrap-test}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	echo "Godot 4.4+ was not found on PATH. Install godot or set GODOT_BIN." >&2
	exit 1
fi

rm -rf "$LOG_DIR"
mkdir -p "$LOG_DIR"
pids=()
cleanup() {
	for pid in "${pids[@]:-}"; do
		kill "$pid" 2>/dev/null || true
	done
}
trap cleanup EXIT INT TERM

implicit_cairn_port="$BASE_PORT"
"$GODOT_BIN" --headless --path "$ROOT" -- --server --port="$implicit_cairn_port" \
	--map=cairn_steps --test-seconds=9 >"$LOG_DIR/implicit-cairn-server.log" 2>&1 &
server_pid=$!
pids+=("$server_pid")
sleep 1
"$GODOT_BIN" --headless --path "$ROOT" -- --join=127.0.0.1 --port="$implicit_cairn_port" \
	--test-seconds=6 >"$LOG_DIR/implicit-cairn-client.log" 2>&1
wait "$server_pid"
pids=()

implicit_peer_id="$(perl -ne 'print $1 if /NETWORK client connected peer=(\d+)/' "$LOG_DIR/implicit-cairn-client.log")"
if [[ -z "$implicit_peer_id" ]]; then
	echo "The implicit Cairn client did not connect. Logs: $LOG_DIR" >&2
	exit 1
fi
if ! grep -q "MAP bootstrap ready peer=$implicit_peer_id generation=1 map=cairn_steps avatars=1" "$LOG_DIR/implicit-cairn-server.log"; then
	echo "The implicit client did not complete generation-1 Cairn admission. Logs: $LOG_DIR" >&2
	exit 1
fi
if ! grep -q "NETWORK avatar spawned id=$implicit_peer_id .*node=/root/NetworkDemo/World_1/Players/Player_$implicit_peer_id" "$LOG_DIR/implicit-cairn-client.log"; then
	echo "The implicit Cairn avatar did not use the authoritative World_1 RPC path. Logs: $LOG_DIR" >&2
	exit 1
fi
implicit_server_world="$(perl -ne 'print "$1/$2/$3" and exit if /WORLD built generation=1 map=(cairn_steps) hash=(\S+) signature=(\S+).*contract=PASS/' "$LOG_DIR/implicit-cairn-server.log")"
implicit_client_world="$(perl -ne 'print "$1/$2/$3" and exit if /WORLD built generation=1 map=(cairn_steps) hash=(\S+) signature=(\S+).*contract=PASS/' "$LOG_DIR/implicit-cairn-client.log")"
if [[ -z "$implicit_server_world" || "$implicit_server_world" != "$implicit_client_world" ]]; then
	echo "Implicit generation-1 Cairn world differs from the server. Logs: $LOG_DIR" >&2
	exit 1
fi
if grep -Eq "World_1@|@Node3D|ERROR:|SCRIPT ERROR|Node not found|Invalid packet|Unable to send packet" "$LOG_DIR"/implicit-cairn-*.log; then
	echo "Implicit generation-1 Cairn bootstrap logged a renamed path or networking error. Logs: $LOG_DIR" >&2
	exit 1
fi
if [[ "${SKOOSH_BOOTSTRAP_QUICK:-0}" == "1" ]]; then
	echo "Network bootstrap quick check passed: implicit generation-1 Cairn startup. Logs: $LOG_DIR"
	exit 0
fi

incompatible_port=$((BASE_PORT + 1))
"$GODOT_BIN" --headless --path "$ROOT" -- --server --port="$incompatible_port" \
	--map=faultline_basin --test-seconds=7 >"$LOG_DIR/incompatible-server.log" 2>&1 &
server_pid=$!
pids+=("$server_pid")
sleep 1
"$GODOT_BIN" --headless --path "$ROOT" -- --join=127.0.0.1 --port="$incompatible_port" \
	--map=faultline_basin --test-compatibility-revision=incompatible-review-fixture \
	--test-seconds=4 >"$LOG_DIR/incompatible-client.log" 2>&1
wait "$server_pid"
pids=()

if ! grep -q "MAP compatibility mismatch peer=.*rejection=disconnect" "$LOG_DIR/incompatible-server.log"; then
	echo "The server did not reject a same-ID incompatible definition hash. Logs: $LOG_DIR" >&2
	exit 1
fi
if ! grep -q "MAP compatibility mismatch server_hash=.*client_hash=.*rejection=pending" "$LOG_DIR/incompatible-client.log"; then
	echo "The client did not report its independently computed incompatible hash. Logs: $LOG_DIR" >&2
	exit 1
fi
if grep -q "NETWORK avatar spawned" "$LOG_DIR"/incompatible-*.log; then
	echo "An incompatible peer created a ghost avatar. Logs: $LOG_DIR" >&2
	exit 1
fi
if grep -Eq "ERROR:|SCRIPT ERROR|Node not found|Invalid packet|Unable to send packet" "$LOG_DIR"/incompatible-*.log; then
	echo "An incompatible peer exchanged preapproval avatar or rollback traffic. Logs: $LOG_DIR" >&2
	exit 1
fi

late_port=$((BASE_PORT + 2))
"$GODOT_BIN" --headless --path "$ROOT" -- --server --port="$late_port" \
	--map=faultline_basin --score-limit=3 --acceptance-mode --require-rotation \
	--test-seconds=65 >"$LOG_DIR/late-server.log" 2>&1 &
server_pid=$!
pids+=("$server_pid")
sleep 1
for client in 1 2; do
	"$GODOT_BIN" --headless --path "$ROOT" -- --join=127.0.0.1 --port="$late_port" \
		--map=faultline_basin --acceptance-mode --bot --test-seconds=60 \
		>"$LOG_DIR/late-client-$client.log" 2>&1 &
	pids+=("$!")
done

cairn_preparing=false
for _attempt in $(seq 1 45); do
	if grep -q "WORLD prepare generation=2 map=cairn_steps" "$LOG_DIR/late-server.log"; then
		cairn_preparing=true
		break
	fi
	sleep 1
done
if [[ "$cairn_preparing" != true ]]; then
	echo "The fixture did not enter Cairn preparation in time. Logs: $LOG_DIR" >&2
	exit 1
fi

# No --map argument: a join during preparation is isolated, then follows the
# server-owned generation once Cairn becomes active.
"$GODOT_BIN" --headless --path "$ROOT" -- --join=127.0.0.1 --port="$late_port" \
	--test-seconds=18 >"$LOG_DIR/late-default-client.log" 2>&1

late_peer_id="$(perl -ne 'print $1 if /NETWORK client connected peer=(\d+)/' "$LOG_DIR/late-default-client.log")"
if [[ -z "$late_peer_id" ]]; then
	echo "The default late client did not connect. Logs: $LOG_DIR" >&2
	exit 1
fi
if ! grep -q "MAP admission queued peer=$late_peer_id phase=1 generation=1" "$LOG_DIR/late-server.log"; then
	echo "The late client did not join while generation 2 was preparing. Logs: $LOG_DIR" >&2
	exit 1
fi
if ! grep -q "MAP bootstrap ready peer=$late_peer_id generation=2 map=cairn_steps avatars=3" "$LOG_DIR/late-server.log"; then
	echo "The server did not complete the late client's Cairn bootstrap. Logs: $LOG_DIR" >&2
	exit 1
fi
if ! grep -q "NETWORK avatar spawned id=$late_peer_id .*World_2/Players/Player_$late_peer_id" "$LOG_DIR/late-default-client.log"; then
	echo "The late client did not create its avatar under World_2. Logs: $LOG_DIR" >&2
	exit 1
fi
if grep -q "Player_$late_peer_id.*World_1\|World_1.*Player_$late_peer_id" "$LOG_DIR"/late-*.log; then
	echo "The late client left a generation-1 ghost avatar path. Logs: $LOG_DIR" >&2
	exit 1
fi

server_world="$(perl -ne 'print "$1/$2/$3" and exit if /WORLD built generation=2 map=(\S+) hash=(\S+) signature=(\S+).*contract=PASS/' "$LOG_DIR/late-server.log")"
client_world="$(perl -ne 'print "$1/$2/$3" and exit if /WORLD built generation=2 map=(\S+) hash=(\S+) signature=(\S+).*contract=PASS/' "$LOG_DIR/late-default-client.log")"
if [[ -z "$server_world" || "$server_world" != "$client_world" ]]; then
	echo "Late-join generation/hash/terrain signature differs from the server. Logs: $LOG_DIR" >&2
	exit 1
fi
if grep -Eq "ERROR:|SCRIPT ERROR|Node not found|Invalid packet|Unable to send packet|result=FAIL" "$LOG_DIR"/late-*.log; then
	echo "Late production-map bootstrap logged an error or ghost-path failure. Logs: $LOG_DIR" >&2
	exit 1
fi

echo "Network bootstrap acceptance passed: implicit Cairn startup, independent hash rejection, and queued Cairn admission. Logs: $LOG_DIR"
