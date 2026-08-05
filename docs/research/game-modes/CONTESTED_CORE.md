# Contested Core

**Revision:** 0.1

**Lifecycle:** Explore

**Last reviewed:** 2026-08-03

**Status:** Lead research concept, not an adopted mode or implementation plan.

## Research Purpose

**Question:** Can a spatial shooting contest produce a legible, satisfying
transition into skiing, carrying, pursuit, and interception at solo-to-2v2
population?

**Hypothesis:** Independent team calibration around an occluding central relay
will make players move for firing angles, then create a pursuit whose route
decisions matter more than simple following.

**Evidence that would weaken the hypothesis:** Players wait beside targets,
cannot explain unlock ownership, treat calibration as a chore, or see most
possessions resolve without a route choice or credible interception.

**Expected loop duration:** 20-60 seconds from first target window through
score or reset.

**Minimum meaningful population:** Solo practice; 1v1 contest.

**Expected competitive population:** 2v2 through 5v5.

## One-Sentence Pitch

Both teams converge on a central relay, shoot spatial targets to release a
Core, then carry it across the terrain to a scoring destination while the
other team pursues, intercepts, and can steal it for a reversal.

## Player Fantasy

The relay begins dormant at the center of a broad basin. Target plates wake
around its circumference, forcing players to move for clean firing angles while
fighting one another. One team may complete calibration first, but release and
pickup policy decide who breaks the Core out of its cage. Defenders decide
whether to follow, cut ahead, or fall back toward the destination. A dropped
Core can reverse the entire play.

The intended rhythm is:

1. **Converge:** travel, posture, and choose an approach to the relay.
2. **Calibrate:** shoot exposed targets while contesting useful terrain.
3. **Break out:** collect the released Core and establish a route.
4. **Pursue:** escort, follow, or take an interception line.
5. **Resolve:** score, steal, expire, or reset.

This creates a pulse of quiet approach, concentrated conflict, and open-field
movement rather than permanent urgency.

## Why Start Here

- It directly tests the player fantasy proposed in the current design discussion.
- It reuses authoritative projectiles, teams, flag carrying, drops, goals,
  score, and round state.
- It works as solo route practice when no opponent is present.
- It can support a base-oriented or base-less destination without changing the
  central interaction.
- The central relay creates an obvious place for available players to
  congregate without forcing everyone in the server to participate.
- It tests shooting while moving before requiring another weapon.

## Unlock Rule Candidates

The unlock should reward firing position and movement, not raw damage output.

| Rule | Description | Strength | Main risk |
|---|---|---|---|
| Shared breach | Everyone damages a common set of targets; the Core opens when all break. | Cheapest and immediately legible. | Encourages last-hit waiting and lets one team benefit from the other's work. |
| Team calibration | An active plate accepts one direct hit from each team during a short window; teams accumulate independent charge. | No last-hit theft or health sponge; works at 1v1. | Can become a rotating aim gallery if geometry does not demand movement. |
| Resonator control | Three spatial targets temporarily belong to the last team that hit them; owning all three releases the Core. | Creates movement, denial, and reversals. | Can stalemate or become hard to read at low population. |
| Combat-fed release | Kills, damage, or movement feats charge each team's release meter. | Integrates the wider fight. | Snowballs combat advantage and obscures why the Core opened. |

### Recommended First Unlock Test

Use **team calibration** before adding a scoring destination:

- Six target sockets surround an occluding relay monument.
- One socket telegraphs, then opens for a three-second window.
- A direct disc hit registers that team for the current target window.
- Splash does not count and repeated team hits in the same window add nothing.
- Both teams can register during the same window.
- The sequence alternates around the relay so one firing perch cannot solve it.
- At the end of the active window, each registered team receives one charge.
- Thresholds resolve only after those charges are awarded, never immediately on
  projectile impact.
- If one team reaches three or four charges, the Core releases.
- If both teams reach the threshold at the same window close, release is tied
  rather than decided by packet or projectile ordering.

This is a research default, not a final choice. Compare it against one
resonator-control session before promotion to `Prototype`.

## Release And Pickup Variants

Calibration success and possession are separate decisions. Compare these
variants explicitly rather than changing them between sessions:

| Variant | Release behavior | Research use |
|---|---|---|
| Neutral ejection | The Core rises from the cage and is immediately available to either team. | Cheapest default; tests whether position earned during calibration is enough initiative. |
| Short claim | A sole calibration winner receives a 1.5-second pickup claim; tied release is neutral. | Tests whether unlock effort otherwise feels unrewarded. |
| Directional ejection | The Core ejects toward the sole winning team's current side with no ownership lock; a tie ejects vertically and neutral. | Creates physical initiative but may couple fairness to map geometry. |
| Immediate possession | On a sole-team release, that team's final valid shooter becomes carrier; a tied release uses neutral ejection. | Preserved as a fast variant, but risks arbitrary range transfers and packet-order perception. |

