# SKOOSH Visual Direction Bake-Off

> **READY FOR USER GO-AHEAD:** The technical runway in `ASSET_PIPELINE_EXPLORATION.md` is complete. Do not spawn workers until the current pipeline work is consolidated into one recorded baseline commit and the user explicitly starts the bake-off.

**Status:** Launch-ready overseer plan. It creates isolated worktrees, spawns three equally scoped visual workers, collects standardized captures, and presents the results for a human decision.

## 1. Goal

Explore three substantially different visual directions against the same playable multiplayer CTF baseline:

1. **Alpine expeditionary sci-fi**
2. **Clean broadcast combat sport**
3. **Retro alien-industrial**

The bake-off should answer:

> Which direction makes SKOOSH most readable, distinctive, exciting in motion, and worth sharing, while remaining feasible for a small project using Godot's Compatibility renderer?

This is a direction-finding exercise, not three production art passes. Each worker should make a coherent, runnable visual prototype and produce comparable screenshots. The user chooses the winner.

## 2. Required project context

The overseer and all workers must read:

- `AGENTS.md`
- `docs/CHECKPOINT.md`
- `docs/VISUAL_QA.md`
- `docs/plans/ASSET_PIPELINE_EXPLORATION.md`
- `tools/asset_pipeline/README.md`
- This plan

`docs/plans/SOLAR_NOMAD_LAUNCHER.md` is a failure/learning brief, not a style guide. The current launcher, runway base, terrain treatment, and suit mannequin are disposable technical examples. Workers should reuse contracts and tooling while creating fresh visible designs.

Relevant constraints:

- Godot 4.4+, typed GDScript, Compatibility renderer.
- Native clients and Linux headless server; no browser target.
- The server remains authoritative over movement results, energy, combat, objectives, and score.
- Multiplayer entry point: `scenes/network_demo.tscn`.
- Use the desktop-safe off-screen capture flow. Do not launch graphical clients on the user's desktop.
- Do not disturb unrelated working-tree changes or untracked files.

## 3. Success criteria

The bake-off succeeds when all three candidates provide:

- A runnable branch/worktree based on the same baseline commit.
- A visibly distinct and internally coherent art direction—not merely a palette swap.
- A standardized visual-QA contact sheet.
- Three nominated hero screenshots selected from the standardized captures.
- A short direction brief and implementation inventory.
- Passing required gameplay checks.
- A candid account of shortcuts, performance concerns, and production implications.

The result is a comparison package and recommendation matrix. Do not merge a candidate automatically.

## 4. Scope of each prototype

Each worker receives the same time/tool budget and should touch enough of the frame to demonstrate a complete direction.

### Required visual areas

Each candidate must address:

1. **World palette and atmosphere**
   - Sky, sun, ambient light, fog, value hierarchy, and distance readability.
2. **Terrain surfacing**
   - Shader/material/color treatment that distinguishes traversable ground, steep terrain, and distant forms.
3. **Base architecture**
   - Improve the red/blue platform silhouette and its connection to the terrain.
   - Team identity should remain obvious without relying entirely on the HUD.
4. **First-person disc launcher**
   - Improve silhouette, composition, materials, and visual hierarchy.
5. **Action feedback**
   - Improve at least one major motion/combat effect, preferably disc launch/impact or jetting.
6. **Objective treatment**
   - Improve flags, capture rings, beacons, or base-state feedback.

### Optional stretch areas

- Remote player silhouette/material treatment.
- Ski trails, jet exhaust, speed feedback, landing feedback.
- Lightweight environment props.
- UI theming that supports the direction without redesigning functional hierarchy.
- Sound additions, provided licensing and attribution are clear.

### Out of scope

- Gameplay redesign or balance changes.
- Movement, weapon, CTF, or networking rule changes.
- Changes to authoritative ownership.
- New maps or a terrain-topology rewrite.
- Full production character pipelines.
- Account systems, matchmaking, or unrelated UX work.
- Large framework or renderer changes.

Presentation must remain separable from simulation. Visual rigs, effects, and animation must not become authoritative collision or gameplay state.

## 5. The three directions

These descriptions are starting constraints, not exact prescriptions. Workers should commit to their assigned identity rather than converging on generic sci-fi.

### A. Alpine expeditionary sci-fi

**Core idea:** A field-deployed military/industrial CTF operation in a severe alpine basin.

