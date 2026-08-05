#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
LOG_DIR="${SKOOSH_ROTATION_LIFECYCLE_LOG_DIR:-$ROOT/.tmp/skoosh-rotation-lifecycle-test}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	echo "Godot 4.4+ was not found on PATH. Install godot or set GODOT_BIN." >&2
	exit 1
fi

rm -rf "$LOG_DIR"
mkdir -p "$LOG_DIR"
"$GODOT_BIN" --headless --path "$ROOT" --script res://tools/test_rotation_lifecycle.gd \
	>"$LOG_DIR/lifecycle.log" 2>&1
cat "$LOG_DIR/lifecycle.log"

grep -q "ACCEPT rotation lifecycle bootstrap=true reconnect=true queued=true ghost=true visibility=true input=true" \
	"$LOG_DIR/lifecycle.log"
if grep -Eq "ERROR:|SCRIPT ERROR|Node not found|Invalid packet|contract=FAIL" "$LOG_DIR/lifecycle.log"; then
	echo "Rotation lifecycle contract logged an error. Logs: $LOG_DIR" >&2
	exit 1
fi
