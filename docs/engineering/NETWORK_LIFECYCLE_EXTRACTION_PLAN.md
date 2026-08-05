# Network lifecycle extraction plan

## Goal

Decompose world construction, avatar membership, admission, and map rotation
without changing the persistent-session/disposable-world protocol documented in
[the map rotation handoff](MAP_ROTATION_HANDOFF.md).

This is the highest-risk maintainability work. It starts only after acceptance
and match rules have owners outside `scripts/network_main.gd`.

**Total size:** XL. It is four projects, not one patch.

## Protocol constraints

Keep all of the following stable throughout this plan:

- `/root/NetworkDemo` and root RPC paths.
- `/root/NetworkDemo/ReplicatedGameState/GameStateSynchronizer`.
- `World_N/Players/Player_<peer_id>`, `Projectiles`, and `Effects` paths.
- RPC annotations, names, reliability, authority, and argument order.
- Serialized admission and immutable transition peer snapshots.
- Map-definition hash validation.
- Gameplay visibility barriers for unadmitted or unready peers.
- Reliable rollback baselines and the final activation baseline.
- Immediate collision/visibility retirement plus bounded world tombstones.
- Stable team and character assignments across generations.

Root RPC methods remain wrappers even after controllers own their state. Do not
move them to controller child nodes as part of this plan.

## Project 1: world builder

**Size:** M

Move deterministic disposable-world construction behind one explicit builder.
Candidate functions are `_adopt_initial_world`, `_configure_map`,
`_configure_environment`, `_rebuild_world`, `_retire_world`,
`_validate_and_log_world`, and world-contract spawn helpers.

The builder should return one typed world result containing the current:

- World root and generation.
- Terrain and map ID/configuration reference.
- Arena platforms and flags.
- Landmarks.
- Players, projectiles, and effects containers.
- Team homes and platform elevations.

The root swaps one result rather than rebinding many unrelated fields. Map
catalog data may remain a `Dictionary`; the world result itself should be typed.

Split this project if needed:

1. Construct and validate `World_N` through a root wrapper.
2. Move initial-world adoption and retirement/tombstone ownership.

Verify:

```bash
./tools/run_headless_tests.sh competitive-maps rotation-lifecycle network-bootstrap oob-recovery
```

Run `map-rotation` before accepting any change to names, retirement, or rebuild
ordering.

## Project 2: avatar registry and visibility

**Size:** M

Give peer assignments and active avatar membership one owner. Candidate
functions are `_spawn_avatar`, `_remove_avatar`, balanced team/character
assignment, `_approved_peer_ids`, and avatar/game-state visibility helpers.

The registry owns:

- Typed peer-to-avatar, team, and character-variant maps.
- Stable assignment restoration.
- Spawn/remove and retirement teardown.
- Gameplay admission membership.
- Avatar and replicated-state visibility operations.

The registry receives the active world result and `player_scene`; it does not
choose maps, run admission deadlines, or initiate rotation.

Preserve player scene paths, authority assignments, rollback property lists,
and `retire_for_rotation()` callback teardown.

Verify:

```bash
./tools/run_headless_tests.sh character-variants rotation-lifecycle network-bootstrap map-rotation
```

## Project 3: admission controller

**Size:** L, split into at least two green packets.

Move the serialized join protocol behind unchanged root RPC wrappers. The
controller owns queue, map agreement, bootstrap/avatar-path acknowledgements,
rollback baseline readiness, deadline, rejection, and final admission state.

Packet A owns state and local transitions:

- Admission queue and active peer.
- Agreement deadline and map/hash decision.
- Pending bootstrap and avatar-observer sets.
- Synchronous timeout/mismatch cleanup.

Packet B owns baseline and visibility orchestration:

- Provisional avatar creation requests through the registry.
- Existing-observer path confirmation.
- Reliable baseline application/acknowledgement.
- Final visibility opening and admission completion.

Keep these root RPC wrappers and signatures stable:

- `_offer_server_map`
- `_report_client_map`
- `_approve_map_peer`
- `_confirm_map_bootstrap`
- `_confirm_avatar_path`
- `_apply_rollback_baseline`
- `_ack_admission_baseline`
- `_admit_peer`

The controller should expose explicit typed state transitions rather than one
large context dictionary. RPC payloads can remain serialization-friendly
arguments at the wrapper boundary.

Verify each packet with:

```bash
./tools/run_headless_tests.sh network-bootstrap map-mismatch rotation-lifecycle
```

Before accepting the project:

```bash
./tools/run_headless_tests.sh rotation-ready-timeout rotation-prepare-disconnect map-rotation
```

## Project 4: rotation controller

**Size:** L, split into at least two green packets.

This project moves the `ACTIVE -> PREPARING -> COMMITTING ->
WAITING_FOR_READY -> ACTIVE` implementation last.

Packet A owns prepare/commit state:

- Immutable transition generation, map, hash, peer IDs, and assignments.
- Prepare acknowledgements and absolute deadline.
- Disconnect removal from the barrier.
- Commit decision and world-builder/registry requests.

Packet B owns build/ready/activate state:

- Built and baseline-ready acknowledgements.
- Immutable ready deadline.
- Disconnect flush.
- Initial and final rollback baselines.
- Activation and one-second rollback warmup.

Keep these root RPC wrappers and signatures stable:

- `_prepare_world`
- `_ack_world_prepared`
- `_commit_world`
- `_ack_world_built`
- `_ack_world_ready`
- `_activate_world`

The controller coordinates the world builder, avatar registry, admission
controller, and match reset through narrow methods. It must not reconstruct
terrain, mutate CTF rules, or inspect acceptance counters.

Verify each packet with:

```bash
./tools/run_headless_tests.sh map-rotation rotation-ready-timeout rotation-prepare-disconnect rotation-lifecycle
```

Then run:

```bash
SKOOSH_TEST_JOBS=1 ./tools/run_headless_tests.sh all
```

## Failure injection gate

Before adding more transition features, extend characterization for:

- Admitted-peer departure during each admission subphase.
- Delayed current- and previous-generation acknowledgements.
- Ready timeout after a successful build acknowledgement.
- Disconnect during preparation and during disconnect flush.
- Retired-world packets resolving only against inert tombstones.

This does not need to block Project 1. It should be in place before Project 3
or 4 changes protocol-state ownership.

## Follow-on gameplay context

Players and weapons currently discover the root by ancestor walking and use a
wide implicit contract containing generation, admission, avatar lookup,
projectile/effect containers, match activity, combat callbacks, bots, voice, and
acceptance hooks.

After lifecycle extraction, introduce a narrow typed gameplay context for the
authoritative subset:

- Active generation and world membership.
- Admitted peer lookup and gameplay peer IDs.
- Avatar lookup/iteration needed for server damage.
- Projectile and effect containers.
- Match-active and respawn operations.
- Combat event recording as an optional observer, not an authority decision.

Migrate projectile and weapon validation first, then player respawn. HUD,
visual QA, bots, and optional presentation hooks can follow separately. Do not
make the context expose every controller or recreate the old root API under a
new name.

## Done state

- The root composes lifecycle owners and retains stable RPC forwarding.
- One typed world result replaces scattered active-world node references.
- Peer assignment, avatar membership, and visibility have one owner.
- Admission and rotation have separate explicit state machines.
- Match and acceptance code do not participate in lifecycle protocol details.
- All static-map, join, mismatch, timeout, disconnect, rotation, OOB, combat,
  and movement checks remain green.
