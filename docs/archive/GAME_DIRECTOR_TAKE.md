# Archived Game Director Take

> **Status:** Pre-bake-off production recommendation retained for historical context. Current direction is documented in `docs/production/VISUAL_DIRECTION.md`.

# Executive recommendation

**Use a hybrid pipeline. Do not make “AI-generated 3D packs” the primary production strategy.**

Approve a **$50–$150 pipeline trial**, followed—only if successful—by a **$200–$600 visual-foundation budget**:

- **License the difficult commodity work:** rigged character, animation foundation, selected terrain materials, possibly a modular architecture kit.
- **Create SKOOSH’s identity in Blender/Godot:** disc launcher, bases, flags, objective machinery, team variants, landmarks, shaders, and gameplay VFX.
- **Use AI selectively:** concepts, decals, masks, texture ideation, and occasional blockouts—not final characters, rigs, or an entire coherent 3D pack.

Blender is an excellent production tool, but it does not eliminate the need for modeling, UV, material, rigging, and art-direction judgment.

## Blunt visual assessment

The current build successfully demonstrates **working multiplayer systems**, but visually it still communicates **“engineering prototype” rather than “game people want to share.”**

The main issues visible in the current captures are:

1. **Primitive bases:** large floating slabs do not suggest a believable place or competitive arena.
2. **Placeholder first-person weapon:** it occupies every gameplay frame, making the whole build feel temporary.
3. **Limited terrain vocabulary:** slopes are more readable than before, but surfaces lack material identity, scale cues, route language, and landmarks.
4. **Placeholder player presentation:** the silhouette is understandable, but still reads as assembled primitives; it needs animation and better material hierarchy.
5. **Weak action spectacle:** discs, impacts, jetting, skiing, landings, flag pickup, and capture need a cohesive effects language.
6. **Unresolved art direction:** the HUD has personality, while terrain, architecture, weapon, and characters do not yet feel like one universe.

The earlier Y2K-style experiment confirms an important point: **palette and lighting changes alone will not cross the quality threshold. Real assets and motion treatment are now required.**

## What the demo needs most

The target should be one excellent **15–30 second gameplay sequence**:

> Spawn at a recognizable team base → see another armored player jet away → ski downhill with strong speed and terrain feedback → fire a clearly visible disc → get a satisfying impact → steal an unmistakable flag → return to a visibly energized capture structure → trigger a memorable win effect.

Everything purchased or created should support that sequence.

### Priority 1 — Hero disc launcher

This is the highest-return asset because it appears in nearly every frame.

It needs:

- A deliberate, recognizable silhouette.
- A visible disc chamber or energy mechanism.
- Three or four controlled material families.
- Firing movement, recoil or mechanical response.
- Muzzle flash, projectile launch, reload/cooldown feedback.
- Team-neutral identity distinct from generic rifle packs.

**Recommendation:** make this custom in Blender. A licensed hard-surface kit may provide components, but the final silhouette should belong to SKOOSH.

### Priority 2 — Modular base and objective kit

Create a small kit, not a giant environment:

- Platform/deck.
- Supports and terrain transitions.
- Edge barriers and ramps.
- One strong pylon or antenna landmark.
- Flag pedestal and capture structure.
- Team-color trim/light modules.

The red and blue bases must be identifiable by **silhouette and architecture**, not just large colored floors.

**Recommendation:** adapt a licensed modular foundation or build a small custom kit. Avoid dropping an entire marketplace environment into the arena.

### Priority 3 — Terrain material and route language

The terrain must be readable at 30–60 m/s, not merely attractive in screenshots.

It needs:

- Traversable hardpack/snow/synthetic surface.
- Steep rock or non-ideal terrain.
- Secondary highland material.
- World-space or triplanar blending.
- Macro variation without visible tiling.
- Edge, contour, or directional cues.
- A few large landmarks for navigation and scale.

**Recommendation:** licensed/CC0 PBR source textures plus a custom Godot shader. Do not generate unique textures for the entire landscape.

### Priority 4 — Character and animation foundation

Remote players need to communicate movement and intent immediately:

- Strong armored silhouette.
- Red/blue identification without full-body neon.
- Idle and grounded stance.
- Forward ski lean.
- Airborne/jet pose.
- Firing response.
- Hit/death or elimination treatment.
- Jet attachment points and weapon grip.

