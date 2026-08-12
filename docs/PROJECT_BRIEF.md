# Counting Sheep — Project Brief

*(Repo/code name: "Phone in the Other Room". Canonical agent guide: [`AGENTS.md`](../AGENTS.md).)*

## One-paragraph summary

Counting Sheep is an iOS + watchOS app that protects phone-free time around sleep. Before
bed, the user starts Wind Down and physically puts the phone in another room; it
stays tucked away overnight and through a chosen morning-quiet window. An Apple Watch can make
one optional placement check using Nearby Interaction (UWB). Ollie, a pixel-art border collie,
guards the ritual and offers one user-chosen offline cue before bed and after waking. This is
a Wind Down ritual, not a productivity tool or sleep-quality tracker. The established
`NightWatch*` names remain internal for persisted-data compatibility.

First-run onboarding makes the promise legible: app shielding is the simplest no-hardware
starting point, NFC is an optional second layer, and Wind Down also offers a finite, locally
bundled set of cautious screen-time and sleep-habit ideas. These ideas are invitations, not
medical treatment, scores, or a feed. Its final save action explicitly hands off to a short,
dismissible app tour that spotlights the real Home plan, start action, and bottom navigation. A real
five-minute practice is offered afterward but never gates finishing the tour.

## Target user

Someone who scrolls later than intended in bed, reaches for the phone immediately after
waking, and has tried willpower-based fixes that did not stick. They do not want a clinical
sleep app or drill-sergeant blocker; they want the decision taken out of the bedroom, kindly.

## The core bedtime problem

The phone within arm's reach of the bed is the failure point. Software limits are easy to
dismiss in a tired moment. Counting Sheep makes **physical distance** feel like a warm ritual,
then carries that same decision through the first quiet part of the morning.

## The behavioural loop being addressed

```
in bed or newly awake → phone is within reach → "just one check" →
doomscroll longer than intended → less time for winding down or starting the day → repeat
```

Counting Sheep breaks the loop at "phone is within reach" and replaces the extraction point
with a warmer loop:

```
requested wind-down cue → open the app-access barrier →
optional Wind Down check → one offline evening cue → Ollie keeps the quiet →
one quiet morning cue → the phone wakes later → Ollie's Trail Note → Farm choices
```

The product loop is deliberately closed but small: **Prompt → Protect → Observe → Learn**.
Coaching remains a later layer and must offer one transparent experiment, not keep someone
inside the app. Counting Sheep supports the bedtime ritual; it does not become the ritual.

## Desired emotional tone

Warm. Cozy. Playful but calm. Like a children's-book farm at dusk. The user should feel
*cared for*, never policed, judged, or hustled. Ending a run early gets a warm factual
receipt, not a failure screen. Dark-room-friendly visuals; nothing urgent, flashing, or loud.

## Key product principles (full version: `docs/PRODUCT_PRINCIPLES.md`)

1. Physical separation is the product. Everything else supports the ritual.
2. The edges of sleep are the niche. Evening and morning screen time are the differentiator.
3. Build the ritual through purposeful habit formation. Completed primary protected nights
   resolve Ollie's search; found sheep join a finite, manageable flock with collection,
   shearing, trading, and customization paths.
4. Low friction wins. One tap to start. Setup is minutes, not a project.
5. Sequence substantial systems into coherent vertical slices so the bedtime ritual stays legible.

## App Store 1.0 scope (decided July 2026)

**Shipped surface: four tabs — Home, Nights, Farm, and Settings.**

- **Home**: one-time Wind Down plan → saved wind-down reminder → one-tap Wind Down →
  wind-down / overnight / morning-quiet phases → morning completion or kind early end.
  Active runs label those phases as phone-free wind-down, sleep time, and phone-free morning.
  Silent phase-change notices support bedtime and waking, followed by the requested audible
  completion. Setup also offers a private, optional reason for the quiet; custom wording stays
  in-app unless the person separately allows it in notifications. Home names the exact
  eligible ritual before it starts: the usual Wind Down, a bounded one-time quiet, or the
  optional five-minute practice. App limits can be skipped for one run without changing
  the saved shielding preference.
  NFC is the default Wind Down tag for new plans; App Shielding remains the simplest
  no-hardware path. A writable generic NDEF tag can be
  registered, replaced, or forgotten in place; NFC mode requires that same tag to end
  normally while retaining a multi-step emergency exit. An automatic Wind Down can send
  a chosen Quiet, Balanced, or Supportive cadence and schedule selected-app shielding at the
  saved start time while the app is closed. Optional usage-aware reminders can send one
  generic cue after three minutes in selected apps in each phase, including overnight.
  Optional shielding limits only the selected apps from an eligible Wind Down start through
  morning quiet; the barrier spans overnight and always has an early exit through the
  registered Wind Down tag or Counting Sheep's emergency exit.
  Home stays focused on the saved plan and one-tap start; its schedule block opens the timing editor
  and an Upcoming quiet times card opens a finite Once / Repeats / Usual Wind Down editor for bounded additional quiet.
