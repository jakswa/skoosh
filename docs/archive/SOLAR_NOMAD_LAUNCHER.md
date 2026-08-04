# Solar Nomad Disc Launcher — Design and Iteration Brief

**Status:** Successful asset-pipeline prototype. Its visual model and firing concept are expected to be replaced rather than incrementally polished.

> **Decision:** Treat the current launcher as disposable prototype art. A future launcher pass should start from a fresh concept and may replace all visible geometry, proportions, materials, and animation. Preserve only the proven pipeline and any technical contracts that still make sense.

This file preserves lessons from the prototype so a scorched-earth redesign does not repeat its mistakes. It is not a declaration that SKOOSH must keep the Solar Nomad aesthetic.

## 1. Why this prototype exists

The launcher is the first end-to-end test of whether an agent can create an original hero asset rather than rearranging Godot primitives.

It tests:

- Scripted hard-surface construction in Blender.
- Editable `.blend` source and reproducible generation.
- UVs and generated PBR texture maps.
- Articulated export hierarchy.
- Optimized GLB import into Godot's Compatibility renderer.
- First-person animation and gameplay-responsive presentation.
- A shared source design for seated ammunition and the projectile.
- Real authoritative multiplayer integration and off-screen capture.

The test has succeeded as a pipeline proof. The current launcher remains prototype art.

## 2. Current visual direction

**Working name:** Solar Nomad

Visual vocabulary:

- Pale ceramic structural shells.
- Dark graphite receiver and mechanical spine.
- Restrained solar-alloy/gold hardware.
- Cyan contained-energy accents.
- A visible removable disc held in a top-mounted cradle.
- Split forward rails intended to communicate acceleration and direction.

The redesign moved away from the first pass's broad slab and decorative platter. The current version uses a narrower split shell, exposed center channel, compact receiver, and three physical disc clamps.

## 3. What is working

User playtest feedback confirms that the result is a major improvement over the placeholder and that the asset pipeline is already compelling.

Strong elements:

- The launcher reacts convincingly to scene lighting.
- The first-person silhouette is intentional and recognizable.
- The visible disc, recoil, rotor movement, disappearance, and recharge provide satisfying state feedback.
- The weapon now occupies a more useful position in the first-person frame.
- The disc cradle is visibly attached rather than accidentally intersecting the cowling.
- Generated ceramic and alloy surfaces establish material separation without external assets.
- The source can be regenerated and substantially redesigned quickly.
- Gameplay tests continue to pass with server-authoritative combat.

## 4. Current design problems

### 4.1 Bulk and surface quality

The launcher is still somewhat bulky and visually janky:

- Some large surfaces remain too planar and thick.
- The front rails can read as a tuning fork or architectural beams rather than a handheld weapon.
- Smart UV projection and procedural micro-detail do not replace deliberate hero-asset UV layout.
- Bevel width, shell thickness, and edge rhythm are not yet consistently art-directed.
- The model has no hands or body contact to communicate scale and ergonomics.

A future pass may revise individual pieces or replace the whole generated design. The generator is an iteration tool, not a constraint.

### 4.2 The firing mechanism does not tell a coherent story

The disc visibly disappears from the top cradle, but the projectile begins at the forward muzzle. Nothing currently shows how the disc travels from cradle to muzzle.

This makes the animation satisfying as feedback but mechanically confusing.

The next design must choose one clear firing story:

1. **Rail-fed launcher:** clamps release, the disc slides or snaps into the center channel, accelerates down the rails, and exits at the muzzle.
2. **Top-launch catapult:** the cradle itself energizes and throws the disc directly forward; the projectile origin moves to the cradle and the forward rails are redesigned or removed.
3. **Energy-template weapon:** the seated object is explicitly a charge/template rather than the physical projectile; effects must communicate that distinction.

The recommended direction is **rail-fed launcher** because it explains the existing split rails and preserves the satisfying visible ammunition.

### 4.3 The projectile does not yet read as the seated disc

The projectile GLB is exported from the same charge geometry, but visual continuity is not currently convincing in motion.

Likely causes:

- Projectile orientation does not present the disc silhouette clearly from common viewing angles.
- Its scale, rim thickness, and emissive balance differ perceptually from the seated version.
- The trail, glow, and muzzle flash can obscure the underlying geometry.
- A symmetrical spinning disc provides few motion cues.
- The Godot projectile orientation and Blender disc axes have not been deliberately art-directed together.

A future pass should:

- Validate the projectile's local axes and facing in a dedicated review scene.
- Use the same physical scale for seated and flying versions unless expansion is explicitly part of the fiction.
- Add a readable rim and one asymmetric rotating index.
- Tilt or bank the disc enough to preserve its silhouette while moving.
- Attach the trail to the disc center without hiding the rim.
- Tune emissive energy so the projectile is a disc first and a glow second.

### 4.4 Socket duplication

The Blender hierarchy exports a `MuzzleSocket`, but gameplay currently uses a manually positioned Godot `MuzzleOrigin` in `scenes/network_player.tscn`.

That duplication is fragile and contributed to the visual/mechanical mismatch. The next pipeline iteration should consume an authored socket or export marker directly, then derive gameplay/VFX attachment from it. The authoritative server must use the same deterministic transform.

### 4.5 Animation remains procedural

Current presentation in `scripts/network_player.gd` provides:

- Recoil.
- Rotor spin.
- Disc disappearance and recharge.
- Idle motion.

This is useful and responsive, but it is not a fully authored mechanical animation. The next pass should preserve named moving groups and use an `AnimationPlayer` or a focused weapon-view script for a deliberate sequence. A pre-fire charge would alter gameplay timing; a post-fire reload/recharge can remain purely presentational.

## 5. Current asset contract

Primary source and generator:

```text
tools/asset_pipeline/create_solar_nomad_launcher.py
assets/source/weapons/solar_nomad_disc_launcher.blend
```

Generated runtime assets:

```text
assets/models/weapons/solar_nomad_disc_launcher.glb
assets/models/weapons/solar_nomad_disc.glb
assets/textures/weapons/solar_nomad/
```

Important exported nodes:

- `SolarNomadDiscLauncher`
- `DiscRotor`
- `ChargeCore`
- `MuzzleSocket`

Godot integration:

```text
scenes/network_player.tscn
scenes/disc_projectile.tscn
scripts/network_player.gd
scripts/network_weapon.gd
```

Provenance and statistics:

```text
assets/manifests/solar_nomad_disc_launcher.json
```

Regenerate from the repository root:

```bash
blender --background --python tools/asset_pipeline/create_solar_nomad_launcher.py
```

Godot must reimport both GLBs afterward.

## 6. Recommended next launcher pass

Perform this only when launcher redesign is again the active priority:

1. Create a fresh style/mechanical brief and a four-frame firing sequence before modeling.
2. Build a new silhouette blockout without reusing the current visible body as a constraint.
3. Approve first-person proportions and mechanical readability before UVs or surface polish.
4. Replace the manual muzzle transform with the authored socket contract.
5. Animate the physical disc through the newly chosen firing mechanism.
6. Correct projectile orientation, scale, rim, trail, and glow until it unmistakably matches.
7. Author shell thickness, bevel hierarchy, UV seams, and material roughness as one coherent design.
8. Add a temporary hand/arm foundation to evaluate ergonomics and scale.
9. Capture seated, firing, flight, impact, and recharge states from the live game.

## 7. Acceptance criteria

The launcher is ready to graduate from pipeline prototype when:

- [ ] A viewer can explain how the disc moves from storage to launch by watching it once.
- [ ] The projectile visibly matches the seated ammunition.
- [ ] Projectile and VFX originate from authored sockets.
- [ ] Recoil and reload/recharge animation have readable timing and no teleporting parts.
- [ ] Broad surfaces have intentional UVs, normals, thickness, and edge hierarchy.
- [ ] The weapon reads as handheld once arms are present.
- [ ] No prominent geometry appears embedded, floating, or accidentally intersecting.
- [ ] Compatibility-renderer captures remain readable at rest and speed.
- [ ] Ground-jet, multiplayer, and visual-QA validation pass.

## 8. Pipeline lesson

The most important result is not the current launcher design. It is that the project can now produce, critique, regenerate, integrate, animate, and validate a real custom asset. Future work should keep that loop while applying a stricter concept/mechanical brief before investing in surface polish.