Use **neutral ejection** for the first local graybox. If repeated human evidence
shows that opponents routinely steal release despite losing calibration, test
the short claim next. Do not add claim time preemptively.

## Destination Variants

The destination changes the emotional shape of the entire mode and must remain
an explicit experiment.

| Variant | Carrier destination | What it emphasizes | Main risk |
|---|---|---|---|
| Home delivery | The carrier's own team uplink. | Familiar retreat, escort, home identity, and casual base defense. | Unlock winner may simply withdraw to safety; defenders can feel permanently behind. |
| Enemy assault | The opposing team's goal. | Penetration, prepared defense, open-field turnovers, and difficult finishes. | Goal camping and repeated defender respawns can suppress low-pop carriers. |
| Rotating extraction | One announced neutral uplink elsewhere in the basin. | Base-less route variety and map circulation. | Destination changes can feel arbitrary or overload objective markers. |
| Out-and-back | A distant gate arms the Core; scoring requires returning through center. | Route practice, repeated central encounters, and readable solo play. | Return geometry may become repetitive and center camping may dominate. |

The cheapest casual prototype is **home delivery**. The strongest base-defense
hypothesis is **enemy assault**. The strongest no-base hypothesis is **rotating
extraction**. Do not combine destination rules within one session block.

## Core Rules For A Graybox

- The server owns release, pickup, carrier team, drops, destination, timers,
  score, and reset.
- Carrying initially changes no movement, jet, health, or weapon values.
- The carrier remains able to fire.
- The Core is visible on the player model and produces a restrained trail.
- The carrier and valid destination are marked in world space and on the HUD.
- Death, disconnect, or manual respawn drops the Core at the last server-valid
  in-bounds position.
- Out-of-bounds carrier recovery returns the Core directly to the relay.
- A forced drop has a 0.5-second global pickup lockout, then becomes available
  to either team.
- A turnover immediately changes the valid destination and presentation.
- An unattended dropped Core returns to the relay after roughly eight seconds.
- A possession timer may return the Core after roughly 45 seconds, but should
  be tested against a timer-free casual form rather than assumed necessary.
- There is no passing, throwing, inventory, carrier ability, or movement
  penalty in the first experiment.

## Open And Competitive Forms

### Open Relay

- The server runs continuously with no match clock or score limit.
- A solo player can unlock and deliver the Core as a practice run.
- A practice run becomes an exhibition run immediately if human opposition
  joins an active team or damages/interacts with its carrier. It cannot set a
  solo record or formal score.
- The next release begins under normal contested scoring if both teams have
  active participants.
- Players may remain in the lounge, practice elsewhere, watch, or enter the
  relay fight. Joining reclassifies the run; it does not abort it.
- A run that remains solo may update personal practice records.
- An exhibition run records event telemetry and completion but no personal
  record or formal team score.
- A contested run may update session, team, and personal contested statistics.
- Every capture rings an announcement and resets the relay after a short pause.

### Competitive Relay

- Teams and rosters lock before the first release.
- Use a fixed unlock threshold and deterministic target schedule.
- Run a bounded match or two side-swapped halves.
- Continue a live possession after the regulation horn until score or reset.
- Use a fresh neutral calibration for golden-score overtime.

The competitive form should not be specified fully until Open Relay proves the
target, pickup, chase, and destination loop.

## Map Shape

A useful prototype map needs five readable spaces:

1. A central crown with smooth relay collision and several firing approaches.
2. A RED half with a fast exposed spine, high traverse, and screened gully.
3. A BLUE half with equivalent route classes, not necessarily exact geometry.
4. Broad scoring or extraction volumes that tolerate high-speed crossing.
5. Lateral routes that let defenders intercept instead of merely following.

One stationary position must not see every target or every goal approach.
Spawns should support quick re-entry without placing freshly spawned defenders
inside the scoring volume. A player choosing to lounge near a team base may
gain information and a prepared interception line, but must sacrifice influence
over the central unlock.

## Population Behavior

| Population | Intended behavior |
|---|---|
| Solo | Shoot the target sequence, run delivery routes, and record practice splits. |
| 1v1 | Contest target access, then alternate runner and pursuer through live steals. |
| 2v2 | Natural carrier, escort, pursuer, and interceptor decisions emerge. |
| 3v3-5v5 | Some players can hold firing angles or defend destinations without every role becoming mandatory. |
| Uneven | Use the same rules for both teams; label results and adjust only between releases. |

