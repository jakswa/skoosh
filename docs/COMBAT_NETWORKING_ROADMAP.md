# SKOOSH combat networking roadmap

## Current contract

The dedicated server owns health, death, respawn, teams, flags, score, and round state. A client may request a pulse-rifle shot only for its own avatar. The server independently enforces death/round state and cooldown, reconstructs its current muzzle ray, rejects requests more than 2 m from the server muzzle or more than 18 degrees from server aim, performs the accepted ray against the server collision world, rejects friendly fire, and applies damage.

The current player collision capsule is also the current hitbox. The more detailed armor model is presentation only.

This is sufficient for the local vertical slice, but it is not finished Internet-grade hit registration. In particular, shooting evaluates current server transforms rather than historical transforms from the client's fire tick.

## Next implementation stages

### 1. Measure movement under impairment

- Add repeatable latency, jitter, reordering, and packet-loss scenarios.
- Record correction distance, correction frequency, floor/contact disagreement, rollback depth, and input age.
- Verify skiing, ground-jet pops, crest launches, impacts, and respawns before expanding combat.

### 2. Define a historical hitbox record

- Record one compact authoritative capsule/head state per alive player per network tick.
- Retain only a bounded window matching the maximum compensated latency.
- Clear or mark discontinuities on death, respawn, and authoritative teleport.
- Keep historical hitboxes separate from presentation meshes and live physics transforms.

### 3. Add bounded server rewind

- Include the input/fire tick in validated shot requests.
- Clamp accepted fire age and reject future, stale, duplicate, or impossible requests.
- Evaluate the server-approved ray against historical capsule/head geometry at the accepted tick.
- Prefer analytic ray/capsule tests or a dedicated query structure over mutating the live physics world.
- Preserve server-owned cadence, team rules, damage, and kill credit.

### 4. Validate high-speed edge cases

- Test crossing targets, crest launches, carrier chases, point-blank shots, simultaneous kills, death during flag capture, and shots spanning a respawn discontinuity.
- Decide explicitly whether world geometry is rewound. Initial recommendation: rewind players only and use current static map geometry.
- Measure perceived fairness from both shooter and victim perspectives.

### 5. Harden and scale

- Add per-peer command/fire budgets and malformed-request counters.
- Instrument hit acceptance/rejection reasons without trusting client hit claims.
- Add relevancy and bandwidth measurements at 8–16 players.
- Run the same suite against a Linux dedicated-server export and then a real direct-IP host.

## Deferred by design

- Skeletal/per-limb hitboxes and damage multipliers
- Client-authoritative hits
- Matchmaking, accounts, progression, and inventory
- A second weapon until the movement and pulse-rifle path pass impairment testing
