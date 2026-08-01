# SKOOSH — Authoritative Multiplayer Movement Spike

**Purpose:** Answer whether Godot can preserve SKOOSH's skiing/jet movement under realistic network conditions before combat and CTF expand the architecture.  
**Time-box:** Approximately 1–2 focused engineering weeks for the network experiment, excluding open-ended movement polish.  
**Decision:** Evaluate Godot first. Do not port engines or build two networking stacks in parallel.

> **Implementation checkpoint:** The first Godot/netfox vertical slice now runs: headless authoritative server, two clients, rollback movement, remote interpolation, bot-driven ski/jet testing, and an authoritative pulse-rifle death/respawn loop. Local zero-latency acceptance passes. Remaining spike work is impairment testing, correction instrumentation, 8–16 actor scaling, and human playtesting.

## 1. Outcome required

At the end of the spike, one headless authoritative server and two native clients must traverse representative terrain while:

- The local client predicts its own movement immediately.
- The server computes authoritative movement from input commands.
- The local client reconciles and replays after snapshots.
- Each client smoothly interpolates the other skier.
- Artificial latency, jitter, and loss can be enabled.
- Correction and performance metrics explain whether Godot is viable.

This is an engine decision experiment, not the start of production matchmaking.

## 2. Explicit non-goals

Do not add during the spike:

- Guns, damage, health, or lag compensation.
- CTF, teams, bases, flags, or scoring.
- Accounts, matchmaking, parties, persistence, or databases.
- Cloud orchestration or managed hosting.
- NAT traversal or community-server discovery.
- Packet bit-packing or sophisticated delta compression.
- Bots capable of playing the game.
- Kernel anti-cheat.
- A second engine port.
- Simultaneous netfox and hand-rolled implementations.
- Major art or course expansion.

Terrain readability and movement control deserve a small local pass, but must not consume the network time-box.

## 3. Pause/resume checklist

Before implementation resumes:

1. Read `CHECKPOINT.md` and `RESEARCH_FINDINGS.md`.
2. Initialize source control and commit the existing playable baseline if the owner approves; the current directory is not yet a Git repository.
3. Pin one Godot stable version for client, server, CI, and all contributors.
4. Re-run editor import, runtime smoke, and course-state checks on that version.
5. Move useful temporary acceptance harnesses into a repository `tests/` area so behavior preservation is repeatable.
6. Verify the current netfox release, Godot-version compatibility, license, and CharacterBody rollback guidance against primary docs.
7. Record current movement values and test measurements before refactoring.
8. Keep the existing game playable after every milestone.

Do not start by provisioning a VPS. Local server and two-client operation comes first.

## 4. Architecture constraints

### 4.1 Authority

The client sends input commands, not an authoritative transform. The server owns:

- Position and velocity.
- Ground/air and ski state.
- Jet energy and recharge timing.
- Spawn/reset state.
- Later: weapon cadence, projectiles, damage, flags, and score.

Client-reported transform/velocity may be logged diagnostically during the spike but must never drive server state.

### 4.2 Simulation seam

Do not require the first movement implementation to be mathematically pure. It must instead be **replayable and inspectable**:

```text
command source -> movement step(command, fixed_delta) -> CharacterBody/collision world
                       |                         |
                  capture state            restore state
```

The movement motor must:

- Never read `Input` directly.
- Accept one explicit command for one fixed tick.
- Capture all correction-relevant state.
- Restore that state before replay.
- Produce diagnostics for contact and divergence.
- Avoid camera, HUD, and visual-effect responsibilities.

### 4.3 Presentation separation

The simulation transform is corrected immediately. A separate presentation transform may smooth small visible corrections. Camera, FOV, particles, audio, and HUD remain client-only and must not feed collision or authority.

### 4.4 Transport boundary

Game code should depend on commands, states, snapshots, and authority roles—not directly on netfox internals everywhere. Keep a narrow adapter so netfox can be removed if the spike identifies a blocker.

## 5. Candidate command and state

Exact encoding is deferred, but define a stable semantic shape.

### Player command

- `sequence` or simulation tick.
- Forward/back axis.
- Left/right axis.
- Ski held.
- Jet held and, if introduced, lateral/vertical jet intent.
- View yaw and pitch or a normalized aim representation.
- Later commands can add fire and weapon selection.

Send a small bundle of recent unacknowledged commands with each unreliable input update rather than making movement wait for reliable delivery.

### Predicted movement state

- Simulation tick/last processed sequence.
- Global transform or position/orientation.
- Velocity.
- Jet energy.
- Recharge timer.
- Ski and jet-active state.
- Floor snap/movement mode where relevant.
- Landing-transfer state, if it spans ticks.
- Grounded state and floor normal for diagnostics and correction comparison.

