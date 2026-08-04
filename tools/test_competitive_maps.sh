#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/tmp/godot-skoosh/Godot_v4.4.1-stable_linux.x86_64}"

if [[ ! -x "$GODOT_BIN" ]]; then
  echo "Set GODOT_BIN to a Godot 4.4+ executable." >&2
  exit 1
fi

"$GODOT_BIN" --headless --path "$ROOT" --script res://tools/test_competitive_maps.gd
