# Maintainability roadmap

## Status

This is the active decomposition roadmap for the multiplayer game. It is a
behavior-preserving plan, not a rewrite proposal and not a feature roadmap.

The current tree is still tractable: most gameplay scripts have focused
responsibilities and the server-authority boundary is coherent. The immediate
problem is that `scripts/network_main.gd` has become a roughly 2,500-line
persistent root with about 100 functions. It coordinates nearly every domain,
so otherwise local changes require reasoning about one shared state space.

The objective is not a small file. The objective is explicit ownership, narrow
contracts, and a root whose remaining code genuinely must live at the stable
network path.

## Non-negotiable contracts

Every extraction must preserve these behaviors:

- The dedicated server owns movement results, energy, combat, objectives, and
  score.
- `/root/NetworkDemo` remains the persistent session and stable RPC facade.
- `/root/NetworkDemo/ReplicatedGameState` and its synchronizer path remain
  stable.
- Disposable gameplay continues to live below monotonic `World_N` paths.
- Admission and rotation continue to hide incomplete peers and worlds.
- Generation and definition-hash checks continue to reject stale traffic.
- Retired-world tombstones and the final rollback baseline remain intact.
- Existing command-line flags, acceptance output, and direct test entry points
  remain supported unless a separate behavior change deliberately removes them.

The stable root RPC wrappers are concrete compatibility code, not accidental
indirection. Moving their implementation is allowed; moving their node path,
annotation, argument order, or reliability mode is not part of this roadmap.

## Mainline method

Work stays on `main`. Each work packet must be small enough to finish, verify,
and commit before starting the next packet.

1. Begin from a green relevant test set.
2. Move one ownership boundary without changing protocol or gameplay behavior.
3. Keep root wrappers only where path stability or an existing consumer
   requires them.
4. Run the packet's focused tests, then the full serialized suite when shared
   lifecycle code changed.
5. Commit the green packet on `main`; do not stack several unfinished
   extractions in the worktree.

If a packet cannot remain green independently, split it again. Line-count
reduction is never sufficient evidence that a packet is complete.

## Sizing

Sizes describe review and regression surface rather than calendar estimates.

| Size | Expected shape | Rule |
|---|---|---|
| S | One narrow owner, a few files, focused tests | One independently green commit |
| M | One domain boundary with several callers | One to two independently green commits |
| L | Protocol or lifecycle state spanning several boundaries | Must be split into two or more green packets |
| XL | Multiple L boundaries | Never execute as one project or patch |

## Ordered work

| Order | Work | Size | Why now |
|---|---|---:|---|
| 0 | Finish and baseline the current narrow fixes | S | Do not refactor against a moving or red behavior baseline. |
| 1 | Extract acceptance evaluation and reporting | M | Removes production-root test policy with little gameplay risk. |
| 2 | Extract CTF and score rules into a match director | M | Creates the first real gameplay-domain owner and clean acceptance events. |
| 3 | Extract acceptance route/contact driving | M | Removes test-only world mutation after the match API exists. |
| 4 | Extract deterministic world construction | M | Gives admission and rotation one explicit disposable-world result. |
| 5 | Extract avatar assignment, registry, and visibility policy | M | Removes shared peer/world membership state before protocol extraction. |
| 6 | Extract shared rollback-baseline mechanics | M | Admission and rotation must not grow competing baseline implementations. |
| 7 | Extract admission implementation behind root RPC wrappers | L | Admission becomes manageable once world, avatar, and baseline APIs are explicit. |
| 8 | Extract rotation and active-world lifecycle coordination behind root RPC wrappers | L | Highest-risk move; depends on all earlier lifecycle seams. |
| 9 | Replace authoritative root duck typing with a gameplay context | M | Prevents weapons and players from growing a new implicit monolith. |

Detailed plans:

- [Acceptance boundary](ACCEPTANCE_BOUNDARY_PLAN.md)
- [Match director](MATCH_DIRECTOR_EXTRACTION_PLAN.md)
- [Network lifecycle](NETWORK_LIFECYCLE_EXTRACTION_PLAN.md)

