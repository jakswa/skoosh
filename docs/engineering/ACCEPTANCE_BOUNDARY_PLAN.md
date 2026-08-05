# Acceptance boundary extraction plan

## Goal

Remove automated acceptance policy and test-only world driving from
`scripts/network_main.gd` without weakening the authoritative gameplay path or
replacing the current shell suite.

`scripts/network_acceptance.gd` already owns many counters and elementary
failure predicates, and `tools/run_headless_tests.sh` already owns suite
selection, isolated ports, bounded processes, and artifacts. This plan finishes
that separation. It does not build a generic test framework.

**Total size:** L, split into three independently green M packets.

## Current leakage

The root still owns or directly branches on:

- Acceptance CLI requirements and timer state.
- Metrics forwarding from combat, voice, movement, avatars, and rotation.
- Acceptance-only spawn placement.
- Full-route waypoint observation.
- Test-only pickup/capture positioning.
- Duplicate capture evaluation.
- Character-variant and rotation result evaluation.
- Coordinated acceptance shutdown.

The most coupled regions are `network_main.gd:1254-1262`, `:1276-1319`,
`:1633-1657`, `:1706-1848`, and `:2314-2485`. These references are a planning
map, not a promise that line numbers remain stable.

## Required contracts

- Existing CLI flags keep their meaning and output remains machine-readable.
- Existing `ACCEPT ...` lines and process exit statuses remain compatible with
  current shell assertions.
- Test code may position an acceptance actor, but it may not award score,
  damage, impact, admission, or rotation state directly.
- The same authoritative contact and capture APIs used by live gameplay decide
  acceptance outcomes.
- Acceptance is inert when no test flags are enabled.
- `_finish_client_automated_test` remains a root RPC wrapper while its path is
  part of coordinated shutdown.

## Packet A: evaluation snapshot

**Size:** M

Move result assembly and pass/fail policy out of `_finish_automated_test`.

Add one typed, read-only acceptance snapshot containing only values needed for
evaluation, such as role, current peer/avatar assignments, world generation,
map history, world phase, match generation, and world-contract status. The root
builds the snapshot; the acceptance owner evaluates it. The acceptance owner
must not retain a root reference or read private root fields.

Keep these on the root for this packet:

- CLI parsing.
- Timer creation.
- The final quit and shutdown RPC calls.
- Thin `record_*` methods already called by scene scripts.

Completion evidence:

- `_finish_automated_test` only gathers the snapshot, asks for a result, logs
  that result, and performs shutdown.
- Character-variant and rotation failure policy no longer lives in the root.
- Existing output keys remain stable.

Verify:

```bash
./tools/run_headless_tests.sh character-variants multiplayer-faultline map-rotation
```

## Packet B: observation sink

**Size:** M

Make acceptance observations explicit and optional instead of embedding test
policy in production domain methods.

- Keep one recorder responsible for metrics and generation summaries.
- Route avatar, combat, voice, movement, CTF, objective-reset, match-reset, and
  rotation observations through narrow methods.
- Prefer match-director events for captures, objective resets, and round
  completion once that director exists.
- Keep production log messages independent from acceptance counters.
- Type peer/generation maps internally where Godot 4.4 typed dictionaries fit;
  do not convert dynamic report payloads or map catalog data as part of this
  packet.

Root `record_*` wrappers may remain temporarily because weapons and players
currently discover the root. They should delegate immediately and can disappear
later when the gameplay-context boundary is introduced.

Verify:

```bash
./tools/run_headless_tests.sh fast
./tools/run_headless_tests.sh multiplayer-faultline multiplayer-cairn
```

## Packet C: test-only driver

**Size:** M

Move acceptance route tracking and accelerated contact positioning into a
driver that is constructed only for acceptance runs.

The driver may:

- Select the acceptance spawn transform from map data.
- Observe an authoritative pickup and route progress.
- Ask one selected actor to move to a pickup or capture contact position.
- Decide when a generation has demonstrated movement, combat, and capture.
- Request the next normal contact attempt through a narrow root or match API.

The driver may not:

- Change scores, flag state, round state, world phase, or admission state.
- Call private match-state setters.
- Duplicate CTF eligibility rules.
- Bypass generation or admitted-peer checks.

The match director should expose successful pickup/capture/reset events before
this packet. That lets `_take_flag` and `_capture_flag` stop containing
acceptance branches. The duplicate-award characterization should invoke the
same public authoritative capture attempt twice and observe that the second
attempt is rejected.

Verify:

```bash
./tools/run_headless_tests.sh multiplayer-faultline multiplayer-cairn map-rotation
```

## Shell scope

Do not rewrite the runner in this work. `tools/run_headless_tests.sh` already
provides the useful top-level boundary. Individual scenario scripts may retain
their domain-specific log assertions and startup ordering.

A small shared shell helper is allowed later if repeated PID cleanup, bounded
waits, and Godot discovery are causing real maintenance defects. It should not
hide scenario assertions or replace direct `tools/test_*.sh` entry points.

## Done state

- Production match, combat, voice, and lifecycle methods contain no acceptance
  pass/fail policy.
- Test-only movement/contact mutation has one owner constructed only in
  acceptance mode.
- Evaluation consumes a typed snapshot rather than private root fields.
- The root retains only CLI/timer wiring, compatibility wrappers, and shutdown
  coordination.
- Full headless acceptance remains green with unchanged authority boundaries.
