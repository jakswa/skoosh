# SKOOSH Asset Pipeline Exploration

**Status:** Exploration complete and exercised by the visual bake-off. The selected hybrid now includes a purpose-built disc launcher/projectile, terrain/base language, and a replacement rigged character. See `docs/production/VISUAL_DIRECTION.md`.

## 1. Purpose

Determine what asset-production setup SKOOSH needs before attempting competing visual directions.

The earlier Y2K/Tribes-like experiment demonstrated that changing colors, materials, lighting, and primitive arrangements is not enough. A credible visual candidate needs real models, textures, animation, and effects. This exploration will test practical ways to obtain and integrate those assets before committing money or multiplying the work across several bake-off branches.

This is a paired process:

- **User:** sets budget, taste, licensing comfort, service-account access, and final quality judgment.
- **Agent:** researches options when requested, sets up tools, creates controlled experiments, integrates assets, validates Godot compatibility, and documents costs and cleanup.

No purchases, subscriptions, account creation, or uploads to third-party generation services happen without explicit user approval.

### Current checkpoint

The Solar Nomad launcher experiment has moved the project beyond a model-import smoke test:

**Going well**

- Agents can generate and substantially redesign original hard-surface assets in Blender.
- Editable source, deterministic generation, UVs, PBR maps, articulated nodes, optimized GLBs, import settings, and provenance are retained.
- User feedback can be incorporated through rapid model regeneration rather than destructive scene edits.
- Godot materials react to real scene lighting in both the original Compatibility runway and the adopted Forward+ renderer.
- Gameplay-responsive recoil, disc removal, recharge, muzzle presentation, and a shared projectile source are functional.
- Authoritative multiplayer, ground movement, and standardized off-screen capture validate successfully.
- A textured terrain shader and optimized shared base kit now prove world-asset integration without changing collision.
- A neutral skinned momentum-suit mannequin now replaces the primitive remote-player world model, proving armature, skin, animation, team materials, and multiplayer presentation.
- The current experiments used no external assets, uploads, subscriptions, or purchases.

**Still needed**

- Hand integration and a production reload animation remain after the selected launcher's visible seat/feed/gate pass.
- The disc remains authoritative swept-ray physics with a disc-shaped presentation; physical disc-volume collision is deferred.
- UV layout, normals, trim/texture strategy, and surface finish need a higher-quality manual/art-directed pass.
- The Vector Expedition Runner establishes a selected silhouette and improved locomotion loop; production deformation, hand integration, retargeting, and a complete animation set remain unproven.
- Production VFX language and terrain treatment remain direction work rather than pipeline blockers.
- Licensed/CC0 and AI-3D sourcing paths have not yet been compared against local Blender generation; Round 1 intentionally does not require them.
- Small binary source assets are tracked directly; Git LFS remains a later scale decision.

Launcher-specific design debt and continuation criteria are documented in `docs/archive/SOLAR_NOMAD_LAUNCHER.md`.

## 2. Questions to answer

1. Can agents create useful custom hard-surface models through Blender scripting and iterative screenshots?
2. Which asset categories need licensed foundations rather than agent-authored work?
3. Are AI-generated 3D assets usable after cleanup, and under what license and cost?
4. Can generated or procedural textures meet the terrain-readability and material-quality bar?
5. Should effects be built in Godot, adapted from packs, or use a hybrid approach?
6. What source formats, folder layout, import settings, and version-control policy should the project standardize?
7. What is the realistic cost per visual direction and for the eventual winner?
8. What quality level can the available machine and adopted Forward+ profiles sustain at 60 FPS?

## 3. Expected likely outcome

The working hypothesis is a hybrid pipeline:

- Licensed/CC0 foundation for rigged characters, animations, and some natural materials.
- Blender-authored custom weapon, base architecture, objective pieces, and props.
- Godot-authored shaders, lighting, integration, and gameplay-responsive VFX.
- Optional image generation for concepts, decals, masks, and effect textures.
- Optional AI 3D generation only when its topology, UVs, licensing, and cleanup cost prove acceptable.

This hypothesis must be tested rather than assumed.

## 4. Project constraints

- Godot 4.4+ with Forward+; balanced is the default feature profile and lean is the low-spec profile.
- Native desktop clients and Linux headless server.
- The server remains authoritative over gameplay; assets are presentation only.
- Existing deterministic terrain and gameplay collision should remain stable during pipeline experiments.
- Off-screen Forward+ visual review must use `tools/capture_visual_qa_private_wayland.sh`; Xvfb remains available only for historical Compatibility checks.
- Required gameplay validation remains:

```bash
./tools/test_ground_jet.sh
./tools/test_multiplayer_demo.sh
```

- Do not launch graphical clients on the desktop unless the user explicitly requests it.
- Do not disturb unrelated working-tree changes or untracked files.

## 5. Current tool baseline

Current setup:

- Godot 4.4.1 is available through the project tooling.
- ImageMagick and FFmpeg are available.
- Blender 5.2.0 LTS is available at `/usr/sbin/blender`, including background Python and GLB export.
- Blender's optional online-extension module currently warns that `cattrs` is unavailable. Local modeling and export are unaffected; do not treat the online extension library as configured.

The Blender version and generator command are recorded in `tools/asset_pipeline/README.md`.

Potential optional capabilities, each requiring a separate decision:

- Image-generation tool/API.
- AI 3D-generation service/API.
- Licensed asset marketplace access.
- Texture/material authoring software.
- Git LFS for large binary source assets.

## 6. Decision gates

The user and agent should make these decisions in order.

### Gate A — Target quality and scope

Agree on the immediate target:

- A polished indie/AAA-inspired vertical slice.
- One compact CTF arena and a repeatable 15–30 second gameplay sequence.
- Real in-engine output, not concept art presented as gameplay.

Do not target literal AAA asset volume across the complete map.

### Gate B — Budget

Choose an exploration ceiling before purchases:

- **Free-first:** CC0 assets and local tools only.
- **Small trial budget:** approximately $50–$150 for one or two representative assets.
- **Foundation budget:** approximately $200–$600 after a direction is chosen.

The agent must show the user the exact asset, price, license, engine restrictions, and intended experiment before any purchase.

### Gate C — External-service policy

For each service, decide:

- May project references or screenshots be uploaded?
- May generated output be used commercially?
- Who owns the generated output?
- Is generated content private or used for service training?
- What source files and generation metadata must be retained?

### Gate D — Foundation strategy

Choose one for the first experiment:

1. Local agent-authored assets only.
2. Licensed/CC0 foundation plus local customization.
3. AI-generated foundation plus local cleanup.
4. A controlled comparison of all three.

## 7. Standard asset pipeline to test

Preferred interchange conventions:

- Models and rigs: glTF 2.0 / `.glb` for Godot integration.
- Blender source: `.blend` retained outside imported runtime assets when useful.
- Textures: PNG or another agreed lossless source format; imported/compressed by Godot.
- Materials: metallic/roughness workflow appropriate to Godot.
- Scale: 1 Blender meter equals 1 Godot meter.
- Orientation: verify forward/up axes through an automated or documented export preset.
- Runtime collision: separate simple collision from render meshes.
- Team variants: material parameters or controlled material variants, not duplicate geometry when avoidable.
- LODs: evaluate after the first representative model; do not create them blindly.

Proposed repository layout, subject to testing:

```text
assets/
  manifests/
  models/
    characters/
    environment/
    weapons/
  materials/
  textures/
  vfx/
  audio/
  source/          # Optional source files; may require Git LFS.
```

Do not establish this structure permanently until one end-to-end import experiment succeeds.

## 8. Required asset manifest

Every external or generated asset tested must record:

- Asset name and category.
- Creator/vendor/service.
- Source URL or generation service/model.
- Acquisition date and price.
- Exact license or terms snapshot/reference.
- Commercial-use permission.
- Godot/non-originating-engine permission.
- Redistribution restrictions.
- Attribution requirements.
- AI-generation or training restrictions when relevant.
- Source files received.
- Modifications made.
- Final runtime files derived from it.

An asset with unclear provenance or incompatible terms does not enter a release branch.

## 9. Controlled experiments

Run these sequentially. Do not attempt a complete art pass during pipeline discovery.

### Experiment 1 — Hero disc launcher model

**Why first:** The first-person weapon is visible in nearly every gameplay frame, hard-surface modeling is relatively agent-friendly, and the existing primitive weapon provides a clear before/after comparison.

Test up to three paths against the same brief:

- Blender/Python agent-authored model.
- Licensed weapon or modular hard-surface foundation customized into a disc launcher.
- AI-generated 3D foundation cleaned in Blender, if a service is approved.

Minimum output:

- Deliberate silhouette rather than joined primitives.
- Beveled hard-surface geometry and intentional normals.
- UVs or another deliberate material-mapping strategy.
- At least three material regions.
- Disc chamber and muzzle details that support animation/VFX.
- Godot-ready `.glb` integrated into the real first-person view.
- One idle screenshot and one firing screenshot from the off-screen capture flow.

