#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
PORT="${SKOOSH_PORT:-9077}"
MAP_ID="${SKOOSH_MAP_ID:-faultline_basin}"
LOG_DIR="${SKOOSH_LOG_DIR:-$ROOT/.tmp/skoosh-network}"
mkdir -p "$LOG_DIR"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "Godot 4.4+ was not found on PATH. Install godot or set GODOT_BIN to a command name or absolute path." >&2
  exit 1
fi

pids=()
cleanup() {
  for pid in "${pids[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT INT TERM

"$GODOT_BIN" --headless --path "$ROOT" -- --server --port="$PORT" \
	--map="$MAP_ID" \
  >"$LOG_DIR/server.log" 2>&1 &
pids+=("$!")
sleep 1

"$GODOT_BIN" --path "$ROOT" --position 60,80 -- --join=127.0.0.1 --port="$PORT" --map="$MAP_ID" \
  >"$LOG_DIR/client-1.log" 2>&1 &
pids+=("$!")
"$GODOT_BIN" --path "$ROOT" --position 720,80 -- --join=127.0.0.1 --port="$PORT" --map="$MAP_ID" \
  >"$LOG_DIR/client-2.log" 2>&1 &
pids+=("$!")

echo "SKOOSH network lab running $MAP_ID on UDP $PORT"
echo "Logs: $LOG_DIR"
echo "Clients are opponents: TEAM comms stay local; choose GLOBAL with G in the V menu."
echo "Close both client windows or press Ctrl-C here to stop the server."
wait "${pids[1]}" "${pids[2]}" || true
