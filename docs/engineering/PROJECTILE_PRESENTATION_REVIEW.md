# Projectile presentation reviewer audit

**Audit date:** 2026-08-05

**Audited source:** `.tmp/director-final-gameplay`, dirty working tree based on
`b71411f` (`fix: align OOB with visible map rims`)

**Scope:** Analysis and implementation planning only. No gameplay changes were
made as part of this audit.

## Post-audit implementation status

Commit `4549342` implemented the first-stage simulation/presentation split after
this audit. Disc and grenade simulation remains on the projectile root while a
top-level `PresentationRoot` interpolates between tick transforms. The focused
`tools/test_projectile_presentation.sh` contract verifies that presentation does
not change simulation position or launch serialization.

Accordingly, the source references and "no interpolation" findings below are a
record of the audited pre-fix tree, not the current implementation state. The
remaining active work is telemetry, bounded owner-correction concealment, the
grenade fuse freeze, impairment qualification, and presentation-only world
impact prediction. Those stages should remain separate patches.

## Executive conclusion

The reviewer's primary diagnosis is correct: discs and grenades update their
rendered root transform only on the 60 Hz netfox tick, while players have a
`TickInterpolator`. This is the strongest source-level explanation for motion
that looks smooth on players but stepped on projectiles, especially above 60
rendered frames per second.

Several follow-up observations are also valid: owner reconciliation can cause a
visible correction, clients do not predict world impacts, grenades freeze for
up to 12 ticks while awaiting an authoritative impact, and impacts and tracers
allocate substantial presentation state at runtime.

The proposed patches should not be applied verbatim, however:

- Interpolating the projectile root means interpolating the same transform used
  as simulation and reconciliation state. netfox is designed to restore the
  latest tick state before simulation, but callback order, every out-of-tick
  transform write, dedicated-server behavior, and teardown must be proven.
- Merely putting meshes beneath a `Visual` child and interpolating that child's
  unchanged local transform would not smooth root movement. A real
  simulation/presentation seam must either drive the presentation transform
  from tick state or deliberately validate root interpolation.
- `physics_jitter_fix=0.0` is a reasonable network/custom-interpolation
  baseline, but the claim that Godot and netfox currently "fight" and produce
  doubled or dropped ticks is not established by this repository.
- Moving cooldown slack to the server by shortening the authoritative cooldown
  would weaken the server contract and should not be done.
- The existing `NetworkSimulator` is not an environment-variable-ready
  impairment harness. It only supplies fixed latency and loss, is editor-build
  only, is disabled in project settings, and owns its own autoconnection path.

The correct next pass is a measured presentation change, not a netcode rewrite:
add projectile and frame-timing telemetry, compare interpolation designs and
`physics_jitter_fix` values, then address correction concealment and predicted
world-only impacts without moving collision, damage, cadence, or score authority
off the server.

## Claim audit

