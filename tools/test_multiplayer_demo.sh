#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/tmp/godot-skoosh/Godot_v4.4.1-stable_linux.x86_64}"
CLIENT_BIN="${SKOOSH_CLIENT_BIN:-$GODOT_BIN}"
PORT="${SKOOSH_TEST_PORT:-19077}"
TEST_SECONDS="${SKOOSH_TEST_SECONDS:-50}"
CLIENT_TEST_SECONDS=$((TEST_SECONDS + 1))
LOG_DIR="${SKOOSH_TEST_LOG_DIR:-$ROOT/.tmp/skoosh-network-test}"
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
  --test-seconds="$TEST_SECONDS" --require-combat --require-movement --require-ctf \
  --require-voice >"$LOG_DIR/server.log" 2>&1 &
server_pid=$!
pids+=("$server_pid")
sleep 1

client_command=("$CLIENT_BIN" --headless)
if [[ "$CLIENT_BIN" == "$GODOT_BIN" ]]; then
  client_command+=(--path "$ROOT")
fi

for client in 1 2; do
  "${client_command[@]}" -- --join=127.0.0.1 --port="$PORT" \
    --bot --test-seconds="$CLIENT_TEST_SECONDS" >"$LOG_DIR/client-$client.log" 2>&1 &
  pids+=("$!")
done

set +e
wait "$server_pid"
status=$?
set -e

for pid in "${pids[@]:1}"; do
  set +e
  wait "$pid" 2>/dev/null
  client_status=$?
  set -e
  if [[ $client_status -ne 0 ]]; then
    status=$client_status
  fi
done

cat "$LOG_DIR/server.log"
if grep -Eq "ERROR:|SCRIPT ERROR|rejected" "$LOG_DIR"/*.log; then
  echo "Multiplayer acceptance logged an error or rejected launch. Logs: $LOG_DIR" >&2
  status=1
fi
for client in 1 2; do
  if ! grep -q "VOICE received" "$LOG_DIR/client-$client.log"; then
    echo "Client $client did not receive a team voice command. Logs: $LOG_DIR" >&2
    status=1
  fi
done
if [[ $status -ne 0 ]]; then
  echo "Multiplayer acceptance failed. Client logs: $LOG_DIR" >&2
  exit "$status"
fi

echo "Multiplayer acceptance passed. Logs: $LOG_DIR"
