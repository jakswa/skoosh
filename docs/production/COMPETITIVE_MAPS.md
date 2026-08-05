# Competitive CTF Maps

SKOOSH ships two maps in the competitive rotation. Both use deterministic,
authored height functions, one render mesh, and one matching trimesh collider.
The catalog drives the server and every client from the same `--map` ID; a peer
that reports a different ID is disconnected before its playable avatar spawns.

## Production Rotation

| Map | Footprint and team axis | Terrain and routes | Sightline and identity |
|---|---|---|---|
| Faultline Basin | 704 m x 448 m mesh; long rounded-capsule play space; RED/BLUE west/east | East-west fault trench, exposed north basalt spine, and south recovery gully screened by a continuous shoulder | Direct low trench view between bases; violet basalt night, mineral haze, split fault spires |
| Cairn Steps | 480 m x 672 m mesh; north-south superellipse; RED/BLUE south/north | Transverse stepped escarpment crossed by an exposed east chute, screened west switchback, and high central jet saddle | Escarpment blocks direct base view; chalk hardpack, graphite cuts, survey-day atmosphere, stacked cairns |

These are terrain routes, not prop suggestions. Route contracts sample grade at
four-meter intervals and require stable landing normals at named recovery points.
Team red and blue remain route/objective accents; biome colors do not replace
team navigation.

The playable boundaries begin rising inside OOB and leave only a 20-24 m
collision margin before the visible mesh edge. Faultline uses a capsule boundary
and Cairn a superellipse, avoiding both the former square-box edge and a
deceptive expanse of rendered-but-unplayable terrain. The server evaluates these
curved boundaries and owns recovery and carried-flag return. A steep collidable
terrain crest is the primary stop; sixteen neutral signal beacons mark its inner
approach. OOB recovery remains a failsafe for exceptional launches over the rim.

## Selection

Faultline is the default. Select Cairn explicitly on the server and every client:

```bash
SKOOSH_MAP_ID=cairn_steps ./tools/run_multiplayer_demo.sh
```

Direct process arguments use `--map=faultline_basin` or `--map=cairn_steps`.
`--map=kestrel_basin` remains available only as an explicit legacy/test arena;
Kestrel is not in the production rotation.

## Automated Evidence

```bash
./tools/test_competitive_maps.sh
./tools/test_map_mismatch.sh
SKOOSH_TEST_MAP=faultline_basin ./tools/test_multiplayer_demo.sh
SKOOSH_TEST_MAP=cairn_steps ./tools/test_multiplayer_demo.sh
```

The map suite rejects a compact or rotated clone pair through production-count,
aspect, curved-boundary, recovery-rise, base-separation, measured terrain
symmetry, lane-spacing, route-length, route-grade, landing-normal, direct
sightline, swapped-profile-distance, palette, environment, mesh, and collider
contracts.

Automated geometry and match completion are not evidence of human competitive
balance. The maps still need repeated offense/defense route timing, spawn
pressure, skiing feel, visibility, impairment, minimum-spec, and spectator
playtests. The procedural terrain/material and primitive landmarks establish a
coherent production map direction, not final production art.

Each multiplayer map run reserves its first capture for a collision-driven bot
traversal of every waypoint on that map's authored acceptance route. The server
tags that capture `route=full`; the harness rejects acceleration unless it sees
that evidence first. The explicit `--acceptance-mode --require-ctf` seam then
server-positions the same carrier for separate normal pickup and capture-volume
contacts. This keeps `_capture_flag()` eligibility and authority intact while
proving scores 1-2-3, both two-second objective rearms, the five-second
intermission, zero-score reset, and duplicate rejection in one roughly
116-second wall-clock run per map: a 110-second timed scenario, three-second
coordinated shutdown grace, and process launch/teardown overhead.