Do not make the threshold depend on simultaneous shooters. A single player must
be able to complete calibration.

## Main Failure Modes

| Failure | Warning sign | First correction to test |
|---|---|---|
| Aim gallery | Players stand still waiting for sockets. | Increase occlusion and move useful firing approaches farther apart. |
| Disguised health bar | Players describe calibration as target chores. | Reduce required windows before adding complexity. |
| Automatic score | Unlock winner reaches the destination without defender contact. | Improve interception geometry or test enemy assault before slowing carriers. |
| Goal camp | Low-pop carriers repeatedly die to the same respawning defender. | Move spawn influence, widen approaches, and expose the defender's perch. |
| Uncatchable carrier | Pursuers lose despite cleaner lines. | Add lateral cuts and route compression before carrier penalties. |
| Confusing reversal | A thief carries toward the wrong destination. | Strengthen world markers, Core color/symbol, and turnover announcement. |
| Center monopoly | One strong player prevents anyone else from interacting. | Test alternate approach heights, brief release resets, or open activity rotation. |
| Timer resentment | The Core vanishes during a credible scoring attempt. | Remove the casual timer or extend warnings before changing movement. |

## Cheapest Useful Experiment

Build only enough to answer these questions:

1. Do rotating target angles make players ski and shoot, or stop and wait?
2. Does releasing the Core create an understandable transition into pursuit?
3. Can a pursuer intercept by terrain choice rather than only follow?
4. Which destination creates the best low-pop behavior?
5. Can uninvolved players practice, watch, or join without harming the loop?

Use existing flag carry/drop behavior, the disc projectile, debug target meshes,
wide goal volumes, and terse HUD text. Run solo, 1v1, and 2v2 before adding
final geometry, match structure, new weapons, or generalized mode code.

### Continue, Change, Or Stop

- Continue to `Prototype` if players can explain target state and release,
  pursue through more than one route, and produce at least occasional predicted
  interceptions in 1v1 or 2v2.
- Change the unlock rule if calibration produces stationary waiting or players
  describe it as repeated target chores.
- Change the destination if most releases become automatic scores or repeated
  goal camping.
- Defer this formulation if lateral interception remains ineffective after map
  geometry is adjusted.
- Reject this formulation if target unlocking and carrying remain two unrelated
  activities across repeated human sessions.

## Initial Evidence Profile

All ratings are assumptions until a human session is recorded.

| Criterion | Rating | Current basis |
|---|---|---|
| Movement expression | 4A | Relay angles, carrying, route choice, and pursuit can all use movement. |
| Solo and low-pop viability | 4A | One player can calibrate and deliver; 1v1 supplies contest. |
| Opt-in intensity | 4A | Open Relay can coexist with roaming and lounge play. |
| Lounge compatibility | 4A | Central releases create discrete events rather than constant pressure. |
| Chase and interception | U | Depends on map scale and lateral routes. |
| Legibility | 3A | Target windows, charge, release, carrier, and destination create substantial state. |
| Downtime | 4A | Calibration and delivery alternate without elimination waits. |
| Comeback and stalemate | U | Release advantage, goal geometry, and possession timers remain untested. |
| Map burden | 3A | Needs a central crown, route classes, lateral cuts, and several destination sockets. |
| Networking burden | 4A | Mostly bounded authoritative state built from existing projectiles and flag rules. |
| Content and AI burden | 5A | Requires objective meshes and no tactical AI. |
| Learning yield | 5A | One graybox tests moving aim, possession, chase, low-pop, and destination topology. |

## Experiment Log

| Date | Build / variant | Participants | Observation | Decision |
|---|---|---|---|---|
| 2026-08-03 | Concept only | None | No playable experiment has run. All profile ratings remain assumptions. | Keep at `Explore`. |

## Preservation And Revisit Notes

Even if this complete formulation is deferred or rejected, preserve the target
window batching, neutral ejection, destination comparison, continuous-run
classification, and relay-crown map vocabulary as donors for CTF, Breakline,
target assault, training, or commons events.

Revisit after movement interception is proven, after a larger authored basin
exists, or when a target-shooting activity can be tested without building a
general mode framework.

## Open Questions

- Should an unlock winner receive a short pickup claim, favorable ejection
  direction, or only positional initiative?
- Is exact global carrier tracking necessary, or are periodic pings healthier?
- Should direct target hits count under realistic projectile latency?
- Does shooting targets teach disc leading or distract from fighting players?
- Can a base defender remain useful without making the goal oppressive?
- Does home delivery feel comforting and legible or merely anticlimactic?
- Can rotating extraction remain readable in the lean renderer profile?
- How should a lounge participant explicitly opt into team and objective state?
