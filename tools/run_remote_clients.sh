#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/tmp/godot-skoosh/Godot_v4.4.1-stable_linux.x86_64}"
HOST="${1:-${SKOOSH_HOST:-}}"
PORT="${SKOOSH_PORT:-9077}"
LOG_DIR="${SKOOSH_LOG_DIR:-$ROOT/.tmp/skoosh-remote}"

if [[ -z "$HOST" ]]; then
  echo "Usage: $0 <server-host>" >&2
  exit 1
fi
if [[ ! -x "$GODOT_BIN" ]]; then
  echo "Set GODOT_BIN to a Godot 4.4+ executable." >&2
  exit 1
fi

mkdir -p "$LOG_DIR"
pids=()
cleanup() {
  for pid in "${pids[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT INT TERM

"$GODOT_BIN" --path "$ROOT" --position 60,80 -- --join="$HOST" --port="$PORT" \
  >"$LOG_DIR/client-1.log" 2>&1 &
pids+=("$!")
"$GODOT_BIN" --path "$ROOT" --position 720,80 -- --join="$HOST" --port="$PORT" \
  >"$LOG_DIR/client-2.log" 2>&1 &
pids+=("$!")

echo "Two SKOOSH clients connecting to $HOST:$PORT"
echo "Logs: $LOG_DIR"
echo "Close both windows or press Ctrl-C here to stop."
wait "${pids[0]}" "${pids[1]}" || true
