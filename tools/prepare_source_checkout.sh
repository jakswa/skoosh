#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
IMPORT_LOG="${SKOOSH_IMPORT_LOG:-$ROOT/.tmp/skoosh-import.log}"
CLASS_CACHE="$ROOT/.godot/global_script_class_cache.cfg"
IMPORTED_ASSET="$ROOT/.godot/imported/kestrel_relay_disc.glb-88b2b6b0db0d5bfcc4934b2a66eb2241.scn"
KEY_FILE="$ROOT/.godot/skoosh-imported-key"
LOCK_DIR="$ROOT/.godot/skoosh-import.lock"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	echo "Godot 4.4+ was not found on PATH. Install godot or set GODOT_BIN to a command name or absolute path." >&2
	exit 1
fi

revision="source"
dirty_hash="source"
if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	revision="$(git -C "$ROOT" rev-parse HEAD)"
	dirty_hash="$(git -C "$ROOT" diff --binary HEAD | git -C "$ROOT" hash-object --stdin)"
fi
godot_version="$("$GODOT_BIN" --version)"
cache_key="$revision:$dirty_hash:$godot_version"

cache_ready() {
	local imported_key=""
	if [[ -f "$KEY_FILE" ]]; then
		IFS= read -r imported_key <"$KEY_FILE" || true
	fi
	[[ -f "$CLASS_CACHE" && -f "$IMPORTED_ASSET" && "$imported_key" == "$cache_key" ]]
}

if cache_ready; then
	exit 0
fi

mkdir -p "$ROOT/.godot" "$(dirname "$IMPORT_LOG")"
lock_acquired=false
for ((attempt = 0; attempt < 1200; attempt++)); do
	if mkdir "$LOCK_DIR" 2>/dev/null; then
		lock_acquired=true
		break
	fi
	if cache_ready; then
		exit 0
	fi
	sleep 0.1
done
if [[ "$lock_acquired" != true ]]; then
	echo "Could not acquire the Godot import lock within 120s. Remove $LOCK_DIR if no import is running." >&2
	exit 1
fi
cleanup() {
	rmdir "$LOCK_DIR" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

if cache_ready; then
	exit 0
fi

echo "Preparing this source checkout with Godot..."
if ! "$GODOT_BIN" --headless --path "$ROOT" --import >"$IMPORT_LOG" 2>&1; then
	echo "Godot could not import the project. See $IMPORT_LOG" >&2
	exit 1
fi
if grep -Eq "SCRIPT ERROR:|No loader found for resource|referenced non-existent resource|Failed to instantiate an autoload" "$IMPORT_LOG" \
	|| [[ ! -f "$CLASS_CACHE" || ! -f "$IMPORTED_ASSET" ]]; then
	echo "Godot did not finish preparing the project. See $IMPORT_LOG" >&2
	exit 1
fi
printf '%s\n' "$cache_key" >"$KEY_FILE"
echo "Source checkout ready. Import log: $IMPORT_LOG"
