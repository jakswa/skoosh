# SKOOSH — Project Checkpoint

**Checkpoint date:** 2026-07-31  
**Status:** First playable movement/time-trial MVP plus an initial authoritative multiplayer/combat vertical slice; human multiplayer playtest and impairment testing remain.  
**Direction decision:** Proper multiplayer is a destination. Native desktop clients use an authoritative dedicated-server model; browser support is no longer a destination. Godot 4.4+, ENet, and Forward+ with the balanced presentation profile are the current baseline.
**Purpose:** Record where the project is, the first playtest impressions, and the likely cost of expanding it. This is context, not an instruction to address the feedback immediately.

> **Reading note:** This is an append-only project history. Sections 1-12 preserve the original movement-prototype checkpoint; sections 13-15 supersede them with the current multiplayer, disc/voice, and selected visual-direction state.

## 1. What exists now

SKOOSH is a self-contained Godot 4.x first-person movement toy using typed GDScript and the Forward+ renderer. The balanced profile enables decals, clustered team lights, SSAO, and restrained volumetric fog; expensive showcase features remain off by default.

The current build includes:

- A deterministic 512 m × 512 m generated terrain with 32,768 triangles and one trimesh collider.
- First-person mouse look and WASD movement.
- Momentum skiing with downhill acceleration, low drag, crest launches, and landing momentum transfer.
- Air steering and limited vertical/forward jets with drain, depletion, delay, and recharge.
- Dynamic speed FOV and basic jet feedback.
- An eight-gate ordered time-trial course.
- Run timing, completion state, reset, recovery, and persisted best time.
- A HUD for speed, jet energy, checkpoint progress, timer, controls, completion, pause, and F3 movement diagnostics.
- Generated terrain colors, procedural sky, lighting, fog, emissive gates, and gate pulses.
- Linux and legacy Web export presets. Web is no longer a product target; its preset can be removed during later project cleanup.

The original narrow movement/time-trial MVP in `docs/archive/PLAN.md` remains preserved, while the current project entry point now exercises the authoritative combat/CTF vertical slice documented below.

## 2. Validation completed

- Godot 4.4.1 import/editor parsing succeeds without script or resource errors.
- Headless runtime smoke tests succeed.
- Automated opening-line test reaches roughly 35 m/s while skiing; walking is roughly 8.5 m/s.
- Jet drain, delayed recharge, spawn reset, ordered checkpoint logic, completion, and best-time persistence have automated coverage through temporary headless test harnesses.
- The first gate can be crossed at skiing speed in the automated opening-line test.
- Terrain stays within the planned triangle budget.

This validation proves that the systems execute and the opening movement loop works. It does **not** replace repeated human course playtesting, combat testing, accessibility/readability testing, or multiplayer testing.

## 3. First hands-on feedback

The first player feedback is:

- The terrain is difficult to read with the current colors/material treatment.
- Turning while moving feels too difficult, enough that attempting the gates was not appealing.
- It is unclear whether this is intentionally Tribes-like inertia, insufficient steering authority, unclear course/terrain presentation, or some combination.
- Left/right jet input could alter airborne trajectory more strongly.
- That lateral jet influence might be speed-dependent, but the desired curve is not decided.
- Possible longer-term additions include capture the flag and a couple of guns.

No changes are being made from this feedback at this checkpoint. These are observations and hypotheses to test, not settled solutions.

## 4. Near-term movement and readability outlook

These are the least expensive and highest-leverage areas to iterate before adding a larger game around the movement.

### Terrain readability

Likely work:

- Increase value and hue separation between valleys, traversable slopes, steep rock, and high ground.
- Reduce the current pale/cyan wash from the interaction of vertex colors, fog, ambient light, and sun.
- Improve the existing terrain shader or use more deliberate vertex-color bands; bake-off candidates may use Forward+ features within their recorded feature budget.
- Use slope/height contour accents, restrained procedural texture variation, or broad directional markings rather than downloaded textures.
- Improve gate-to-gate route communication independently of terrain appearance.

**Estimated complexity:** small to medium. The terrain data already exposes height and normals, so the main work is visual design and repeated playtesting rather than new architecture.

### Steering authority

There are several different controls that should be tuned independently:

