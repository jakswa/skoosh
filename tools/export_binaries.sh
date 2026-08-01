#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"

cd "$ROOT"
mkdir -p build/linux build/windows build/server build/dist

"$GODOT_BIN" --headless --path "$ROOT" --export-release "Linux Client"
"$GODOT_BIN" --headless --path "$ROOT" --export-release "Windows Client"
"$GODOT_BIN" --headless --path "$ROOT" --export-release "Linux Dedicated Server"

chmod +x build/linux/skoosh.x86_64 build/server/skoosh-server.x86_64
tar -C build/linux -czf build/dist/skoosh-linux-client.tar.gz skoosh.x86_64
tar -C build/server -czf build/dist/skoosh-linux-server.tar.gz skoosh-server.x86_64
if command -v zip >/dev/null 2>&1; then
  zip -j -q build/dist/skoosh-windows-client.zip build/windows/skoosh.exe
else
  echo "zip is unavailable; distribute build/windows/skoosh.exe directly." >&2
fi

(
  cd build/dist
  sha256sum ./* > SHA256SUMS
)

echo "Release artifacts written to $ROOT/build/dist"
