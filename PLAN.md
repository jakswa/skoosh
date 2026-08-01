# SKOOSH — Implementation Plan

## 1. Product definition

Build a small, original, first-person 3D movement game inspired by the feeling of momentum skiing and jet-assisted flight across rolling terrain. This is a **movement toy and time trial**, not a full Tribes clone.

The core promise is:

> Start on a ridge, dive into a valley, gain speed by skiing, use limited jets to shape the next arc, launch over a crest, and chase a faster line through a short course.

Use the name **SKOOSH** and only original/generated visuals, sounds, terrain, text, and code. Do not use Tribes names, maps, characters, weapons, logos, or extracted assets.

## 2. Scope

### MVP must include

- A runnable Godot project that opens directly into play.
- First-person mouse look and keyboard movement.
- Momentum-preserving skiing over sloped terrain.
- Jet-assisted flight with visible energy drain and recharge.
- A deterministic, attractive, low-poly outdoor terrain.
- One ordered checkpoint course with a timer and saved best time.
- Current speed, jet energy, timer, checkpoint progress, and concise control hints.
- Instant reset to the current run's spawn point.
- Falling/out-of-bounds recovery.
- Dynamic field of view and simple speed/jet feedback.
- Desktop play as the primary target and a browser-compatible rendering path.

### Explicitly out of scope

- Multiplayer or networking.
- Weapons, damage, enemies, bots, vehicles, teams, inventory, or loadouts.
- Accounts, backend services, analytics, monetization, or an asset pipeline.
- A large world, procedural world streaming, multiple courses, or a level editor.
- Mobile/touch controls and gamepad support for the first pass.
- Photorealism or dependence on external art packs.

Do not expand scope until all acceptance criteria in section 12 pass.

## 3. Technology and constraints

- **Engine:** Godot 4.x stable, preferably 4.3 or newer.
- **Language:** GDScript only. Do not use C#, so web export remains possible.
- **Renderer:** Compatibility renderer (`gl_compatibility`) from the start.
- **Dependencies:** No third-party addons and no downloaded assets.
- **Platforms:** Linux/Windows desktop first; Godot web export second.
- **Performance target:** Stable 60 FPS at 1080p on an ordinary laptop, with terrain kept near or below 35,000 triangles.
- **Code style:** Typed GDScript where practical, small focused scripts, exported tuning variables grouped by purpose, and comments explaining movement math rather than narrating obvious code.
- **Project behavior:** The game must be playable offline and must not require build-time secrets or network access.

If a requested effect is unreliable in the Compatibility renderer, choose the simpler compatible effect.

## 4. Player experience and controls

### Controls

| Action | Input |
|---|---|
| Look | Mouse |
| Move/steer | W/A/S/D |
| Ski | Hold Space |
| Jet | Hold Shift or Right Mouse Button |
| Reset run | R |
| Capture mouse / resume | Left click |
| Release mouse / pause overlay | Escape |
| Toggle debug movement readout | F3 |

Prevent the browser context menu from interfering with Right Mouse when running a web build if Godot does not already consume it. Shift must always remain an equivalent jet input.

### Intended feel

- Normal walking is responsive but deliberately slower than skiing.
- Holding ski removes nearly all ground drag; gravity accelerates the player down slopes.
- Climbing costs speed, descending gains speed, and crossing a crest naturally launches the player.
- Landing while skiing transfers a controlled portion of downward momentum into slope-tangent momentum. Smooth landings should feel rewarding.
- Steering while skiing or airborne shapes a trajectory but cannot instantly reverse high-speed momentum.
- Jets provide enough upward acceleration to extend a jump or clear a ridge, but sustained flight is impossible because energy is limited.
- There is no ordinary jump button. Terrain, speed, and jets create airtime.
- No normal gameplay action hard-caps speed at the walk speed. A high emergency velocity cap may prevent physics instability.

Target speed bands, to be tuned by play rather than treated as rigid requirements:

- Walking: 7–11 m/s.
- Early skiing: 15–30 m/s.
- Good course line: 30–60 m/s.
- Exceptional launch: 60–90 m/s.
- Physics safety cap: approximately 120 m/s.

## 5. Project structure

The implementation agent should create approximately this structure. Minor changes are fine when they simplify the project, but avoid a monolithic script.