- Ground ski steering.
- Air control without jets.
- Lateral influence while jetting.
- Low-speed alignment versus high-speed trajectory shaping.
- Camera direction versus movement-input direction.

Simply increasing all steering could erase the momentum identity. A likely model is stronger assistance at low and medium speed, with diminishing authority at high speed. Lateral jet force could add acceleration perpendicular to current velocity rather than directly rotating velocity, preserving inertia while making intentional corrections noticeable.

Possible speed-dependent behavior:

- Strong correction below approximately 25–30 m/s so new players can line up.
- Moderate correction in the normal 30–60 m/s course band.
- Diminishing correction above that, so exceptional speed still demands planning.
- A separate small lateral jet acceleration while airborne, driven by A/D and limited by the same energy pool.

**Estimated complexity:** small for raw tuning, medium for a good speed-dependent model, and medium-to-large for sufficient playtesting across terrain, gates, jets, and landing behavior.

The important distinction is whether the problem is insufficient steering, poor visual anticipation, an overly sharp course, or all three. Changing movement before isolating those factors can create compensating bugs.

## 5. Combat outlook

Adding “a couple guns” is feasible, but it changes SKOOSH from a movement toy into the foundation of an action game.

A minimal combat sandbox would need:

- A weapon controller separate from movement.
- Fire input, cooldowns, ammo/energy rules, spread or projectile parameters, and weapon switching.
- Hitscan and/or projectile collision at very high relative movement speeds.
- Health, damage, death, respawn, and spawn safety.
- Crosshair feedback, hit confirmation, impact effects, and combat HUD state.
- Targets or another player/bot to make weapons meaningful.
- Rules for firing while skiing and jetting without damaging movement responsiveness.

A sensible first pair would exercise different technical paths:

1. A simple hitscan precision weapon.
2. A visible slow-to-medium projectile with splash or impulse.

Even these require careful high-speed collision handling. Fast player and projectile movement can tunnel through targets unless ray queries, continuous collision strategies, or server-authoritative traces are used.

**Estimated complexity:**

- Weapons firing at static targets: medium.
- Complete local combat loop with health and respawn: medium-to-large.
- Polished combat against moving players: large.
- Balanced combat that remains fun at skiing speeds: large and iteration-heavy.

## 6. Capture-the-flag outlook

Capture the flag is not one feature; it is a bundle of match, team, spawn, objective, map, UI, and usually networking systems.

A CTF mode needs at minimum:

- Team identity and team-colored presentation.
- Two bases, flags, pickup/drop/return/capture rules, and edge-case handling.
- Team spawns and respawns.
- Match state, score, timers, win conditions, and round reset.
- Objective HUD, world markers, carrier identification, and announcements.
- Terrain/map redesign around two-way traversal, offense, defense, recovery routes, and base visibility.
- Other participants: local bots or networked players.

A rules-only prototype with scripted test actors is manageable, but it would not yet be a real CTF game. Bots capable of skiing, navigating generated terrain, fighting, and understanding objectives are a large project by themselves.

### If CTF means multiplayer

Networking is the dominant complexity increase. It introduces:

- Server authority and anti-cheat boundaries.
- Replication of movement, jets, weapons, damage, flags, scores, and match state.
- Client prediction and server reconciliation for momentum movement.
- Interpolation of remote high-speed players and projectiles.
- Lag compensation for hitscan weapons.
- Join/leave handling, match startup, disconnect recovery, and host/server UX.
- Testing under latency, packet loss, different frame rates, and native desktop clients.

Godot provides networking primitives, but not a finished prediction/reconciliation architecture for this movement model.

**Estimated complexity:**

- Local CTF rule prototype with test actors: large.
- CTF with competent bots: very large.
- Basic networked CTF vertical slice: very large.
- Reliable, polished Internet multiplayer CTF: a new major phase, likely several times the effort of the current MVP.

If multiplayer CTF is the actual destination, networking assumptions should enter the architecture before weapons and match systems become deeply coupled to a single-player model.

## 7. Agreed iteration sequence

Research changed the order: networking assumptions enter before weapons and CTF.

### Iteration A — Simulation seam and local legibility

