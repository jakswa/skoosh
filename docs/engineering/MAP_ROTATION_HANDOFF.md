# Authoritative map rotation

## Status

Automatic production rotation is implemented. A dedicated server starting on
Faultline Basin rotates to Cairn Steps after a score-limit match, then back to
Faultline after the next match. `--map=faultline_basin` and
`--map=cairn_steps` select the initial point in that rotation.

Kestrel Basin remains the explicit legacy/test single-map opt-out because it is
not a production rotation member. `--require-map-baseline` also suppresses
rotation for the static-map acceptance fixture only. A client without `--map`
follows the server's current production generation; an explicit client map is
an exact startup assertion.

## World seam

`NetworkDemo` remains alive for the ENet peer, lobby, `NetworkTime`, connection
handlers, and match director. Replicated match state lives on a dedicated
persistent child so its visibility can close without hiding root protocol RPCs.
Disposable gameplay state is rebuilt under monotonically named `World_N`
children:

- Deterministic terrain render mesh and trimesh collider.
- Platforms, flags, landmarks, curved OOB data, and map presentation.
- `Players`, `Projectiles`, and `Effects` containers.
- Fresh avatars, rollback histories, interpolators, and generation-qualified
  RPC paths.

Team and character assignments live at the persistent root and are restored in
stable peer-ID order. The active world supplies map bounds, terrain queries,
objective homes, spawn transforms, bot routes, and transient containers.
Objective homes, platform elevations, and spawn transforms are
generation-scoped. They are rebound from the new world before match reset,
avatar spawn, respawn, bots, or acceptance contacts can use them; no retired
world coordinate is an implicit persistent-session value.

Retired worlds become invisible and collisionless immediately. Their netfox
rollback/interpolation processing is deactivated, but their paths remain as
inert tombstones for ten seconds so delayed reliable packets resolve against an
old generation rather than a newly reused path. Generation checks reject that
traffic. The tombstone and netfox input-submission state are then freed.

## Compatibility

`SkooshMapCatalog.get_definition_hash()` computes a SHA-256 digest over the
complete map definition and explicit revisions for:

- Map-bootstrap protocol.
- Deterministic terrain generation.
- Landmark generation.
- Disposable-world construction.

Clients compute their own digest. A same-ID incompatible build is disconnected
before any avatar is created. Changes to those systems that are not represented
in map data must bump the corresponding revision in `scripts/map_catalog.gd`.

## Admission

Admission is isolated from active gameplay and serialized by the server. A
connection attempt never pauses the match or clears live projectiles/effects.

1. New peers enter a queue. Admission begins only while the world is `ACTIVE`;
   joins during preparation, commit, or readiness wait for the next active
   generation.
2. The server offers generation, map ID, definition hash, and the immutable
   admitted-peer snapshot. The client has five seconds to report compatibility
   before construction starts; an accepted report starts a separate eight-second
   deadline for world bootstrap, avatar-path confirmation, and rollback baseline
   readiness.
3. The joining client builds the offered generation and creates the advertised
   avatar paths. Existing peers create the joining avatar while all gameplay
   replication to and from that peer remains hidden. Provisional avatars are
   collisionless and authoritative rollback, damage, targeting, objectives, and
   voice ignore them.
4. The server sends a reliable authoritative rollback state baseline for every
   current avatar. Only after the client applies it and all existing observers
   acknowledge the new avatar path does the server mark the peer admitted.
5. Input, combat, voice, objectives, rollback state, projectile accepts, and
   root match state all exclude unadmitted peers. Concurrent joins cannot form
   different peer snapshots because only one admission is active at a time.

If a match ends during an active admission, that incomplete peer is disconnected
before the immutable transition peer set is captured. Queued peers remain
connected and bootstrap against the committed generation afterward.
An admitted-peer departure also terminates the one incomplete admission rather
than letting its immutable avatar snapshot drift. Timeout and mismatch rejection
clear admission state synchronously before transport teardown, so a late
acknowledgement cannot race the rejection.

If the joining peer or any already-admitted observer leaves during an incomplete
admission, the transaction is cancelled before its immutable avatar snapshot
can drift. Active admission, deadline, provisional avatar, bootstrap state,
pending observer paths, baseline readiness, and transaction assignments are
cleared synchronously before transport teardown. Late acknowledgements cannot
complete the cancelled transaction, and queued peers remain queued.

## Rotation protocol

The server owns `ACTIVE`, `PREPARING`, `COMMITTING`, and
`WAITING_FOR_READY`, plus map ID and monotonic generation.

