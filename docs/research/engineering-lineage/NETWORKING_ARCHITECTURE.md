# Networking architecture context

**Status:** Durable research context. Not an active implementation roadmap.

Read [`README.md`](README.md) for document authority and the GPL clean-room boundary.
Read [`../../CHECKPOINT.md`](../../CHECKPOINT.md) for current implementation
status.

## Conditional architecture recommendation

The current implementation uses this stack, and the lineage research recommends
continuing with it. This is not an unconditional framework commitment: the checkpoint
and measured impairment/scale results decide whether netfox remains suitable.

Keep the current stack:

| Layer | Responsibility |
|---|---|
| ENet | Peer transport, channels, reliable ordering, fragmentation, RTT/loss behavior, and unreliable throttling. |
| Godot high-level multiplayer | Peer lifecycle, authority, RPC dispatch, and scene integration. |
| netfox | Shared ticks, owner input history, prediction/reconciliation, and interpolation. |
| SKOOSH application layer | Gameplay validation and, when scale requires it, per-client interest, priority, and snapshot budgets. |

Do not replace this with `PacketPeerUDP` unless an application-level scheduler and compact
snapshot path already exist and profiling identifies a transport-specific blocker. Raw
UDP would otherwise require rebuilding reliability, ordering, fragmentation, congestion
response, connection lifecycle, and netfox integration without improving gameplay
relevance.

ENet is not a security layer. Authentication/admission, confidentiality/integrity when
required, malformed-payload validation, rate limits, and anti-cheat remain separate
requirements.

## The durable lineage lessons

### Current state is not an event

Use replaceable snapshots for state where only the newest value matters:

- Position and velocity.
- Aim and pose.
- Energy and other continuously changing values.
- Remote projectile presentation when a newer sample supersedes an older one.

Use events for occurrences that must not vanish when a newer state arrives:

- Accepted fire, impact, death, pickup, capture, and round transition.
- Inventory or future seat/mount transactions.
- VGS/chat dispatch.

Choose reliability and ordering per event family. Do not put every message on one
reliable ordered stream, and do not use snapshot convergence for transactions.

### Interest and priority are different

Interest answers whether an entity is relevant enough to consider for a peer. Priority
answers which relevant entity gets bytes first when the packet budget is short.

A scalable server path should eventually:

1. Generate candidates from a spatial index plus gameplay exceptions.
2. Score candidates per client by threat, objective role, distance/time to approach,
   recent interaction, visibility, and age since last update.
3. Increase age so low-priority actors cannot starve forever.
4. Fill a per-client application budget from highest value downward.
5. Leave skipped state pending rather than sending every visible actor and relying on
   ENet to drop arbitrary packets.

Binary visibility filters are still useful as a hard gate. They are not a replacement
for graded priority during a clustered base fight.

### Loss should not resurrect obsolete state

If a lost snapshot has already been superseded by a newer sample for the same state,
do not retransmit the old value. Reliable convergence means the client reaches current
truth; it does not mean every intermediate transform arrives.

Reliable events have the opposite requirement: retry the occurrence, deduplicate it,
and preserve ordering only where gameplay needs it.

### Creation and baselines are explicit lifecycle states

A newly relevant actor needs a full baseline before deltas. An actor becoming dormant
or irrelevant needs a clear policy for proxy retention and eventual removal. Relevance
changes must not produce deltas against missing state.

Keep player presentation proxies alive while merely changing update tiers. Frequent
scene spawn/despawn would churn interpolation and rollback history. Reserve actual
despawn for lifecycle changes or numerous world entities that are genuinely absent.

## Dated project observations

The following observations describe the source as inspected on 2026-08-03. They are not
a status record; verify them against current code and `docs/CHECKPOINT.md` before acting.

As inspected during the lineage pass:

- Player simulation state is server-owned and player input is owner-authoritative at the
  input child (`scenes/network_player.tscn`, `scripts/network_player.gd`).
- netfox rollback currently broadcasts each player's input to all visible peers. Its own
  API supports server-only input, and production scaling should remove this raw-input
  all-peer component.
- Disabling input broadcast does not solve all-to-all state replication by itself.
  Remote movement state also needs scoping or replacement by a remote snapshot path.
- Built-in `MultiplayerSynchronizer` already carries cold player metadata and global
  match/flag state. That is an appropriate use; do not force all hot movement through
  per-property scene replication at 64 players.