| Reviewer claim | Verdict | Repository evidence and qualification |
|---|---|---|
| Projectiles have no render interpolation. | **Confirmed.** | `scenes/network_player.tscn:596-599` interpolates player and head transforms. Neither projectile scene has an interpolator. `scripts/disc_projectile.gd:63-86` and `scripts/grenade_projectile.gd:23-54` move their rendered roots only from `NetworkTime.on_tick`. |
| The tick distance is large enough to be obvious. | **Confirmed.** | A base 82 m/s disc advances about 1.37 m per tick. With 55% of a 40 m/s aligned player velocity it advances about 1.73 m, not quite 1.9 m at that stated player speed. The exact visual severity still requires a high-refresh capture or screen-space telemetry. |
| Add a root `TickInterpolator` with `record_first_state=true`. | **Plausible but not yet safe to merge blindly.** | netfox documents this projectile use and `record_first_state` already defaults to `true` in `addons/netfox/tick-interpolator.gd:18-21`. The root is also gameplay state, however. The interpolator writes old render state during `_process`, restores `_state_to` in `before_tick_loop`, and rotates snapshots in `after_tick_loop` (`tick-interpolator.gd:147-181`). |
| Reconciliation and interpolator callback order is a landmine. | **Confirmed risk; proposed `teleport()` mitigation is conditional.** | `NetworkWeapon` connects its reconcile callback in `_ready` (`addons/netfox.extras/weapon/network-weapon.gd:15-18`); `TickInterpolator` connects deferred from `_enter_tree` (`tick-interpolator.gd:127-139`). The weapon will normally reconcile first. `teleport()` updates both snapshots (`tick-interpolator.gd:84-91`), which can protect the following restore if property setup is complete and every transform write uses it. This needs an explicit callback-order test rather than an assumption. |
| Reconcile can visibly pop the owner's shot. | **Confirmed mechanism; magnitude unmeasured.** | Disc requests may differ by 1.5 m at launch and 24 m/s in velocity (`scripts/network_weapon.gd:170-213`). On acceptance, `_reconcile` applies server launch data and reprojects the locally traveled scalar distance along server velocity (`network_weapon.gd:216-221`). Grenades use a separate age-based ballistic reconcile (`scripts/grenade_launcher.gd:5-10`). There are no correction-distance metrics. |
| Set `physics/common/physics_jitter_fix=0.0`. | **Reasonable experiment and likely baseline, not a proven judder fix.** | The setting is absent, so Godot's default 0.5 applies. Physics and netfox are both configured for 60 Hz with `sync_to_physics=true` (`project.godot:34-45`). Godot recommends zero for network games and custom interpolation. Missing projectile interpolation remains the direct source-proven cause; no current telemetry proves competing compensators or dropped/doubled ticks. |
| Impacts arrive late because only the server sweeps. | **Confirmed behavior; latency amount is not always exactly half an RTT.** | Both projectile scripts put mask-3 ray queries inside `multiplayer.is_server()`. Clients continue presentation until the reliable authority RPC in `scripts/network_weapon.gd:306-318`. For the shooter, total perceived delay can include request travel, the server's later projectile launch, impact travel, and RPC return. It must be measured as launch, impact, and presentation ages rather than labeled with one fixed RTT fraction. |
| Grenades freeze for 12 ticks after their fuse. | **Confirmed.** | At age 144 the client returns without moving; it frees at age 156 (`scripts/grenade_projectile.gd:23-33`). At 60 Hz that is up to 200 ms of frozen presentation. The fallback does not play an effect. |
| Clients can safely predict mask-1 world impacts. | **Directionally sound, with missing event-state design.** | Static production-map geometry is generated deterministically and world traffic is generation-gated. Prediction must remain presentation-only, be keyed by generation plus projectile identity, hide rather than authoritatively resolve the projectile, deduplicate the later RPC, tolerate impact-before-accept ordering, and clear on world retirement. Player hits, splash, hit markers, damage, and despawn authority remain server-owned. |
| Grenade fuse prediction is exact. | **Mostly, after authoritative launch acceptance.** | The fuse tick count is deterministic, but the owner and server can disagree on launch tick/state before reconciliation, and a collision may terminate the grenade before the fuse. Predict presentation from accepted authoritative launch data and still reconcile to the server impact. |
| Impact and tracer creation can hitch. | **Allocation path confirmed; hitch magnitude unmeasured.** | Each projectile impact constructs a node, sphere, torus, ten fragment nodes/meshes, materials, light, and tween (`scripts/network_weapon.gd:319-404`). Each hitscan presentation constructs a tracer mesh, material, and tween (`scripts/hitscan_weapon.gd:143-171`). The server also executes the local presentation call. Profiling is needed to attribute a frame-time spike or shader-pipeline compile to these allocations. |
| Client `+2` throttles all weapons, including gatling. | **Partly incorrect.** | The `+2` applies to disc and grenade input only (`scripts/network_weapon.gd:50-66`). Their 0.82 s disc cooldown rounds to 50 ticks and the client waits 52 ticks, about 0.867 s. Gatling uses exact local cooldown and a separate three-tick server request-attempt interval (`scripts/hitscan_weapon.gd:4,43-89`), not the projectile launcher's six-tick gate. |
| Put cooldown slack on the server as cooldown minus two ticks. | **Rejected.** | The server must continue enforcing at least the configured cadence. If measured tick skew causes valid boundary requests to be declined, fix request timing/validation or local prediction policy; do not make the authority fire faster than the weapon definition. |
| Wiring `NetworkSimulator` behind an environment variable is almost free. | **Incorrect/incomplete.** | `addons/netfox.extras/network-simulator.gd:64-95` disables itself without the editor feature and uses netfox autoconnect. It supports fixed one-way latency and independent loss only (`:32-36,130-152`), not jitter, reordering, duplication, seed control, or the current explicit server/client launcher flow. |
| The 12-tick fast-forward cap can leave remote shots behind. | **Confirmed.** | Both projectile types cap presentation fast-forward at 12 ticks (`scripts/disc_projectile.gd:39-49`, `scripts/grenade_projectile.gd:9-20`) while launch validation accepts request ages through 60 ticks (`scripts/network_weapon.gd:191-213`). Whether to raise the cap, shorten accepted age, or smooth a correction must follow impairment measurements. |