Compare:

- Visual quality.
- Agent effort and iteration speed.
- Cleanup required.
- Import reliability.
- Runtime cost.
- Licensing confidence.
- Ease of restyling across visual directions.

#### Experiment 1 result — Solar Nomad launcher vertical slice

The first local-only path succeeded and was refined from model import through firing presentation:

- An original ivory, graphite, solar-alloy, and contained-plasma launcher was generated in Blender.
- User review drove a narrower split-shell silhouette, fewer modeled surface seams, a visibly clamped removable disc, and improved screen placement.
- Editable source, a reproducible Python generator, two optimized GLBs, generated PBR maps, and an asset manifest are retained.
- The source preserves `DiscRotor`, `ChargeCore`, and `MuzzleSocket`; the runtime animates recoil, rotor movement, disc ejection, and recharge.
- The projectile uses a separate GLB exported from the same disc geometry that visibly seats in the launcher.
- The authoritative projectile now starts at the muzzle and converges toward the center reticle.
- Two deterministic 512×512 hero-surface families provide base-color, normal, and roughness maps; secondary mechanisms use compact authored material inputs.
- `tools/test_ground_jet.sh` and `tools/test_multiplayer_demo.sh` passed.
- Dedicated experiment captures cover muzzle fire/recharge; the standardized off-screen live multiplayer capture passed with projectile-flight and impact states.
- Final standardized output is under `build/asset-pipeline/solar-nomad-v2-authority/`; intermediate folders retain the design evolution and dedicated firing frames.

This proves the Blender → UV/PBR material → articulated GLB → Godot integration → authoritative firing → live capture path for a hard-surface hero asset. It does **not** yet prove skeletal animation, licensed-asset adaptation, character/hand integration, or acceptable production speed for a complete environment.

### Experiment 2 — Terrain material set

**Runway result:** A deterministic 256×256 albedo-detail, normal, and roughness set now feeds `assets/materials/terrain/runway_terrain.gdshader`. The Compatibility-safe shader preserves slope/height/contour vertex-color readability while adding world-space micro and macro variation. It is integrated into the live generated terrain and passed off-screen capture. Final directions should improve its top projection on steep faces rather than inherit its appearance blindly.

Test a representative terrain treatment using:

- CC0/licensed PBR textures.
- Procedural/generated textures.
- A hybrid using authored masks and sourced surface detail.

Minimum material families:

- Traversable primary surface.
- Steep rock/cliff.
- Secondary highland or hardpack surface.

Minimum output:

- Albedo/base color.
- Normal detail.
- Roughness response.
- Height/slope/world-space blending.
- Macro variation that does not obviously tile.
- Compatibility-safe shader/material.
- Terrain remains readable at skiing speed and in distant captures.

Judge both still images and traversal states. A texture that looks attractive while stationary but destroys slope readability fails.

### Experiment 3 — Base architecture kit

**Runway result:** `runway_base_kit.glb` replaces both primitive platform render meshes while retaining the original authoritative 14 m box collision. One shared GLB supplies layered deck, pier, braces, approach cheeks, pylons, objective plinth, and signal pieces. The editable source retains 26 construction meshes; the runtime export consolidates them to four material meshes. Runtime team accents avoid duplicated geometry. This is a neutral construction proof, not candidate architecture.

Create or adapt a tiny modular kit rather than a whole environment pack.

Minimum pieces:

- Deck/platform surface.
- Structural support.
- Ramp or terrain transition.
- Wall/edge module.
- Pylon/landmark.
- Objective pedestal.
- Team-color trim or light module.

Minimum output:

- One base transformed enough that default debug-box character is no longer dominant.
- Render mesh remains separate from existing gameplay collision during the experiment.
- Reuse is visible and intentional.
- Materials share a coherent texel density and trim logic.

Compare agent-authored hard-surface construction with a licensed modular foundation if budget permits.

### Experiment 4 — Effects package

Test a small action chain rather than isolated particles:

1. Jet activation or ski contact.
2. Disc muzzle event.
3. Projectile trail.
4. Disc impact.

Minimum output:

- Layered timing: core flash, shape expansion, particles/debris, and decay.
- Clear color and intensity hierarchy.
- Readable against terrain and bases.
- Compatibility-safe particles/materials.
- Client-side presentation that does not alter authoritative results.
- No major overdraw or frame stall in the capture run.

