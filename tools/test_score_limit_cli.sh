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

for limit in 3 4 5; do
  output="$($GODOT_BIN --headless --path "$ROOT" -- --server \
    --port="$((BASE_PORT + limit))" --score-limit="$limit" --test-seconds=0.2 2>&1)"
  if [[ "$output" != *"score_limit=$limit"* ]]; then
    printf '%s\n' "$output" >&2
    echo "Accepted score limit $limit was not applied." >&2
    exit 1
  fi
done

rm -rf "$LOG_DIR"
mkdir -p "$LOG_DIR"
replication_port=$((BASE_PORT + 20))
"$GODOT_BIN" --headless --path "$ROOT" -- --server --port="$replication_port" \
  --score-limit=4 --test-seconds=3 >"$LOG_DIR/server.log" 2>&1 &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT INT TERM
sleep 0.5
"$GODOT_BIN" --headless --path "$ROOT" -- --join=127.0.0.1 \
  --port="$replication_port" --test-seconds=2 >"$LOG_DIR/client.log" 2>&1
wait "$server_pid"
trap - EXIT INT TERM
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
for option in "${invalid_options[@]}"; do
  set +e
  output="$($GODOT_BIN --headless --path "$ROOT" -- --server "$option" --test-seconds=0.2 2>&1)"
  status=$?
  set -e
  if [[
    $status -eq 0
    || "$output" != *"STARTUP ERROR: --score-limit"*
    || "$output" == *"NETWORK server listening"*
  ]]; then
    printf '%s\n' "$output" >&2
    echo "Invalid score limit '$option' did not fail startup clearly." >&2
    exit 1
  fi
done

echo "Score-limit CLI acceptance passed: 3/4/5 accepted, 4 replicated, malformed and out-of-range values rejected."
