# SKOOSH — Research Paths for a Confident Technical Trajectory

> **Status:** Research pass completed. The distilled recommendation is in `RESEARCH_FINDINGS.md`, and the resulting execution plan is in `MULTIPLAYER_SPIKE.md`. Retain this document as the research brief and evidence checklist for follow-up questions.

## 1. Research objective

Determine the most credible, approachable path from the current Godot movement prototype to a native-desktop, authoritative multiplayer game featuring momentum skiing, jet-assisted air control, a small weapon set, and capture the flag.

The research should produce an actionable recommendation, not a general engine survey. It should identify:

- Whether Godot remains a sound choice.
- Whether another comparably approachable engine materially reduces multiplayer risk.
- What networking architecture the movement requires regardless of engine.
- Which risks can be answered from evidence and which require a prototype.
- The smallest experiment that can justify committing to an engine and architecture.

The core question is:

> Which stack lets a small team build and operate authoritative high-speed multiplayer while retaining Godot-like iteration speed and comprehensibility?

## 2. Current project context

The researcher should inspect `PLAN.md` and `CHECKPOINT.md` before beginning.

Current implementation:

- Godot 4.4.1-compatible project.
- GDScript and the Compatibility renderer.
- Native desktop is now the target; browser support has been abandoned.
- Deterministic generated 512 m × 512 m terrain with 32,768 triangles and one trimesh collider.
- `CharacterBody3D` movement in `scripts/player.gd`.
- Walking, low-drag skiing, gravity-driven slope acceleration, crest launches, landing momentum transfer, air steering, and limited jets.
- Eight-gate local time trial, HUD, reset/recovery, and persisted best time.
- No combat, teams, networking, accounts, matchmaking, or backend.

Known early feedback:

- Terrain is currently difficult to read.
- Turning at speed feels insufficient or insufficiently communicated.
- More lateral airborne/jet influence may be desirable.
- Two guns and capture the flag are candidate future features.
- Proper multiplayer is a definite destination.
- The project owner is a staff full-stack web engineer who values transparent systems, quick iteration, and approachable tooling.

The project is still small enough to refactor or port. Avoid treating existing Godot code as either sunk cost or disposable without evidence.

## 3. Working product assumptions

Use these as comparison parameters unless research uncovers a reason to change them:

- Native Windows and Linux clients.
- Linux headless dedicated server.
- Initially 4–12 players; assess feasibility up to 16 or 24.
- Server-authoritative movement, jets, weapons, damage, flags, and scores.
- Approximately 60 Hz movement simulation; snapshot rate may be lower.
- Direct-IP and developer-hosted servers before matchmaking/accounts.
- One authored or heavily authored map before procedural competitive maps.
- One hitscan and one projectile/splash weapon as the first combat slice.
- No bots initially unless they are clearly cheaper than multiplayer test participants.
- No requirement for kernel-level anti-cheat.
- Public-client code and packets must not be trusted for authoritative state.
- A small team must be able to understand and debug the complete stack.

These are research assumptions, not final design commitments.

## 4. Hard gates for candidate stacks

Reject or strongly penalize a stack that cannot demonstrate all of the following:

1. Native Windows/Linux 3D client builds.
2. A practical Linux headless dedicated-server build.
3. UDP or an equivalent low-latency unordered/unreliable transport.
4. Server-authoritative simulation.
5. Local client prediction and server reconciliation for custom movement.
6. Remote-player snapshot interpolation.
7. Custom high-speed collision queries or kinematic movement.
8. Active maintenance, usable documentation, and inspectable examples.
9. Licensing and operating costs suitable for an indie project.
10. A workflow one technically strong generalist can understand and maintain.

“Has multiplayer” is not enough. Peer-to-peer synchronization, transform replication without prediction, and host-authoritative demos do not satisfy the requirement.

## 5. Primary research path: Godot viability

Research Godot first and most deeply because it is already productive and enjoyable for this project.

### 5.1 Dedicated server and transport

Verify with current Godot 4.x primary documentation and source where needed:

- Headless/dedicated-server export and runtime modes.
- ENet support, channels, reliable/unreliable ordering, MTU behavior, and bandwidth controls.
- Whether one project can cleanly export both client and dedicated server.
- Scene-tree and physics behavior in headless mode.
- Deployment requirements and binary size.
- Current status of IPv6, encryption, authentication hooks, and connection handling.
- Whether Steam Networking/Steam Datagram Relay would require third-party bindings later.

