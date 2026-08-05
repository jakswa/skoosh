#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
PORT="${SKOOSH_READY_TIMEOUT_TEST_PORT:-19722}"
LOG_DIR="${SKOOSH_READY_TIMEOUT_LOG_DIR:-$ROOT/.tmp/skoosh-ready-timeout-test}"

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

started_at="$SECONDS"
"$GODOT_BIN" --headless --path "$ROOT" -- --server --port="$PORT" \
	--map=faultline_basin --score-limit=3 --acceptance-mode --require-rotation \
	--test-seconds=60 >"$LOG_DIR/server.log" 2>&1 &
pids+=("$!")
sleep 1
"$GODOT_BIN" --headless --path "$ROOT" -- --join=127.0.0.1 --port="$PORT" \
	--map=faultline_basin --acceptance-mode --bot --test-seconds=55 \
	>"$LOG_DIR/ready-client.log" 2>&1 &
pids+=("$!")
"$GODOT_BIN" --headless --path "$ROOT" -- --join=127.0.0.1 --port="$PORT" \
	--map=faultline_basin --acceptance-mode --bot --test-skip-transition-ready \
	--test-seconds=55 >"$LOG_DIR/non-ready-client.log" 2>&1 &
pids+=("$!")

ready_peer_id=""
non_ready_peer_id=""
for _attempt in $(seq 1 100); do
	ready_peer_id="$(perl -ne 'print $1 if /NETWORK client connected peer=(\d+)/' "$LOG_DIR/ready-client.log")"
	non_ready_peer_id="$(perl -ne 'print $1 if /NETWORK client connected peer=(\d+)/' "$LOG_DIR/non-ready-client.log")"
	if [[ -n "$ready_peer_id" && -n "$non_ready_peer_id" ]]; then
		break
	fi
	sleep 0.1
done
if [[ -z "$ready_peer_id" || -z "$non_ready_peer_id" ]]; then
	echo "The timeout fixture clients did not report peer IDs. Logs: $LOG_DIR" >&2
	exit 1
fi

barrier_completed=false
for _attempt in $(seq 1 45); do
	if grep -q "WORLD ready timeout peer=$non_ready_peer_id generation=2 rejection=disconnect" "$LOG_DIR/server.log" \
		&& grep -q "WORLD active peer=1 generation=2 map=cairn_steps" "$LOG_DIR/server.log"; then
		barrier_completed=true
		break
	fi
	sleep 1
done

if [[ "$barrier_completed" != true ]]; then
	echo "A non-ready peer stalled the generation-2 barrier. Logs: $LOG_DIR" >&2
	exit 1
fi
if ! grep -q "WORLD ready intentionally skipped peer=$non_ready_peer_id generation=2" "$LOG_DIR/non-ready-client.log"; then
	echo "The fault client did not exercise the skipped-ready path. Logs: $LOG_DIR" >&2
	exit 1
fi
survivor_active=false
for _attempt in $(seq 1 50); do
	if grep -q "WORLD active peer=$ready_peer_id generation=2 map=cairn_steps.*avatars=1" "$LOG_DIR/ready-client.log"; then
		survivor_active=true
		break
	fi
	sleep 0.1
done
if [[ "$survivor_active" != true ]]; then
	echo "The intended surviving client did not activate alone on Cairn. Logs: $LOG_DIR" >&2
	exit 1
fi
if (( SECONDS - started_at > 45 )); then
	echo "The ready timeout exceeded the bounded test window. Logs: $LOG_DIR" >&2
	exit 1
fi
if grep -Eq "ERROR:|SCRIPT ERROR|Node not found|Invalid packet|Unable to send packet" "$LOG_DIR"/*.log; then
	echo "Ready-timeout disconnect produced replication or rollback errors. Logs: $LOG_DIR" >&2
	exit 1
fi

echo "Rotation ready-timeout acceptance passed: non-ready peer disconnected without stalling Cairn activation. Logs: $LOG_DIR"