- **Nights (one finite scroll)**: the latest primary night as the main result, consistently
  dated by the night-ending wake day; a newer one-time quiet period appears only as a compact
  secondary row. A seven-day board keeps protected, ended-early, and additional-only states
  distinct, while **View all nights** opens the shared calendar summary and grouped per-day
  detail. Morning note, Apple Health, and Screen Time appear together as optional context for
  the relevant night. Apple Health includes sleep duration, available core/deep/REM stages and
  seven-night wake-time range, and separate consented Screen
  Time reports for selected apps in user-chosen evening and morning reporting windows. Health
  samples are matched to the night they end; an older available sample is dated and never
  presented as last night. A collapsed, optional three-question morning note records the
  person's own rough sleep-onset, restfulness, and bedtime-sleepiness reflections without
  producing a score or reward. Screen Time reports identify their report date, show selected
  app time as a share of the full window, offer tappable hourly detail, and distinguish
  Apple's exact first iPhone pickup from selected-app activity. Reporting windows are
  independent of Wind Down durations. Overnight hours are never credited as focus or quiet
  minutes. Apple's Sleep Score remains in the Health app because HealthKit does not expose it
  to third-party apps.
  Once there are at least two protected and two other measured nights, a local comparison
  shows how sleep duration differs between them, explicitly as association rather than
  causation. Detailed behavioural and HealthKit history stays on the phone.
- **Farm**: a living paged pasture backed by the real active flock; one current narrative
  action; compact flock, discovery, and wool status; The Barn for finite capacity,
  shearing, trading, favourites, and pending arrivals; the Trail Board for missing sheep and
  one favoured lead; Ollie's Trail Notes for persisted results; and the nested Farm Shop plus
  Your Shepherd customization. Discovery history remains after an owned sheep is traded.
  The feature-flagged **Night Flock** hub is also nested here: two to eight Apple-linked,
  invited members share only positive phone-tucked and quiet-morning states through one
  seven-night challenge. It has preset identities, system aliases, fixed reactions, safety and
  deletion controls, and no feed, chat, discovery, leaderboard, reward, or Farm economy effect.
  A compact aggregate may appear on Home before Wind Down; active Wind Down has no social UI.
- **Settings**: Appearance, Wind Down schedule, bookends, App Shielding or NFC + App Shielding, automatic Wind Down and shielding;
  a replayable “How Wind Down works” explanation and a finite, source-linked guidance guide;
  Apple Health, Screen Time, and notification connections; optional impact-sharing controls;
  a destructive local reset that erases the saved Wind Down plan, NFC pairing, selections, and local history
  before returning to Welcome; system permissions and remote impact records remain outside that reset;
  privacy information; feedback and support; and app version information. Optional feedback
  can use private Supabase delivery only after its release gates pass, and otherwise uses a
  prefilled email fallback.

**Gated out of normal navigation:** general Friends, the legacy mock Farm/Shop, the legacy keepsake
shelf, and mock-data screens. Debug access requires `-ollie.debug.enableMockScreens YES`;
these screens are never reachable in Release. The shipping Farm and Farm Shop read only real
persisted production data. ADR-0016's production Night Flock is a separate narrow exception and
remains fully hidden and network-silent while `SUPABASE_NIGHT_FLOCK_ENABLED=NO`.

**Still deferred:** adaptive coaching, routine checklists, composite behavioural scores,
general Friends/social features beyond ADR-0016, and later sheep lifecycle systems such as
breeding or seasonal migration. They are not required for the current Farm loop.

## Non-goals

- Generic productivity / pomodoro timing
- Medical or clinical sleep tracking, sleep-quality scoring, or health claims
- Social feeds, leaderboards, or competitive mechanics
- Engagement for its own sake — success is the user returning for the phone-away ritual,
  then using selected distracting apps less around sleep
- Android, iPad, or web versions (iPhone-first; Watch is an optional Wind Down check)

## Success criteria for TestFlight

1. **It ships**: signed build on TestFlight, installable by external testers, no P0 crashes
   in the first two weeks.
2. **The ritual sticks**: testers complete Night Watch on 5+ of their first 14 nights.
3. **The tone lands**: qualitative feedback uses words like "cute", "calm", "gentle" — and
   nobody reports feeling guilted or nagged.
4. **The pitch is legible**: a new tester can explain what the app does after one session
   ("it puts my phone to bed and helps me wake before it, and there's a dog").
5. **The start choices are legible**: new plans begin with NFC and explain the honor timer,
   Watch, and QR as optional alternatives rather than prerequisites.
6. **Quiet behaviour and sleep outcomes are both observed honestly**: evaluate completed
   quiet minutes and, only with HealthKit consent, changes in sleep duration/stages and
   morning restfulness. Report sample sizes and associations; do not claim causation.
7. **The payoff is legible**: testers can explain how Wind Down creates a Trail Note, how a
   sheep reaches The Barn, and how keeping, shearing, trading, and customization differ.
