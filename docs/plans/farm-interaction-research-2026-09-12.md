# Farm interactions and physics — research and proposed experiments

Research requested for both the personal Farm and Slumber Party. No app code or backend changes
in this research task. The founder highlighted Ollie gathering sheep, fetching a toy and
accompanying a Shepherd as examples of interactions worth exploring in both places.

## Relevant sources

1. **Tiny Glade, developer Anastasia Opara's Twitter/X thread.** The author describes testing
   how to communicate the game through short clips and mentions separate sheep-petting posts.
   This is a close subject reference for readable, playful interactions in an illustrated
   diorama; it is not a physics implementation guide or proof of retention benefits.
   [Original thread](https://x.com/anastasiaopara/status/1634569679384502272),
   [readable author-thread archive](https://threadreaderapp.com/thread/1634569679384502272.html).
   Direct X loading failed during this research; the archive was readable. No claim of having
   watched the inaccessible embedded clips. Broad X searches were sparse, so technical findings
   below come from directly readable developer resources.
2. **Sébastien Bénard, Game feel demo.** An interactive developer tool lets the reader toggle
   individual presentation features to compare their effect. Adapt the comparison method to
   a sheep rather than copying its combat presentation.
   [Demo and source links](https://deepnight.net/games/game-feel/).
3. **12 principles for game animation, developer discussion using Little Nemo.** Squash/stretch
   conveys material and impact; preserve perceived volume and keep collision shapes simple
   enough that visual deformation does not break contact behavior. Apply modestly to wool,
   with smaller effects on the Shepherd and fitted clothing.
   [Article](https://www.gamedeveloper.com/game-platforms/12-principles-for-game-animation).
4. **Daniel Holden, Spring-It-On.** Spring/damper behavior can preserve velocity continuity,
   and frame-dependent smoothing can behave differently or become unstable at other update
   rates. Tune bounce/settling separately from motion toward a goal; use a stable time-based
   formulation and test interruptions.
   [Developer article with demonstrations](https://theorangeduck.com/page/spring-roll-call).
5. **Craig Reynolds, Steering Behaviors for Autonomous Characters.** Seek, arrival, separation,
   obstacle avoidance and group behavior offer building blocks for animals that move with a
   purpose. Our proposed combination is a short Ollie gather/fetch sequence, not unrestricted
   flock simulation running constantly.
   [Author's demonstrations](https://www.red3d.com/cwr/steer/).
6. **Apple, SpriteKit physics documentation.** Simple collision shapes trade fidelity for lower
   simulation cost; circles are efficient. Mass, damping and restitution control response.
   These principles are relevant even if we retain the current SwiftUI scene renderer.
   [Body shapes](https://developer.apple.com/documentation/spritekit/shaping-a-physics-body-to-match-a-node-s-graphics),
   [physical properties](https://developer.apple.com/documentation/spritekit/configuring-a-physics-body).

These sources inform the experiments below; the interactions, scope and art choices are our
proposals for Counting Sheep, not claims that another developer implemented the same system.

## What the current source actually provides

- `Shared/PastureScene.swift` already defines footprints, bounded positions, settled placement,
  deterministic overlap nudges, scamper targets and chase plans. Nudges calculate landing
  positions; this is not continuous velocity/impulse collision simulation.
- `PastureSceneController` schedules graze/hop/sniff/stance/wave states and a paired Ollie/sheep
  chase. The viewed sequence returns to saved positions afterward. It does not implement a
  player-thrown ball, retrieval, a petting loop or multi-animal herding.
- `PastureCharacterHitTarget` already combines a 0.35-second hold/drag with visual scale/rotation.
  Preserve tap-versus-drag suppression and explicit accessible actions when adding interactions.
- `SharedMeadowSceneController` duplicates some scheduling/drag concepts for the prototype and
  persists only local arrangement. The selected redesign requires shared placements. Reuse a
  common domain/behavior layer while keeping the personal and shared storage adapters separate.

## Experiments suited to our artwork

| Experiment | Touch or trigger | Intended response | Scope |
| --- | --- | --- | --- |
| Pet a sheep | Explicit Pet action initially; later evaluate a short stroke gesture | Wool compresses slightly, head/ears react if supported, brief lean/hop, then settles | Both Farms |
| Pick up and place | Existing hold/drag, with clear grab feedback | Body trails or tilts slightly; shadow stays on the ground; short settling bounce on release | Both Farms |
| Gentle push | Short drag/release with bounded momentum | Nearby animal gives way; small impulse, wool response and quick recovery | Both Farms |
| Fetch with Ollie | Select Ollie, choose Play, toss a toy into a valid ground area | Ollie looks toward it, accelerates, slows near it, retrieves and returns | Personal Farm first; shared owned companion if selected |
| Gather nearby sheep | Explicit action near an owned Ollie | Short curved approach; nearby sheep separate and gather loosely; everyone comes to rest | Both Farms where Ollie is present |
| Shepherd acknowledgement | Select or intentionally place near another resident | Head/torso orientation and a supported wave/pat pose; never implies a real member acted | Both Farms |
| Responsive surroundings | Character moves past grass or a hanging lantern is touched | Local rustle or restrained pendulum response | Shared scene first, reusable personally |

Start with one sheep, one Shepherd and one Ollie. Compare the same gesture with response layers
on/off: movement alone; spring response; wool deformation; contact shadow; character attention.
Then test two-person and eight-person party density. Do not add every effect simultaneously.

### Important implementation tricks for this Farm

- **Ground and height are different.** Keep an animal's ground position separate from its lift
  or hop height. Draw its shadow at the ground anchor; lift the artwork above it. Depth order
  should follow ground depth, not the top of a jumping sprite. Ground-plane motion must not
  treat the bottom of the phone screen as gravity for the entire diorama.
- **Render shape and physical footprint differ.** Use simple ground footprints for proximity
  and collision, with separate forgiving touch areas. A hat or wool curl should not catch on
  every neighbour. Scenery needs explicit walkable/blocked regions; painted paths alone do
  not keep characters out of a barn wall or water.
- **Choose a material response.** Wool can compress and rebound; the Shepherd gets subtler
  body/pose motion. Keep head shape, face, hair and fitted cosmetics recognizable. Where the
  renderer lacks independent ears, paws or limbs, list required new rig/pose work rather than
  assuming a flat image can produce it. All clothing must remain attached during movement.
- **Retain control.** Once grabbed, the character must respond immediately. Avoid a loose spring
  that makes the object lag far behind the finger. Use secondary tilt/compression for softness;
  cap release velocity and bounce count. Cancel safely on backgrounding or membership changes.
- **Use distinct phases.** Grab, drag, release, impact, recover and idle should be interruptible.
  A moving sheep needs an attention/reaction phase, not a repeating whole-body wobble. Scale
  collision response by meaningful impact with cooldowns so resting contact does not retrigger.
- **Keep gestures unambiguous.** Tap selects; hold/drag moves. Pet/Play can start as explicit
  actions in the selection panel. Prototype any stroking/flick shortcuts against camera pan,
  vertical scrolling, VoiceOver and accidental greeting sends before enabling them.
- **Coordinate movement.** Fetch and gathering need target selection, arrival and separation.
  They should finish rather than start an endless chase. Respect current deliberate placements;
  a helper should not continually undo another person's shared arrangement.
- **Separate local response from shared outcome.** In the first shared version, animate touch
  immediately and reconcile validated final placements. Do not stream every wool oscillation
  or grant anything because a collision occurred. A group-impacting gather action would need
  a bounded, revision-checked multi-entity outcome, not unrelated unbounded position writes.
- **Respect device conditions.** Use stable timestep handling, cap catch-up after suspension,
  stop off-screen work and avoid per-frame persistence/network calls. Test actual phone frame
  pacing and energy cost. Reduce Motion retains selection and useful actions with less movement;
  interactive access during Wind Down remains allowed under the new founder decision.

## Engineering recommendation

Begin by extending the existing native scene foundation with a small shared motion/interaction
model and per-character response parameters. Keep public member identity, private animal
ownership and rewards out of the simulation itself. SwiftUI continues to host navigation,
selection, accessible controls and the existing renderers.

Evaluate a bounded SpriteKit spike only if we need continuous multi-body contacts or toy
constraints that are awkward in the current model. Apple provides useful physics primitives,
but adopting its renderer would require proving compatibility with our customized Shepherd
and cosmetics; it is not a drop-in replacement for current SwiftUI character views. Do not
introduce a third-party engine or rewrite both Farms before measuring the small native slice.

Suggested sequence: (1) sheep pet/pick/place/push with stable ground shadows; (2) bounded
Ollie fetch and gather; (3) common interaction layer in both Farms; (4) shared outcome
reconciliation and optional companion density test. Ollie's shared inclusion is still a design
decision, but these experiments give it a concrete basis rather than judging it as extra scenery.

Acceptance: on-device touch recording, repeated taps/drags and mid-animation interruption,
stable fitted outfits/head shapes, no tiny or occluded targets, 2/8-member density, identical
semantics at different display rates, Reduce Motion and VoiceOver alternatives, offline/shared
placement recovery, no reward or receipt side effects from local play. Existing full build/unit
gates apply when code is implemented; no new build/test result is claimed for this research.