- Refactor local input out of movement simulation while preserving behavior.
- Add command/state capture and repeatable movement tests.
- Resolve enough terrain readability and steering/jet feel to exercise a representative line repeatedly.

**Complexity:** medium.

### Iteration B — Authoritative movement spike

- Run a headless Godot server and two native clients over ENet.
- Add local prediction, acknowledgment/replay reconciliation, and remote interpolation.
- Test latency/loss and profile 8–16 simulated players.
- Continue with Godot unless measured results trigger a narrow alternative-engine spike.

**Complexity:** medium-to-large and the next major decision gate.

### Iteration C — External direct-IP test

- Deploy one simple Linux server after local networking works.
- Test real Internet latency, disconnects, version checks, and logs.
- Keep operations to a VPS plus systemd/container restart policy.

**Complexity:** medium.

### Iteration D — Networked combat slice

- Add authoritative health, death, respawn, one projectile weapon, then one hitscan weapon with lag compensation.
- Test aiming, inheritance, splash/impulse, and hit feedback at skiing speeds.

**Complexity:** large.

### Iteration E — Networked CTF vertical slice

- Build an authored two-base competitive core.
- Add teams, flags, captures, score, objective HUD, join/leave handling, and administration basics.
- Defer bots, matchmaking, accounts, and fleet orchestration until the core match works.

**Complexity:** very large.

## 8. Architecture pressure from expansion

The current scripts are appropriately small for an MVP, but combat/CTF would require decomposition.

Likely new boundaries:

- `player_movement.gd`: movement simulation and movement state only.
- `player_input.gd`: local input translated into movement/weapon commands.
- `health.gd`: damage, death, and invulnerability.
- `weapon_controller.gd` plus individual weapon resources/scripts.
- `projectile.gd` and a shared damage/impact contract.
- `spawn_manager.gd`: course, combat, and team-safe respawns.
- `match_manager.gd`: generic round state and score.
- `ctf_manager.gd` and `flag.gd`: objective-specific state.
- Network snapshots/commands separated from presentation if multiplayer proceeds.
- HUD split into movement, combat, and objective widgets.

The terrain generator can remain, but a competitive mode will need more deliberate map guarantees than the current one-way time-trial route.

## 9. Main risks

- **Feel risk:** adding stronger turning can make momentum irrelevant; leaving it weak can make routes feel inaccessible.
- **Readability risk:** players cannot plan high-speed lines if terrain slope and distance are visually ambiguous.
- **Combat risk:** high-speed movement makes aiming, hit detection, spawn safety, and weapon balance unusually demanding.
- **Map risk:** a fun one-way ski course does not automatically become a balanced two-base combat map.
- **Networking risk:** prediction/reconciliation for momentum movement is substantially harder than synchronizing conventional walking.
- **Scope risk:** bots, multiplayer, two weapons, and CTF together are not a small bolt-on; they constitute a second product phase.
- **Framework risk:** netfox is appropriately shaped but not proven for this exact high-speed 3D profile; keep its boundary replaceable.

## 10. Decisions still open

Multiplayer is now a destination, using an authoritative dedicated server so clients never own position, velocity, energy, firing cadence, damage, or objective state. Godot is the selected default, conditional on the movement spike. Remaining decisions:

1. Which pinned Godot version, physics backend, and netfox release—if netfox is adopted—will the spike use?
2. Should steering be accessible and expressive, or intentionally demand long anticipation at speed?
3. Should lateral jets consume the existing shared energy or use a separate impulse/cooldown model?
4. Should guns emphasize precision, projectile leading, splash/impulse, or movement utility?
5. Should terrain remain generated, become authored, or use generated terrain with authored competitive corridors and bases?
6. Will public servers be developer-hosted only at first, or should community-hosted dedicated servers be supported?
7. Is the first population target 12, 16, or another measured cap?

## 11. Practical scope summary

- Terrain readability pass: **small-to-medium**.
- Better lateral air/jet control: **small-to-medium**, with tuning risk.
- More forgiving high-speed steering: **medium**, because course and landing feel must be retested.
- Two guns against test targets: **medium**.
- Full local combat loop: **medium-to-large**.
- CTF rules and a suitable map: **large**.
- Bots that ski and play CTF: **very large**.
- Networked CTF with satisfying high-speed combat: **very large / major new project phase**.