```text
skoosh/
├── PLAN.md
├── project.godot
├── export_presets.cfg
├── icon.svg
├── scenes/
│   ├── main.tscn
│   ├── player.tscn
│   └── checkpoint_gate.tscn
├── scripts/
│   ├── main.gd
│   ├── player.gd
│   ├── terrain.gd
│   ├── course_manager.gd
│   ├── checkpoint_gate.gd
│   ├── hud.gd
│   └── movement_audio.gd       # optional polish phase
└── shaders/
    └── terrain.gdshader        # only if vertex colors are insufficient
```

Prefer scene-authored node composition for stable structure and scripts for generated terrain/course content. Do not create separate markdown documentation; this file remains the single product and implementation reference.

## 6. Scene architecture

### `main.tscn`

Use a root `Node3D` with these logical children:

- `WorldEnvironment`: procedural sky, ambient light, tone mapping, and conservative fog if compatible.
- `DirectionalLight3D`: warm angled sunlight with shadows.
- `Terrain`: a scripted `StaticBody3D` containing generated mesh and collision.
- `CourseManager`: owns ordered gates, run state, timing, reset behavior, and best-time persistence.
- `Player`: instantiated player scene.
- `HUD`: a `CanvasLayer` reading player/course state.
- Optional distant decorative meshes only if they do not add collision complexity.

`main.gd` should coordinate initialization in a deterministic order:

1. Generate terrain and collision.
2. Build/place the course using `terrain.height_at(x, z)`.
3. Place the player at a safe spawn transform.
4. Connect player, course, and HUD signals.
5. Capture the mouse and begin in a ready state.

### `player.tscn`

Suggested hierarchy:

- `CharacterBody3D` with `player.gd`.
  - Capsule `CollisionShape3D`.
  - `Head` (`Node3D`) for pitch.
    - `Camera3D`.
      - Minimal crosshair may remain in HUD instead.
  - One downward `RayCast3D` only if additional ground lookahead is needed.
  - `AudioStreamPlayer` children only during the polish phase.

Use a capsule around 1.0 m radius/diameter scale and an eye height that makes terrain speed legible. Keep the collision shape centered correctly so resets never embed it in terrain.

### `checkpoint_gate.tscn`

Use an `Area3D` with a generous box trigger, two emissive posts, and a top beam or ring-like silhouette made from primitive meshes. A gate receives its ordered index and changes appearance among inactive, next, and completed states. Collision should detect only the player body.

## 7. Terrain and visual direction

### Terrain generation

Generate one deterministic square terrain at startup or in an editor-safe tool script:

- Approximately 512 m × 512 m.
- 129 × 129 vertices (128 × 128 quads, 32,768 triangles).
- A fixed seed using Godot's built-in `FastNoiseLite`, layered at two or three frequencies.
- Broad rolling hills must dominate; small noise should add visual variation without creating collision chatter.
- Sculpt or blend in at least one long valley, several smooth bowls, and crest lines that support launch/landing arcs.
- Raise the outer boundary gradually to suggest a contained alpine basin and reduce accidental exits.
- Expose a deterministic `height_at(x, z) -> float` function using exactly the same height formula used to build the mesh. Course gates and spawn points must use this function.
- Generate smooth normals and a matching trimesh collision shape.
- Avoid CSG terrain and avoid one collision body per tile.

A suitable height composition is broad low-frequency noise plus a few analytic sine/gaussian ridges and bowls. Clamp or smooth extreme local slopes. The result matters more than the exact formula.

### Terrain appearance

Aim for a clean, colorful alien-alpine look:

- Deep valley color: cool teal/green.
- Mid slopes: desaturated grass/rock.
- High elevations: pale stone or light snow.
- Steep faces: darker exposed rock.
- Bright blue/cyan sky and warm sun.
- Checkpoints: high-contrast cyan for the next gate and muted violet for inactive/completed gates.

Use generated vertex colors based on height and estimated slope with a `StandardMaterial3D`, or a small Compatibility-safe shader. No texture downloads. Add subtle distance fog only if it works in both desktop and web rendering.

Keep the world readable at speed: strong silhouettes, little visual clutter, no dense vegetation, and no small collidable props.

## 8. Movement implementation

Implement movement in `player.gd` with all important values exported and grouped under headings such as Walking, Skiing, Air, Jets, Camera, and Safety. Emit signals for HUD values and run events rather than making HUD own physics logic.

### Core state

At minimum track:

- Velocity inherited from `CharacterBody3D`.
- Whether the body was/is grounded.
- Whether ski is held.
- Whether jet is active.
- Current jet energy and recharge delay.
- Current horizontal/total speed.
- Mouse yaw and pitch.
- Last safe spawn/reset transform.
- Pre-move velocity for ski landing transfer.

Configure the body for slope movement rather than character-platform behavior:

- `motion_mode` grounded.
- `floor_stop_on_slope = false`.
- `floor_constant_speed = false`.
- A reasonable floor angle around 50–55 degrees.
- Floor snapping enabled for walking and disabled or nearly zero while skiing, so crests cause launches.
- Avoid treating near-vertical terrain as floor.

### Wish direction

Convert WASD input into a world-space direction using camera yaw only. Do not allow camera pitch to make normal movement climb into the air. On a floor, project the wish direction onto the floor plane. Normalize input so diagonal input is not stronger.

### Quake-style acceleration

Use acceleration toward a desired direction without globally clamping existing momentum. Conceptually:

```text
current_along_wish = velocity dot wish_direction
available = wish_speed - current_along_wish
if available > 0:
    added = min(acceleration * wish_speed * delta, available)
    velocity += wish_direction * added
```

Use distinct acceleration and wish-speed values for walking, skiing, and air control. This lets players steer high-speed motion without deleting momentum merely because total velocity exceeds the nominal wish speed.

### Walking

When grounded and not skiing:

- Apply strong horizontal/tangent friction.
- Accelerate toward the walk wish direction.
- Use floor snap to remain planted on ordinary slopes.
- Walking should be reliable for lining up a run but should never be the fastest strategy.

### Skiing

When ski is held:

- Set floor snap to zero or a minimal value.
- On a valid floor, project velocity onto the floor plane without resetting its magnitude to walk speed.
- Apply gravity every physics tick; collision sliding should turn gravity into downslope acceleration.
- Apply only tiny drag, enough to avoid endless numerical motion but not enough to spoil long glides.
- Apply weak Quake-style steering projected onto the floor.
- Preserve momentum through normal terrain seams and do not auto-stop on slopes.
- Let the body leave the ground naturally at convex crests.

When an airborne skiing player lands on a valid floor, calculate the incoming velocity projected onto the new floor plane. Blend a configurable portion of incoming total speed into that tangent direction. Start with a landing-transfer factor around `0.6–0.75`. This should reward matching a downslope landing while avoiding infinite speed from tiny repeated contacts. Apply transfer only on a genuine air-to-floor transition and only to floor collisions, never wall collisions.

Do not introduce a hidden automatic jump every frame. If seam snagging occurs, first fix collision, floor snap, safe margin, and terrain smoothness. Add only a very small one-time ski lift on contact as a last resort.

### Air control

While airborne:

- Apply gravity.
- Allow weak Quake-style steering using yaw-relative input.
- Preserve existing momentum and prevent instant turns.
- Do not apply walking friction.
- Clamp downward speed only if needed for collision stability.

### Jets

While either jet input is held and energy is available:

- Drain energy continuously.
- Apply world-up acceleration strong enough to overcome gravity modestly.
- Apply a smaller forward component in the flattened camera/wish direction so jets can shape an arc.
- Allow jets on ground or in air.
- Never refill while actively firing.

After release or depletion, wait a short delay before recharge. Suggested starting values:

| Parameter | Initial value |
|---|---:|
| Max energy | 100 |
| Drain | 30 per second |
| Recharge | 20 per second |
| Recharge delay | 0.4 seconds |
| Gravity | 28–32 m/s² |
| Vertical jet acceleration | 40–44 m/s² |
| Forward jet acceleration | 7–10 m/s² |

Tune these as a system. Full energy should shape one major jump, not permit indefinite hovering.

### Safety and resets

- Apply only an emergency total-speed cap around 120 m/s, preserving direction.
- Reset when R is pressed, when the player falls well below terrain, or when far outside map bounds.
- A reset restores transform, clears velocity, refills jet energy, resets FOV, and restarts the run cleanly.
- Store spawn transforms above the sampled terrain height and validate with a downward ray if necessary.

## 9. Camera, HUD, feedback, and audio

### Camera

- Capture mouse at launch; Escape releases it and shows a small paused/click-to-resume overlay.
- Clamp pitch to about ±85 degrees.
- Keep mouse sensitivity as an exported setting.
- Smoothly widen FOV from roughly 78–82 degrees at low speed toward 98–105 degrees at high speed. Base it on horizontal speed and smooth the transition to avoid pumping.
- Add at most subtle camera roll from lateral steering. It must be easy to disable and must not cause nausea.
- Do not add head bob while skiing.

### HUD

Keep HUD minimal and readable:

- Centered small crosshair.
- Large speed readout in `m/s` near the lower center.
- Jet energy bar with a firing/depleted/recharging visual state.
- Current run timer and best time.
- `CHECKPOINT n / total`.
- Brief controls card that fades after the player begins moving but can reappear after reset.
- Completion panel showing current time, best time, and “R to run again.”
- F3 debug panel showing grounded state, ski state, velocity vector, floor angle, vertical speed, and jet energy.

Use Godot theme overrides and simple panels; no external font is required.

### Feedback

Required inexpensive feedback:

- Dynamic FOV based on speed.
- Gate color change and a short scale/brightness pulse when crossed.
- Jet energy bar reacts immediately.
- Subtle screen-edge tint or reticle change while jetting.

Optional polish after the game is complete:

- Generate a loopable wind-noise `AudioStreamWAV` in code, with volume/pitch driven by speed.
- Generate a separate filtered noise/rumble loop for jets.
- A short synthesized checkpoint tone.
- Sparse speed streak particles that use very few particles and work in Compatibility mode.

Audio generation must be deterministic and self-contained. Skip audio rather than blocking the MVP on it.

## 10. Course and run loop

Create one ordered course of approximately 45–90 seconds for a new player and 25–50 seconds for a practiced run.

### Layout

- Spawn the player on or near a high ridge, facing the first valley.
- Place 6–8 gates along a route containing:
  1. An obvious opening descent.
  2. A broad turn that demonstrates ski steering.
  3. A valley-to-crest jet opportunity.
  4. A downhill landing that rewards momentum transfer.
  5. A final fast descent or launch into the finish.
- Gate vertical position comes from `terrain.height_at()` plus sufficient clearance.
- Orient each gate toward the segment direction and make trigger volumes forgiving.
- A gate should be visible from the prior gate under normal conditions.
- Crossing gates out of order does nothing except optionally flash the correct next gate.

The implementation agent must play the route and adjust XZ positions, terrain features, spawn yaw, and gate size. Do not accept a mathematically generated route that is technically valid but unpleasant to traverse.

### Timing and persistence

- The run enters `READY` after spawn/reset.
- Start timing on the first meaningful movement input, ski input, or jet input.
- Advance only when the expected checkpoint is crossed.
- Stop at the final gate and show results.
- Save best time using `ConfigFile` at `user://skoosh.cfg` only when a completed time improves it.
- Reset returns to the original course spawn and clears checkpoint state.
- The HUD should format time as `MM:SS.mmm` or `SS.mmm`.

Recommended course state enum: `READY`, `RUNNING`, `FINISHED`.

## 11. Implementation order

Keep the project runnable after every phase. Complete and validate one phase before polishing the next.

### Phase 1 — Bootstrap and graybox

- Create `project.godot`, input actions, Compatibility renderer settings, main scene, light, sky, and player scene.
- Add a temporary flat floor plus smooth primitive ramps/bowls or an initial terrain mesh.
- Implement mouse capture/look, walking, reset, and a basic debug readout.
- Validate script parsing and collision before proceeding.

**Exit condition:** The project launches without errors; walking, looking, mouse release, and reset work.

### Phase 2 — Movement core

- Implement ski mode, slope gravity, low drag, no ski floor snap, crest launches, air steering, landing transfer, and emergency caps.
- Add jets and energy/recharge state.
- Expose tuning constants and add debug metrics.
- Spend focused playtest time on a simple valley and opposing ramps.

**Exit condition:** Diving down a hill gains clearly visible speed, climbing loses speed, a crest launches naturally, a smooth downhill landing retains useful momentum, and jets cannot sustain infinite flight.

### Phase 3 — Final terrain and visual readability

- Implement deterministic terrain mesh, normals, vertex colors/material, and one trimesh collider.
- Add broad hand-shaped features needed by the course.
- Add environment, sunlight, fog if safe, and out-of-bounds recovery.
- Remove temporary test geometry unless intentionally hidden behind a debug flag.

**Exit condition:** The whole terrain is traversable without obvious snagging, collision gaps, severe jitter, or unreadable slopes.

### Phase 4 — Course and HUD

- Implement gates, ordered progression, timer states, best-time save, reset wiring, and completion state.
- Build and hand-tune the route.
- Implement final HUD, controls hint, pause overlay, and F3 panel.

**Exit condition:** A fresh player can infer the route, complete a timed run, see a result, reset, and beat a persisted best time.

### Phase 5 — Juice, compatibility, and cleanup

- Add dynamic FOV, gate pulses, jet tint, and optional procedural sound.
- Add a web export preset and verify all materials/effects use Compatibility-safe features.
- Profile terrain and physics.
- Remove dead code, warnings, placeholder labels, and temporary debug output.
- Ensure project starts directly in `main.tscn`.