Separate facts about Godot's high-level multiplayer API from facts about ENet itself.

### 5.2 Custom movement prediction

Determine whether `CharacterBody3D.move_and_slide()` is a suitable basis for command replay and prediction.

Investigate:

- Which internal state affects `move_and_slide()` results.
- Whether the necessary state can be captured, restored, and replayed.
- Behavior when replaying many physics ticks during reconciliation.
- Floating-point and collision divergence between client and server.
- Differences between Godot Physics and Jolt in current Godot versions.
- Headless/client consistency for trimesh collisions and floor detection.
- Whether collision ordering or contact state introduces unacceptable nondeterminism.
- Whether a custom kinematic sweep/slide solver would be safer than `CharacterBody3D`.
- How floor normals, slope transitions, crest launches, and landing transfer should enter predicted state.
- Performance of replaying movement commands against the current terrain collider.

The research must not assume lockstep determinism is required. Evaluate normal authoritative client prediction with periodic correction.

### 5.3 Godot multiplayer frameworks and examples

Evaluate maintained Godot networking projects that may reduce implementation work. Candidates may include Netfox and other current Godot 4 prediction/rollback libraries discovered during research.

For each candidate, verify:

- Current engine-version compatibility.
- Release cadence and maintainer activity.
- License.
- Dedicated-server authority support.
- Prediction/reconciliation versus rollback-only behavior.
- Support for 3D custom kinematic movement.
- Ability to inspect and modify the implementation.
- Production users or credible public projects.
- Whether it supports ENet directly or imposes a transport.
- Whether adopting it reduces total complexity or merely hides it.

Do not equate fighting-game rollback with authoritative shooter prediction. Explain the difference where relevant.

### 5.4 Godot-specific prototype shape

Propose a narrow Godot spike that includes:

- One local headless server.
- Two clients.
- Input commands containing tick/sequence, movement axes, ski, jet, yaw, and pitch.
- Shared movement simulation code that does not read `Input` directly.
- Client prediction for the locally controlled skier.
- Server snapshots and acknowledgment of processed commands.
- Reconciliation through restore and replay.
- Interpolation for the remote skier.
- Configurable latency, jitter, packet loss, duplication, and reordering.
- The opening descent, one crest launch, jet use, and a downhill landing.
- Instrumentation for correction magnitude, replay count, speed divergence, and contact-state disagreement.

Identify which parts can be implemented without prematurely building a general networking framework.

## 6. Comparative engine research

Compare a small serious shortlist, not every engine available.

### 6.1 Unreal Engine

Research current supported approaches for:

- Dedicated servers and source-build requirements.
- `CharacterMovementComponent` custom movement modes.
- Saved moves and client prediction for custom velocity/energy state.
- Current status of Network Prediction and Mover plugins.
- Server reconciliation and remote smoothing.
- Replication Graph or current interest-management mechanisms.
- Lag compensation patterns for hitscan weapons.
- Gameplay Ability System relevance versus unnecessary complexity.
- Linux server deployment and build pipeline.
- Licensing, royalties, account/tooling requirements, and repository size.
- C++ versus Blueprint boundaries for a maintainable networking core.

Find concrete examples of nonstandard predicted movement. Conventional walking replication alone is insufficient evidence.

Questions to answer:

- Does Unreal eliminate meaningful custom prediction work, or relocate it into complex engine extension points?
- How steep is the workflow for a senior web engineer without prior Unreal/C++ game experience?
- Is the mature shooter stack worth the heavier editor, build, and architecture?

### 6.2 Unity

Do not evaluate “Unity networking” as one product. Compare specific current stacks:

- Netcode for GameObjects.
- Netcode for Entities and predicted ghosts.
- FishNet prediction facilities.
- Mirror and its current prediction support.
- Photon Fusion dedicated/server modes and licensing.
- Any other clearly stronger current candidate discovered during research.

For each, assess:

- True dedicated-server authority.
- Custom movement prediction and reconciliation.
- Kinematic versus rigid-body support.
- Snapshot interpolation and lag compensation.
- Headless Linux support.
- Debugging/latency simulation tools.
- Maturity and production evidence.
- Lock-in, pricing, CCU charges, and self-hosting.
- Complexity added by ECS if Netcode for Entities is favored.
- Long-term maintenance and Unity-version compatibility.

Questions to answer:

- Does C# familiarity and ecosystem breadth outweigh framework fragmentation?
- Which single Unity stack is the honest comparison to Godot, rather than combining the best claims of several incompatible stacks?