Likely vocabulary:

- Pale snow or hardpack, exposed dark slate, cold atmospheric depth.
- Graphite metal, worn ceramic armor, structural braces, antennas, floodlights.
- Warm low sun against cool shadows.
- Red/blue as controlled team accents; teal/mint as neutral technology.
- Heavy, practical disc launcher and relay-station bases.

Avoid:

- Giant flat team-colored surfaces.
- Glossy showroom materials.
- Generic present-day military realism.

### B. Clean broadcast combat sport

**Core idea:** A purpose-built high-speed future sport with exceptional readability and broadcast-friendly shapes.

Likely vocabulary:

- Clean neutral terrain or synthetic ski surfaces.
- Bright but disciplined color blocking.
- White/light-gray architecture with strong red/blue lanes and edge markings.
- Graphic capture zones, score-state animation, readable silhouettes.
- Sleek equipment that feels regulated and athletic rather than military.

Avoid:

- Turning the scene into a featureless white test chamber.
- Excessive neon on every surface.
- UI noise that competes with gameplay.

### C. Retro alien-industrial

**Core idea:** An uncanny, older extraterrestrial facility repurposed for momentum combat.

Likely vocabulary:

- Monumental geometric structures embedded in the terrain.
- Dark mineral surfaces, oxidized or strange metallic materials, selective saturated energy.
- Unfamiliar capture devices and disc technology.
- Strong silhouettes, repeating symbols, restrained haze, ominous scale.
- A bolder identity than conventional human sci-fi.

Avoid:

- Random psychedelic colors without value structure.
- Visual noise that obscures terrain slope or teams.
- Horror darkness that damages competitive readability.

## 6. Asset policy gate

Before spawning workers, the overseer must choose and state one policy for all three candidates.

### Selected Round 1 policy

Use repository-local, procedurally generated, or worker-authored assets only. Workers may create shaders, materials, geometry, textures, and effects, but should not download third-party packs during the bake-off.

Reasons:

- Keeps comparisons reproducible and fair.
- Avoids licensing ambiguity.
- Tests the strength of the direction rather than the quality of a purchased pack.
- Prevents one candidate from winning solely through unrelated high-fidelity assets.

Workers may include a future asset-sourcing proposal in their direction brief.

### If external assets are allowed

Apply the same rules to every worker. Require an asset manifest containing:

- Source URL and creator.
- Exact license.
- Whether redistribution in game exports is permitted.
- Modifications made.
- Any attribution requirement.

Do not accept assets with unclear provenance or incompatible redistribution terms. Clearly label generated assets and their tool/source.

## 7. Isolation and branch strategy

All candidates must begin from the same recorded baseline commit.

Suggested branches/worktrees:

- `visual-bakeoff/alpine-expeditionary`
- `visual-bakeoff/broadcast-sport`
- `visual-bakeoff/retro-alien`

Suggested worktree directories outside the control worktree:

- `../skoosh-bakeoff-alpine`
- `../skoosh-bakeoff-sport`
- `../skoosh-bakeoff-alien`

The overseer should:

1. Record the baseline commit SHA.
2. Confirm existing changes are not overwritten, cleaned, stashed, or folded into bake-off work.
3. Create each branch/worktree from that exact SHA.
4. Give each worker ownership of only its assigned worktree.
5. Prohibit workers from merging, rebasing onto one another, or editing the control worktree.
6. Record each candidate's final commit SHA beside its captures.

Workers should commit their candidate so the result remains inspectable after their session. Follow the repository co-author trailer requirement when committing.

## 8. Parallel tool allocation

The tools are usable in parallel only when unique ports and output/log directories are assigned.

### Candidate slots

| Candidate | Visual QA port | Multiplayer test port |
|---|---:|---:|
| Alpine expeditionary | `29101` | `19101` |
| Broadcast sport | `29102` | `19102` |
| Retro alien-industrial | `29103` | `19103` |

The overseer should choose a shared ignored collection root in the control repository, for example:

```text
build/visual-bake-off/
  alpine/
  sport/
  alien/
```

Each worker writes only to its own subdirectory.

### Visual-QA commands

Alpine:

```bash
SKOOSH_VISUAL_QA_PORT=29101 \
SKOOSH_VISUAL_QA_DIR=/absolute/control/root/build/visual-bake-off/alpine \
./tools/capture_visual_qa.sh
```

