# Home hero: approved direction and staged delivery

2026-08-28. Design decisions and implementation plan, **not native implementation acceptance**.
Prototype: `output/design/home-minimal-20260828/index.html`.

## Founder decisions

- Adopt the minimalist personal Home direction: prominent welcoming Ollie, 1–3 small home
  ornaments, compact Wind Down timing, a connected Slumber Party preview with recognizable
  members/statuses and one recent highlight. Full shared history stays in Slumber Party.
- “Night 2 of 7” must read on one line. At narrow widths or large text, move the complete
  label to its own row rather than squeezing, truncating or splitting it.
- Approve `ollie-ear-reference-study.png` and `ollie-tongue-welcome-study.png` as pose references
  for animation sets visible in **both Home and Farm**. These live in the prototype's `assets/`.
- Defer the shared hero scene: too busy, with insufficient distinction between characters.
  A shared Farm remains a possible future exploration, not a commitment in this build.
- Explore the personal Shepherd in the hero. Its art may be revised to fit Ollie/sheep more
  closely, but clothing and cosmetic customization must remain intact. Inclusion and release
  timing are not yet chosen.
- Compare the title's moon with the supplied Counting Sheep logo; replacement is not yet chosen.
- The founder confirmed only the dark-tile logo is available and supplied a larger JPG.
  Do not keep requesting a transparent/vector original or make it a prerequisite for Home work.
- The window should follow the iPhone's local time. The initial implementation uses daytime
  from 06:00 until 18:00 and nighttime otherwise, with foreground/time-zone refresh and no
  location permission. This is an illustrative clock-based scene, not measured sunrise/sunset.
- The optional Shepherd comparison must use visible character proportions and a shared ground
  line, not equal image-canvas sizes. Ollie stays unchanged; the Shepherd's visible height is
  approximately 1.1 times seated Ollie's height. This does not approve a native Shepherd hero.

The older body-timing sheet still contains rejected ears. Approval of the two new poses does
not approve that sheet, its asset quality, or its use in production.

## What changed in the prototype

The round label now has nonwrapping text and can move intact to a new flex row. Personal Ollie
remains the default. A checkbox compares a single personal Shepherd beside Ollie, retaining
Ollie's size and omitting the lamp so there is only one background ornament. It uses existing
Shepherd art and is not a redesign of the avatar. The group-scene option is marked deferred.

The header selector compares the existing moon with the **unaltered** supplied logo at 28 px.
Its large padding makes the actual sheep tiny. Recommendation: keep the moon for this pass;
then compare a clean, tightly framed sheep-only transparent/vector source. A sheep mark could
give the header more specific brand identity, but the dark tile and surplus padding should not
be part of an inline title mark. No brand asset has been cleaned or regenerated here.

Logo follow-up: a clean mark can be derived from the supplied artwork in a separate design
pass and compared at actual header size. That would be a newly prepared asset requiring visual
review, not an existing transparent source. Keeping the moon is the recommended default for
this implementation; logo replacement remains optional and does not block the work.

## Next implementation pass and review checkpoints

1. Confirm the actual working candidate and preserve all earlier Home/session/social repairs.
   Record the source baseline before edits; do not assume another task's checkout has them.
2. Implement the approved native Home composition with real view-model data and the existing
   idle animation first. Keep personal Ollie alone and the moon as defaults. Show actual native
   screenshots beside the approved prototype at small/large sizes and larger text before
   expanding scope; a successful build alone is not visual acceptance.
3. Prepare the approved ear/tongue/flop actions as coherent production assets, then integrate
   the same repertoire into Home and Farm with the necessary cosmetic alignment. Review clips
   of each action and the return to idle in both scenes. Do not silently substitute the rejected
   body-study ears or call the approved stills a finished animation.
4. Re-run build/tests and interaction regression checks, inspect the complete candidate, and
   report exact changes, evidence and remaining gates. A new app build or distribution is a
   separate step; physical-device/two-account and rollout checks cannot be claimed from the
   prototype. Stay in this parent task for orchestration and acceptance.

The native Home and both-scene Ollie animation work are the next delivery scope. Shepherd
restyling, adding the Shepherd to the hero, a shared Farm, and logo replacement remain separate
design choices. None needs to be resolved to begin the approved implementation.

## Implementation checkpoint — 2026-08-28

Native composition and social preview work is in progress in the existing checkout, with the
inherited repair candidate preserved separately in `/tmp/counting-sheep-home-hero-20260828`.
Corrected main test runs passed 716 tests. Exact revisions and remaining validation gates are
recorded in `home-hero-implementation-checkpoint.md`; green tests alone do not accept the design.

The window is now a small native four-pane UI ornament with day/night skies driven by the
iPhone's local clock. No duplicate raster window assets or image cleanup are required for it.
**The new Home/Farm animation assets are not integrated yet.** Farm's action callback is still a neutral renderer, and Home's
new accessory parameter has not yet been connected to authored pose-compatible layers.

Two built-in image-generation attempts returned painted checkerboards without alpha. Neither
is a usable production sprite atlas. Deterministic background removal, frame registration and
cosmetic preparation were explicitly authorized by the founder on 2026-08-28. The processed
sprite/runtime implementation and its validation are recorded in `ollie-motion-implementation.md`.
Do not ship the unprocessed attempted images, claim the still candidates are animations, or silently substitute
another image-generation API. The Mac relocked and was subsequently accessible again; immediate
and scheduled start routing were exercised, but this does not replace physical-device QA.
The founder rejected the Shepherd comparison's art mismatch and chose removal from the current
preview. Ollie alone remains the native/default preview. An off-by-default design comparison
may show the centered pair; it is not a newly shipped app preference.