Floor contacts should be recomputed from the authoritative/client physics world. They are not trusted client claims.

## 6. Implementation milestones

### M0 — Baseline and repeatability

Deliverables:

- Pinned Godot version recorded.
- Clean editor/runtime validation.
- Existing movement/course tests made repeatable from the repository.
- Baseline telemetry for walk speed, opening ski speed, jet depletion, reset, and first gate.
- A short manual scenario recorded: descend, crest, jet, land.

Exit condition: refactor regressions can be detected without relying only on subjective play.

### M1 — Local command-driven movement refactor

Refactor `scripts/player.gd` without adding networking:

- Extract local input collection into a command source.
- Extract movement stepping and correction-relevant state from presentation.
- Add `capture_state()` and `restore_state()` boundaries.
- Preserve current mouse look and HUD behavior.
- Keep one local client behaving like the existing build.

Suggested conceptual boundaries, subject to implementation findings:

- `player_command.gd`: command value/serialization semantics.
- `player_input.gd`: local input and view intent.
- `player_motor.gd`: CharacterBody movement step and state capture/restore.
- `player.gd`: orchestration and signals.
- `player_presentation.gd`: optional later extraction for render smoothing/FOV.

Do not force a Resource/Node/class split merely to match these filenames. Prefer the smallest clear seam.

Exit condition:

- No movement method reads `Input` directly.
- Existing automated values remain within declared tolerance.
- Spawn/reset restores complete movement state.
- A recorded command sequence can be replayed locally with explainable results.

### M2 — Short movement/readability calibration

Before judging network corrections against the movement model:

- Improve terrain value/slope readability enough to follow representative lines.
- Test a restrained speed-dependent steering curve.
- Test lateral airborne jet acceleration without directly rotating velocity.
- Decide on one provisional movement profile for the network spike.

This is not final balance. Time-box it to one or two human playtest iterations. Record all tuning values so later comparisons use the same profile.

Exit condition: the owner is willing to attempt the opening descent, a turn, crest, jet, and landing repeatedly.

### M3 — Headless server and two clients

Build the minimum topology:

- One server process starts without rendering/audio dependencies.
- Two client processes connect over loopback/LAN ENet.
- Server assigns player identity and spawn.
- Server receives bounded commands and runs authoritative movement at 60 Hz.
- Clients receive snapshots containing their acknowledged command sequence.
- Disconnect and process shutdown do not corrupt the scene.

Use direct connection configuration. No server browser or account system.

Exit condition: both clients can move, and the server—not either client—determines their authoritative transforms.

### M4 — Prediction, reconciliation, and remote interpolation

Preferred first path:

- Evaluate the current compatible netfox release as scaffolding.
- Use its network-time/simulation facilities and latency simulator where they reduce work.
- Follow documented CharacterBody transform, physics-factor, and floor-refresh caveats exactly for the pinned versions.
- Keep SKOOSH command/state semantics behind a small adapter.

Required behavior:

- Local input feels immediate.
- Snapshot acknowledgment retires processed commands.
- Client restores authoritative state and replays remaining commands.
- Render smoothing hides small correction while simulation stays authoritative.
- Remote skiers interpolate from buffered snapshots.

Fallback rule:

Switch to a minimal custom command/snapshot layer only after recording a specific netfox blocker, such as unbounded rollback scope, unworkable CharacterBody integration, or opaque correction behavior. Do not maintain both implementations.

Exit condition: representative skiing works at zero latency before impairment testing.

### M5 — Network impairment and instrumentation

Add configurable:

- 0, 80, 120, and optionally 180 ms round-trip latency.
- Jitter.
- 1–3% packet loss.
- Packet duplication and reordering if supported cleanly.

Measure:

- Correction distance distribution.
- Corrections per second.
- Hard snaps over the selected threshold.
- Commands replayed per reconciliation.
- Client replay CPU time.
- Client/server velocity difference.
- Jet-energy difference.
- Grounded-state and floor-normal disagreement.
- Server physics tick time.
- Snapshot bytes per client and aggregate bandwidth.

Each large correction should log enough context to answer:

- Which command/tick was acknowledged?
- Were client and server grounded?
- What were position and velocity before/after replay?
- Was this a slope transition, crest, landing, jet depletion, reset, or unexplained event?

Exit condition: results can be reviewed without relying solely on visual impressions.

### M6 — Scale and decision report

Run one authoritative server with synthetic or scripted command sources for 8 and 16 players. Synthetic players need only exercise collision/movement; they are not gameplay bots.

Test scenarios:

1. Walking and stopping on a slope.
2. Opening ski descent.
3. Sharp steering input at 25, 40, and 60 m/s.
4. Crest launch with air steering.
5. Jet burn through depletion/recharge delay.
6. High-speed downhill landing with momentum transfer.
7. Two players crossing at 40–50 m/s.
8. Reset/out-of-bounds recovery.
9. A short packet-loss burst during landing.

Produce a stay/switch/extend recommendation with raw logs and known caveats.

## 7. Provisional success criteria

These are starting thresholds to calibrate, not promises of perceptual quality.

At approximately 120 ms round-trip latency and 2% loss:

- Median local correction below roughly 0.3 m.
- 95th percentile below roughly 1.0 m in ordinary traversal.
- Corrections above 2 m uncommon—target fewer than one per normal minute.
- Grounded-state disagreement below roughly 2% of representative ticks.
- No routine energy or movement-mode divergence.
- Remote skier visually trackable at 40–50 m/s.
- Server tick comfortably within the 16.67 ms budget at 16 simulated players; target below 8 ms on the selected reference machine.
- Client reconciliation/replay does not create visible frame stalls.
- A developer can explain correction outliers from instrumentation.

A scenario may need its own threshold. Landing contact transitions are expected to be harder than open-air movement.

## 8. Failure triage

If corrections are excessive, investigate in this order:

1. Command sequencing, acknowledgment, and fixed-tick alignment.
2. Missing captured/restored movement state.
3. `move_and_slide()` delta handling during replay.
4. Floor-state refresh and CharacterBody transform synchronization.
5. Different terrain/collision versions or spawn transforms.
6. Input/view quantization or command-loss behavior.
7. Contact-order and physics-engine divergence.
8. Visual smoothing incorrectly mistaken for simulation error.
9. Need for a custom kinematic sweep/slide motor.

Do not jump directly to another engine before separating architecture bugs from engine limitations.

## 9. Go/no-go decision

### Continue with Godot

Continue if:

- The movement seam remains understandable.
- Ordinary corrections meet or approach the calibrated thresholds.
- Outliers are explainable and fixable.
- CharacterBody workarounds are localized rather than scattered.
- Server/client performance has comfortable initial headroom.
- The owner still finds the workflow approachable.

### Extend the Godot spike

Allow one narrow extension if evidence points to a contained fix:

- Replace only the movement hot path with typed/native code.
- Replace `move_and_slide()` with a custom kinematic motor.
- Replace netfox with a minimal custom adapter after a documented blocker.

Set a second deadline and test the same scenarios. Do not allow indefinite framework construction.

### Trigger an alternative-engine spike

Escalate only if:

- Representative contacts routinely produce multi-meter corrections after correct replay/state handling.
- The required CharacterBody workaround is broad and fragile.
- A custom motor is estimated to exceed the cost of a port.
- Server performance fails after narrow optimization.
- Networking makes the Godot workflow unreasonably opaque.

If triggered, test one runner-up—not both. Start with Unity/FishNet for approachability unless the failure specifically demands Unreal's movement/server facilities.

## 10. Sequence after a successful spike

Do not jump directly from the spike to complete CTF.

1. Harden the movement API and network diagnostics.
2. Finish terrain readability and steering/jet feel iterations.
3. Deploy one direct-IP Linux server for external latency testing.
4. Add health, death, and server-authoritative respawn.
5. Add one server-authoritative projectile/splash weapon.
6. Add one hitscan weapon and target-history lag compensation.
7. Build a deliberately authored two-base competitive map.
8. Add teams, flags, CTF state, score, and objective HUD.
9. Add join/leave handling and basic server administration.
10. Add authentication, discovery, matchmaking, fleet management, and moderation only as actual usage requires.

## 11. Open decisions after the pause

These do not block documenting the plan but must be answered during execution:

- Which pinned Godot stable version and physics backend?
- Which exact netfox release/commit, if adopted?
- Is 12 or 16 the initial maximum-player target?
- Does lateral jetting share the existing energy pool?
- What steering curve is the provisional network-test profile?
- Is `CharacterBody3D` retained or replaced after measurements?
- Are public servers developer-hosted only initially?
- Is Steam integration part of the first public test or later?

## 12. Definition of done

The spike is done when the repository contains:

- A playable command-driven local movement implementation.
- A headless authoritative server launch path.
- Two-client local launch tooling.
- Prediction/reconciliation and remote interpolation.
- Network impairment controls.
- Repeatable scenarios and metric collection.
- A captured result set.
- A written decision to continue Godot, extend one narrow experiment, or test one alternative.

Anything beyond this belongs to the next product iteration.