1. A score-limit win freezes gameplay, snapshots admitted peer IDs, chooses the
   next production map, and sends generation/map/hash prepare data. The prepare
   barrier has a four-second deadline.
2. At the existing five-second intermission tick, non-acknowledging peers are
   disconnected and the server commits the remaining immutable peer set.
3. Every peer retires the old world, builds the new map, and recreates avatars
   in peer-ID order with server-preserved assignments.
4. Clients acknowledge path/world construction. The first build acknowledgement
   establishes a current-tick server rollback baseline; clients apply it and
   acknowledge readiness under one immutable eight-second ready deadline.
5. Missing peers are disconnected. After disconnect delivery is observed, or a
   bounded one-second flush expires, the server sends one final current-tick
   baseline immediately before the reliable activation message.
6. Match/objective state resets, its replicated generation is set to the active
   world generation, root state visibility resumes, and rollback/input resume
   after a one-second warmup.

The final baseline avoids a netfox history-window overflow when terrain
construction or a ready timeout advances synchronized time by more than the
128-tick rollback history.

Admission and rotation share baseline capture, server seeding, client
application, generation validation, and tick-identity mechanics. Their peer
barriers and acknowledgement decisions remain separate, so one transaction's
baseline can never satisfy the other. The lifecycle state machine remains the
only owner of global rollback enable/disable transitions.

`--require-map-baseline` suppresses rotation for its fixture and is distinct
from explicitly selecting legacy Kestrel. Both static paths still use the
active map's current objective-home and spawn binding for initial spawn, death,
OOB recovery, and new-match reset.

## Traffic boundaries

The following cross-transition traffic carries or validates generation and
rejects a mismatch:

- Projectile request, accept, decline, and impact presentation.
- Hitscan request and tracer/hit presentation.
- Grenade impact presentation.
- Voice request and delivery.
- Prepare, build, baseline-ready, commit, and activation messages.
- Replicated match/objective state carries `match_state_generation`; root
  replication is hidden during construction and the HUD suppresses state whose
  generation does not match the active world.

The generic netfox weapon proxy now delegates generation validation and RPC
target selection to `SkooshDiscLauncher`. Projectile accepts target admitted
gameplay peers rather than broadcasting to every ENet connection. This prevents
a queued join from receiving a `World_N/.../Weapon/Node` RPC before map approval
has created that path.

## Acceptance

- `tools/test_map_rotation.sh`: two connected peers complete
  `Faultline -> Cairn -> Faultline`; generation/map/hash/world signatures match
  on server and clients; peer IDs and assignments persist; acceptance bots and
  the authoritative contact seam prove fire, movement, and scoring still execute
  in all three generations; retired worlds are gone.
- `tools/test_network_bootstrap.sh`: an independently computed incompatible hash
  is rejected without an avatar; a default-map client joins a Cairn-first server
  under the exact generation-1 RPC path; and a default-map client joining during
  Cairn preparation is queued then admitted directly into generation 2 without
  ghost paths or preapproval gameplay RPCs.
- `tools/test_rotation_lifecycle.sh`: direct lifecycle contracts cover exact
  generation-1 replacement and reconnect paths, session-state reset, queued-peer
  departure isolation, synchronous timeout eviction, root-state visibility, and
  retired input callback teardown.
- `tools/test_rotation_ready_timeout.sh`: a client that builds but withholds its
  baseline-ready acknowledgement is disconnected within the bounded deadline;
  the remaining peer activates without rollback or packet errors.
- `tools/test_rotation_prepare_disconnect.sh`: a disconnect during preparation
  is removed from the immutable barrier and the remaining peer activates on
  Cairn.
- `tools/test_multiplayer_demo.sh`: the static-map fixture still proves the full
  authored route, score accumulation, score-limit win/reset, combat, movement,
  voice, and character variants without invoking rotation.

All of the above pass headlessly, along with `tools/test_ground_jet.sh`,
`tools/test_competitive_maps.sh`, `tools/test_map_mismatch.sh`, and
`tools/test_score_limit_cli.sh`.

## Remaining qualification

- Artificial latency, jitter, and loss across prepare/build/baseline/activation.
- Scale and bandwidth testing beyond two active clients plus one queued join.
- Deterministic stale-message injection for every transition/gameplay RPC and
  fault injection for admitted-peer departure during each admission subphase.
- Human playtesting of match pacing across repeated map changes.
- Operator tuning of the four-second prepare and eight-second readiness limits
  on minimum-spec server/client hardware.
