# SKOOSH combat networking roadmap

## Current contract

The dedicated server owns health, death, respawn, teams, flags, score, and round state. A client may request a disc launch only for its own avatar. The server independently enforces alive/round state, post-teleport lockout, cadence, ownership, team, and bounded request age. It discards the requested transform, reconstructs the launch from its current muzzle and aim, and owns swept projectile collision, splash falloff, friendly-fire rejection, damage, and kill credit. Clients predict only projectile presentation.

The current player collision capsule is also the current hitbox. The more detailed armor model is presentation only.

This is sufficient for the local vertical slice, but it is not finished Internet-grade projectile registration. Launch validation uses current server transforms, remote projectile presentation is only coarsely fast-forwarded, and impaired-network behavior has not been qualified.

## Next implementation stages

### 1. Measure movement under impairment

- Add repeatable latency, jitter, reordering, and packet-loss scenarios.
- Record correction distance, correction frequency, floor/contact disagreement, rollback depth, and input age.
- Verify skiing, ground-jet pops, crest launches, impacts, and respawns before expanding combat.

### 2. Bound and instrument launch requests

- Clamp accepted fire age and reject future, stale, duplicate, or impossible launch requests.
- Record launch age, origin/angle correction, rejection reason, impact age, and projectile lifetime.
- Clear launch eligibility across death, respawn, and authoritative teleport discontinuities.
- Measure whether visual fast-forwarding needs a smoother correction path.

### 3. Decide latency treatment by weapon type

- Keep disc collisions forward-simulated and server-owned; do not rewind moving projectiles through historical world state.
- Consider a small, bounded launch fast-forward only after impairment measurements show it is needed and fair.
- If a future hitscan weapon is added, record compact historical capsules and evaluate server-approved rays analytically rather than mutating the live physics world.
- Preserve server-owned cadence, team rules, splash, damage, and kill credit for every weapon type.

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
- A second weapon until movement and disc-launcher paths pass impairment testing