## Delivery sequence

### 1. Native Home composition

Use existing design tokens and navigation. Restore the personal welcome above compact plan and
Slumber Party content; do not revive the oversized duplicated Wind Down container. Keep the next
relevant phone-away/phone-wake times understandable and expand for bedtime, personal wake time,
quiet bookends and editing. The static prototype's example times are not production derivations.

The Slumber Party preview uses real current-member/expiry/block projections, with one stable
highlight per visit and truthful no-group/no-activity/offline fallbacks. Joining already enables
sharing; round lifecycle is progress context, not a sharing gate. Respect the multiple-party
model: preserve a route to all parties and never mix members, highlights or round labels between
groups. Do not reset a still-valid selected party after refresh. Do not infer that someone is
online or at home from an avatar being drawn.

Preserve contextual guidance/library access, resumable onboarding anchors, protection repair,
session-start navigation and the Active/receipt shell. A cosmetic redesign must not regress
the earlier Phone Away fixes. Keep the same four tabs and existing reward settlement.

### 2. Shared Ollie motion, delivered for Home and Farm

Retain separate actions: existing head tilt, a brief photo-based ear tuck, a brief tongue
greeting, and ear tuck → relaxed flop → rest for a few seconds → rise. Do not force tongue-out
into every rest or every cycle. Use occasional variations separated by neutral holds, without
immediate repeats; finalize cadence after seeing the finished motion at actual sizes.

Generate new transition frames from the approved poses and original Ollie identity. Check face,
purple eyes, blaze, proportions, ear continuity, tongue attachment and the return to neutral.
Require true alpha, consistent canvas/ground registration and no dark rectangle or painted
checkerboard on the Farm background. The prototype stills are not ready to drop into the app.

Code inspection found two different renderers:

- `Views/Components/OllieRitualView.swift`: Home idle frames and timing.
- `Views/Components/FarmSharedComponents.swift:195`: `OllieFarmAvatar` uses a neutral static base,
  equipped accessory overlay and a fixed depth mask. `FarmPastureView.swift` supplies a settled
  position and a 72-point size.

Create a shared action/frame vocabulary, with scene-specific size and ground anchor. Farm must
use matching accessory transforms or authored pose overlays/depth masks; a fixed scarf over a
flopping body is not acceptable. Preserve equipped item IDs and cosmetic appearance in both
scenes. Pause expressive motion during Farm dragging and keep settled position, footprint,
tap hit testing and persistence stable. Shop/member thumbnails need not acquire animations.

Pause offscreen and while backgrounded; honor Reduce Motion with a settled still. Preload only
the required action frames; check memory, decode cost and frame pacing on a physical device.
No new timer, progression, social publishing or reward side effects belong in the animator.

### 3. Shepherd art refresh in a separate phase/build — recommendation

The current `ShepherdAvatarView` layers a hair-specific base, skin mask, optional outfit tint,
authored outfit overlay and hair-specific accessory. Five hair silhouettes and skin choices
already exist. A replacement flattened image would discard that functionality.

First approve a small style board with proportions, face, texture and outline treatment that
sits comfortably beside Ollie/sheep. Then rebuild base and masks with fixed attachment anchors,
adapt every existing clothing/accessory asset, and compare the full customization matrix in
Home, Farm, Shop, onboarding and Slumber Party thumbnails. Preserve saved appearance/catalog IDs
and equipped purchases; no resets. Distinguish avatars through existing skin, hair and clothing
before adding new data or personality systems.

Recommendation: keep Ollie as the emotional lead now. Decide whether to include the small
personal Shepherd after reviewing its composition toggle; do not make that an automatic choice.
Stage the art migration separately so it does not delay or destabilize the Home/session repairs.

## Acceptance checks before native acceptance

- Compare real screenshots at small and large iPhone sizes and Dynamic Type. No clipped round
  label, crowded plan row, tiny Ollie or duplicate setup/start CTAs. Validate scrolling to the
  library and all actions. The HTML larger-text toggle is not an iOS Dynamic Type test.
- Verify no-party, one/multiple-party, before/between/active-round, empty/stale/offline and
  protection-repair states using actual data. A single highlight must stay scoped and factual.
- Start immediate and scheduled Phone Away from all entry points: visible immediate transition,
  no extra back navigation or app switch. Purpose changes update immediately. Test session
  restore, early end and independent Wind Down/morning/Phone Away/party reward settlement.
- Run all animation actions in Home and Farm, equipped and unequipped, including interrupted
  transitions, Reduce Motion, background/foreground, drag and tab changes. No jumping/bleeding
  sprites, cosmetic loss, repeated decoding spikes or new frame-driven global state updates.
- Build/tests, native visual inspection, VoiceOver and physical-device checks remain necessary.
  Existing physical two-account and hosted rollout/privacy gates remain separate. Prototype
  screenshots and previously green source tests do not satisfy these new checks.

## Remaining design choices

1. Keep personal Ollie alone, or add the small personal Shepherd beside him? Prototype permits
   comparison; Ollie alone remains the selected default until the founder chooses otherwise.
2. Whether to replace the moon after reviewing a clean mark derived from the dark-tile source.
   Source availability is resolved: there is no separate transparent/vector original.
3. Confirm separate-phase Shepherd restyling when scheduling that work; no new avatar art or
   shared-Farm implementation is included in the current prototype.