Compare locally authored Godot effects against a licensed VFX foundation only if the pack explicitly supports the needed renderer and redistribution terms.

### Experiment 5 — Character and animation foundation

**Runway result:** A deliberately neutral rigid-skinned momentum-suit mannequin exports one armature/skin and the `MomentumLean` loop. Godot imports it as `Skeleton3D`, 16 skinned mesh parts, and an `AnimationPlayer` with the named animation. It replaces the former primitive multiplayer world model, receives runtime team armor variants, scales animation playback with horizontal speed, remains hidden for the local first-person player, and passed live off-screen multiplayer capture. This removes basic skeleton integration as a bake-off unknown, but the mannequin remains disposable runway art rather than a production character or proof of animation retargeting.

Run only after the earlier experiments clarify the pipeline. Characters are the category least likely to benefit from fully scripted asset creation.

Test:

- One licensed rigged character suited to the chosen fidelity.
- A small animation set: idle, ski/lean, airborne/jet, fire, and death or elimination.
- Material/team-color customization.
- Attachment points for weapon and jet effects.

Do not commission or purchase an expensive character before confirming scale, rig import, animation retargeting, and Godot compatibility with a low-cost representative asset.

## 10. Evaluation rubric

Score each tested path from 1–5:

| Criterion | Meaning |
|---|---|
| In-engine visual quality | Quality of actual Godot captures, not marketplace renders or concepts. |
| Direction flexibility | Ability to support several candidate aesthetics. |
| Cleanup time | Manual/agent work needed after acquisition or generation. |
| Technical reliability | Import, materials, animation, renderer support, and repeatability. |
| Runtime performance | Suitability for the target scene and 60 FPS goal. |
| Licensing confidence | Clarity for commercial builds and repository/export distribution. |
| Cost efficiency | Result relative to purchase/subscription and labor cost. |
| Reproducibility | Can another worker repeat or extend the workflow? |

Record failures as useful outcomes. The purpose is to avoid multiplying a broken pipeline across four visual candidates.

## 11. Capture and comparison protocol

For every experiment:

1. Preserve a baseline capture from the unchanged game.
2. Integrate the asset into the real multiplayer scene.
3. Run the relevant automated checks.
4. Run `tools/capture_visual_qa.sh` with a unique port/output directory.
5. Compare equivalent frames side by side.
6. Record source files, runtime files, commands, time/effort, and known defects.

For model close-ups, a temporary off-screen asset-review scene may be created, but it supplements rather than replaces real gameplay captures.

## 12. Pairing workflow

Use short decision loops to avoid overwhelming context:

1. Agent presents one concrete choice or experiment with a short recommendation.
2. User approves, rejects, or adjusts budget/taste.
3. Agent performs only that experiment.
4. Agent returns a compact result summary plus image paths.
5. User judges whether the quality direction is promising.
6. Detailed notes go into this document or an experiment log rather than the chat response.

The agent should not silently expand an experiment into a full visual pass.

## 13. Deliverables

By the end of exploration, produce:

- A pinned tool list and installation instructions.
- A proven Blender-to-Godot export workflow, if Blender is selected.
- An approved external-service and purchase policy.
- An asset-license manifest template and at least one completed example.
- Results from representative model, texture, base-kit, and VFX experiments.
- A recommendation for character/animation sourcing.
- A version-control decision for binary/source assets and Git LFS.
- Estimated per-direction and winner-refinement budgets.
- A concise asset-pipeline guide workers can follow.
- A go/no-go decision for resuming `docs/archive/VISUAL_BAKE_OFF.md`.

## 14. Resume criteria for the visual bake-off

Remove the hold only when:

- [x] Round 1 target is coherent direction prototypes, using a free-first/local-only asset policy.
- [x] Blender model-production paths have completed successful Godot imports.
- [x] Real weapon and base models demonstrate meaningful improvement over primitives.
- [x] A terrain texture/material path works in Compatibility and the adopted Forward+ renderer.
- [x] A representative firing/projectile/impact VFX chain works in live multiplayer.
- [x] Licensing and manifests are understood for repository-authored Round 1 work.
- [x] Small `.blend` source and runtime assets are tracked directly; `.blend1` backups are excluded. Git LFS remains a later scale decision.
- [x] Worker prompts can name exact tools and asset permissions.
- [x] Standard captures prove the work is more than a palette swap.

The technical hold may now be removed when the user explicitly starts the bake-off. Workers must treat all runway visuals—including Solar Nomad—as disposable examples, not a house style.