## Important design constraints

### Keep simulation authoritative

No proposed smoothing or prediction may alter the server-owned contract in
`docs/engineering/COMBAT_NETWORKING_ROADMAP.md`:

- Server projectile roots and swept collision remain authoritative.
- Client world queries may decide only what to show or temporarily hide.
- Clients never claim player contact, splash targets, hit markers, damage, kill
  credit, cadence, or projectile termination.
- Authoritative RPCs always finalize projectile removal and impact location.
- All presentation state is qualified by the active world generation and is
  cleared during map retirement.

### Do not conflate two smoothing problems

There are two independent discontinuities:

1. **Normal 60 Hz stepping:** every projectile advances a large distance once
   per network tick. Tick interpolation or an equivalent presentation seam
   addresses this continuously.
2. **Reconciliation correction:** an accepted owner shot can receive a new
   origin and velocity approximately one request/response trip later. A decaying
   visual error offset can conceal a bounded correction, but does not fix normal
   tick stepping.

A `VisualRoot` introduced only for the correction offset is useful, but its
static local transform cannot by itself interpolate parent movement.

### Root interpolation options

Two implementation spikes are credible:

**Option A: validate netfox interpolation on the root.** This is the smallest
change and matches netfox's intended restore-before-simulate model. Deactivate
the interpolator on a dedicated server; call `teleport()` after initialization,
remote launch application, owner reconciliation, and true discontinuities;
prove callback order; and audit every non-tick transform read/write. Reject this
option if render-state writes can leak into launch data, collision, impact, or
reconciliation.

**Option B: create a real simulation/presentation split.** Store the tick-state
transform independently and drive a presentation root from its previous and
current snapshots each render frame. Collision and reconciliation consume only
simulation state. This is more code but removes signal-order dependence and is
the safer long-term boundary if projectile behavior grows.

Do not implement a nominal `VisualRoot` whose local transform never receives
tick targets; it will inherit the same stepped parent motion.

## Recommended execution plan

### Stage 0: establish evidence

Add bounded, opt-in telemetry keyed by world generation, source peer, and a
monotonic shot sequence. Random projectile ID may remain as transport identity
for the first experiment, but should not be the sole correlation key.

Record:

- client request, server receive/spawn, client accept, reconcile, authoritative
  impact, client impact presentation, and local fallback ticks;
- launch age, reconcile position vector/distance, velocity delta, fast-forward
  amount, impact age, lifetime, and termination reason;
- render timestamp/delta, physics frame, network tick, ticks executed per frame,
  `NetworkTime.tick_factor`, clock stretch, rollback depth/time, and projectile
  root plus screen position;
- active and peak projectile/effect/tracer counts, effect construction time,
  and frame-time spikes around first and repeated impacts.

Report distributions and percentiles, not only peaks.

### Stage 1: qualify the landed presentation seam

The implementation selected Option B: simulation remains on the projectile
root and a top-level `PresentationRoot` interpolates render transforms. The
focused contract proves simulation-position and launch-serialization isolation,
but it does not qualify all runtime conditions.

1. Compare current effective `physics_jitter_fix=0.5` with `0.0`; keep all other
   timing settings fixed.
2. Exercise 60, 120, and 144 Hz render conditions, V-Sync on and off, and a
   stable cap. The current visual-QA path caps at 60 FPS and cannot qualify this
   issue alone.
3. Test multiple network ticks in one render frame, rollback, local and remote
   shots, immediate spawn, reconcile, impact, lifetime expiry, map retirement,
   and dedicated-server execution.
4. Trace simulation and presentation transforms to prove no render state enters
   launch data, collision, impact, or reconciliation.

Expected result: the landed between-tick presentation remains smooth with
identical server launch, path, collision tick, impact position, damage, and
despawn.

### Stage 2: conceal bounded owner reconciliation

1. Measure correction vectors before selecting a threshold or decay rate.
2. Put disc/grenade render nodes beneath a presentation root.
3. After authoritative reconciliation, retain the pre-correction rendered world
   position as a visual error and decay it toward zero over a short bounded
   interval.
4. Snap instead of conceal for non-finite state, large corrections, generation
   changes, projectile expiry, and other true discontinuities.
5. Keep projectile root/simulation state immediately authoritative.

