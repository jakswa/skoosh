#!/usr/bin/env bash
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="${SKOOSH_PROJECT_ROOT:-$SCRIPT_ROOT}"
REAL_GODOT_BIN="${GODOT_BIN:-/tmp/godot-skoosh/Godot_v4.4.1-stable_linux.x86_64}"
WESTON_BIN="${WESTON_BIN:-$(command -v weston || true)}"
RENDERING_METHOD="${SKOOSH_RENDERING_METHOD:-forward_plus}"
MAP="${SKOOSH_MAP:-kestrel_basin}"
case "$MAP" in
  kestrel_basin|relay_divide|split_crown) ;;
  *) echo "SKOOSH_MAP rejected '$MAP'; expected kestrel_basin, relay_divide, or split_crown." >&2; exit 2 ;;
esac

if [[ ! -x "$REAL_GODOT_BIN" ]]; then
  echo "Set GODOT_BIN to a Godot 4.4+ executable." >&2
  exit 1
fi
if [[ -z "$WESTON_BIN" || ! -x "$WESTON_BIN" ]]; then
  echo "Private GPU-backed off-screen capture requires Weston. Set WESTON_BIN to its executable." >&2
  exit 1
fi

SCRATCH_ROOT="${SKOOSH_TMP_DIR:-$ROOT/.tmp}"
WESTON_LOG_DIR="${SKOOSH_VISUAL_QA_DIR:-$ROOT/build/visual-qa/$MAP/current}/logs"
mkdir -p "$SCRATCH_ROOT" "$WESTON_LOG_DIR"
WRAPPER_DIR="$(mktemp -d "$SCRATCH_ROOT/forward-wrapper.XXXXXX")"
GODOT_WRAPPER="$WRAPPER_DIR/godot-forward-plus"
cleanup() {
  rm -rf "$WRAPPER_DIR"
}
trap cleanup EXIT INT TERM

# capture_visual_qa.sh calls Godot three ways. Dedicated/headless processes use
# Godot's dummy display as usual. Each rendered process receives its own private
# headless Wayland compositor, giving Vulkan or OpenGL a GPU-backed presentation
# queue without ever creating a window on the user's desktop. WESTON_MODULE_MAP
# and LD_LIBRARY_PATH may be supplied when testing an unpacked Weston build.
cat >"$GODOT_WRAPPER" <<EOF
#!/usr/bin/env bash
set -euo pipefail
for argument in "\$@"; do
  if [[ "\$argument" == "--headless" ]]; then
    exec "$REAL_GODOT_BIN" "\$@"
  fi
done

runtime_dir="\$(mktemp -d "$SCRATCH_ROOT/wayland.XXXXXX")"
chmod 700 "\$runtime_dir"
socket="skoosh-forward-\$\$"
weston_log="\$runtime_dir/weston.log"
weston_pid=""
cleanup_render() {
  if [[ -n "\$weston_pid" ]]; then
    kill "\$weston_pid" 2>/dev/null || true
    wait "\$weston_pid" 2>/dev/null || true
  fi
  if [[ -f "\$weston_log" ]]; then
    cp "\$weston_log" "$WESTON_LOG_DIR/weston-\$\$.log"
  fi
  rm -rf "\$runtime_dir"
}
trap cleanup_render EXIT INT TERM

XDG_RUNTIME_DIR="\$runtime_dir" WAYLAND_DISPLAY= \
  "$WESTON_BIN" --backend=headless --renderer="${SKOOSH_WESTON_RENDERER:-gl}" --shell=kiosk-shell.so \
  --socket="\$socket" --width=1280 --height=720 --idle-time=0 --no-config \
  --log="\$weston_log" >/dev/null 2>&1 &
weston_pid=\$!
for _attempt in {1..100}; do
  if [[ -S "\$runtime_dir/\$socket" ]]; then
    break
  fi
  if ! kill -0 "\$weston_pid" 2>/dev/null; then
    echo "Private Weston compositor failed:" >&2
    cat "\$weston_log" >&2 || true
    exit 1
  fi
  sleep 0.05
done
if [[ ! -S "\$runtime_dir/\$socket" ]]; then
  echo "Private Weston compositor did not create its socket." >&2
  cat "\$weston_log" >&2 || true
  exit 1
fi
# The socket appears before relocated/newer Weston builds have advertised all
# required globals. Give shell and wl_shm registration time to settle.
sleep 2.0

profile_args=()
run_args=("\$@")
if [[ "${SKOOSH_GPU_PROFILE:-0}" == "1" ]]; then
  profile_args+=(--gpu-profile --print-fps --disable-vsync --max-fps 0)
  run_args=()
  skip_next=false
  for argument in "\$@"; do
    if [[ "\$skip_next" == true ]]; then
      skip_next=false
      continue
    fi
    if [[ "\$argument" == "--max-fps" ]]; then
      skip_next=true
      continue
    fi
    run_args+=("\$argument")
  done
fi

set +e
env DISPLAY= XDG_RUNTIME_DIR="\$runtime_dir" WAYLAND_DISPLAY="\$socket" \
  XDG_SESSION_TYPE=wayland \
  "$REAL_GODOT_BIN" --display-driver wayland --rendering-method "$RENDERING_METHOD" \
  --audio-driver Dummy "\${profile_args[@]}" "\${run_args[@]}"
status=\$?
set -e
exit "\$status"
EOF
chmod +x "$GODOT_WRAPPER"

SKOOSH_VISUAL_QA_CONNECT_ATTEMPTS="${SKOOSH_VISUAL_QA_CONNECT_ATTEMPTS:-1200}" \
  GODOT_BIN="$GODOT_WRAPPER" "$ROOT/tools/capture_visual_qa.sh"
