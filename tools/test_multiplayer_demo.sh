#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/tmp/godot-skoosh/Godot_v4.4.1-stable_linux.x86_64}"
PORT="${SKOOSH_TEST_PORT:-19077}"
LOG_DIR="${SKOOSH_TEST_LOG_DIR:-/tmp/skoosh-network-test}"
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
  --test-seconds=12 --require-combat --require-movement >"$LOG_DIR/server.log" 2>&1 &
server_pid=$!
pids+=("$server_pid")
sleep 1

for client in 1 2; do
  "$GODOT_BIN" --headless --path "$ROOT" -- --join=127.0.0.1 --port="$PORT" \
    --bot --test-seconds=13 >"$LOG_DIR/client-$client.log" 2>&1 &
  pids+=("$!")
done

set +e
wait "$server_pid"
status=$?
set -e

for pid in "${pids[@]:1}"; do
  wait "$pid" 2>/dev/null || true
done

cat "$LOG_DIR/server.log"
if [[ $status -ne 0 ]]; then
  echo "Multiplayer acceptance failed. Client logs: $LOG_DIR" >&2
  exit "$status"
fi

echo "Multiplayer acceptance passed. Logs: $LOG_DIR"
