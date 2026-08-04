#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/tmp/godot-skoosh/Godot_v4.4.1-stable_linux.x86_64}"
PORT="${SKOOSH_CHARACTER_TEST_PORT:-19079}"
LOG_DIR="${SKOOSH_CHARACTER_TEST_LOG_DIR:-$ROOT/.tmp/skoosh-character-test}"
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
  --test-seconds=8 --require-character-variants >"$LOG_DIR/server.log" 2>&1 &
pids+=("$!")
sleep 1

for client in 1 2 3; do
  "$GODOT_BIN" --headless --path "$ROOT" -- --join=127.0.0.1 --port="$PORT" \
    --test-seconds=9 --require-character-variants >"$LOG_DIR/client-$client.log" 2>&1 &
  pids+=("$!")
done

status=0
for pid in "${pids[@]}"; do
  if ! wait "$pid"; then
    status=1
  fi
done

if ! grep -q "variant_name=Khepri Triune Salvage" "$LOG_DIR/server.log"; then
  echo "Server did not assign Khepri. Logs: $LOG_DIR" >&2
  status=1
fi
if ! grep -q "role=server result=PASS.*visual_shells=0 resources_cached=false" "$LOG_DIR/server.log"; then
  echo "Server loaded or instantiated a character shell. Logs: $LOG_DIR" >&2
  status=1
fi
for client in 1 2 3; do
  if ! grep -q "role=client result=PASS" "$LOG_DIR/client-$client.log"; then
    echo "Client $client did not validate all replicated variants. Logs: $LOG_DIR" >&2
    status=1
  fi
  if ! grep -q "current_variant_peers=3 current_variants=3" "$LOG_DIR/client-$client.log"; then
    echo "Client $client did not observe all three variants. Logs: $LOG_DIR" >&2
    status=1
  fi
  if ! grep -q "CHARACTER observed.*name=Khepri Triune Salvage" "$LOG_DIR/client-$client.log"; then
    echo "Client $client did not instantiate replicated Khepri. Logs: $LOG_DIR" >&2
    status=1
  fi
done
if grep -Eq "ERROR:|SCRIPT ERROR|result=FAIL" "$LOG_DIR"/*.log; then
  echo "Character variant acceptance logged an error. Logs: $LOG_DIR" >&2
  status=1
fi

if [[ $status -ne 0 ]]; then
  exit "$status"
fi
echo "Character variant acceptance passed: all variants replicated; server shells=0. Logs: $LOG_DIR"
