#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "Godot 4.4+ was not found on PATH. Install godot or set GODOT_BIN." >&2
  exit 1
fi

(
  cd "$ROOT/audio/generated"
  sha256sum --check SHA256SUMS
)

"$GODOT_BIN" --headless --path "$ROOT" res://tools/test_client_audio.tscn
