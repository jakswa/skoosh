# Match director extraction plan

## Goal

Move CTF, scoring, objective reset, and round-transition rules from
`scripts/network_main.gd` into one authoritative match owner while preserving
the current replicated-state path and root-facing API.

**Total size:** M, preferably two green commits rather than one broad move.

## Existing seam

`scripts/network_match_state.gd` already owns the replicated score, flag, round,
and generation properties. `NetworkDemo/ReplicatedGameState` and
`GameStateSynchronizer` are stable network paths. They remain in place.

The new match director owns rules applied to that state. It must not duplicate
the state in a second set of fields.

Candidate root logic begins around:

- Objective and HUD queries: `network_main.gd:1398-1427`.
- CTF tick and contacts: `:1660-1800`.
- Capture, score, and reset: `:1803-1881`.
- New-round and flag lifecycle: `:2198-2311`.

## Ownership boundary

The director owns:

- Flag pickup, carry, drop, teammate return, timeout return, and capture rules.
- Capture idempotence and score mutation.
- Objective-rearm deadline and completion.
- Score-limit win and round deadline.
- Match reset of score and objective state.
- Match queries used by HUD, player respawn, and bots.
- Domain events for pickup, capture, objective ready, round won, and match reset.

The root retains:

- Server/client lifecycle and current world phase.
- Avatar iteration and lookup until the avatar registry is extracted.
- Rotation initiation and protocol execution.
- Stable public wrappers used by players, HUD, visual QA, and tests.
- Presentation calls that bind replicated state to the current flag nodes.

The director requests rotation through a signal or returned transition result.
It never calls rotation RPCs or changes the world phase itself.

## Stable facade

Keep these root methods while current consumers rely on them:

- `is_round_active`
- `player_carries_enemy_flag`
- `get_capture_limit`
- `is_objective_resetting`
- `get_flag_status`
- `get_team_name`
- `get_bot_objective_position`
- `prepare_player_respawn`

They should delegate to the director or compose a director query with current
world/avatar information. This is temporary, concrete compatibility for scene
consumers, not a second match implementation.

## Packet A: characterize and move pure rules

**Size:** S to M

1. Add focused characterization for pickup, teammate return, carrier death,
   timeout, capture eligibility, duplicate capture rejection, score accumulation,
   score-limit win, objective reset, and new-match reset.
2. Construct the director with the existing `SkooshNetworkMatchState` and the
   two current flag homes.
3. Move flag getters/setters and pure transition rules first.
4. Keep root tick/contact wrappers and log text stable while they delegate.

Do not create a generic game-mode framework in this packet. A second mode can
justify an interface when it exists.

Verify:

```bash
./tools/run_headless_tests.sh score-limit-cli oob-recovery multiplayer-faultline
```

## Packet B: integrate lifecycle events

**Size:** M

1. Move capture scoring, objective reset, round end, and new-round reset.
2. Emit domain events consumed by acceptance recording instead of calling
   acceptance counters from match rules.
3. Have the root translate the round-won event into `_begin_rotation()` when the
   current map participates in production rotation.
4. Have disconnect, death, OOB recovery, and respawn call explicit director
   methods for carrier cleanup.
5. Remove acceptance-specific branches from capture rules after the acceptance
   driver can observe director events.

Verify:

```bash
./tools/run_headless_tests.sh multiplayer-faultline multiplayer-cairn oob-recovery map-rotation
```

Then run the serialized full suite:

```bash
SKOOSH_TEST_JOBS=1 ./tools/run_headless_tests.sh all
```

## Typed boundary

Use typed parameters and return values for player, team, flag state, positions,
and transition outcomes. A dynamic `Dictionary` is not needed for the match
director's internal authoritative state.

Do not convert `MapCatalog` as part of this extraction. The director may receive
the already-selected score limit, homes, and route-independent match constants
as typed values.

## Rejection conditions

Stop and split the packet if any proposed director:

- Stores a second authoritative copy of replicated match state.
- Needs an unbounded reference to every root field.
- Owns ENet calls, RPC annotations, terrain construction, or readiness barriers.
- Reimplements avatar admission or visibility checks.
- Changes flag, score, or reset timing while moving code.

## Done state

- CTF and score transitions have one server-authoritative owner.
- `network_main.gd` coordinates match ticks and rotation but does not implement
  flag or scoring rules.
- Replicated property names and node paths are unchanged.
- Acceptance observes match events rather than being embedded in match logic.
- HUD, respawn, OOB, disconnect, bots, static matches, and rotating matches all
  retain current behavior.