Sport:

```bash
SKOOSH_VISUAL_QA_PORT=29102 \
SKOOSH_VISUAL_QA_DIR=/absolute/control/root/build/visual-bake-off/sport \
./tools/capture_visual_qa.sh
```

Alien:

```bash
SKOOSH_VISUAL_QA_PORT=29103 \
SKOOSH_VISUAL_QA_DIR=/absolute/control/root/build/visual-bake-off/alien \
./tools/capture_visual_qa.sh
```

`xvfb-run -a` allocates private displays automatically. These captures must remain off-screen and must not use the desktop display.

### Resource caution

Each visual run starts a server, a rendered llvmpipe/Xvfb client, and another client after rendering the lobby. Three simultaneous runs may saturate CPU or memory and produce timing flakes.

Preferred policy:

- Development may occur in parallel.
- Run no more than one or two final visual captures simultaneously unless the machine has demonstrated sufficient capacity.
- If a capture fails under load, rerun it alone before judging the candidate.

### Other test behavior

- `tools/test_ground_jet.sh`: safe to run in parallel.
- `tools/test_multiplayer_demo.sh`: requires unique `SKOOSH_TEST_PORT` and `SKOOSH_TEST_LOG_DIR`.
- `tools/test_oob_recovery.sh`: not parallel-safe because its port is hardcoded and its default temporary log is shared. The overseer must run it sequentially, preferably on the winner or all final candidates one at a time.
- Interactive demo runners also require unique ports/log directories, but graphical desktop clients must not be launched unless the user explicitly requests them.

## 9. Worker workflow

Each worker should follow this sequence.

### Step 1: Inspect and declare intent

- Read the required context.
- Inspect the current visual-QA contact sheet and relevant scenes/scripts.
- Write five adjectives defining the assigned direction.
- Identify the largest current visual problems for that direction.
- State a small implementation plan before editing.

### Step 2: Establish a coherent frame

Prioritize broad changes before detail:

1. Palette, lighting, sky, and fog.
2. Terrain treatment.
3. Base silhouettes/materials.
4. Weapon silhouette/materials.
5. Objective and action effects.
6. Optional detail only after the full frame is coherent.

A candidate that consistently treats the whole frame is preferable to one highly detailed isolated model surrounded by unchanged prototype art.

### Step 3: Preserve gameplay

- Do not alter authoritative rules or ownership.
- Do not change collision merely to fit a decorative mesh unless behavior remains demonstrably identical.
- Keep visual effects client-side and event-driven where appropriate.
- Avoid broad refactors unrelated to presentation.

### Step 4: Validate

From that worker's worktree:

```bash
./tools/test_ground_jet.sh
```

Then use the assigned multiplayer slot, for example:

```bash
SKOOSH_TEST_PORT=19101 \
SKOOSH_TEST_LOG_DIR="$PWD/.tmp/bakeoff-multiplayer" \
./tools/test_multiplayer_demo.sh
```

Finally, produce the assigned off-screen visual-QA capture.

### Step 5: Package the candidate

Provide:

- Final candidate commit SHA.
- Standard contact sheet path.
- Three nominated hero screenshots from the standardized run.
- A concise direction brief containing:
  - Five defining adjectives.
  - Palette/material logic.
  - What changed.
  - What remains placeholder.
  - Expected production path.
  - Asset/license notes.
  - Compatibility/performance concerns.
- Test results and log paths.

Do not hand-select screenshots from a separate prettier scene. Hero images must come from the real lobby or live multiplayer capture flow. An additional concept image may be included only if clearly labeled and excluded from scoring.

## 10. Standardized comparison

The overseer should compare equivalent states wherever available:

- Lobby.
- Initial spawn/rest frame.
- Team comms open.
- Traversal or close-player state.
- Flag carry.
- Disc flight/impact.
- Round secured.

The existing event-driven capture timing can vary slightly. If one candidate misses an event state, rerun it before treating the absence as an artistic failure.

For presentation to the user:

1. Build a gallery with the same state from all three candidates adjacent.
2. Include each full contact sheet.
3. Label candidates clearly, or use A/B/C first if the user prefers a less biased review.
4. Keep technical commentary separate from the initial visual comparison.
5. Do not select the winner on the user's behalf unless asked.

## 11. Judging rubric

Suggested scoring, used as decision support rather than an automatic verdict:

| Criterion | Weight | Questions |
|---|---:|---|
| Gameplay readability | 25% | Are slope, route, players, teams, projectiles, and objectives readable at speed? |
| Identity and coherence | 25% | Does the candidate feel intentional and distinct across terrain, architecture, weapon, and effects? |
| Shareability | 20% | Would a screenshot or short clip make someone curious to play? |
| Motion and action feel | 15% | Do jetting, skiing, firing, impacts, and capture feel responsive and satisfying? |
| Production feasibility | 10% | Can a small project extend this direction without an unrealistic content burden? |
| Technical preservation | 5% | Does it retain Compatibility support, performance, tests, and authority boundaries? |

Automatic concerns to call out separately:

- Runtime/parser errors.
- Failed gameplay acceptance.
- Unlicensed assets.
- Reliance on unavailable renderer features.
- Severe frame stalls or transparency/lighting cost.
- Gameplay changes disguised as visual work.

## 12. Overseer decision report

After collecting all candidates, the overseer should write a short report containing:

- Baseline and candidate commit SHAs.
- Paths to all galleries and contact sheets.
- Test status for each candidate.
- Rubric table with brief evidence.
- Strongest and weakest aspect of each direction.
- Production-risk comparison.
- Any promising hybrid opportunities.
- A direct request for the user's choice.

The report should remain concise. Let the images lead.

## 13. After the user chooses

Do not merge all three branches.

Preferred follow-up:

1. Create a fresh implementation branch from the agreed baseline or current mainline.
2. Spawn a consolidation/refinement worker for the chosen direction.
3. Cherry-pick only clean, self-contained commits when appropriate; otherwise reimplement the strongest prototype ideas cleanly.
4. If the user wants a hybrid, list exact borrowed elements rather than loosely merging visual systems.
5. Produce a small art bible covering palette, material families, scale, team-color rules, effects language, and asset policy.
6. Run the normal visual and gameplay validation again.

Prototype code is evidence, not automatically production code.

## 14. Worker prompt template

The overseer may adapt the following for each worker:

```text
You own the SKOOSH visual bake-off candidate: <DIRECTION>.

Work only in this assigned worktree: <WORKTREE>.
Baseline commit: <SHA>.
Assigned visual-QA port: <VISUAL_PORT>.
Assigned multiplayer-test port: <TEST_PORT>.
Assigned shared capture directory: <CAPTURE_DIR>.
Asset policy: <POLICY>.

Read AGENTS.md, docs/CHECKPOINT.md, docs/VISUAL_QA.md,
`docs/plans/ASSET_PIPELINE_EXPLORATION.md`, `tools/asset_pipeline/README.md`,
and `docs/plans/VISUAL_BAKE_OFF.md` completely before editing. Treat existing
runway assets as technical examples, not a required visual style.

Create a coherent runnable visual prototype for your assigned direction. Address
world atmosphere, terrain treatment, base architecture, first-person weapon,
at least one major action effect, and objective presentation. Do not alter
authoritative gameplay/network ownership or redesign rules. Use Compatibility-
safe techniques. Do not launch graphical clients on the desktop; use the
Xvfb visual-QA flow.

You are competing on direction quality, readability, shareability, motion feel,
and realistic production feasibility—not raw quantity of changes. Start by
stating five defining adjectives and a small plan. Finish with a committed
candidate, passing ground-jet and multiplayer tests, a standardized contact
sheet, three nominated captures, and a concise direction brief. Record the
final commit SHA, commands, outputs, shortcuts, and risks.

Do not edit the control worktree, merge another candidate, or clean unrelated
files.
```

## 15. Completion checklist

- [ ] Overseer records one baseline commit.
- [ ] Asset policy is chosen and identical for all candidates.
- [ ] Three isolated branches/worktrees are created.
- [ ] Unique ports and output/log directories are assigned.
- [ ] Workers receive equal scope and budget.
- [ ] All candidates run `test_ground_jet.sh`.
- [ ] All candidates run `test_multiplayer_demo.sh` on unique ports.
- [ ] All candidates produce off-screen standardized visual captures.
- [ ] Each candidate provides three hero screenshots and a brief.
- [ ] Overseer normalizes and presents the comparison.
- [ ] User chooses the direction.
- [ ] Winner is refined on a fresh branch rather than blindly merging all prototypes.
