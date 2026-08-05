# Movement and UX research context

**Status:** Durable research context. Not a movement tuning specification or active UX
backlog.

Read [`README.md`](README.md) for document authority and the source-license boundary.

Statements below about what SKOOSH "already" or "currently" does are observations from
2026-08-03, not canonical status. Verify them against current source and
[`../../CHECKPOINT.md`](../../CHECKPOINT.md).

## Prediction and reconciliation

The useful historical architecture is command-driven server authority:

1. Sample a compact input command at a fixed simulation tick.
2. Predict the owner immediately.
3. Send recent input redundantly rather than requiring reliable delivery of every input
   packet.
4. Let the server simulate commands in order.
5. Treat authoritative state as the boundary through which earlier input has been
   incorporated.
6. Restore authoritative state and replay only later local input.
7. Smooth the visible result separately from collision/simulation state.

This does not require deterministic lockstep. It requires replayable state, compatible
client/server collision inputs, bounded divergence, and corrections that preserve feel.

SKOOSH already follows this overall model through netfox at 60 Hz. The remaining question
is empirical: whether `CharacterBody3D.move_and_slide()` floor/contact behavior remains
close enough through fast slope transitions, crests, landings, jets, and replay.

## State and diagnostics

Capture every mutable value needed to restart movement, not only transform and velocity.
Current synchronized state includes movement transform/velocity, jet energy and recharge,
jet-pop latch, ski/jet flags, teleport discontinuity, and view transform. Floor contact,
floor normal, and snap state are derived during replay.

Instrumentation should record:

- Correction distance and frequency.
- Input age and authoritative simulation boundary.
- Replay depth and replay CPU.
- Client/server grounded disagreement.
- Floor-normal disagreement.
- Residual error after replay.
- Speed retained through landing, crest, seam, step, and wall contacts.

Do not infer movement quality from a zero-latency two-client pass.

## Skiing is more than zero friction

The lineage review confirms that apparent ground friction is usually several mechanisms:
acceleration toward desired velocity, drag, speed resistance, gravity projection,
stepping, and collision-normal projection. A ski mode must decide each term explicitly.

SKOOSH already has the core ski behavior:

- Reduced floor snap and low drag while skiing.
- Tangent-aware slope acceleration.
- Limited air steering and jet influence.
- Landing momentum transfer.
- Reconstruction of tangent vertical velocity removed by `CharacterBody3D` grounding.
- A restrained, fuel-costed low-speed jet pop.

The next movement work is qualification and tuning, not adding a first friction toggle.
If measured correction remains unacceptable, replace only the movement collision hot
path with a controlled sweep/slide motor before replacing netfox, ENet, or Godot.

## Terrain implications

The historical terrain lesson is architectural rather than format-specific: broadphase
collision should query local cells/swept volumes and reject coarse height ranges instead
of making work proportional to total map area.

SKOOSH's current 512 m generated mesh and single trimesh collider prove the compact
prototype, not a 4 km^2 production map. Before building streaming, profile representative
Godot heightfield or chunked static collision for:

- High-speed sweeps and missed contacts.
- Chunk-boundary normal continuity while skiing.
- Raycast and projectile cost.
- Server load time and memory.
- Precision at map extremes.
- Separation of visual LOD from authoritative collision.

Readable ski lines matter as much as collision cost. Terrain shading, contour language,
silhouettes, and landmarks must let a player predict slope and landing shape at speed.

## HUD information hierarchy

A Tribes-style HUD should answer four questions without requiring menu inspection:

1. **Movement:** current speed and jet energy.
2. **Survival/combat:** health, weapon readiness, hit/damage direction, and meaningful
   correction/debug information only when diagnostics are enabled.
3. **Objective:** both flag states, carrier/carry state, return/capture conditions, score,
   and off-screen direction when needed.
4. **Communication:** active VGS path, team/global scope, speaker, and confirmation.

SKOOSH already provides speed, energy, health, K/D, score, flag states, carrying/round
status, and F3-gated networking diagnostics. It also has world-space flag objects. The
useful remaining objective work is off-screen direction, carrier clarity, and human
testing under high-speed combat, not another generic HUD rewrite.

Debug metrics should remain available but visually separate from competitive information.

## Sensors and radar

No advanced radar policy is adopted yet. If introduced, keep these concepts separate:

- Exact actor state for nearby/relevant threats.
- Coarse sensor contact with visibly lower precision/update cadence.
- Fading last-known contact with age.
- Global objective status and possibly coarse carrier information.
- Unknown/hidden state enforced by the server, not merely hidden in client UI.

Icons should communicate team, objective role, precision, and staleness without relying
only on color. Start with distance/team/objective rules and hysteresis. Terrain line-of-
sight sensing is expensive and boundary-noisy; add it only for a deliberate stealth
design.

Sensor gameplay rules can inform interest management, but network interest and render
visibility are not identical. An off-screen incoming projectile can be network-critical.

## VGS / quickchat

The lineage's durable VGS lesson is muscle-memory navigation: open, category, intent.
A good command system has stable shallow paths, visible TEAM/GLOBAL scope, immediate
local audio/text feedback, compact semantic command IDs, server validation/rate limits,
and mute/accessibility support.

SKOOSH already has 12 categorized TEAM/GLOBAL commands, numeric navigation, authoritative
relay/rate limiting, voice playback, and text toasts. Refine this system rather than
replace it. Human tests should determine:

- Whether common commands take at most two or three presses after opening.
- Whether scope is unmistakable before dispatch.
- Whether objective commands need contextual base/flag/direction information.
- Whether voice casting and radio processing remain legible during jets, impacts, and
  high-speed wind.

## Vehicles and loadouts

The source pass identified useful vehicle rules: stable seat identity, authoritative
mount changes, safe dismount placement, scoped-together occupants, explicit control and
camera ownership, and deterministic destruction policy.

These are retained only as future context. Vehicles multiply prediction, ownership,
collision, seat, and interest-management cases and should remain deferred until player
replication is qualified. Loadout-station flow and advanced inventory are likewise not
adopted requirements.

## Feel principles worth retaining

- Show speed because momentum and route choice are player decisions.
- Smooth camera/models/effects, not authoritative collision state.
- Use correction thresholds deliberately; tiny noise should not create visible motion,
  while very large discontinuities should not be hidden by a long glide.
- Gate low-value impact effects below perceptual thresholds.
- Use clamped, monotonic HUD mappings.
- Keep the local player readable through speed, cloak/damage effects, and correction.
- Name and test important feel constants instead of scattering unexplained multipliers.
- Treat human playtesting at realistic latency as evidence, not polish after networking.

Active visual validation belongs in
[`../../production/VISUAL_QA.md`](../../production/VISUAL_QA.md), and current
combat qualification belongs in
[`../../engineering/COMBAT_NETWORKING_ROADMAP.md`](../../engineering/COMBAT_NETWORKING_ROADMAP.md).
