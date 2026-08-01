#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
LOG_FILE="${TMPDIR:-/tmp}/skoosh-oob-recovery.log"

cd "$ROOT_DIR"
"$GODOT_BIN" --headless --path . --script res://tools/test_oob_recovery.gd >"$LOG_FILE" 2>&1
cat "$LOG_FILE"

respawns="$(grep -c "COMBAT respawn peer=42" "$LOG_FILE" || true)"
if [[ "$respawns" -ne 2 ]]; then
  echo "Expected one respawn per distinct OOB excursion, got $respawns" >&2
  exit 1
fi

grep -q "ACCEPT OOB recovery latch" "$LOG_FILE"
