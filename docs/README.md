# SKOOSH Documentation

`CHECKPOINT.md` is the canonical project handoff. Read it first for the current
state, constraints, decisions, and known gaps. The repository `README.md` is the
shortest path to running the game.

## Read First

| Document | Authority |
|---|---|
| [Project checkpoint](CHECKPOINT.md) | Canonical product, technical, validation, and handoff state. |
| [Repository README](../README.md) | Shortest path to running, testing, and exporting the game. |

## Immediate Work

These are the only current implementation plans. Follow the parent roadmap and
keep each work packet green on `main`.

| Order | Document | Purpose |
|---:|---|---|
| 0 | [Maintainability roadmap](engineering/MAINTAINABILITY_ROADMAP.md) | Sequence, ownership rules, sizing, and verification gates. |
| 1 | [Acceptance boundary](engineering/ACCEPTANCE_BOUNDARY_PLAN.md) | Extract test policy and test-only world driving. |
| 2 | [Match director](engineering/MATCH_DIRECTOR_EXTRACTION_PLAN.md) | Extract authoritative CTF, score, objective-reset, and round rules. |
| 3 | [Network lifecycle](engineering/NETWORK_LIFECYCLE_EXTRACTION_PLAN.md) | Split world, avatar, baseline, admission, and rotation ownership behind stable RPC paths. |

## Implemented Reference

| Document | Current use |
|---|---|
| [Map rotation](engineering/MAP_ROTATION_HANDOFF.md) | Implemented world seam and generation/admission protocol contracts. |
| [Competitive maps](production/COMPETITIVE_MAPS.md) | Implemented production rotation, map contracts, and remaining human validation. |

## Future Qualification

These contain legitimate later work, but they are not in the immediate
maintainability queue.

| Document | Future scope |
|---|---|
| [Combat networking roadmap](engineering/COMBAT_NETWORKING_ROADMAP.md) | Impairment, launch validation, latency treatment, and scale qualification. |
| [Projectile presentation review](engineering/PROJECTILE_PRESENTATION_REVIEW.md) | Telemetry, correction, fuse, prediction, and profiling after the landed presentation seam. |

## Operations

| Document | Purpose |
|---|---|
| [Playtesting and distribution](operations/PLAYTESTING_AND_DISTRIBUTION.md) | Source, release, export, and playtest workflows. |
| [Server deployment](operations/SERVER_DEPLOYMENT.md) | Dedicated-server operator runbook. |

## Production Reference

| Document | Purpose |
|---|---|
| [Visual direction](production/VISUAL_DIRECTION.md) | Selected art direction and presentation rules. |
| [Visual QA](production/VISUAL_QA.md) | Off-screen capture and visual review workflow. |
| [Voice assets](production/VOICE_ASSETS.md) | Voice provenance, processing, and regeneration. |
| [Audio](production/AUDIO.md) | Adaptive soundscape, mixer buses, provenance, and regeneration. |
| [Asset tooling](../tools/asset_pipeline/README.md) | Commands and contracts for generating current game assets. |
| [Audio generation](../tools/generate_game_audio.sh) | Procedural game-audio renderer and regeneration command. |

## Decision Records

These explain why the project chose its current technical and visual baselines.
They are evidence, not active task lists.

| Document | Decision |
|---|---|
| [Networking research](decisions/RESEARCH_FINDINGS.md) | Stay with Godot, ENet, and an authoritative server model. |
| [Forward+ evaluation](decisions/FORWARD_PLUS_EVALUATION.md) | Use balanced Forward+ by default with a lean low-spec profile. |
| [Asset pipeline exploration](decisions/ASSET_PIPELINE_EXPLORATION.md) | Completed pipeline experiments, conclusions, and remaining production risks. |
| [Visual bake-off report](decisions/BAKE_OFF_REPORT.md) | Use the selected Kestrel, STRATOS, and Khepri hybrid. |

## Research

Research preserves exploratory evidence and possibilities without making them
current project truth or roadmap commitments.

| Area | Purpose |
|---|---|
| [Exploratory research](research/README.md) | Game-mode concepts, evaluation methods, and engineering-lineage findings. |

## Archive

`archive/` preserves superseded plans, completed experiments, and early
recommendations. Archived documents describe the project at the time they were
written and do not override the checkpoint or immediate plans.

| Document | Historical context |
|---|---|
| [Original solo MVP plan](archive/PLAN.md) | Movement and time-trial baseline. |
| [Multiplayer spike](archive/MULTIPLAYER_SPIKE.md) | Original networking experiment plan. |
| [Research brief](archive/RESEARCH_PATHS.md) | Questions and evidence standards behind the networking decision. |
| [Visual bake-off plan](archive/VISUAL_BAKE_OFF.md) | Completed three-candidate process. |
| [Solar Nomad launcher](archive/SOLAR_NOMAD_LAUNCHER.md) | Prototype lessons and failure modes. |
| [Early game-director take](archive/GAME_DIRECTOR_TAKE.md) | Pre-bake-off production recommendation. |

## Media

- `screenshot.png` is the repository README hero image.
- `screenshots/` contains selected playtest and presentation captures.

When adding documentation, put current procedures with their owning area,
decision evidence in `decisions/`, and superseded material in `archive/`. Update
this index and inbound links in the same change.
