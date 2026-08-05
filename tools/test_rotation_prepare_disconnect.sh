#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
PORT="${SKOOSH_PREPARE_DISCONNECT_TEST_PORT:-19723}"
LOG_DIR="${SKOOSH_PREPARE_DISCONNECT_LOG_DIR:-$ROOT/.tmp/skoosh-prepare-disconnect-test}"

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

"$GODOT_BIN" --headless --path "$ROOT" -- --server --port="$PORT" \
	--map=faultline_basin --score-limit=3 --acceptance-mode --require-rotation \
	--test-seconds=60 >"$LOG_DIR/server.log" 2>&1 &
pids+=("$!")
sleep 1
for client in 1 2; do
	"$GODOT_BIN" --headless --path "$ROOT" -- --join=127.0.0.1 --port="$PORT" \
		--map=faultline_basin --acceptance-mode --bot --test-seconds=55 \
		>"$LOG_DIR/client-$client.log" 2>&1 &
	pids+=("$!")
done

preparing=false
for _attempt in $(seq 1 400); do
	if grep -q "WORLD prepare generation=2 map=cairn_steps" "$LOG_DIR/server.log"; then
		preparing=true
		break
	fi
	sleep 0.1
done
if [[ "$preparing" != true ]]; then
	echo "The fixture did not enter generation-2 preparation. Logs: $LOG_DIR" >&2
	exit 1
fi

disconnected_pid="${pids[2]}"
disconnected_peer_id="$(perl -ne 'print $1 if /NETWORK client connected peer=(\d+)/' "$LOG_DIR/client-2.log")"
surviving_peer_id="$(perl -ne 'print $1 if /NETWORK client connected peer=(\d+)/' "$LOG_DIR/client-1.log")"
if [[ -z "$disconnected_peer_id" || -z "$surviving_peer_id" ]]; then
	echo "The preparation fixture clients did not report peer IDs. Logs: $LOG_DIR" >&2
	exit 1
fi
disconnect_started_at="$SECONDS"
kill "$disconnected_pid" 2>/dev/null || true

activated=false
for _attempt in $(seq 1 200); do
	if grep -q "WORLD active peer=1 generation=2 map=cairn_steps.*avatars=1" "$LOG_DIR/server.log"; then
		activated=true
		break
	fi
	sleep 0.1
done
if [[ "$activated" != true ]]; then
	echo "A preparation-phase disconnect stalled or corrupted Cairn activation. Logs: $LOG_DIR" >&2
	exit 1
fi
if ! grep -q "NETWORK peer left id=$disconnected_peer_id" "$LOG_DIR/server.log"; then
	echo "The server did not observe the preparation-phase disconnect. Logs: $LOG_DIR" >&2
	exit 1
fi
survivor_active=false
for _attempt in $(seq 1 50); do
	if grep -q "WORLD active peer=$surviving_peer_id generation=2 map=cairn_steps.*avatars=1" "$LOG_DIR/client-1.log"; then
		survivor_active=true
		break
	fi
	sleep 0.1
done
if [[ "$survivor_active" != true ]]; then
	echo "The intended surviving client did not activate alone on Cairn. Logs: $LOG_DIR" >&2
	exit 1
fi
if (( SECONDS - disconnect_started_at > 20 )); then
	echo "Preparation-phase disconnect recovery exceeded the bounded window. Logs: $LOG_DIR" >&2
	exit 1
fi
if grep -Eq "ERROR:|SCRIPT ERROR|WARNING:|Node not found|Invalid packet|Unable to send packet" "$LOG_DIR"/*.log; then
	echo "Preparation-phase disconnect produced a networking or rollback error. Logs: $LOG_DIR" >&2
	exit 1
fi

echo "Rotation preparation-disconnect acceptance passed: the remaining peer activated on Cairn. Logs: $LOG_DIR"