### 6.3 Approachable alternative screening

Briefly screen current versions of Flax, Stride, Bevy, and any credible alternative identified by the researcher. Promote one to deeper evaluation only if it passes the hard gates and offers a concrete advantage.

Screen for:

- Editor and iteration approachability.
- 3D terrain/collision support.
- Dedicated-server support.
- Prediction/reconciliation ecosystem.
- Project and maintainer health.
- Debugging and profiling.
- Licensing.
- Availability of experienced developers and examples.

Avoid recommending a small engine merely because its API is pleasant. A less mature networking ecosystem would increase, not reduce, this project's risk.

### 6.4 SDK/middleware path

Investigate whether an engine-independent networking layer would improve the trajectory:

- ENet directly.
- Valve GameNetworkingSockets or Steam Networking Sockets.
- Photon Fusion where applicable.
- Managed hosting SDKs only when they affect simulation architecture.

Distinguish:

- Transport libraries.
- Replication/prediction frameworks.
- Backend/account services.
- Fleet/orchestration services.

Nakama, PlayFab, GameLift, Agones, Hathora, Edgegap, and similar products do not automatically solve movement prediction. Describe exactly what each relevant product would and would not provide.

## 7. Networking architecture research

Produce an engine-neutral reference architecture before making the engine recommendation.

### 7.1 Command and state model

Define the likely predicted command and state surfaces.

Candidate command fields:

- Client command sequence/tick.
- Movement axes.
- Ski state.
- Jet state.
- View yaw/pitch or aim vector.
- Fire/switch-weapon actions later.

Candidate predicted state:

- Position and orientation.
- Linear velocity.
- Grounded/airborne state.
- Floor/contact normal where necessary.
- Ski state.
- Jet energy and recharge timing.
- Any landing-transfer state.
- Last processed command.

Research whether contact normals should be transmitted, recomputed, or used only diagnostically.

### 7.2 Tick and snapshot strategy

Evaluate:

- 60 Hz versus lower server simulation rates for high-speed traversal.
- Snapshot rates of approximately 10–30 Hz with interpolation.
- Input batching and redundancy.
- Delta compression only after correctness.
- Separate channels for input, snapshots, reliable match events, and chat/admin traffic.
- Entity relevancy and interest management for a small map/player count.
- Bandwidth estimates at 8, 16, and 24 players.

Use measurements or transparent calculations rather than generic claims.

### 7.3 Reconciliation and smoothing

Research proven approaches for:

- Restoring an acknowledged state and replaying unacknowledged commands.
- Soft visual correction versus hard simulation correction.
- Camera smoothing independent of collision state.
- Thresholds for snapping after severe divergence.
- Handling server corrections during landing, crest launch, and jet depletion.
- Preventing correction smoothing from creating wall/terrain penetration.
- Separating render transforms from authoritative simulation transforms.

### 7.4 High-speed collision and weapons

Investigate:

- Swept collision for fast players and projectiles.
- Server-side hitscan traces.
- Historical player-state buffers for lag compensation.
- Rewinding target hitboxes without rewinding the entire world.
- Splash damage and impulse authority.
- Projectile prediction versus server-only projectiles with cosmetic client prediction.
- Maximum useful rewind windows and abuse controls.
- How very high player speed affects map size, relevancy, and snapshot error.

### 7.5 Determinism requirements

Explain clearly:

- Why authoritative shooter prediction does not require perfect cross-machine determinism.
- Where deterministic-enough replay still matters.
- How physics-engine divergence affects corrections.
- When a custom kinematic movement solver is preferable.
- Why full rollback of complex 3D physics may be the wrong model.

## 8. Security and anti-cheat research

Create a practical threat model rather than promising “cheat-proof” multiplayer.

### 8.1 Server-authoritative guarantees

Specify how the server should prevent or limit:

- Position/teleport spoofing.
- Speed and acceleration manipulation.
- Unlimited jet energy.
- Fire-rate and ammunition manipulation.
- Fake hits, damage, deaths, captures, and scores.
- Invalid team or spawn actions.
- Packet floods and malformed commands.
- Replay or duplicate command abuse.

### 8.2 Remaining client-side threats

Document what authority alone does not solve:

- Aimbots.
- Trigger bots.
- Wallhacks using replicated information.
- Input automation/macros.
- Client binary modification.
- DDoS and server-address exposure.
- Collusion, griefing, and account abuse.

Research proportionate mitigations for an early indie game. Avoid kernel anti-cheat unless evidence makes it unavoidable.

