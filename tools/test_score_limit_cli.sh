#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
BASE_PORT="${SKOOSH_SCORE_LIMIT_TEST_PORT:-19630}"
LOG_DIR="${SKOOSH_SCORE_LIMIT_LOG_DIR:-$ROOT/.tmp/skoosh-score-limit-test}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "Godot 4.4+ was not found on PATH. Install godot or set GODOT_BIN to a command name or absolute path." >&2
  exit 1
fi

rm -rf "$LOG_DIR"
mkdir -p "$LOG_DIR"

active_pids=()

terminate_tree() {
  local pid="$1"
  local child
  while read -r child; do
    [[ -n "$child" ]] && terminate_tree "$child"
  done < <(pgrep -P "$pid" 2>/dev/null || true)
  kill "$pid" 2>/dev/null || true
}

cleanup() {
  local pid
  for pid in "${active_pids[@]:-}"; do
    terminate_tree "$pid"
  done
  for pid in "${active_pids[@]:-}"; do
    wait "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT INT TERM

valid_logs=()
for limit in 3 4 5; do
  log="$LOG_DIR/valid-$limit.log"
  valid_logs+=("$log")
  (
    trap - EXIT INT TERM
    output="$($GODOT_BIN --headless --path "$ROOT" -- --server \
      --port="$((BASE_PORT + limit))" --score-limit="$limit" --test-seconds=0.2 2>&1)"
    if [[ "$output" != *"score_limit=$limit"* ]]; then
      printf '%s\n' "$output"
      echo "Accepted score limit $limit was not applied."
      exit 1
    fi
  ) >"$log" 2>&1 &
  active_pids+=("$!")
done
valid_failed=0
for index in "${!active_pids[@]}"; do
  if ! wait "${active_pids[$index]}"; then
    cat "${valid_logs[$index]}" >&2
    valid_failed=1
  fi
done
active_pids=()
if ((valid_failed)); then
  exit 1
fi

replication_port=$((BASE_PORT + 20))
"$GODOT_BIN" --headless --path "$ROOT" -- --server --port="$replication_port" \
  --score-limit=4 --test-seconds=3 >"$LOG_DIR/server.log" 2>&1 &
server_pid=$!
active_pids=("$server_pid")
sleep 0.5
"$GODOT_BIN" --headless --path "$ROOT" -- --join=127.0.0.1 \
  --port="$replication_port" --test-seconds=2 >"$LOG_DIR/client.log" 2>&1
wait "$server_pid"
active_pids=()
if ! grep -q "ACCEPT multiplayer.*score_limit=4" "$LOG_DIR/client.log"; then
  cat "$LOG_DIR/server.log" "$LOG_DIR/client.log" >&2
  echo "Client did not replicate non-default score limit 4." >&2
  exit 1
fi

invalid_options=(
  "--score-limit="
  "--score-limit=abc"
  "--score-limit=03"
  "--score-limit=+3"
  "--score-limit=3.0"
  "--score-limit=2"
  "--score-limit=6"
  "--score-limit"
)
invalid_logs=()
for index in "${!invalid_options[@]}"; do
  option="${invalid_options[$index]}"
  log="$LOG_DIR/invalid-$index.log"
  invalid_logs+=("$log")
  (
    trap - EXIT INT TERM
    set +e
    output="$($GODOT_BIN --headless --path "$ROOT" -- --server "$option" --test-seconds=0.2 2>&1)"
    status=$?
    set -e
    if [[
      $status -eq 0
      || "$output" != *"STARTUP ERROR: --score-limit"*
      || "$output" == *"NETWORK server listening"*
    ]]; then
      printf '%s\n' "$output"
      echo "Invalid score limit '$option' did not fail startup clearly."
      exit 1
    fi
  ) >"$log" 2>&1 &
  active_pids+=("$!")
done
invalid_failed=0
for index in "${!active_pids[@]}"; do
  if ! wait "${active_pids[$index]}"; then
    cat "${invalid_logs[$index]}" >&2
    invalid_failed=1
  fi
done
active_pids=()
if ((invalid_failed)); then
  exit 1
fi
trap - EXIT INT TERM

echo "Score-limit CLI acceptance passed: 3/4/5 accepted, 4 replicated, malformed and out-of-range values rejected."
