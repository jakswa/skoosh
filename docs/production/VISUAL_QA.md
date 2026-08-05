# Visual QA

SKOOSH has an off-screen capture flow for visual and UX iteration. It renders the real lobby and a live two-client authoritative CTF match, rather than a mock UI scene.

## Run

Compatibility renderer:

```bash
./tools/capture_visual_qa.sh
```

Forward+ or a GPU-backed renderer comparison:

```bash
./tools/capture_visual_qa_private_wayland.sh
```

The Compatibility runner starts rendered Godot processes on disposable Xvfb displays with TCP disabled. Xvfb cannot provide the Vulkan presentation queue required by Forward+. The Forward+ runner instead starts a private headless Weston compositor for each rendered process; it requires the `weston` executable or an explicit `WESTON_BIN` path and keeps sockets/wrappers under the repository's ignored `.tmp/` directory. Do not disable libdecor plugins for this path: Godot 4.4 uses libdecor when the kiosk compositor does not advertise server-side decorations. Both paths avoid the desktop display, desktop screenshots, pointer movement, and host keyboard focus. Multiplayer input comes from the existing acceptance bot.

Captures and logs are written to the ignored directory:

```text
build/visual-qa/current/
build/visual-qa/current/contact-sheet.png
build/visual-qa/current/logs/
```

The private-Wayland path retains a `weston-<pid>.log` for each rendered process alongside the Godot logs.

The suite captures the lobby plus real first-person states around spawn, combat, traversal, flag carry, round result, and late match. Elimination is also event-captured if the rendered player dies. Captures other than elimination are written only while the rendered player is alive, including a state check after the rendered frame, so weapon and combat names cannot be satisfied by the death/reboot overlay.

The command fails if a rendered client exits unsuccessfully, any Godot log contains `SCRIPT ERROR` or `ERROR:`, or any required named state is absent. Required states are lobby, spawn, team comms, grenade, general combat, projectile flight, combat effect, gatling, sniper, traversal, and late match. Elimination, flag-carrier, and round-result captures remain optional because they are event-driven.

Override the engine, output directory, port, or capture duration when needed:

```bash
GODOT_BIN=/path/to/Godot \
SKOOSH_VISUAL_QA_DIR=.tmp/skoosh-visual-qa \
SKOOSH_VISUAL_QA_PORT=29078 \
SKOOSH_VISUAL_QA_SECONDS=24 \
SKOOSH_MAP_ID=cairn_steps \
./tools/capture_visual_qa.sh
```

The private-Wayland runner additionally accepts:

```bash
SKOOSH_RENDERING_METHOD=forward_plus \
SKOOSH_RENDERER_PROFILE=balanced \
./tools/capture_visual_qa_private_wayland.sh
```

Run the full suite once per production map with `SKOOSH_MAP_ID=faultline_basin`
and `SKOOSH_MAP_ID=cairn_steps`. Automated gameplay captures use central
acceptance-only combat sockets so weapon/effect states remain deterministic on
large maps. The capture-only server accepts wider predicted launch presentation
skew from the slow off-screen renderer but still constructs authoritative launch
state; normal clients keep production spawn and launch-validation bounds.

When profiling renderer throughput, `SKOOSH_GPU_PROFILE=1` disables VSync and the frame cap and prints one-second project FPS samples. This is diagnostic evidence, not a substitute for testing representative minimum-spec hardware.

## Review Checklist

- Lobby hierarchy, field labels, focus affordance, error/status placement, and 1280x720 fit.
- HUD hierarchy at rest and speed: score/objective priority, health/energy readability, reticle contrast, and control-hint dominance.
- Team and objective recognition across terrain, platforms, flags, player silhouettes, and fog.
- Combat feedback during firing and elimination.
- Flag-carrier instruction and win/loss notice clarity under motion.
- Terrain slope, depth, route, horizon, and platform-edge readability.
- Text clipping, overlap, unsafe margins, and contrast in every captured state.

These images are intended for human or agent review, not strict pixel-diff gating. Live network timing and player motion make exact pixels vary slightly even though the terrain and bot behavior are deterministic.
