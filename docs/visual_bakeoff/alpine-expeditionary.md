# KESTREL BASIN // FORWARD RELAY

## Candidate brief

**Five defining adjectives:** austere, wind-scoured, field-rigged, weighty, signal-bright.

**Implementation intent:** Recast the live CTF arena as a severe high-altitude relay dispute. Pale hardpack and fractured slate make slope changes readable under a low amber sun; compact graphite-and-ceramic stations visibly brace against the basin rather than sitting on it. Team identity is restricted to red or blue signal cloth, lamps, and cable markings, while neutral mint identifies active survey technology. A fresh Blender-authored induction launcher, relay-station kit, objective mast, and matching projectile establish a practical expeditionary silhouette without borrowing the runway art. Client-only launch and impact presentation will use expanding mint pressure rings, hot fragments, and hard directional light while authoritative combat remains untouched.

Broad implementation order:

1. Establish cold shadow, warm sun, pale hardpack, slate exposure, and long-distance contour readability.
2. Replace the runway platforms with braced relay stations whose render shell respects the unchanged box collision.
3. Replace the first-person launcher and objective silhouettes with expeditionary equipment.
4. Build a layered disc-flight and impact language, then tune team and UI accents only after the world frame coheres.

## Iteration evidence

### Iteration 1

Evidence: `build/visual-bake-off/alpine/iteration-1/` and `build/visual-bake-off/alpine/iteration-1/contact-sheet.png` (11 live states, private Wayland, Forward+ balanced).

Three largest failures observed in the actual captures:

1. The solid team capture disc and local volumetric base fog become enormous cyan fields when the camera is close, hiding the station and violating the controlled-accent rule. Fix: replace the filled capture mesh with a narrow ring, disable local team fog volumes, and retain small signal lights/markings.
2. Amber sunlight plus cream vertex color turns hardpack into desert sand, while the horizon is flat neutral gray. Fix: move hardpack toward cold blue-gray, make the horizon visibly cool, reduce amber saturation, and preserve warm/cool separation through light rather than albedo.
3. Pale launcher ceramic reads showroom-clean and the expanding impact core blows out near-camera combat states. Fix: darken/roughen launcher ceramic toward worn field ceramic and reduce the impact core radius, opacity, and expansion while preserving the mint pressure ring and fragments.

### Iteration 2

Evidence: `build/visual-bake-off/alpine/iteration-2/`. The first pass produced all 11 live states but was rejected by the harness after a single contention-sensitive predicted launch rejection; the directory is rerun in isolation after the corrections below so its contact sheet and logs represent the accepted pass.

Three largest failures observed in the actual captures:

1. At capture or round result range, the graphite foundation becomes one monolithic dark wall. Fix: add flush ceramic service panels and narrow team service marks to the existing authoritative box face, preserving collision while exposing construction scale.
2. Direct-lit hardpack still leans peach rather than cold mineral white. Fix: cool the terrain vertex family again and make the directional light a less saturated amber; shadow remains blue-gray.
3. The pressure torus can read as a broad mint band across the near-camera impact frame. Fix: narrow its tube and cap expansion so fragments and the core carry the event without obscuring terrain or objectives.

The accepted rerun produced 11 states and `build/visual-bake-off/alpine/iteration-2/contact-sheet.png` with no logged runtime errors.

## Why this is a different game

KESTREL BASIN treats the match as a contested high-altitude survey deployment rather than a generic arena. Relay keys replace flags, open braced stations cling to the basin, the launcher is a heavy induction tool with an exposed removable charge, and team ownership is communicated by service markings and lamps rather than fully colored buildings. Terrain, equipment, objective language, atmosphere, and HUD terminology all support the same field-expedition fiction while the SKOOSH simulation remains unchanged.

## Palette and material logic

- Hardpack: cold off-white and blue-gray, with analytic wind scoring and 3.25 m contour strata.
- Exposed slope: low-value dark slate with rough mineral response; steepness remains readable at speed.
- Light: low warm sun with cool ambient fill and restrained global volumetric depth.
- Architecture: rough graphite load frames, worn gray ceramic service panels, slate decks, and small emissive mint floodlights.
- Identity: muted controlled red/blue on narrow rails, cables, objective rings, and suit modules only.
- Technology: neutral mint/teal is reserved for relay traces, projectile energy, reticle, and pressure effects.
- Surfaces deliberately avoid gloss; metals are rough and ceramic is matte. No downloaded textures are used.

## Implemented changes

- Replaced the runway terrain material with `alpine_hardpack.gdshader`, preserving the generated topology and authoritative trimesh collision.
- Regraded sky, sun, ambient fill, depth fog, volumetric fog, SSAO, team lights, and capture-zone presentation.
- Replaced the runway base GLB with a fresh Blender-authored braced relay station containing a layered deck, bearing, wind braces, gantries, floodlight rails, service panels, survey mast, and objective socket.
- Replaced the Solar Nomad launcher/projectile with a fresh Blender-authored Kestrel induction launcher and matching relay disc.
- Replaced solid capture discs with narrow objective rings and replaced banner flags with rotating relay-key beacons.
- Added muzzle pressure-ring presentation, a longer mint projectile trail, and layered impact core/ring/fragment/light decay. Effects remain client presentation driven by the authoritative impact RPC.
- Restricted team color on remote suits and stations, rethemed lobby/HUD terminology, and named the candidate KESTREL BASIN // FORWARD RELAY.
- Added a selectable Weston renderer override to the private-Wayland QA wrapper; its default remains unchanged.

