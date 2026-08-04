# SKOOSH Visual Direction

## Selected direction

SKOOSH uses **Kestrel Day** as its current production foundation: cold hardpack,
dark slate, warm low sun, cool distance, graphite mechanisms, weathered ceramic,
expedition orange, and mint neutral technology. Team red and blue remain
controlled navigation/gameplay accents rather than whole-surface washes.

The selection deliberately incorporates:

- STRATOS contour bands, route lanes, timing marks, and aerofoil equipment shape.
- Khepri's triune monument, capture-cage, and asymmetric-symbol vocabulary.
- Three character shells spanning Vector, STRATOS, and Khepri silhouettes, with
  restrained shared team roles and a root-motion-free lean loop.
- An open-slot disc launcher with a visible seated disc and feed path. Circular
  barrels, muzzle lenses, and nozzle rings are outside the weapon language.

## Theme catalog

These are map vocabularies, not runtime skins. A future map may select one
coherent package while preserving shared gameplay semantics and authority.

| Theme | Atmosphere | Terrain | Architecture and technology | Best future use |
|---|---|---|---|---|
| Kestrel Day | Warm low sun, cool shadows, clear distance | Pale hardpack, slate, restrained route paint | Field-rigged ceramic/graphite relays, mint survey signals | Primary competitive daytime maps |
| Khepri Night | Bruised violet night, restrained mineral haze | Iron shelves, blue-black cliffs, broad strata | Oxidized monuments, amber charge, triune cages | Night maps, ancient facilities, high-identity events |
| STRATOS Graphic | High-key broadcast light, clean distance | Synthetic chalk/slate, explicit contours and timing marks | Modular gates, regulated equipment, broadcast geometry | Training, tournament, and spectator-focused maps |

Do not mix all three palettes on one map. Shared elements should be semantic:
traversable ground, steep terrain, team ownership, objective state, warning,
neutral technology, and route guidance. Each map authors those semantics in its
own coherent material and atmosphere family.

## Asset rules

- A seated disc must visibly correspond to the flying disc.
- Disc launchers use rails, gates, clamps, or fields, never conventional barrels.
- Team color targets approximately one quarter of a character or structure.
- Decorative geometry must not imply authoritative collision on competitive routes.
- Character silhouettes prioritize helmet, shoulder/hip sweep, and twin jet pods.
- Character shells use overlapping graphite articulation volumes; rigid armor
  may separate by value, but may not read as floating anatomy at play scale.
- Team recognition must survive 48-96 px through helmet, chest/bib, pelvis, and
  pod/shoulder planes rather than relying on small trim or warning accents.
- First-person hands, production deformation, and complete movement animations
  remain future work and must not be implied by prototype rigs.

## Renderer budget

Balanced Forward+ remains the baseline. Lean disables SSAO and volumetric fog;
terrain values, route marks, team accents, objective silhouettes, and launcher
readability must survive that fallback. TAA, SSR, SSIL, and SDFGI remain opt-in
only when a map demonstrates visible benefit and records its cost.

## Gameplay boundary

Themes own presentation only. Terrain topology/collision, movement, energy,
combat, objective contact, score, and replication remain authoritative and may
not vary with a visual theme.