### 8.3 Information exposure

Evaluate whether all player state must be replicated to every client. Consider:

- Relevancy and line-of-sight culling.
- Spectator implications.
- Flag/carrier visibility rules.
- Server replay and moderation data.
- Cost and limitations of hiding information in a fast outdoor game.

## 9. Server operations and hosting research

The first external server should be simple. Research a progression from local development to public testing.

### 9.1 Local and LAN phase

- One headless process and two client processes on a development machine.
- Deterministic command logging.
- Latency/loss simulation without an external server.
- Repeatable startup scripts and configuration.

### 9.2 First VPS phase

Compare several ordinary Linux VPS options and at least one game-hosting platform for:

- Regional availability.
- UDP support.
- 2–4 vCPU instance pricing.
- Egress limits and DDoS posture.
- Container support.
- Static public IPs.
- Operational transparency.

Estimate CPU, memory, and bandwidth for one 8–16 player match. Mark assumptions clearly.

Define the minimum operational package:

- Headless server binary/container.
- Command-line or environment configuration.
- Firewall and exposed UDP port.
- systemd/container restart policy.
- Structured logs.
- Health endpoint or process-level health check.
- Version/protocol compatibility check.
- Graceful shutdown and match restart.

Do not introduce Kubernetes, fleet orchestration, databases, or matchmaking until concurrency requires them.

### 9.3 Later hosting questions

Research but do not prematurely select:

- Developer-hosted versus community-hosted servers.
- Steam Datagram Relay and server discovery.
- Regional fleets and allocation APIs.
- Matchmaking and party systems.
- Authentication/session tickets.
- Metrics, moderation, bans, and replay retention.
- Cost crossover between VPS hosting and managed game hosting.

## 10. Comparable games, postmortems, and Tribes technical archaeology

Treat Tribes as an explicit research lineage, not merely a reference for subjective feel. Search for documented engineering and design decisions that can prevent rediscovering old problems.

### 10.1 Tribes lineage

Research the relevant games separately rather than conflating them:

- Starsiege: Tribes.
- Tribes 2.
- Tribes: Vengeance.
- Tribes: Ascend.
- Later community projects and spiritual successors where their developers discuss inherited or rejected decisions.

Look for primary or near-primary material from Dynamix, GarageGames/Torque maintainers, Irrational, Hi-Rez, Prophecy Games, and developers who worked on the relevant systems:

- GDC or conference talks.
- Technical whitepapers and engine documentation.
- Contemporary postmortems.
- Developer interviews.
- Public source-code releases or legally available engine descendants.
- Archived official forums, developer posts, and patch notes when stronger sources do not exist.

Investigate the Torque engine lineage where relevant. Torque documentation and source may preserve concepts such as move queues, control objects, ghosting, datablocks, update masks, scoped objects, client prediction, and server connection state. Establish which findings are demonstrably from a shipped Tribes title, which come from a later Torque version, and which are researcher inference. Do not present an engine descendant as exact Tribes source without evidence.

Specific Tribes questions:

- What was authoritative on the server versus predicted locally?
- How were player input moves queued, acknowledged, replayed, or corrected?
- What server tick and packet-update rates were used, and did they change between titles?
- How did the games represent skiing: low friction, contact projection, explicit state, or another mechanism?
- How were terrain contact, slope transitions, stepping, and crest launches handled?
- How much movement state was replicated beyond position and velocity?
- How did jets interact with prediction and energy authority?
- How did inheritance work for player velocity, weapon projectiles, and explosions?
- How were fast projectiles and hitscan-like weapons validated or compensated for latency?
- What exploits or desynchronization bugs appeared, and how were they mitigated?
- How did bandwidth constraints shape player counts, map scale, and update relevance?
- Did remote players use interpolation, extrapolation, animation smoothing, or combinations?
- How were vehicles or deployables scoped, if those lessons apply to future SKOOSH entities?
- Which networking decisions aged well and which were artifacts of contemporary bandwidth/hardware?

Specific movement/design questions:

- Which steering limits were intentional mastery versus engine limitations?
- How did different Tribes titles change air control, jet authority, friction, and skiing accessibility?
- How were terrain textures, lighting, fog, contours, and landmarks used to communicate slope at speed?
- How did map layouts make long-anticipation movement compatible with CTF interception and defense?
- How did weapon projectile speed, inheritance, splash radius, and impulse complement player velocity?
- Which changes were controversial with experienced players, and why?

Use patch history carefully: balance changes can reveal design constraints but are not proof of implementation details.

