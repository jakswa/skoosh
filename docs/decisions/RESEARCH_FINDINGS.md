# SKOOSH — Research Findings and Decision Record

**Status:** Historical pre-implementation decision record; the authoritative movement spike passed and the resulting multiplayer systems are now on `main`.
**Decision:** Stay with Godot, ENet, and an authoritative dedicated-server model.
**Confidence:** Moderate. Engine, transport, and hosting feasibility are well supported; impaired-network and scale qualification remain incomplete.

## Recommendation

Continue with Godot 4.4+ and native desktop clients. Use a Linux headless dedicated server and ENet/UDP. Build a command/snapshot architecture with:

- Server-authoritative movement, jets, weapons, damage, flags, and match state.
- Input-command prediction for the local player.
- State acknowledgment, restore, and replay for reconciliation.
- Snapshot interpolation for remote players.
- Separate unreliable traffic from reliable match events.
- Server-side history and target-hitbox rewind when hitscan combat is added.

Godot passes the practical engine and deployment gates. Unreal and Unity do not eliminate the game-specific skiing/jet prediction work, and both add enough workflow or ecosystem complexity that a port is not justified before Godot is tested directly.

At the time of this record, the next decision gate was a measured multiplayer
movement spike. That gate passed. Current networking gaps are tracked in
`docs/engineering/COMBAT_NETWORKING_ROADMAP.md` and the project checkpoint.

## Why Godot remains favored

- The project already iterates quickly in Godot.
- Native Windows/Linux clients and Linux headless servers are supported.
- ENet provides the transport characteristics needed for a small native multiplayer game.
- Godot is open, inspectable, free, automation-friendly, and understandable by a small team.
- Current terrain, scenes, movement behavior, HUD, and test work remain useful.
- Available Godot libraries such as netfox have the correct server-authoritative prediction shape and document CharacterBody rollback caveats.
- If GDScript becomes a measured hot path, typed GDScript, C#, GDExtension, or a custom movement solver are narrower escape hatches than changing engines.

## Why not switch now

### Unreal

Unreal has the strongest conventional shooter/server ecosystem, but custom momentum movement still requires advanced extension work. Mover/Network Prediction may help, yet introduce C++, source-build and toolchain weight, experimental or evolving APIs, and a substantially less approachable workflow. It relocates rather than removes the core custom-movement problem.

Unreal remains the runner-up if Godot cannot meet movement-correction or server-performance targets after practical escape hatches are tested.

### Unity

FishNet Prediction V2 is the strongest single Unity comparison identified. It is credible, but a port introduces Unity-version and networking-framework choices without eliminating custom movement prediction. C# is attractive, but framework fragmentation and migration cost outweigh that benefit at this stage.

### Smaller alternatives

Flax, Stride, Bevy, and similar candidates do not currently offer enough proven prediction/reconciliation advantage to offset smaller ecosystems or steeper language/tooling requirements.

## What the research establishes

High confidence:

- A native Godot client/headless-server topology is feasible.
- ENet is a suitable first transport.
- Perfect cross-machine determinism is not required for authoritative prediction and correction.
- Client commands, authoritative simulation, acknowledgment/replay, and remote interpolation are established architecture.
- The Tribes networking lineage used recognizably similar command, control-object, ghost/snapshot, delivery-tier, and interpolation concepts.
- Public hosting is not initially complicated: a small UDP-capable Linux VPS is sufficient after local testing.
- Accounts, matchmaking, orchestration, and managed hosting are not prerequisites for the first network test.

Still unproven:

- Whether SKOOSH's slope contact, crest launch, jets, and landing transfer produce acceptably small corrections.
- Whether `CharacterBody3D.move_and_slide()` remains practical during restore/replay.
- Whether a custom kinematic sweep/slide motor will be required.
- Whether netfox reduces complexity for this game or imposes too much generalized rollback behavior.
- Real server tick cost at 8–16 players.
- Whether the current movement is fun enough to preserve before network tuning.

## Important planning corrections

The research report is directionally strong, but implementation should retain these distinctions:

1. **Replayable is not necessarily pure.** A useful movement API accepts a command and fixed delta and exposes capture/restore state. Collision queries still depend on the physics world, so `simulate(state, command) -> state` may not be a mathematically pure function unless a custom solver is built.
2. **Replay behavior depends on the selected framework.** Clients restore/replay for reconciliation. Netfox also rewinds and resimulates authoritative state when late client inputs arrive, so its server rollback cost must be measured rather than excluded from the budget.
3. **Do not trust or validate a client-supplied position against tolerance.** The normal client sends bounded commands, while the server computes position, velocity, energy, and contact state itself. Client transform reports are diagnostic at most.
4. **Hitscan rewind does not require rewinding the entire world.** Preserve historical target hitbox transforms, rewind query representations temporarily, trace authoritatively, then restore.
5. **Do not build netfox and a hand-rolled stack in parallel during the first time-box.** Select one implementation path for the spike, keep game-facing boundaries replaceable, and use the second only if a recorded blocker justifies it.
6. **Do not optimize packet packing or fleet hosting before movement correctness.** Dictionaries/RPC scaffolding may be acceptable in a disposable local spike; production encoding follows measurements.
7. **Visual smoothing must not mutate collision state.** Keep simulation and presentation transforms separate once reconciliation exists.

## Tribes lessons to carry forward

Worth preserving:

- Server-authoritative player control with local prediction.
- Recent-input redundancy rather than relying on reliable delivery for every move.
- Distinct delivery classes for input, latest-state snapshots, and reliable events.
- Relevancy/scoping when player/entity scale warrants it.
- Delayed interpolation for remote actors.
- Terrain and maps authored around readable ski lines.
- Weapons designed around velocity, inheritance, splash, and interception.

Do not inherit blindly:

- Historical low tick rates imposed by dial-up bandwidth.
- Extreme bandwidth compression before profiling.
- 128-player design assumptions.
- Accidental movement behavior merely because it existed in Tribes.
- Full movement-window retransmission strategies that can amplify congestion.

## Architecture boundary to build next

The current `scripts/player.gd` combines:

- Local input and mouse look.
- Movement simulation.
- CharacterBody collision response.
- Presentation/FOV.
- Telemetry and reset behavior.

Before adding weapons, split responsibilities conceptually into:

- **Command source:** gathers local input or receives network commands.
- **Movement motor:** advances a body from one command at a fixed tick.
- **Movement state:** captures/restores all state needed for correction.
- **Network driver:** sends commands, applies snapshots, and triggers replay.
- **Presentation:** camera, FOV, effects, and render smoothing.

The first refactor must preserve current local behavior before networking is introduced.

## Decision matrix

| Criterion | Weight | Godot + netfox/custom | Unreal + Mover | Unity + FishNet |
|---|---:|---:|---:|---:|
| Custom movement prediction | 30% | 4/5 | 4/5 | 4/5 |
| Iteration and approachability | 20% | 5/5 | 2/5 | 3/5 |
| Dedicated server maturity | 15% | 4/5 | 5/5 | 4/5 |
| Shooter networking facilities | 15% | 3/5 | 4/5 | 4/5 |
| Debugging/testing tooling | 10% | 3/5 | 4/5 | 4/5 |
| Licensing/operating cost | 5% | 5/5 | 3/5 | 3/5 |
| Rendering/content workflow | 5% | 3/5 | 5/5 | 4/5 |
| **Weighted score** | | **4.00** | **3.55** | **3.75** |

The scores do not prove Godot prediction quality. They justify testing the favored, lower-friction stack before paying migration cost.

## Source trail to retain

The detailed research identified these primary source families for implementation review:

- Current Godot documentation for dedicated-server export and ENet APIs.
- Godot engine issues/source concerning `CharacterBody3D.move_and_slide()` delta and floor-state behavior.
- netfox documentation for NetworkTime, RollbackSynchronizer, authoritative-server ownership, CharacterBody caveats, and network simulation.
- Godot Jolt documentation concerning determinism limitations.
- Frohnmayer and Gift, *The TRIBES Engine Networking Model* (1998).
- Valve/Source lag-compensation documentation for target history and rewind.
- Current Unreal Mover/Network Prediction and dedicated-server documentation.
- Current FishNet Prediction V2 documentation and examples.

Before depending on an exact API, workaround, price, or engine-version claim, verify it against the version selected for the spike.

## Decision trigger

Stay with Godot if the spike demonstrates:

- A clean command-driven local movement seam.
- Explainable and acceptably small corrections through representative terrain contacts.
- Smooth remote players at skiing speed.
- Comfortable server tick cost at the initial player target.
- A networking implementation the project owner can inspect and reason about.

Escalate to a narrow alternative-engine spike only if:

- CharacterBody replay remains fragile after documented workarounds.
- A custom Godot kinematic motor is judged more expensive than a port.
- Server performance misses target after narrow optimization escape hatches.
- Corrections routinely break movement feel under ordinary latency.

See `docs/archive/MULTIPLAYER_SPIKE.md` for the original execution plan.
