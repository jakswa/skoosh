# Asset pipeline tools

## Solar Nomad disc launcher

This pipeline experiment creates an original hard-surface first-person weapon and matching projectile using Blender Python. It saves editable source, generates deterministic PBR texture maps, and exports optimized Godot-ready GLBs.

From the repository root:

```bash
blender --background --python tools/asset_pipeline/create_solar_nomad_launcher.py
```

Expected outputs:

```text
assets/source/weapons/solar_nomad_disc_launcher.blend
assets/textures/weapons/solar_nomad/*.png
assets/models/weapons/solar_nomad_disc_launcher.glb
assets/models/weapons/solar_nomad_disc.glb
```

The editable source retains 23 named construction meshes, UVs, non-destructive bevel modifiers, and the `DiscRotor`, `ChargeCore`, and `MuzzleSocket` animation contract. The launcher export preserves those articulated groups while consolidating static geometry by material and parent group. The separate projectile GLB comes from the same disc geometry that seats inside the launcher.

The generated ceramic and solar-alloy material families each provide base-color, normal, and roughness maps. Graphite, gunmetal, and emissive energy use compact authored material inputs; this keeps the projectile lightweight and avoids surface noise on the simplified mechanism.

The current Blender 5.2 installation reports that its optional online-extension module cannot import `cattrs`, but local modeling, texturing, `.blend` saving, and GLB export complete successfully. This pipeline does not use the online-extension module.

After changing the generator, rerun it and allow Godot to reimport both GLBs before capture. Validate the live integration with:

```bash
./tools/test_ground_jet.sh

SKOOSH_TEST_PORT=19108 \
SKOOSH_TEST_LOG_DIR="$PWD/build/asset-pipeline/solar-nomad/test-logs" \
./tools/test_multiplayer_demo.sh

SKOOSH_VISUAL_QA_PORT=29111 \
SKOOSH_VISUAL_QA_DIR="$PWD/build/asset-pipeline/solar-nomad" \
./tools/capture_visual_qa.sh
```

## Reusable runway examples

The launcher generator proved one hero asset. The runway examples exercise the same repository-local approach across additional domains without establishing an art direction.

```bash
# Deterministic terrain albedo/detail-normal/roughness maps.
python tools/asset_pipeline/create_runway_terrain_textures.py

# Shared static base GLB: editable construction meshes are saved before the
# runtime copy is consolidated to one draw mesh per material.
blender --background --python tools/asset_pipeline/create_runway_base_kit.py

# Technical skinned mannequin with a named skeleton and MomentumLean animation.
blender --background --python tools/asset_pipeline/create_runway_suit_rig.py
```

`blender_asset_utils.py` contains direction-neutral construction, UV, material, static-consolidation, save, and GLB-export helpers. Candidate generators should import it while keeping dimensions and design decisions in their own scripts.

The base kit is instantiated for both teams from one GLB. `team_base_visual.gd` supplies presentation-only team material variants while the original simple collision remains authoritative. The terrain shader adds deterministic world-space detail to existing gameplay-derived vertex colors. The neutral character replaces the former primitive multiplayer world model and proves that Blender armatures, skin data, named animation, team material overrides, local-player hiding, and remote-player presentation survive the complete path. It remains disposable bake-off runway art, not a production character.

Verify the imported contracts headlessly:

```bash
./tools/test_asset_pipeline.sh
```

Visually inspect the animated skinned mannequin in the dedicated turntable scene:

```bash
./tools/run_asset_pipeline_review.sh
```

This launches only the review scene. The same rig is also installed as the current remote multiplayer world model; local first-person players remain hidden from their own world model as before.

Current source policy for these small experiments is to track `.blend` source directly and exclude Blender `.blend1` backups. Reconsider Git LFS if production source files or texture sets become materially larger.

Asset provenance and source/runtime statistics are recorded under `assets/manifests/`.

## Kestrel Basin bake-off assets

The alpine-expeditionary candidate generates its induction launcher, matching relay disc, and shared braced relay station from one repository-local Blender script:

```bash
TMPDIR="$PWD/.tmp" blender --background --python tools/asset_pipeline/create_alpine_expedition_assets.py
```

Editable launcher and station `.blend` files are retained. The runtime GLBs use graphite, worn ceramic, expedition-orange hardware, narrow team markings, and neutral mint relay materials without external textures. Provenance and binary sizes are recorded in `assets/manifests/kestrel_basin_assets.json`.

## Forward+ qualification decal

The renderer experiment uses one neutral landing-zone decal to demonstrate projected decals without anchoring a future direction to team-specific source art:

```bash
python tools/asset_pipeline/create_forward_plus_showcase_textures.py
```

This writes `assets/textures/environment/forward_plus_base_decal.png`. RED and BLUE tint the same texture at runtime. See `docs/plans/FORWARD_PLUS_EVALUATION.md` for the lean, balanced, and showcase feature profiles.