The best leverage is to make movement command-driven, readable, and enjoyable, then prove it under authority and latency. Every later system—aiming, weapons, maps, flags, hosting, and moderation—depends on that foundation being trustworthy.

## 12. Pause handoff

- Research outcome: `docs/decisions/RESEARCH_FINDINGS.md`.
- Original execution plan: `docs/archive/MULTIPLAYER_SPIKE.md`.
- Research brief and source-discovery paths: `docs/archive/RESEARCH_PATHS.md`.
- Original product baseline: `docs/archive/PLAN.md` and this checkpoint.
- Git was initialized and the validated pre-CTF multiplayer baseline is commit `d992749`.
- Multiplayer implementation is now underway; see the implementation checkpoint below.

## 13. Multiplayer implementation checkpoint

Implemented:

- Vendored netfox v1.35.3 (`addons/netfox*`) under its MIT license.
- Godot/ENet authoritative server on UDP port 9077, with CLI server/client modes.
- Dedicated server owns no player avatar; peers receive balanced RED/BLUE assignments.
- Shared `MovementBody` seam used by solo and network players.
- Netfox rollback state/input synchronization at 60 Hz and tick interpolation.
- Networked skiing, jet energy/state, mouse aim, reset, and out-of-bounds recovery.
- Restrained low-speed ground-jet pop: 7.5 m/s minimum upward velocity plus a fixed 6-energy cost; disabled above 11 m/s planar speed and latched until jet release.
- Pulse rifle: authoritative cadence/ray/damage, 40 damage, 0.32 s cooldown, friendly-fire rejection, and bounded client origin/direction validation.
- Server-owned health, kills, deaths, one-second death state, and team respawn.
- Compact CTF arena with two raised, 48 m-separated team platforms.
- Server-owned flag pickup, carry, drop, teammate return, timeout return, capture, sudden-death win/loss, five-second intermission, and round reset.
- Objective HUD with team, score, flag status, carry prompt, win/loss notice, health, K/D, speed, energy, RTT, and rollback telemetry.
- More readable low-poly armored player models with team colors, helmet/visor, backpack, jet pods, and an improved first-person rifle model.
- `tools/run_multiplayer_demo.sh` for a headless server plus two graphical clients.
- `tools/test_multiplayer_demo.sh` for automated combat, movement, capture, win, and round-reset acceptance.
- `tools/test_ground_jet.sh` for the low-speed pop and high-speed exclusion.
- Linux client and dedicated-server export presets; browser preset removed.

Latest automated zero-latency result:

- Two opposing peers spawned and synchronized.
- Authoritative combat produced kills, deaths, and respawns.
- A bot picked up and captured the enemy flag, RED won, and round 2 began.
- Bot movement reached 40.5 m/s and exercised jets.
- Peak observed rollback was 5 ticks; peak network-loop time was 1.95 ms on this machine.
- Ground-jet acceptance measured an 8.20 m/s first-tick pop for 6.50 energy; a 20 m/s player received no pop.
- No parser, runtime, client, or server errors/warnings in the final check.
- Original solo smoke and full course acceptance still pass; the one-second grounded jet check now drains 36 energy including the fixed pop cost.

Important limitations:

- CTF is deliberately sudden death (one capture) for a quick two-client loop.
- No artificial latency, jitter, or loss has been measured yet.
- Correction-distance/contact-disagreement instrumentation is not implemented yet.
- The pulse rifle uses the server's current collision world and has no historical hitbox rewind/lag compensation yet; see `docs/engineering/COMBAT_NETWORKING_ROADMAP.md`.
- Scale testing beyond two clients is not implemented yet.
- The revised CTF scene and player art need a human graphical playtest.
- netfox broadcasts input for this prototype; production relevancy/bandwidth hardening remains.

## 14. Voice, disc, and playtest presentation pass

Implemented on the `feature/voice-disc-ux` playtest branch:

- Replaced the hitscan pulse rifle with the only/default disc launcher: 82 m/s visible projectiles, 55% shooter-velocity inheritance, 0.82-second cadence, 5.8 m authoritative splash, and up to 105 damage.
- Clients predict disc presentation, while the server substitutes its current muzzle/aim, simulates swept flight, resolves impact/falloff, rejects friendly fire, and owns damage and kill credit.
- Added server-rate-limited TEAM/GLOBAL voice commands with a `V` menu and 12 commands across social, objective, and status channels. Five Cartesia-generated voice packs are randomized per connection and use restrained radio-band post-processing.
- Added compact callsigns, clearer score/objective/vitals/weapon hierarchy, F3-gated network telemetry, contextual pointer help, hit/damage feedback, and a focused connection terminal.
- Darkened terrain values, added four-meter contour banding, reduced cyan fog wash, and strengthened team/base contrast.
- Extended multiplayer acceptance to require a cross-peer GLOBAL voice relay plus disc impacts/damage, and to fail on logged script errors or rejected launches.
- Extended off-screen visual QA with team-comms, disc-flight, and disc-impact event captures.

Still pending:

- Human combat, voice-cast, radio-treatment, and audio-level playtesting.
- Artificial latency, jitter, and loss qualification for launch timing and remote projectile presentation.
- Projectile correction/age metrics, scale testing, and production command budgets beyond the current per-speaker voice cooldown.

## 15. Selected visual direction

The three-way visual bake-off completed from shared baseline `593f763`. The
selected direction uses Kestrel's daytime alpine atmosphere and practical
material hierarchy, STRATOS route grammar and aerofoil equipment silhouette,
and Khepri triune monument/objective language. The implementation remains on
`feature/voice-disc-ux` by explicit user request.

The former runway mannequin is replaced by three Blender-authored character
shell variants. The server assigns and replicates one presentation-only variant
per player while preserving the `MomentumLean` contract and gameplay capsule.
The launcher exposes a seated disc and open launch gate; the flying visual is
disc-shaped while authoritative swept-ray projectile behavior is intentionally
unchanged. See `docs/production/VISUAL_DIRECTION.md` and
`docs/decisions/BAKE_OFF_REPORT.md`.

## 16. Four-slot combat loadout

Implemented on `feature/combat-loadout`:

- Added server-validated slots for the existing disc, an arcing impact/fuse grenade, a deterministic-spread gatling gun, and an accurate sniper rifle.
- The grenade uses swept ballistic flight, 7.2 m authoritative splash, teammate immunity, and half self-damage without blast impulse.
- Gatling and sniper clients request fire only; the server reconstructs current-world rays from its own muzzle and aim, applies range/damage rules, and owns hit confirmation.
- Added a 0.25-second switch settle, independent cooldowns, number-key selection that yields to the voice menu, compact HUD status, and color-coded first/third-person presentation.
- Extended acceptance bots and server counters to require accepted fire from every slot, a grenade impact, and confirmed gatling and sniper hits while preserving the movement, voice, CTF, and round-reset checks.

Current limitation: hitscan is authoritative but not lag compensated. Historical player-capsule evaluation remains part of impairment qualification rather than this loadout implementation.

## 17. Production competitive maps

Implemented on `feature/proper-competitive-maps`:

- Replaced the compact default with exactly two production rotation maps: default Faultline Basin and Cairn Steps. Kestrel Basin remains explicitly selectable as a legacy/test arena only.
- Faultline uses a west-east capsule footprint, direct longitudinal fault trench, high basalt spine, screened recovery gully, recoverable raised perimeter, and violet night profile.
- Cairn uses a north-south superellipse footprint, transverse stepped escarpment, exposed chute, screened switchback, central jet saddle, recoverable raised perimeter, and chalk/graphite day profile.
- Map catalog data now drives deterministic terrain dimensions, curved authoritative OOB, bases, symmetric spawn sockets, bot routes, route marking, landmarks, material palette, atmosphere, and pre-spawn server/client map agreement.
- Added automated contracts for production count/rotation, profile and swapped-axis topology distance, footprint/aspect, curved boundary recovery, base separation, route spacing/length/grade/landings, sightlines, symmetry, one-mesh/one-collider generation, and map mismatch rejection.

These checks and automated CTF completions do not establish human balance or final production art. Both maps still require repeated human skiing, offense/defense, visibility, spawn-pressure, impairment, and minimum-spec evaluation. See `docs/production/COMPETITIVE_MAPS.md`.