### 10.2 Successors and adjacent games

Find credible technical material from:

- Midair and Midair: Community Edition.
- Legions: Overdrive and comparable momentum/jet games.
- Quake and Source movement-prediction lineages.
- Modern shooters with custom predicted movement modes.
- Open-source authoritative shooters where code is inspectable.

For Midair and other direct successors, prioritize developer accounts of what was difficult to reproduce, what they deliberately changed from Tribes, and how modern latency/player expectations altered the design.

### 10.3 Required archaeology output

Produce a separate evidence table containing:

- Title/engine and year/version.
- Source and source quality.
- Confirmed architecture or design decision.
- Motivation, if documented.
- Observed failure mode or tradeoff.
- Whether the lesson still applies to SKOOSH.
- Confidence and unresolved ambiguity.

Conclude with three lists:

1. **Decisions worth preserving** from the Tribes lineage.
2. **Historical constraints no longer worth inheriting.**
3. **Questions that old documentation cannot answer and must be prototyped.**

Do not copy proprietary code or assets. Public source should be used to understand architecture and algorithms, with licenses recorded before any code reuse. Historical architecture may be highly informative without being directly suitable today.

## 11. Movement design research

Networking should preserve a movement model worth preserving. Research design approaches for approachable momentum controls.

Investigate:

- Speed-dependent steering curves.
- Acceleration perpendicular to velocity versus directly rotating velocity.
- Separate ground, air, and jet-assisted steering authority.
- Input responsiveness at low speed without high-speed instant reversal.
- Landing-assistance models that remain predictable online.
- Camera/reticle cues that communicate turn authority.
- Training-course design for teaching fall lines and anticipation.

Identify which movement values must be server authoritative and which are cosmetic.

The result should be a small set of candidate formulas suitable for A/B testing, not a claim that research can decide game feel.

## 12. Terrain and competitive-map research

Terrain readability is not the primary engine decision, but it affects whether the movement can be evaluated.

Research Compatibility-safe or equivalent native-desktop techniques for:

- Height- and slope-based color ramps.
- Triplanar procedural materials.
- Macro variation without visual noise.
- Distance and slope contours.
- Lighting/fog combinations that preserve terrain relief.
- Route markers that do not substitute for readable geometry.
- Competitive authored terrain blended with generated surroundings.

For CTF, study:

- Two-way traversal and return routes.
- Base approach visibility.
- Offense/defense travel times.
- Spawn safety at high speed.
- Flag-carrier interception opportunities.
- Whether the current generated terrain should become background around an authored competitive core.

## 13. Developer-experience research

Evaluate each serious candidate from the perspective of a staff web engineer guiding a small project.

Assess:

- Time from code change to playable build.
- Debugger and profiler quality.
- Ability to run server plus multiple clients locally.
- Network simulation and visualization tools.
- Automated/headless test support.
- Build reproducibility and CI complexity.
- Language and type-system ergonomics.
- Source-code accessibility.
- Upgrade stability.
- Documentation accuracy.
- Quality of examples for custom predicted movement.
- Ease of using AI coding agents without generating opaque editor state.
- Availability of developers if the team expands.

Include a small implementation exercise where possible; screenshots and feature lists are weak evidence for approachability.

## 14. Evidence standards

Prioritize sources in this order:

1. Current official documentation.
2. Current engine/framework source code and issue trackers.
3. Maintainer-authored examples and talks.
4. Shipped-project postmortems.
5. Reputable technical articles with code.
6. Community discussions only as leads or evidence of recurring pain.

For every consequential claim, record:

- URL and title.
- Publication/update date.
- Engine/framework version.
- Whether the source is primary or secondary.
- Direct evidence versus researcher inference.
- Any contradiction with another source.

Beware of:

- Tutorials that only replicate transforms on a LAN.
- Old engine major versions.
- Peer-hosted demos presented as dedicated-server architecture.
- Framework marketing without custom-movement examples.
- “Deterministic networking” claims that omit 3D collision details.
- Combining features from incompatible Unity networking stacks.
- Assuming Unreal's default character prediction automatically covers custom skiing.
- Treating backend products as movement-netcode solutions.

## 15. Required deliverables

The research pass should produce all of the following.

### 15.1 Executive recommendation

A concise recommendation containing:

- Recommended engine and networking stack.
- Runner-up and the conditions under which it becomes preferable.
- Confidence level.
- Most important evidence.
- Most dangerous unresolved assumption.
- Explicit “stay with Godot” or “switch now” rationale.

