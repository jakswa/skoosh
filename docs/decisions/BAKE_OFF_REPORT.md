# SKOOSH Visual Bake-Off Report

## Baseline and policy

- Shared pushed baseline: `593f7632aae299f120b3b702ce0596cfedd3b424`
- Renderer: Godot 4.4.1 Forward+, balanced profile
- Asset policy: repository-local, procedural, or worker-authored assets only
- Every candidate includes fresh editable Blender source, generated runtime assets, a manifest, two capture-and-critique loops, and a direction brief.
- Kestrel was adopted as a scaffold on `feature/voice-disc-ux`, then selectively rebuilt rather than merging all three candidate branches.

## Gallery

- Equivalent states, A/B/C adjacent: `build/visual-bake-off/comparison/equivalent-states.png`
- Nominated hero overview: `build/visual-bake-off/comparison/nominated-heroes.png`
- Full standardized sheets, A/B/C adjacent: `build/visual-bake-off/comparison/contact-sheets.png`

## Candidates

| ID | Direction | Evidence branch | Final commit |
|---|---|---|---|
| A | KESTREL BASIN, alpine expeditionary sci-fi | `visual-bakeoff/alpine-expeditionary` | `6191c84a` |
| B | STRATOS, clean broadcast combat sport | `visual-bakeoff/broadcast-sport` | `6c9375cd` |
| C | KHEPRI RELAY, retro alien-industrial | `visual-bakeoff/retro-alien` | `71ac4bca` |

## Rubric evidence

| Criterion | A: KESTREL BASIN | B: STRATOS | C: KHEPRI RELAY |
|---|---|---|---|
| Gameplay readability, 25% | Strong architecture and objective contrast; pale terrain remains sparse and some slope bands merge at distance. | Clearest route and slope grammar; large red home rings and high-key surfaces can dominate the spawn frame. | Strong silhouettes and selective cyan targets; lowest scene value separation, especially across distant terrain. |
| Identity and coherence, 25% | Consistent hardpack, graphite relay, induction-tool, and mint signal language; closest of the three to familiar human sci-fi. | Terrain marks, gate, relay, launcher, and UI all support a regulated sport; base body is still visually slab-like. | Most unfamiliar silhouette and strongest fiction across monument, objective, weapon, and atmosphere; material families need another separation pass. |
| Shareability, 20% | Grounded and polished, with a readable weapon and practical station; broad terrain can look empty in stills. | Immediately legible and bright, with a clear competitive premise; some frames retain prototype-clean flatness. | Strongest mood and curiosity hook; dark monochrome frames reduce small-thumbnail readability. |
| Motion and action, 15% | Pressure-ring and mint signal language reads cleanly after iteration reductions. | Timing-ring language suits the sport and route marks communicate speed; close objective rings still compete with action. | Annular effects and forked projector feel specific to the fiction; red impact/elimination states can flood the frame. |
| Production feasibility, 10% | Moderate asset burden; modular expedition kits and procedural terrain can scale, but station and weapon need LOD/trim work. | Lowest content burden; graphic surfaces, modular gates, and simple regulated equipment are small-team friendly. | Highest bespoke-art burden; monumental architecture and alien material language need disciplined modularization and LODs. |
| Technical preservation, 5% | Authority and qualified routes preserved; decorative braces and gantries are non-colliding. | Authority and routes preserved; deck shell is approximately 0.1-0.3 m above box collision. | Authority and routes preserved; prongs, teeth, and cages are decorative and non-colliding. |

## Direction summaries

| Candidate | Strongest aspect | Weakest aspect | Main production risk |
|---|---|---|---|
| A: KESTREL BASIN | Practical, cohesive world and equipment hierarchy | Sparse terrain and conventional human-sci-fi familiarity | Turning detailed station/weapon prototypes into modular, collision-honest production kits |
| B: STRATOS | Fastest competitive read and clearest scalable graphic system | Oversized home-zone graphics and flat prototype-clean surfaces | Preserving restraint as broadcast graphics, sponsors, and UI expand |
| C: KHEPRI RELAY | Most distinctive silhouette, mood, and fiction | Dark value compression and weaker distant terrain/team readability | Producing enough coherent alien architecture without a bespoke-content explosion |

## Validation

| Candidate | Ground jet | Multiplayer acceptance | Standardized visual QA |
|---|---|---|---|
| A | PASS, `8.20 m/s`, `6.50` energy | PASS, 4 kills/deaths, 6 impacts, 3 captures/rounds | PASS, 11 states, Forward+/Vulkan |
| B | PASS, `8.20 m/s`, `6.50` energy | PASS on isolated rerun, 4 kills/deaths, 4 impacts, 3 captures/rounds | PASS, 11 states, Forward+/Vulkan |
| C | PASS, `8.20 m/s`, `6.50` energy | PASS, 4 kills/deaths, 5 impacts, 3 captures/rounds | PASS, 11 states, Forward+/Vulkan |

STRATOS's first final multiplayer run completed combat, voice, movement, jetting, and flag pickup but missed the capture deadline. The required isolated rerun passed all three rounds. All visual runs were serialized. The visual client logs retain the baseline one-resource teardown diagnostic accepted by the harness; no candidate introduced a parser or in-match runtime failure.

## Applied consolidation

- Kestrel daylight, warm/cool depth, practical material hierarchy, and controlled team accents are the foundation.
- STRATOS contributes restrained terrain contours, route/timing marks, and the aerofoil launcher silhouette.
- Khepri contributes triune monument vanes and three-axis objective cages, not its dark palette.
- The launcher was rebuilt around a visible disc feed and open gate; the projectile remains authoritative swept-ray physics.
- The shared runway mannequin was replaced by the Vector Expedition Runner rig and a revised `MomentumLean` animation.

## Consolidation validation

- Asset contract: PASS, one skeleton, 24 skinned meshes, six `MomentumLean` tracks, five consolidated base material meshes.
- Ground jet: PASS, `8.20 m/s` pop, `6.50` energy, `0.20 m/s` high-speed exclusion.
- Multiplayer: PASS, four kills/deaths, four damaging disc impacts, global voice relay, jet use, and three captures/rounds.
- Final hybrid Forward+ sheet: PASS, 11 live states on Vulkan. The earlier pre-renderer stall came from forcing Godot's libdecor fallback to use an empty plugin directory; the repaired runner now completes under private Weston and retains compositor logs for future diagnosis.

## Decision

The user selected a Kestrel-daylight hybrid on the current `feature/voice-disc-ux` branch. Khepri Night and STRATOS Graphic remain cataloged future map vocabularies in `docs/production/VISUAL_DIRECTION.md`.