**Exit condition:** Desktop build is clean and satisfying; a web build succeeds when matching export templates are installed, or any environment-only export blocker is recorded in the final agent report.

## 12. Acceptance criteria

The implementation is complete only when all applicable checks pass.

### Startup and stability

- [ ] Opening the project and pressing Play starts gameplay directly.
- [ ] No GDScript parse errors, missing-resource errors, or continuous error spam occurs.
- [ ] Terrain mesh and collision are deterministic between runs.
- [ ] The player never spawns embedded in terrain.
- [ ] Reset works from ground, air, after finishing, and after falling out of bounds.

### Movement

- [ ] Walking is responsive and slower than a normal ski run.
- [ ] Holding Space on a descent produces sustained acceleration with little drag.
- [ ] Skiing uphill consumes momentum rather than maintaining an artificial constant speed.
- [ ] Releasing ski returns to planted, higher-friction walking behavior.
- [ ] Convex crests can launch the player without a scripted jump.
- [ ] Air steering is useful but cannot instantly reverse high-speed motion.
- [ ] Smooth downhill landings retain/transfer more useful momentum than poor uphill landings.
- [ ] Jets visibly drain energy, overcome gravity modestly, stop at zero, and recharge after release.
- [ ] Full jet energy cannot provide permanent flight.
- [ ] Routine movement does not trigger the emergency speed cap.

### Course and UI

- [ ] All gates are visible/reachable and trigger reliably at high speed.
- [ ] Only the expected next gate advances progression.
- [ ] Timer starts on first action, stops at finish, and formats correctly.
- [ ] Best time survives a project restart.
- [ ] Speed, jet energy, checkpoint count, and timing state are legible.
- [ ] Escape releases the mouse and click resumes capture.
- [ ] F3 debug information can be hidden during normal play.

### Presentation and performance

- [ ] Terrain has broad smooth skiable shapes rather than noisy bumps.
- [ ] Lighting, terrain, sky, and gates are visually distinct without external assets.
- [ ] Dynamic FOV communicates speed without violent changes.
- [ ] The terrain remains near or below the triangle budget.
- [ ] Play is smooth on desktop with no obvious frame spikes after initial generation.
- [ ] The project uses GDScript and Compatibility rendering only.
- [ ] A web export preset exists and does not rely on unsupported native dependencies.

## 13. Validation commands and playtest checklist

Use whichever Godot executable is installed (`godot`, `godot4`, or an absolute path). At minimum run:

```bash
# Import resources and catch parse/load errors.
godot --headless --editor --path . --quit

# Start the main scene briefly and inspect output for runtime errors.
godot --headless --path . --quit-after 5

# Launch for manual playtesting.
godot --path .
```

If headless rendering cannot initialize in the current environment, use the editor/parser check and document that limitation rather than weakening the project.

Manual playtest sequence:

1. Reset and complete a run using only walking where possible; confirm it is slow but stable.
2. Reset, hold ski through the opening descent, and verify speed rises continuously.
3. Approach a crest both with and without jets; compare useful airtime.
4. Land once aligned down a slope and once facing uphill; verify the aligned landing is superior.
5. Empty jet energy, hold the button, release it, and observe delayed recharge.
6. Cross a wrong gate, then the correct one at high speed.
7. Finish, reset, finish faster, restart the project, and confirm the best time remains.
8. Fall off/out of the map and verify automatic recovery.
9. Rapidly toggle ski near terrain transitions and watch for snagging, jitter, or speed exploits.
10. Test mouse capture/release and all HUD states in both windowed desktop and web export when available.

## 14. Tuning priorities and decision rules

Tune in this order:

1. Collision stability and smooth contact.
2. Gravity, terrain scale, and slope shapes.
3. Ski drag and landing momentum transfer.
4. Ski/air steering authority.
5. Jet vertical force, drain, and recharge.
6. Camera FOV feedback.
7. Course placement and target times.
8. Visual/audio polish.

When tradeoffs arise:

- Prefer fun momentum over physical realism.
- Prefer predictable controls over elaborate simulation.
- Prefer broad terrain edits over hacks in player physics.
- Prefer one obvious route with optional line choices over many unclear routes.
- Prefer generated primitives and color over adding an asset dependency.
- Prefer a finished movement toy over partially implemented combat or multiplayer.
- Never hide a movement bug by clamping all speed to a low maximum.

The final implementation agent should conclude with a concise report listing what was built, validation performed, remaining environment-only limitations, and the most important exported values to tune next.