The reviewer's `3.0 m` threshold and `14.0` decay constant are starting
hypotheses, not accepted tuning values.

### Stage 3: predict world-only impact presentation

1. On admitted clients, sweep only static world layer 1 along the same presented
   segment. Do not query or claim player layer 2.
2. On predicted contact, hide/freeze the presentation and play a provisional
   world effect. Do not apply splash, hit feedback, damage, or authoritative
   removal.
3. Track provisional state by generation plus stable shot identity. Handle
   impact-before-accept, duplicate current-generation events, declined launches,
   and map retirement.
4. When the authority event arrives, suppress an equivalent duplicate, correct
   a materially different impact, finalize despawn, and show server-owned hit
   feedback.
5. Apply the same contract to grenade fuse presentation only after accepted
   launch state is known. Remove the current 12-tick frozen-fuse interval.

### Stage 4: reduce effect frame-time risk

Profile first-use and steady-state impact/tracer frame time in Forward+ and the
lean profile. If the path is material:

- move authored effect structure and reusable meshes to packed scenes;
- use a bounded pool with complete reset on reuse and world retirement;
- avoid mutating shared `StandardMaterial3D` alpha across simultaneous effects;
  use per-instance shader parameters only with a shader designed for them;
- cap concurrent cosmetic effects under sustained gatling/projectile load;
- skip local presentation construction on dedicated servers;
- warm required effect and shader variants during a non-gameplay loading phase,
  then verify warming on exported client builds.

### Stage 5: revisit cadence and fast-forward policy

Do this only with rejection and launch-age data:

- Remove or reduce the projectile client's `+2` delay only if server acceptance
  remains reliable at cooldown boundaries.
- Keep the server cooldown at or above the configured weapon cooldown.
- Separate anti-abuse request budgets from legal cadence for projectile and
  hitscan weapons; a rejected request should not accidentally suppress a later
  valid request without an intentional policy.
- Choose a fast-forward cap together with maximum accepted launch age. Avoid a
  policy where a request is legal at 60 ticks old but can only be presented 12
  ticks into its trajectory unless a measured smoothing strategy closes the
  difference.

## Impairment harness requirement

Do not couple qualification to netfox's existing autoconnect-only simulator
without redesigning it. The harness must work with SKOOSH's explicit server and
client CLI, dedicated-server export, ports, and map-rotation admission flow. It
must provide deterministic scenarios for:

- one-way latency or RTT;
- jitter;
- loss;
- reordering;
- duplication;
- random seed and emitted impairment counters.

An external UDP proxy or Linux `tc netem` harness may be smaller and more
representative than extending the autoload. Whichever implementation is chosen,
run at least baseline, moderate-latency, high-latency, and latency-plus-loss
profiles against local owner shots, remote shots, world impacts, player impacts,
grenade fuse expiry, declines, respawn discontinuities, and map rotation.

## Acceptance gates

The later implementation is complete only when all of these hold:

- Projectile root and screen-space motion no longer hold for repeated render
  frames at 120/144 Hz under stable frame pacing.
- Dedicated-server launch, collision tick, impact position, splash, damage,
  cadence, and despawn results are unchanged by presentation interpolation.
- No stale render transform enters launch serialization, reconcile distance,
  collision queries, or impact resolution.
- Bounded owner corrections settle without oscillation, long trails, or hiding
  large authority disagreement.
- Predicted static-world impacts do not duplicate effects, hit markers, or
  sounds when the reliable authority event arrives.
- Impact-before-accept, decline, loss/retransmission, fallback, and generation
  retirement leave no ghost projectile or stale dedup entry.
- Grenades no longer freeze visibly between fuse and authority presentation.
- `physics_jitter_fix=0.0` is retained only after timing traces show neutral or
  improved pacing and no player interpolation regression.
- Effect pooling/warming, if implemented, improves measured frame time and
  fully resets color, alpha, light, tween, ownership, and generation state.
- Existing movement and multiplayer headless suites remain green, with focused
  projectile presentation/impairment coverage added alongside them.

## Priority summary

1. Instrument launch, correction, impact, frame pacing, and effect cost.
2. Qualify the landed between-tick presentation seam and A/B
   `physics_jitter_fix`.
3. Add measured, bounded correction concealment.
4. Add generation-safe world-only impact and grenade-fuse prediction.
5. Pool/warm effects if profiling confirms frame-time cost.
6. Revisit client cooldown margin and fast-forward limits from impairment data;
   do not weaken authoritative cadence.
