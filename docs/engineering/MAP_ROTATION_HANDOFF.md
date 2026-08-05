# Authoritative map rotation handoff

## Status

Automatic rotation is intentionally not implemented on
`feature/proper-maps-score-loop`. Faultline Basin and Cairn Steps are real map
definitions in this branch, but the live scene still has no disposable-world
boundary. A generation-based implementation completed the happy-path rotation
in a discarded spike, then independent review and fault injection found unsafe
admission, rollback-baseline, and timeout behavior. No partial rotation code was
retained.

The server-owned score-limit loop is complete and resets the current map after
intermission. Runtime rotation remains separate work.

## What was inspected

- `scenes/network_demo.tscn` owns one static terrain, arena, flags, players,
  projectiles, effects, root state synchronizer, lobby, and renderer profile.
- `scripts/network_main.gd::_configure_map()` caches static
  `@onready` terrain/platform/flag references and computes one set of homes and
  spawn transforms.
- `scripts/terrain.gd::generate()` is one-shot behind `_generated`; it creates
  both the render mesh and trimesh collider directly under the static terrain
  body. There is no teardown/reconfigure contract.
- `scripts/network_main.gd::_spawn_avatar()` independently creates the same
  named avatar on every peer. Each avatar owns rollback history and RPC paths.
- `RollbackSynchronizer::_exit_tree()` disconnects rollback signals, and the
  history transmitter frees its root's input-submission entry on predelete.
  This makes fresh avatar instances plausible, but there is no game-level
  generation barrier preventing old network messages from reaching reused
  node paths.
- `NetworkWeapon` retains predicted projectile IDs/data per avatar and uses
  reliable RPCs on the weapon node. `SkooshDiscLauncher` puts projectile nodes
  in the root `Projectiles` container, while impact RPCs put presentation in
  `Effects`. None of those requests, accepts, declines, or impacts carries a
  world generation.
- `NetworkEvents` starts/stops the shared network clock with the ENet peer. A
  whole-scene replacement would also replace the node that currently owns
  connection handlers and the root synchronizer; this branch has no tested
  persistent-session shell around it.

## Explored options

| Option | Result |
|---|---|
| Change or reload the main scene | Rejected. It couples ENet ownership, root RPC paths, netfox lifecycle, lobby, and world teardown without a peer-preservation handshake. |
| Mutate terrain configuration and move the existing bases | Rejected. The terrain generator is one-shot, landmarks are static scene children, and changing selected catalog data would not replace the complete world safely. |
| Rebuild selected children in place | Recommended after adding a disposable world seam and generation protocol. It can preserve the root node, ENet peer, `NetworkTime`, lobby, and replicated session state. |

## Discarded spike findings

The spike used generation-qualified worlds and bounded prepare/ready phases. It
proved that terrain, collision, objectives, avatars, and presentation can be
rebuilt while preserving ENet peer IDs, but it was not safe to merge:

- A connection attempt froze existing players and cleared authoritative
  projectiles before map/hash approval, allowing admission traffic to alter a
  live match.
- Hash report, world bootstrap, and avatar-path acknowledgement were separate
  waits. Only the first had a deadline, so a peer could freeze the match after
  reporting a valid hash.
- Concurrent joins could receive different expected-peer snapshots and then
  disagree permanently on the avatar set.
- Clients acknowledged world readiness before receiving an authoritative
  rollback transform/history baseline, producing stale post-rotation fire.
- Joins during prepare/commit could miss activation or target generation paths
  that did not exist locally.
- Admission visibility initially gated regular replication but not all rollback
  and projectile RPC traffic.

The follow-up must keep admission isolated from active gameplay. Do not solve
late join by globally pausing the match or deleting transient authoritative
state. Every post-report phase needs an immutable deadline and retry/bootstrap
semantics for peer-set changes.

## Recommended seam

Keep `NetworkDemo`, its ENet setup, connection handlers, match director, and
session synchronizer alive. Move all disposable state under a generation-named
container such as `World_7`:

- Terrain render mesh and collider.
- Arena collision, flags, platforms, and all landmarks.
- `Players`, `Projectiles`, and `Effects` containers.
- Map-specific environment presentation if the two maps differ there.

Use the existing `SkooshMapCatalog` definitions as inputs to a typed disposable
world builder. It must own or reference the full terrain/world scene, base and
flag transforms, team spawns, landmarks, objective bounds, and map-specific
out-of-bounds contract. Build a fresh world instance for every generation
instead of mutating `SkooshTerrain._generated`.

Split the current responsibilities at these points:

- `network_main.gd::_configure_compact_arena()` becomes world-definition
  application and validation.
- `_spawn_avatar()` and `_remove_avatar()` become generation-aware and target
  the current world's `Players` node.
- `get_team_spawn_transform()` reads validated transforms from the active map.
- `_physics_process()` reads map-owned bounds/terrain queries rather than the
  static `terrain` reference.
- `network_weapon.gd` and `hitscan_weapon.gd` resolve generation-owned
  projectile/effect containers and attach the generation to every gameplay or
  presentation RPC.

Use generation-qualified node paths until old traffic is outside every
relevant lifetime. Reusing `/NetworkDemo/Players/Player_2/...` immediately can
let a delayed reliable weapon RPC address a new avatar with the same path.

## Bounded protocol

Use explicit phases such as `ACTIVE`, `PREPARING`, `COMMITTING`, and
`WAITING_FOR_WORLD`. The server is the only phase/map/generation authority.

1. At match end, the server selects the other real map ID, increments a
   monotonic generation, freezes objective/combat requests, and sends a
   reliable prepare message containing generation, map ID, definition hash,
   and an absolute deadline.
2. Each client validates that map ID/hash, quiesces input, clears predicted
   projectiles/effects, and reliably acknowledges that exact generation.
   Stale generations are ignored; a skipped generation requests a fresh
   bootstrap instead of guessing.
3. The server tracks a finite set of currently connected peer IDs. Disconnects
   are removed from the barrier. A late join receives the current phase and
   generation bootstrap and is added to the pending set only with the same
   bounded deadline.
4. On all acknowledgements, or after disconnecting peers that miss the
   operator-defined timeout, the server sends a reliable commit with a future
   network tick. An unbounded wait is not acceptable.
5. At the commit tick every peer frees the old generation container, waits for
   deletion/physics flush, instantiates the target map under its generation
   name, and recreates one avatar per connected peer in stable peer-ID order.
   The server supplies preserved team and presentation assignments; gameplay
   state starts fresh.
6. Clients acknowledge world readiness with generation and definition hash.
   The server resumes `ACTIVE` only after the bounded readiness barrier. Peers
   that cannot build the agreed world are disconnected rather than allowed to
   simulate a different map.

Every fire request, projectile accept/decline/impact, voice or objective event
that can cross the transition must include the generation and reject a mismatch.
Match/objective replicated state must also carry generation so late snapshots
cannot overwrite the new world.

## Required acceptance

- Complete matches rotate `faultline_basin` to `cairn_steps` and back using the
  real map definitions.
- Connected ENet peer IDs and connection status are unchanged across at least
  two rotations; each peer has exactly one recreated avatar afterward.
- Server and all clients log the same generation, map ID, and definition hash.
- Old avatars, rollback synchronizers, input-submission entries, projectiles,
  effects, terrain mesh/collider RIDs, platforms, flags, and landmarks are gone.
- New collision samples, objective transforms, spawn transforms, and landmarks
  match the selected map on server and clients.
- A client joining during preparation reaches the committed generation; a
  disconnect cannot stall the barrier.
- Duplicate/stale prepare, acknowledgement, commit, fire, projectile, impact,
  and objective messages are ignored by generation.
- A non-acknowledging or map-mismatched peer is handled by a finite timeout and
  cannot keep the server between maps indefinitely.
- The full multiplayer acceptance still proves movement, combat, score-limit
  accumulation, intermission/reset, and no duplicate capture awards after each
  rebuild.