- Avatar and projectile lifecycle is manually mirrored rather than owned by
  `MultiplayerSpawner`. This works for the current prototype but needs explicit late-join
  and baseline treatment before large dynamic worlds.
- Impact presentation and some reliable workflows currently broadcast globally. Apply
  interest targeting before projectile-heavy scale tests.
- Skoosh configures ENet and range compression but was not observed configuring a
  `SceneMultiplayer` authentication callback or DTLS policy. Record an explicit admission
  and transport-security decision before treating public hosting as hardened.

Verify these observations against current source before acting; `docs/CHECKPOINT.md`
owns status. In particular, the project requests input redundancy of three, but vendored
netfox 1.35.3's redundant-history encoder was observed using its default four samples.
Treat that as a current integration issue, not a permanent architecture fact.

## Conditional remote snapshot proposal

**Not implemented or adopted.** Use this boundary only if measurements justify replacing
all-peer remote movement replication. If approved, move execution steps into the owning
engineering roadmap and update the checkpoint.

Do not add custom snapshots alongside unchanged netfox remote movement replication. That
would duplicate traffic and produce competing presentation authorities.

The intended migration is:

1. Keep netfox owner input and authoritative correction between each client and server.
2. Keep authoritative simulation roots on the server.
3. Stop sending each server-owned transform/velocity rollback stream to every remote
   peer through netfox.
4. Send one bounded, versioned, unreliable-ordered actor batch to each peer on an explicit
   channel.
5. Apply batches to persistent remote presentation proxies with interpolation.
6. Send a full baseline on first relevance and after any baseline invalidation.
7. Keep cold metadata and global objective truth on the simpler built-in synchronizers.

Godot's `SceneMultiplayer.send_bytes()` can retain the existing ENet connection while
carrying a packed application batch. If used, specify a target peer, unreliable-ordered
mode, an explicit channel, and strict decoder bounds; its default mode should not be
assumed. A stable RPC receiver is also acceptable if measurements show its framing and
dispatch cost are small.

Start with a simple versioned byte format. Quantize only fields shown by measurement to
matter. Do not begin with a general bitstream, entropy coding, or a historical ghost-ID
scheme.

## Scale policy hypotheses

The following are starting hypotheses for experiments, not accepted product constants:

- A coarse spatial grid updated less often than the 60 Hz movement tick.
- Near/critical/far/dormant update tiers with hysteresis and velocity-based prefetch.
- Per-client snapshot payloads kept below measured fragmentation thresholds.
- An application bandwidth budget that leaves room for owner corrections and reliable
  gameplay events.
- Projectile relevance based on nearby distance and predicted path, not source distance
  alone.
- Global flag status and carrier identity, with carrier transform precision controlled
  by final sensor/radar rules.

The full numeric proposals and their assumptions remain in the external notebook. Adopt
numbers only after representative 8/16/32/64-client traces and playtests.

## Evidence required before lower-level networking

Investigate lower-level ENet or another transport only after batching and prioritization
if measurements show one of these:

- High-level scene/RPC dispatch remains a material part of the 60 Hz server tick.
- Framing is a material fraction of actual egress.
- Critical nearby state cannot meet its age target inside a reasonable client budget.
- ENet ordering/throttle behavior demonstrably conflicts with the application policy.
- A non-Godot dedicated server or stable public protocol becomes a firm requirement.

Until then, custom UDP is risk without evidence.

## Research validation gates

These are evidence requirements, not current task ordering. The owning engineering
roadmap decides when to run them.

Before claiming 32-64-player readiness, measure:

- Per-peer and aggregate bytes/packets by traffic family.
- RTT, packet loss, and newest-state age by relevance tier.
- Correction distance/frequency, input age, and replay depth.
- Server p50/p95/p99 tick cost and rollback work.
- Snapshot encoding/dispatch cost and baseline size.
- Clustered base-fight behavior, not only uniform player placement.
- Late join with active players, projectiles, flags, and round state.

Compare current all-visible behavior, server-only input, binary visibility, and prioritized
snapshot scheduling separately so each optimization's value is visible.

Current immediate execution remains in
[`../../engineering/COMBAT_NETWORKING_ROADMAP.md`](../../engineering/COMBAT_NETWORKING_ROADMAP.md).
