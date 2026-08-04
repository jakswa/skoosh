# Authoritative map rotation handoff

## Status

Automatic rotation is intentionally not implemented on `feature/match-loop`.
Neither `faultline_basin` nor `cairn_steps` exists in this branch, and the live
world has no map-definition or disposable-world boundary. A string or terrain
seed toggle would not exercise the requested maps or prove safe ENet peer
preservation, so no partial rotation code was retained.

The authoritative score-limit match loop is independent of this work and is
intended to rebase onto the branch that introduces the real maps.

## What was inspected

- `scenes/network_demo.tscn` owns one static terrain, arena, flags, players,
  projectiles, effects, root state synchronizer, lobby, and renderer profile.
- `scripts/network_main.gd::_configure_compact_arena()` caches static
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
| Mutate terrain seed and move the existing bases | Rejected. The terrain generator is one-shot, landmarks are static scene children, no real target map definitions exist, and this would be fake rotation. |
| Rebuild selected children in place | Recommended after adding a disposable world seam and generation protocol. It can preserve the root node, ENet peer, `NetworkTime`, lobby, and replicated session state. |

## Recommended seam

Keep `NetworkDemo`, its ENet setup, connection handlers, match director, and
session synchronizer alive. Move all disposable state under a generation-named
container such as `World_7`:

- Terrain render mesh and collider.
- Arena collision, flags, platforms, and all landmarks.
- `Players`, `Projectiles`, and `Effects` containers.
- Map-specific environment presentation if the two maps differ there.

Introduce a typed map definition/resource keyed by the real IDs. It must own or
reference the full terrain/world scene, base and flag transforms, team spawns,
landmarks, objective bounds, and any map-specific out-of-bounds contract. Build
a fresh world instance for every generation instead of mutating
`SkooshTerrain._generated`.

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
