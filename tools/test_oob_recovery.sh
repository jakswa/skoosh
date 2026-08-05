#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
LOG_DIR="${SKOOSH_OOB_TEST_LOG_DIR:-${TMPDIR:-/tmp}/skoosh-oob-recovery}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "Godot 4.4+ was not found on PATH. Install godot or set GODOT_BIN to a command name or absolute path." >&2
  exit 1
fi

cd "$ROOT_DIR"
rm -rf "$LOG_DIR"
mkdir -p "$LOG_DIR"

for map_id in faultline_basin cairn_steps; do
  log_file="$LOG_DIR/$map_id.log"
  "$GODOT_BIN" --headless --path . --script res://tools/test_oob_recovery.gd -- \
    --map="$map_id" >"$log_file" 2>&1
  cat "$log_file"

  respawns="$(grep -c "COMBAT respawn peer=42" "$log_file" || true)"
  if [[ "$respawns" -ne 11 ]]; then
    echo "Expected eight directional, one persistent-OOB retry, one below-terrain, and one manual respawn on $map_id; got $respawns" >&2
    exit 1
  fi
  grep -q "ACCEPT OOB recovery map=$map_id exits=8 below=1 manual=1 carried_flag_safe=true" "$log_file"
done
