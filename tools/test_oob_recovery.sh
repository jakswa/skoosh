#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
LOG_FILE="${TMPDIR:-/tmp}/skoosh-oob-recovery.log"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "Godot 4.4+ was not found on PATH. Install godot or set GODOT_BIN to a command name or absolute path." >&2
  exit 1
fi

cd "$ROOT_DIR"
"$GODOT_BIN" --headless --path . --script res://tools/test_oob_recovery.gd >"$LOG_FILE" 2>&1
cat "$LOG_FILE"

respawns="$(grep -c "COMBAT respawn peer=42" "$LOG_FILE" || true)"
if [[ "$respawns" -ne 3 ]]; then
  echo "Expected two OOB respawns and one manual respawn, got $respawns" >&2
  exit 1
fi

grep -q "ACCEPT OOB recovery and carried-flag safety" "$LOG_FILE"