**Recommendation:** license this. Rigging, skinning, animation, and retargeting are poor places for a small team to reinvent the wheel or rely on AI-generated output.

### Priority 5 — Complete motion/VFX package

For a movement game, effects are not decoration; they sell the core mechanic.

Required chain:

- Ski contact streaks or snow/dust.
- Speed-sensitive trail intensity.
- Jet core, exhaust, heat/energy tail.
- Landing burst.
- Disc muzzle event.
- Readable projectile trail.
- Layered impact: flash, expanding shape, particles/debris, decay.
- Damage direction and hit confirmation.
- Flag pickup/carrier aura.
- Capture/win event.

**Recommendation:** author these in Godot, optionally using a licensed VFX pack for textures or emitters. They must be tuned around SKOOSH’s weapon timing and Compatibility renderer.

## Buy versus build

| Category | Direction |
|---|---|
| Rigged character | **Buy/license** |
| Core animation set | **Buy/license and adapt** |
| Terrain source materials | **CC0 or license** |
| Generic structural components | **License selectively** |
| Hero disc launcher | **Custom Blender asset** |
| Bases/objective machinery | **Custom or heavily customized kit** |
| Flags, beacons, team trim | **Custom** |
| Gameplay VFX | **Custom in Godot** |
| Sky/lighting/shaders | **Custom in Godot** |
| Decals, masks, symbols | **Custom; AI-assisted is reasonable** |
| AI-generated 3D characters/rigs | **Avoid for the demo foundation** |

## Why not rely primarily on AI 3D?

AI 3D can produce an attractive isolated object, but the recurring costs are:

- Unpredictable topology and shading.
- Weak UVs and material separation.
- Inconsistent scale and design language.
- Rigging and animation problems.
- Significant Blender cleanup.
- Difficulty making a coherent modular kit.
- Uncertain provenance or commercial terms depending on service.
- Poor reproducibility when another contributor must extend the set.

It is worth testing on **one non-critical prop**, but it should have to outperform both custom Blender work and licensed adaptation in an actual Godot capture before being trusted.

## Recommended visual direction

For the immediate demo, I would favor **clean broadcast combat sport with rugged expeditionary details**.

That direction:

- Fits the compact symmetrical CTF arena.
- Makes teams, routes, projectiles, and objectives easy to read.
- Works well with controlled low-poly geometry and Compatibility rendering.
- Requires less content than realistic alpine military art.
- Is less risky and asset-intensive than monumental alien architecture.
- Can still gain personality through industrial supports, worn surfaces, branded symbols, and a distinctive disc weapon.

Avoid sterile white test-chamber aesthetics and indiscriminate neon.

## Spending plan

### Stage 1 — Pipeline proof: $50–$150

Prove three things in the real game:

1. One polished disc launcher.
2. One representative base module/pedestal.
3. One terrain material family and disc-impact chain.

Install a pinned Blender version, export through `.glb`, and evaluate real visual-QA captures. Do not bulk-buy packs yet.

### Stage 2 — Foundation: $200–$600

After the direction is approved:

- Rigged character and animation foundation.
- One coherent modular architecture source, if needed.
- Terrain/material sources.
- Limited VFX or hard-surface support assets.
- Budget reserve for a missing animation, conversion tool, or replacement asset.

If substantially more money becomes available, the next best investment is probably **a focused freelance artist cleanup/art-direction pass**, not five more unrelated asset packs.

## Purchase rules

Before buying anything, record:

- Exact license and commercial-use rights.
- Whether redistribution in game builds is allowed.
- Any engine-specific restrictions.
- Source formats included.
- Rig and animation details.
- Texture resolution and material workflow.
- Godot/glTF import viability.
- Required attribution.
- Whether the visual style matches the chosen direction.

**Coherence beats quantity.** One character, one weapon, one seven-piece base kit, three terrain materials, and one polished VFX chain will demo better than a library of mismatched sci-fi packs.

## Meeting-ready decision

> Approve a hybrid asset strategy and a $50–$150 controlled pipeline trial. License characters, animations, and selected material foundations; build the disc launcher, objective architecture, visual language, and gameplay effects specifically for SKOOSH. Treat AI 3D as an experiment, not the production plan. Release the broader $200–$600 budget only after the representative assets improve the real in-engine demo rather than merely looking good in marketplace renders.
