# SKOOSH lineage research context

This directory preserves the durable conclusions from a source-reading pass over
Torque3D and OpenTNL, the engine and networking lineage behind the original Tribes
architecture. It is context for future design and implementation decisions, not an
active roadmap and not a substitute for the current project documentation.

## AI reading order

Before using these findings:

1. Read [`../../CHECKPOINT.md`](../../CHECKPOINT.md) for current project truth.
2. Read [`../../README.md`](../../README.md) for the canonical documentation map.
3. Read [`../../decisions/RESEARCH_FINDINGS.md`](../../decisions/RESEARCH_FINDINGS.md)
   for the adopted Godot/ENet/server-authority decision.
4. Read [`../../engineering/COMBAT_NETWORKING_ROADMAP.md`](../../engineering/COMBAT_NETWORKING_ROADMAP.md)
   before changing combat or impairment qualification work.
5. Use this directory only for lineage-derived architecture and design context.

When documents disagree, use this authority order:

1. Current implementation and tests.
2. `docs/CHECKPOINT.md`.
3. Active owning documents under `docs/engineering/`, `docs/operations/`, and
   `docs/production/`.
4. Decision records under `docs/decisions/`.
5. This research context.
6. Archived plans.

Update the owning current document when a recommendation is adopted. Do not quietly
turn this directory into a second checkpoint or task list.

## Documents here

| Document | Use it for |
|---|---|
| [Networking architecture](NETWORKING_ARCHITECTURE.md) | Interest management, prioritization, snapshot/event boundaries, scaling, and transport decisions. |
| [Movement and UX](MOVEMENT_AND_UX.md) | Prediction/reconciliation principles, skiing contacts, terrain, HUD, VGS, and feel validation. |

## Executive summary

- The research recommendation is to keep Godot high-level multiplayer, ENet, and netfox
  unless measurements identify a specific blocker. This remains conditional on current
  project evidence; do not start a raw UDP stack in parallel.
- ENet solves transport behavior. It does not choose which actor matters to a client,
  provide authentication by itself, or validate gameplay.
- Keep owner input/prediction/correction separate from remote-player presentation.
- At 32-64 players, treat per-client interest, importance, age, and byte budgeting as
  required architecture unless scale tests prove the simpler path sufficient.
- Current-state snapshots and one-shot events need different delivery policies.
- Prediction requires replayable state and server authority, not perfect deterministic
  lockstep.
- Smooth presentation, not authoritative collision state.
- Source reading identifies architecture; impairment, scale, and human feel tests decide
  whether it works for SKOOSH.

## Source and license boundary

Source snapshot inspected on 2026-08-03:

| Source | Commit | License/use |
|---|---|---|
| Torque3D | `ccf404d70fee05bcecd1ebd13ba0a0ef8b46d5f4` | MIT; direct reference and attribution permitted. |
| `elfprince13/OpenTNL` | `b212017f1dbd015857a18e74eb1d7f03203e7764` | GPLv2; clean-room design research only. |
| `kocubinski/opentnl` and its Zap sample | `3af15125bc651472f74542e824e1d19b67a14420` | GPLv2; examples are not Tribes source. |

The research intentionally records OpenTNL algorithms and tradeoffs only as independent
prose. No GPL code, identifiers as an implementation schema, wire format, or control-flow
structure was imported into SKOOSH.

For OpenTNL-derived material:

- Do not copy, transliterate, or line-by-line port code.
- Do not recreate its wire layout, crypto, allocator, array organization, or control flow
  merely because the historical source used them.
- Write a SKOOSH-specific requirement first, then implement independently using Godot,
  ENet, netfox, and measured project needs.
- Keep attribution and source provenance explicit in research discussion.

The detailed citation notebook remains outside this project. It contains source
line ranges, historical protocol details, contradictions, and broad open-question
matrices. Those details should remain there unless a finding becomes a durable
SKOOSH requirement.

## What was deliberately not imported

- Historical packet formats, sequence widths, ghost-ID limits, and cryptography.
- Unmeasured cell sizes, update rates, bandwidth budgets, and compression schemes as
  project commitments.
- Vehicles, loadout stations, advanced radar, and other feature scope not yet adopted.
- A general-purpose bitstream or custom reliability protocol.
- Historical low tick rates or movement behavior as goals in themselves.
