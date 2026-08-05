# Game-Mode Research Framework

This framework preserves ideas without converting imagined appeal into a
roadmap. A concept is evaluated as a profile, not a single score or ranking.

## Evidence Tags

| Tag | Meaning |
|---|---|
| U | Unknown or not yet evaluated. |
| A | Assumption from rules or comparable games. |
| O | Observed in at least one relevant human session. |
| R | Repeated across players, sessions, or variants. |
| M | Measured with telemetry or a controlled comparison. |

Ratings may use forms such as `4O` or `2M`. Higher-confidence evidence may
overturn an earlier, more favorable assumption.

## Evaluation Profile

Use a 1-5 favorable scale and record an evidence tag plus one sentence. Do not
sum or average the ratings.

| Criterion | Research question |
|---|---|
| Movement expression | Does momentum, route choice, jet use, landing, and recovery determine outcomes? |
| Solo and low-pop viability | Is there meaningful play solo, at 1v1, and with uneven drop-in population? |
| Opt-in intensity | Can players choose when to compete, watch, practice, or disengage? |
| Lounge compatibility | Can social and inactive players coexist without sabotaging active play? |
| Chase and interception | Can prediction and terrain cuts beat simple following? |
| Legibility | Can players explain ownership, danger, route, and scoring at skiing speed? |
| Downtime | How quickly does a failure lead to another meaningful choice? |
| Comeback and stalemate | Can pressure reverse, and can players force an indefinite stall? |
| Map burden | How much bespoke geometry and balance work does the concept require? |
| Networking burden | What new latency-sensitive authoritative state or prediction is required? |
| Content and AI burden | Does the concept require many assets, roles, encounters, or capable bots? |
| Learning yield | How many important unknowns can the cheapest experiment retire? |

## Lifecycle Labels

Lifecycle describes evidence and current attention, not quality.

| Label | Meaning | Typical next action |
|---|---|---|
| Seed | Preserved fantasy, mechanic, or question. | Identify its central verb and largest unknown. |
| Explore | Rules and variants are being clarified without implementation commitment. | Define the cheapest falsifiable experiment. |
| Prototype | A deliberately incomplete playable test exists. | Run controlled human sessions. |
| Validate | Repeated play suggests value and warrants stronger evidence. | Test population, map, impairment, and adversarial behavior. |
| Defer | Worth preserving but blocked or currently low-leverage. | Record a concrete resume trigger. |
| Reject | The tested formulation failed its purpose under current constraints. | Preserve evidence and reusable mechanics; stop spending. |

`Reject` never means delete. A rejected mode may donate a target interaction,
map feature, timer, objective marker, social behavior, or telemetry method.

## Standard Concept Card

Every concept promoted beyond the catalog should record:

```markdown
# Concept Name

**Revision:**
**Lifecycle:** Seed / Explore / Prototype / Validate / Defer / Reject
**Last reviewed:**

## One-Sentence Pitch
## Player Fantasy
## Research Question And Falsifiable Hypothesis
## Core Loop And Typical Duration
## Minimum Population, Expected Population, And Solo Form
## Opt-In, Disengagement, And Lounge Behavior
## Objective, Scoring, Reset, Comeback, And Stalemate Rules
## Movement, Chase, Interception, And Recovery Opportunities
## World And HUD Legibility
## Existing Systems Reused
## New Server, Networking, Map, Content, And AI Requirements
## Evaluation Profile
## Cheapest Useful Experiment
## Experiment Log
## Preservation And Revisit Notes
```

## Contested Core Example Sequence

The current lead `Explore` concept can use this sequence; it is an example, not
a generic mandate for every future mode.

1. Record the current movement and course baseline.
2. Test one runner and one laterally offset interceptor without a full mode.
3. Test the central target unlock without carrying or scoring.
4. Add neutral pickup, visible possession, drop, and return.
5. Compare home delivery, enemy assault, and rotating extraction in short blocks.
6. Run solo, 1v1, 2v1, join-in-progress, inactive-player, and disconnect cases.
7. Test a continuous lounge-compatible shell without formal round pressure.
8. Ask players to camp, hide, stall, ignore, monopolize, and strand the objective.
9. Qualify simultaneous hits, pickups, drops, and scoring under impairment only
   after the human interaction earns continued work.

Each experiment should remain disposable. Add only the smallest rule that
addresses an observed repeated failure.