Order 9 should be planned from evidence gathered during orders 4-8. The first
scope should cover authoritative weapon, projectile, respawn, generation, and
container access. HUD, visual QA, and optional presentation hooks can migrate
later. Do not create a generic service locator or event bus.

## Target ownership

| Owner | Owns | Does not own |
|---|---|---|
| `NetworkDemo` root | Transport lifecycle, stable RPC endpoints, controller composition | CTF rules, test result policy, world construction details |
| Acceptance recorder/driver | Test observations, test-only route/contact driving, result evaluation | Score mutation, damage, admission, rotation decisions |
| Match director | Flag transitions, capture eligibility, score, objective reset, round transitions | ENet, world construction, peer admission |
| World lifecycle | Deterministic construction, world retirement/tombstones, and typed references to one `World_N` | Avatar teardown, rotation barriers, match rules |
| Avatar registry | Assignments, avatar lookup, spawn/remove, avatar callback teardown, network visibility | World tombstones, world selection |
| Baseline coordinator | Authoritative capture/seeding, client application, generation validation, and baseline tick identity | Admission/rotation barriers, global phase changes |
| Admission controller | Queue, agreement, bootstrap, visibility barrier, admission baseline | World rotation and match rules |
| Lifecycle/rotation coordinator | Active world binding, legal phase/generation transitions, prepare/commit/ready/activate barriers, rollback enablement | Terrain generation details and CTF contact rules |
| Gameplay context | Narrow authoritative services consumed by players and weapons | Every root field or optional presentation concern |

## Feature admission rule

Until orders 1-8 are complete, new feature code should not add another domain to
`network_main.gd`. A root addition is acceptable only when it is one of:

- A stable RPC wrapper that delegates immediately.
- Controller composition or lifecycle wiring.
- A short adapter for an existing path-bound consumer.

New match modes, progression, administration, moderation, telemetry products,
or additional acceptance scenarios need an owner outside the root first.

New authoritative state bags must identify their owner and lifecycle. Prefer
typed internal state; keep `Dictionary` at RPC, serialization, map-data, or
deliberately dynamic reporting boundaries. Do not launch a repository-wide
dictionary or `has_method()` cleanup.

## Verification gates

Before the first extraction, record a baseline with:

```bash
./tools/run_headless_tests.sh fast
SKOOSH_TEST_JOBS=1 ./tools/run_headless_tests.sh long
```

After a packet that changes `network_main.gd`, player lifecycle, world paths,
admission, or rotation, run:

```bash
SKOOSH_TEST_JOBS=1 ./tools/run_headless_tests.sh all
```

The serialized run is intentional while changing real-time transition
deadlines. The normal concurrent suite remains useful after the serialized run
is green.

An extraction is accepted only when:

- Godot imports and parses without errors.
- Relevant direct scripts and the suite runner still work.
- Authority, paths, generation checks, and protocol logs are unchanged unless
  the packet explicitly adds characterization output.
- The new owner has a narrower input/output contract than the root state it
  replaced.
- Production gameplay no longer branches on the extracted acceptance concern.

## Deliberate non-goals

These are valid future concerns, but they should not inflate this recovery pass:

- Rewriting networking or replacing netfox.
- Disconnecting everyone on rotation. Connection-preserving rotation already
  exists and is characterized; removing it is a separate product decision, not
  a refactor shortcut.
- Moving root RPC methods to child-node paths.
- Converting the entire map catalog to typed resources.
- Removing every `has_method()` call in one sweep.
- A generic dependency-injection framework, event bus, or ECS conversion.
- Full weapon-system decomposition while lifecycle ownership is moving.
- Effect pooling or shader warming without measured frame-time evidence.

## Projectile lane

The projectile simulation/presentation split has already landed: projectile
simulation stays on the root transform while a top-level `PresentationRoot`
interpolates render state. `tools/test_projectile_presentation.sh` characterizes
that separation.

Remaining projectile work stays in its own measured lane described by
[the projectile presentation review](PROJECTILE_PRESENTATION_REVIEW.md):
correction telemetry, bounded reconciliation concealment, the grenade fuse
freeze, impairment qualification, and only then presentation-only world-impact
prediction. Do not combine those with lifecycle extraction or effect pooling.
