# Counting Sheep — Project Brief

*(Repo/code name: "Phone in the Other Room". Canonical agent guide: [`AGENTS.md`](../AGENTS.md).)*

## One-paragraph summary

Counting Sheep is an iOS + watchOS app that protects phone-free time around sleep. Before
bed, the user starts Wind Down and physically puts the phone in another room; it
stays tucked away overnight and through a chosen morning-quiet window. An Apple Watch can make
the phone-authoritative timer glanceable, while the current release starts protection with
either the timer or an optional NFC tag. Ollie, a pixel-art border collie,
guards the ritual and offers a private sequence of up to three evening and two morning
suggestions. This is a Wind Down ritual, not a productivity tool or sleep-quality tracker. The established
`NightWatch*` names remain internal for persisted-data compatibility.

First-run onboarding makes the promise legible: a short local questionnaire produces a
non-clinical Wind Down starting point, the Farm begins with one starter sheep, and a pending
shepherd wearable waits to be claimed later. App shielding is the simplest no-hardware
starting point, NFC is an optional second layer, and Wind Down also offers locally bundled,
cautious screen-time and general sleep-health ideas beside private routine choices. These ideas
are invitations, not insomnia treatment, scores, or a feed. Its final save action hands off to a
resumable in-app guide on the real Home, Farm, Settings, and Nights screens. A five-minute
practice is offered in that guide and never gates finishing it; completing that practice grants
one additional Farm sheep as a welcome gift, without counting as a Wind Down.

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
optional Wind Down check → private evening suggestions → Ollie keeps the quiet →
private morning suggestions → the phone wakes later → Search Journal → Farm choices
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
  completion. Setup also offers a private, optional ordered sequence of up to three evening
  suggestions and two morning suggestions. Putting the phone away is always first. Suggestions
  have no checkmarks, verification, reward, score, streak, or claim that they were completed.
  Custom wording stays in-app unless the person separately allows it in notifications. Home names
  the exact eligible ritual before it starts: the usual Wind Down, a bounded Phone Away, or the
  optional five-minute practice. Actions use “Put phone away,” “Start now,” and “Plan.” App limits can be skipped for one run without changing
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
  and a Phone Away schedule card opens a Once / Repeats editor for bounded phone-away breaks.
- **Nights (one finite scroll)**: the latest primary night as the main result, consistently
  dated by the night-ending wake day; a newer Phone Away appears only as a compact
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
  shearing, trading, favourites, and pending arrivals; **Ollie's Search** for missing sheep and
  one favoured lead; **Search Journal** for persisted results; and the nested Farm Shop plus
  Your Shepherd customization. Discovery history remains after an owned sheep is traded.
  The feature-flagged **Slumber Party** experience appears as a full-width contextual card on
  Farm and Home when enabled. The product promise is: “Slumber Party lets 2–8 people choose one
  Wind Down goal, try routines that work for them, and encourage one another for seven nights.”
  A lobby waits for at least two members, goal acceptance, local setup readiness, and an explicit
  host start. Members keep their own bedtimes and routines; selected source-linked routine ideas
  are optional. Named member progress, fixed reactions, safety controls, deletion, and reusable
  invite codes stay inside the invite-only group. Shared nights can grant a little wool, a small
  Farm keepsake, or one guaranteed Slumber Party sheep search, separate from Wind Down and Phone
  Away guarantees. There is no feed, chat, discovery, or leaderboard. Active Wind Down has no social UI.
- **Settings**: **Your Wind Down**, **Connections**, and **Help & app guide**. Your Wind Down
  contains Appearance, schedule, bookends, App Shielding or NFC + App Shielding, and automatic
  Wind Down and shielding. Help & app guide contains “How Wind Down works,” guidance beside
  routine choices, and the secondary **“About these ideas and sources”** link to the full locally
  bundled source library. There is no duplicate Review Wind Down setup route. Connections contains
  Apple Health, Screen Time, and notification connections; optional impact-sharing controls;
  a destructive local reset that erases the saved Wind Down plan, NFC pairing, selections, and local history
  before returning to Welcome; system permissions and remote impact records remain outside that reset;
  privacy information; feedback and support; and app version information. Optional feedback
  can use private Supabase delivery only after its release gates pass, and otherwise uses a
  prefilled email fallback.

**Gated out of normal navigation:** general Friends, the legacy mock Farm/Shop, the legacy keepsake
shelf, and mock-data screens. Debug access requires `-ollie.debug.enableMockScreens YES`;
these screens are never reachable in Release. The shipping Farm and Farm Shop read only real
persisted production data. ADR-0016's production Slumber Party is a separate narrow exception.
TestFlight/Release archives compile it on (`SUPABASE_NIGHT_FLOCK_ENABLED=YES`); ordinary Debug
keeps it hidden and network-silent.

**Still deferred:** UWB Watch placement checking, QR placement, adaptive coaching, routine checklists, composite behavioural scores,
general Friends/social features beyond ADR-0016, and later sheep lifecycle systems such as
breeding or seasonal migration. They are not required for the current Farm loop.

## Non-goals

- Generic productivity / pomodoro timing
- Medical or clinical sleep tracking, sleep-quality scoring, or health claims
- Social feeds, leaderboards, or competitive mechanics
- Engagement for its own sake — success is the user returning for the phone-away ritual,
  then using selected distracting apps less around sleep
- Android, iPad, or web versions (iPhone-first; Watch is an optional timer companion)

## Success criteria for TestFlight

1. **It ships**: signed build on TestFlight, installable by external testers, no P0 crashes
   in the first two weeks.
2. **The ritual sticks**: testers complete Night Watch on 5+ of their first 14 nights.
3. **The tone lands**: qualitative feedback uses words like "cute", "calm", "gentle" — and
   nobody reports feeling guilted or nagged.
4. **The pitch is legible**: a new tester can explain what the app does after one session
   ("it puts my phone to bed and helps me wake before it, and there's a dog").
5. **The start choices are legible**: new plans clearly distinguish App Shielding from
   optional NFC + App Shielding; neither requires the Apple Watch.
6. **Quiet behaviour and sleep outcomes are both observed honestly**: evaluate completed
   quiet minutes and, only with HealthKit consent, changes in sleep duration/stages and
   morning restfulness. Report sample sizes and associations; do not claim causation.
7. **The payoff is legible**: testers can explain how Wind Down creates a Search Journal entry, how a
   sheep reaches The Barn, and how keeping, shearing, trading, and customization differ.
