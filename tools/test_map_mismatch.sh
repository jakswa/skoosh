#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/tmp/godot-skoosh/Godot_v4.4.1-stable_linux.x86_64}"
PORT="${SKOOSH_TEST_PORT:-19078}"
LOG_DIR="${SKOOSH_TEST_LOG_DIR:-$ROOT/.tmp/skoosh-map-mismatch-test}"

if [[ ! -x "$GODOT_BIN" ]]; then
  echo "Set GODOT_BIN to a Godot 4.4+ executable." >&2
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
  --map=relay_divide --test-seconds=6 >"$LOG_DIR/server.log" 2>&1 &
server_pid=$!
pids+=("$server_pid")
sleep 1

"$GODOT_BIN" --headless --path "$ROOT" -- --join=127.0.0.1 --port="$PORT" \
  --map=split_crown --test-seconds=4 >"$LOG_DIR/client.log" 2>&1
wait "$server_pid"

if ! grep -q "MAP mismatch.*rejection=disconnect" "$LOG_DIR/server.log"; then
  echo "Server did not reject the mismatched map. Logs: $LOG_DIR" >&2
  exit 1
fi
if ! grep -q "MAP mismatch server=relay_divide client=split_crown" "$LOG_DIR/client.log"; then
  echo "Client did not report the mismatched map. Logs: $LOG_DIR" >&2
  exit 1
fi
if grep -q "NETWORK avatar spawned" "$LOG_DIR"/*.log; then
  echo "A map-mismatched peer spawned an avatar. Logs: $LOG_DIR" >&2
  exit 1
fi

echo "Map mismatch rejection passed. Logs: $LOG_DIR"
