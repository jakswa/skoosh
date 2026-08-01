# Visual QA

SKOOSH has an off-screen capture flow for visual and UX iteration. It renders the real lobby and a live two-client authoritative CTF match, rather than a mock UI scene.

## Run

```bash
./tools/capture_visual_qa.sh
```

The runner starts rendered Godot processes on disposable Xvfb displays with TCP disabled. It does not open windows on the desktop display, take desktop screenshots, move the host pointer, or capture host keyboard focus. Multiplayer input comes from the existing acceptance bot.

Captures and logs are written to the ignored directory:

```text
build/visual-qa/current/
build/visual-qa/current/contact-sheet.png
build/visual-qa/current/logs/
```

The suite captures the lobby plus real first-person states around spawn, combat, traversal, flag carry, round result, and late match. Elimination is also event-captured if the rendered player dies. Event-driven images are included only when the match reaches that state. The command fails if the rendered client exits unsuccessfully or fewer than five images are produced.

Override the engine, output directory, port, or capture duration when needed:

```bash
GODOT_BIN=/path/to/Godot \
SKOOSH_VISUAL_QA_DIR=.tmp/skoosh-visual-qa \
SKOOSH_VISUAL_QA_PORT=29078 \
SKOOSH_VISUAL_QA_SECONDS=24 \
./tools/capture_visual_qa.sh
```

## Review Checklist

- Lobby hierarchy, field labels, focus affordance, error/status placement, and 1280x720 fit.
- HUD hierarchy at rest and speed: score/objective priority, health/energy readability, reticle contrast, and control-hint dominance.
- Team and objective recognition across terrain, platforms, flags, player silhouettes, and fog.
- Combat feedback during firing and elimination.
- Flag-carrier instruction and win/loss notice clarity under motion.
- Terrain slope, depth, route, horizon, and platform-edge readability.
- Text clipping, overlap, unsafe margins, and contrast in every captured state.

These images are intended for human or agent review, not strict pixel-diff gating. Live network timing and player motion make exact pixels vary slightly even though the terrain and bot behavior are deterministic.