## Placeholders and production path

- The retained runway momentum suit and `MomentumLean` animation are placeholders. Production character design, deformation quality, hand integration, retargeting, death animation, and a complete movement set are unproven.
- Callsign `Label3D` markers and the functional HUD remain prototype presentation.
- The station kit should be split into authored reusable modules, receive baked edge wear/ice masks, and gain LODs after a direction decision.
- The launcher needs authored hand sockets, first-person arms, a clearer disc feed/reload motion, texture-baked wear, and LOD/triangle review.
- Terrain production should add art-directed macro masks and authored basin landmarks without changing the qualified competitive heightfield or routes.
- Action effects need surface-normal alignment and a GPU-particle debris pass after combat readability and low-end overdraw are measured.

## Source, binary, and license inventory

All new assets are worker-authored original project work with no downloads, external packs, generated services, attribution, or license restrictions. See `assets/manifests/kestrel_basin_assets.json`.

- Generator: `tools/asset_pipeline/create_alpine_expedition_assets.py`.
- Editable source: `assets/source/weapons/kestrel_induction_launcher.blend` (127,958 bytes).
- Editable source: `assets/source/environment/kestrel_relay_station.blend` (129,163 bytes).
- Runtime: `assets/models/weapons/kestrel_induction_launcher.glb` (277,136 bytes).
- Runtime: `assets/models/weapons/kestrel_relay_disc.glb` (41,360 bytes).
- Runtime: `assets/models/environment/kestrel_relay_station.glb` (502,420 bytes).
- Runtime/source shader: `assets/materials/terrain/alpine_hardpack.gdshader`.

## Forward+ and fallback

Balanced uses the adopted SSAO and restrained global volumetric fog. No TAA, SSR, SSIL, SDFGI, shadowed local lights, or downloaded high-resolution texture sets were added. The eight existing unshadowed team lights remain but are lower energy/range; two local team fog volumes are disabled. Dynamic impact lights are short-lived and unshadowed.

Lean fallback disables SSAO and volumetric fog through the existing renderer profile while retaining direct lighting, depth fog, analytic terrain surfacing, unshadowed signal lights, objective geometry, launcher, and effects. Main performance risks are station GLB draw/triangle cost before production LODs, analytic terrain fragment noise, transient transparent impact overdraw, and clustered local lights. Host captures on the Radeon 7900 XT are not minimum-spec proof.

## Collision and authority

No gameplay rules, movement values, weapon values, terrain topology, base placement, objective rules, routes, network ownership, or authoritative collision were changed. Terrain render and collision still come from the same generated mesh. Each station retains the existing 14 x 2 x 14 authoritative box.

Presentation-only station gantries, rails, braces, bearing, survey mast, and understructure have no collision. Gantries are placed outside the box edge and braces/bearing remain below the playing deck to minimize false cover; they must receive matching production collision only after route qualification. Flush service panels do not materially differ from the box face. Objective beacon geometry remains non-colliding, matching the prior flag presentation contract.

## Validation

- `TMPDIR="$PWD/.tmp" ./tools/test_ground_jet.sh`: PASS, `pop=8.20 m/s`, `fuel=6.50`, `high_speed_y=0.20`. Result log: `.tmp/bakeoff-ground-jet.log`.
- `TMPDIR="$PWD/.tmp" SKOOSH_TEST_PORT=19101 SKOOSH_TEST_LOG_DIR="$PWD/.tmp/bakeoff-multiplayer" ./tools/test_multiplayer_demo.sh`: PASS. Four authoritative kills/deaths, four disc impacts with damage, global cross-peer voice, three captures/rounds, peak speed 26.5 m/s, jets exercised, peak rollback 6 ticks, peak network loop 2.39 ms. Logs: `.tmp/bakeoff-multiplayer/`.
- Iteration 1 command: private-Wayland Forward+, balanced, port `29101`, output `build/visual-bake-off/alpine/iteration-1/`: PASS, 11 states.
- Iteration 2 command: same private-Wayland Forward+ profile and port, output `build/visual-bake-off/alpine/iteration-2/`: PASS after isolated reruns of one predicted-launch rejection and one disconnect-cache race, 11 states.

The unpacked Weston 15 binary on this host required `WESTON_MODULE_MAP` entries for its relocated backend/renderer/shell. Forward+ startup also required disabling unrelated implicit Steam fossilize/overlay and Mesa anti-lag/device-select Vulkan layers; without those variables Godot stalled before Vulkan device creation. This is capture-host configuration, not a project fallback. The overseer should use the standardized serial environment that already handles relocated Weston, or carry the same implicit-layer disables before final capture.

## Provisional heroes

Use these iteration-2 live-match frames for later standardized-final nomination:

1. `build/visual-bake-off/alpine/iteration-2/10-spawn.png`
2. `build/visual-bake-off/alpine/iteration-2/50-traversal.png`
3. `build/visual-bake-off/alpine/iteration-2/60-flag-carrier.png`
