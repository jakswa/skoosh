#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/tmp/godot-skoosh/Godot_v4.4.1-stable_linux.x86_64}"
OUTPUT_DIR="${SKOOSH_VISUAL_QA_DIR:-$ROOT/build/visual-qa/current}"
LOG_DIR="$OUTPUT_DIR/logs"
PORT="${SKOOSH_VISUAL_QA_PORT:-29077}"
TEST_SECONDS="${SKOOSH_VISUAL_QA_SECONDS:-20}"
CONNECT_ATTEMPTS="${SKOOSH_VISUAL_QA_CONNECT_ATTEMPTS:-100}"
SERVER_SECONDS=$((TEST_SECONDS + 10))

if [[ ! -x "$GODOT_BIN" ]]; then
  echo "Set GODOT_BIN to a Godot 4.4+ executable." >&2
  exit 1
fi
if ! command -v xvfb-run >/dev/null 2>&1; then
  echo "xvfb-run is required so visual QA cannot touch the desktop session." >&2
  exit 1
fi

mkdir -p "$LOG_DIR"
rm -f "$OUTPUT_DIR"/*.png "$LOG_DIR"/*.log

pids=()
terminate_tree() {
  local pid="$1"
  local child
  while read -r child; do
    [[ -n "$child" ]] && terminate_tree "$child"
  done < <(pgrep -P "$pid" 2>/dev/null || true)
  kill "$pid" 2>/dev/null || true
}
cleanup() {
  for pid in "${pids[@]:-}"; do
    terminate_tree "$pid"
  done
}
trap cleanup EXIT INT TERM

XVFB_ARGS="-screen 0 1280x720x24 -nolisten tcp"

# Lobby and gameplay render on disposable virtual X servers. Neither process
# can create a window or capture the pointer on the user's desktop display.
xvfb-run -a --server-args="$XVFB_ARGS" \
  "$GODOT_BIN" --path "$ROOT" --max-fps 60 -- \
  --visual-qa-dir="$OUTPUT_DIR" --visual-qa-lobby \
  >"$LOG_DIR/lobby.log" 2>&1

"$GODOT_BIN" --headless --path "$ROOT" -- --server --port="$PORT" \
  --test-seconds="$SERVER_SECONDS" >"$LOG_DIR/server.log" 2>&1 &
pids+=("$!")
sleep 1

xvfb-run -a --server-args="$XVFB_ARGS" \
  "$GODOT_BIN" --path "$ROOT" --max-fps 60 -- --join=127.0.0.1 --port="$PORT" --bot \
  --test-seconds="$TEST_SECONDS" --visual-qa-dir="$OUTPUT_DIR" \
  >"$LOG_DIR/qa-client.log" 2>&1 &
qa_pid=$!
pids+=("$qa_pid")

# Xvfb and llvmpipe startup time varies. Wait for this client to connect first
# so it is consistently RED, the acceptance bot's active flag-running team.
qa_connected=false
for ((_attempt = 0; _attempt < CONNECT_ATTEMPTS; _attempt++)); do
  if grep -q "NETWORK client connected" "$LOG_DIR/qa-client.log"; then
    qa_connected=true
    break
  fi
  if ! kill -0 "$qa_pid" 2>/dev/null; then
    break
  fi
  sleep 0.1
done
if [[ "$qa_connected" != true ]]; then
  echo "Visual QA client did not connect. Logs: $LOG_DIR" >&2
  exit 1
fi

"$GODOT_BIN" --headless --path "$ROOT" -- --join=127.0.0.1 --port="$PORT" \
  --bot --test-seconds="$TEST_SECONDS" >"$LOG_DIR/bot-client.log" 2>&1 &
pids+=("$!")

set +e
wait "$qa_pid"
qa_status=$?
set -e
if [[ $qa_status -ne 0 ]]; then
  echo "Visual QA client failed. Logs: $LOG_DIR" >&2
  exit "$qa_status"
fi

for pid in "${pids[@]}"; do
  if [[ "$pid" != "$qa_pid" ]]; then
    wait "$pid" 2>/dev/null || true
  fi
done

shopt -s nullglob
captures=("$OUTPUT_DIR"/[0-9][0-9]-*.png)
required_captures=(
  00-lobby.png
  10-spawn.png
  12-team-comms.png
  24-slot-2-grenade.png
  30-combat.png
  32-projectile-flight.png
  34-combat-effect.png
  36-slot-3-gatling.png
  48-slot-4-sniper.png
  50-traversal.png
  90-late-match.png
)
missing_captures=()
for capture in "${required_captures[@]}"; do
  [[ -f "$OUTPUT_DIR/$capture" ]] || missing_captures+=("$capture")
done
if (( ${#missing_captures[@]} > 0 )); then
  echo "Visual QA missing required captures: ${missing_captures[*]}. Logs: $LOG_DIR" >&2
  exit 1
fi

if grep -Eq "ERROR:|SCRIPT ERROR|rejected|Invalid" "$LOG_DIR"/*.log; then
  echo "Visual QA logged a runtime error. Logs: $LOG_DIR" >&2
  exit 1
fi

if command -v montage >/dev/null 2>&1; then
  montage "${captures[@]}" -thumbnail 640x360 -tile 2x -geometry +12+12 \
    -background '#07121c' "$OUTPUT_DIR/contact-sheet.png"
fi

echo "Visual QA captured ${#captures[@]} states without using the desktop display."
echo "Output: $OUTPUT_DIR"
if [[ -f "$OUTPUT_DIR/contact-sheet.png" ]]; then
  echo "Contact sheet: $OUTPUT_DIR/contact-sheet.png"
fi
