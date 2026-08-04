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

## Historical reusable runway examples

The launcher generator proved one hero asset. These historical runway examples
exercised the same repository-local approach across additional domains before
the visual bake-off; they did not establish the current art direction.

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

The base kit demonstrated one GLB instantiated for both teams, with
`team_base_visual.gd` supplying presentation-only material variants while
simple collision remained authoritative. The terrain shader demonstrated
deterministic world-space detail over gameplay-derived vertex colors. The
neutral runway character formerly replaced the primitive multiplayer model and
proved the armature, skin, animation, team override, and local-player hiding
path. It is historical disposable runway art and is not a current runtime
character.

Verify the imported contracts headlessly:

```bash
./tools/test_asset_pipeline.sh
```

The current review scene shows the three runtime shells described below. The
runway mannequin remains available only as historical source/runtime output.

```bash
./tools/run_asset_pipeline_review.sh
```

This launches only the review scene; it does not change multiplayer state.

Current source policy for these small experiments is to track `.blend` source directly and exclude Blender `.blend1` backups. Reconsider Git LFS if production source files or texture sets become materially larger.

Asset provenance and source/runtime statistics are recorded under `assets/manifests/`.

## Selected Kestrel hybrid direction

The selected direction keeps Kestrel's daytime palette and practical materials,
adds STRATOS route grammar and aerofoil equipment, and uses Khepri's triune
monument/objective vocabulary. Generate the launcher, matching disc, and shared
relay station with:

```bash
TMPDIR="$PWD/.tmp" blender --background --python tools/asset_pipeline/create_alpine_expedition_assets.py
```

Generate the formerly selected remote-player character separately:

```bash
TMPDIR="$PWD/.tmp" blender --background --python tools/asset_pipeline/create_vector_expedition_runner.py
```

The launcher has a visible disc seat/feed path and an open rectangular launch
gate rather than a circular barrel. The Vector Expedition Runner preserved the
proven bone names and `MomentumLean` contract while replacing the runway
mannequin's geometry, posture, equipment, and animation. It was the selected
runner after the bake-off but has since been superseded at runtime by the three
character shells below. Editable `.blend` sources are retained. Provenance is recorded in
`assets/manifests/kestrel_basin_assets.json` and
`assets/manifests/vector_expedition_runner.json`.

## Character shell variants

Generate the three runtime character shell variants:

```bash
TMPDIR="$PWD/.tmp" blender --background --python tools/asset_pipeline/create_character_shell_variants.py
```

This one deterministic generator writes editable `.blend` source and matching
Godot-ready `.glb` files for Vector Sprinter Mk II, STRATOS Foilframe, and
Khepri Triune Salvage. All three use the exact same 12-bone contract, 50 named
rigid-skinned mesh roles (36 established shell roles plus 14 overlapping
articulation interfaces). Their `MomentumLean` clips change the same six
non-root bones and never change the Root transform; importer-generated constant
Root channels are permitted and may be removed by Godot as immutable tracks.
The role names used by runtime team overrides remain intact. Multiplayer uses
these three current runtime shells as server-assigned, presentation-only
character variants.

Run `./tools/test_asset_pipeline.sh` to import and contract-check all three.
Run `./tools/run_asset_pipeline_review.sh` to view the animated lineup. Design,
provenance, output statistics, and limitations are recorded in
`assets/manifests/character_shell_variants.json`.

## Forward+ qualification decal

The renderer experiment uses one neutral landing-zone decal to demonstrate projected decals without anchoring a future direction to team-specific source art:

```bash
python tools/asset_pipeline/create_forward_plus_showcase_textures.py
```

This writes `assets/textures/environment/forward_plus_base_decal.png`. RED and BLUE tint the same texture at runtime. See `docs/decisions/FORWARD_PLUS_EVALUATION.md` for the lean, balanced, and showcase feature profiles.
