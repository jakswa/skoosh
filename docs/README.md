# SKOOSH Documentation

`CHECKPOINT.md` is the canonical project handoff. Read it first for the current
state, constraints, decisions, and known gaps. The repository `README.md` is the
shortest path to running the game.

## Active Work

| Document | Purpose |
|---|---|
| [Project checkpoint](CHECKPOINT.md) | Current product, technical, and validation state. |
| [Maintainability roadmap](engineering/MAINTAINABILITY_ROADMAP.md) | Ordered, mainline-safe decomposition of the overloaded multiplayer root. |
| [Acceptance boundary](engineering/ACCEPTANCE_BOUNDARY_PLAN.md) | Extract test policy and test-only world driving from production coordination. |
| [Match director](engineering/MATCH_DIRECTOR_EXTRACTION_PLAN.md) | Extract authoritative CTF, score, objective-reset, and round rules. |
| [Network lifecycle](engineering/NETWORK_LIFECYCLE_EXTRACTION_PLAN.md) | Split world construction, avatar membership, admission, and rotation behind stable RPC paths. |
| [Combat networking roadmap](engineering/COMBAT_NETWORKING_ROADMAP.md) | Immediate networking and combat qualification work. |
| [Projectile presentation review](engineering/PROJECTILE_PRESENTATION_REVIEW.md) | Audited projectile smoothing risks, implemented seam status, and measured follow-up stages. |
| [Map rotation](engineering/MAP_ROTATION_HANDOFF.md) | Implemented world seam, bounded generation/admission protocols, acceptance, and remaining qualification. |
| [Playtesting and distribution](operations/PLAYTESTING_AND_DISTRIBUTION.md) | Source, release, export, and playtest workflows. |
| [Server deployment](operations/SERVER_DEPLOYMENT.md) | Dedicated-server operator runbook. |
| [Visual direction](production/VISUAL_DIRECTION.md) | Selected art direction and presentation rules. |
| [Visual QA](production/VISUAL_QA.md) | Off-screen capture and visual review workflow. |
| [Competitive maps](production/COMPETITIVE_MAPS.md) | Production CTF rotation, map contracts, selection, and remaining validation. |
| [Asset tooling](../tools/asset_pipeline/README.md) | Commands and contracts for generating current game assets. |
| [Voice assets](production/VOICE_ASSETS.md) | Voice provenance, processing, and regeneration. |

## Decision Records

These explain why the project chose its current technical and visual baselines.
They are evidence, not active task lists.

| Document | Decision |
|---|---|
| [Networking research](decisions/RESEARCH_FINDINGS.md) | Stay with Godot, ENet, and an authoritative server model. |
| [Forward+ evaluation](decisions/FORWARD_PLUS_EVALUATION.md) | Use balanced Forward+ by default with a lean low-spec profile. |
| [Asset pipeline exploration](decisions/ASSET_PIPELINE_EXPLORATION.md) | Completed pipeline experiments, conclusions, and remaining production risks. |
| [Visual bake-off report](decisions/BAKE_OFF_REPORT.md) | Use the selected Kestrel, STRATOS, and Khepri hybrid. |

## Archive

`archive/` preserves superseded plans, completed experiments, and early
recommendations. Archived documents describe the project at the time they were
written and do not override the checkpoint or active documents.

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