### 15.2 Weighted decision matrix

Suggested initial weights:

| Criterion | Weight |
|---|---:|
| Custom movement prediction/reconciliation | 30% |
| Iteration speed and approachability | 20% |
| Dedicated-server maturity | 15% |
| Shooter networking facilities | 15% |
| Debugging, profiling, and test tooling | 10% |
| Licensing and operating cost | 5% |
| Rendering/content workflow | 5% |

Adjust weights only with an explanation. Score evidence quality separately from capability.

### 15.3 Reference architecture

Provide diagrams or precise prose for:

- Client input flow.
- Local prediction.
- Server simulation.
- Snapshot acknowledgment.
- Reconciliation/replay.
- Remote interpolation.
- Reliable match/CTF events.
- Weapon authority and future lag compensation.
- Deployment topology.

### 15.4 Risk register

For each major risk include:

- Probability.
- Impact.
- Evidence.
- Mitigation.
- Earliest experiment that can retire it.
- Consequence if unresolved.

### 15.5 Prototype plan

Design a one- to two-week engine/network spike with:

- Exact scope.
- Instrumentation.
- Test scenarios.
- Success thresholds.
- Stop conditions.
- Code expected to survive versus be discarded.

### 15.6 Cost and operations model

Include:

- Development/build requirements.
- Engine/framework licensing.
- Third-party service fees.
- Early VPS cost range.
- Approximate bandwidth assumptions.
- Operational responsibilities.
- Cost triggers that would justify managed hosting.

### 15.7 Annotated source index

Provide a short annotation for every important source rather than a raw bookmark list.

## 16. Prototype acceptance questions

The research should culminate in a spike capable of answering these questions empirically:

1. Can a skier descend, crest, jet, and land under 80–120 ms simulated latency without distracting rubber-banding?
2. Can the server reject impossible speed, jet, and input transitions without rejecting legitimate skiing?
3. Can client and server replay the current terrain contacts closely enough for corrections to remain small?
4. Can two clients observe one another smoothly at normal course speeds?
5. Can the server run the target player count and tick rate with comfortable CPU headroom?
6. Can a developer inspect why a correction occurred?
7. Can movement commands and server snapshots be recorded and replayed?
8. Can the stack be built and run in CI/headless environments?
9. Is the implementation understandable enough to extend with weapons and CTF?
10. Does the engine remain pleasant after networking enters the workflow?

Suggested measurements, to be calibrated rather than treated as universal truth:

- Correction-distance distribution and worst outliers.
- Corrections per second.
- Grounded/contact-state disagreement rate.
- Client/server speed and jet-energy divergence.
- Command replay count and CPU cost.
- Snapshot bandwidth per player.
- Server frame/tick time at target population.
- Behavior under jitter, 1–3% packet loss, and brief packet bursts.

## 17. Decision rules

Recommend staying with Godot if evidence and the spike show that:

- A clean command-driven movement layer can be shared by client and server.
- Prediction/reconciliation works without deep fragile engine hacks.
- Headless ENet deployment is straightforward.
- Corrections remain acceptable through representative ski/jet/landing scenarios.
- The team can understand and instrument the implementation.
- Alternative engines do not save enough custom work to justify their complexity.

Recommend switching now if:

- `CharacterBody3D` or replacement movement cannot be replayed reliably enough.
- A custom Godot movement/network stack grows substantially beyond the game-specific logic.
- Another engine demonstrates working custom predicted movement with materially less bespoke infrastructure.
- Godot server profiling misses the intended player/tick target without a practical remedy.
- Required debugging information cannot be surfaced effectively.

Do not recommend switching merely because another engine has more features. Do not recommend staying merely because the current prototype was fast to build.

## 18. Expected conclusion shape

The ideal research conclusion will resemble one of these:

- **Stay with Godot:** ENet plus a small custom command/snapshot layer is viable; movement needs a prediction-oriented refactor or custom kinematic solver; proceed with a measured spike and defer hosting services.
- **Adopt a specific Unity stack:** one identified framework demonstrably handles custom predicted movement and dedicated servers better enough to justify porting, with known costs and lock-in.
- **Move to Unreal:** custom movement can fit its supported prediction extension points, and the mature shooter/server stack outweighs the workflow burden.
- **Insufficient evidence:** two narrowly defined competing spikes are required before commitment.

A useful result narrows uncertainty and prescribes the next experiment. A broad list of engines, libraries, and hosting companies without a decision framework is not sufficient.
