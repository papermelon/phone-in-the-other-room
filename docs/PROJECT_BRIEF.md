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

Slumber Party is a core feature and reason to return together, not a peripheral companion link
(founder clarification, 2026-08-27). Friends, couples and families should recognize one another,
see factual shared activity respond promptly, and encourage each other. Idle Home must express
that value alongside a compact, reliable personal start flow. New sharing fields and any change
to seven-night round eligibility remain explicit contract decisions.

Founder decisions on 2026-08-28 set the next Slumber Party slice: adults first with a coordinating
leader; a chosen Shepherd/Ollie/sheep social avatar; last-night sleep and week/month means with
detail; automatic exact-app accountability for Singapore/SEA; and one disclosed sharing contract
accepted at joining, without per-field switches while remaining in the party. Leaving withdraws
new party sharing. Adults may join without Health data. Contextual Health/Screen Time connection
controls should avoid mandatory detours through the app's Settings hub. Later joiners should see
prior group history, and ordinary leave should preserve earlier contributions. Archive duration,
expanded-audience consent and meaningful privacy withdrawal/deletion require review; the joining
agreement does not make history irrevocable. Friendly competition remains a direction to define.
These are planned requirements, not current capabilities. A supported Singapore app-data export
route, truthful connection-state behavior and privacy review must be resolved before delivery.
See `plans/slumber-party-shared-habits-and-guide.md`; older implementation descriptions below
must not be used to veto this new direction or claim it has shipped.

First-run onboarding makes the promise legible through two varied story pages and an optional
chapter of six categorical, local behavioral questions. Explicit answers yield one non-clinical
Wind Down starting pattern and, when separately supported, one secondary pattern; missing answers
never become claims. The explanation and sourced suggestion are separate from a universal
welcome gift: every person, including someone who skips the questions, may choose one finished
Shepherd wearable, claim it exactly once, and wear it now or preserve their existing appearance.
Schedule, quiet durations, private routines, and optional explained reminders remain explicit
choices; saving a schedule or reminder never starts Wind Down automatically. The Farm begins
with one starter sheep. App shielding is the simplest no-hardware
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

- **Home**: one-time Wind Down plan → optional authorized reminder → one-tap Wind Down →
  wind-down / overnight / morning-quiet phases → morning completion or kind early end.
  Active runs label those phases as phone-free wind-down, sleep time, and phone-free morning.
  Silent phase-change notices support bedtime and waking, followed by the requested audible
  completion. Setup also offers a private, optional ordered sequence of up to three evening
  suggestions and two morning suggestions. Putting the phone away is always first. Suggestions
  have no checkmarks, verification, reward, score, streak, or claim that they were completed.
  Custom wording stays in-app unless the person separately allows it in notifications. Home names
  the exact eligible ritual before it starts: the usual Wind Down, a bounded Phone Away, or the
  optional five-minute practice. Actions use “Put phone away,” “Start now,” and “Plan.” New
  Wind Down, Screen-Free Morning, and Phone Away starts require Family Controls authorization
  and a non-empty opaque app/category selection; runtime failure fails open and offers repair.
  NFC is the default Wind Down tag for new plans; App Shielding remains the simplest
  no-hardware path. A writable generic NDEF tag can be
  registered, replaced, forgotten, or recovered in place; Settings can recognize a valid
  Counting Sheep credential from another installation and explicitly reset and pair it even
  when local tag history is empty. Blank tags pair normally, and NFC mode requires that same tag to end
  normally while retaining a multi-step emergency exit. An automatic Wind Down can send
  a chosen Quiet, Balanced, or Supportive cadence and schedule selected-app shielding at the
  saved start time while the app is closed. Optional usage-aware reminders can send one
  generic cue after three minutes in selected apps in each phase, including overnight.
  App protection limits only the selected apps from an eligible Wind Down start through
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
  The feature-flagged **Slumber Party** v4 source and production backend were deployed on
  2026-08-25; updated app distribution and physical proof remain pending. Farm and Home lead to
  a relationship-first **Your Slumber Parties** landing: existing parties come first, while
  create/join fields appear only after the chosen action is opened. A party is
  one long-lived, invite-only group of 2–8 people with a customizable name and fixed seven-night
  rounds. The host starts a round once there are at least two members; the same group, name, and
  members can start another round afterward. Members may join during an active round and backfill
  their factual Wind Down and Phone Away records for that round. Everyone in the party sees its
  current records, revisioned expiring statuses, curated profile snapshots, and fixed cheers.
  Founder clarification on 2026-08-27 makes Slumber Party a core social feature and reason to
  return. Idle Home may show existing member-visible profiles, current statuses and factual
  shared moments from the same party detail cache; it is no longer restricted to a list-only
  bridge. Personal Wind Down and Phone Away remain easy to start. Neither Home nor detail
  infers inactivity from missing updates. Farm explains that the curated Farm look travels and
  settled wool returns to the local Farm. Sharing before/between rounds is approved; an additive
  membership stream keeps rounds as a progress/reward boundary. Newly shared private fields
  remain a separate contract decision; current privacy and reward rules stay in force.
  The active invite stays redeemable through an active round; every current member can retrieve and
  share it, while only the host can create, replace, or revoke it. An ordinary member may leave;
  the host cannot leave and must delete the party for everyone. Ownership transfer is future work.
  One account may hold up to five concurrent parties, and the same qualifying local
  activity can earn separately in each eligible party. The shared profile is a canonical display
  name plus a curated Shepherd look, Ollie ornament, featured sheep definition, and pasture theme;
  no Farm inventory, wool, or full profile is uploaded. There is no feed, chat, discovery, or
  leaderboard. Active Wind Down has no in-app social UI; only best-effort silent system-surface
  feedback may appear and it never delays the local ritual.
- **Settings**: **Your Wind Down**, **Connections**, **Privacy & data**, and **Help & app guide**.
  The compact root uses focused detail screens, progressive disclosure, and contextual help. Your
  Wind Down contains Appearance, Plan & routine, Protection & tags, Reminders & Lock Screen, and automatic
  Wind Down and shielding. Help & app guide contains “How Wind Down works,” guidance beside
  routine choices, and the secondary **“About these ideas and sources”** link to the full locally
  bundled source library. There is no duplicate Review Wind Down setup route. Connections contains
  Apple Health, Screen Time, and Slumber Party when enabled and appropriate. Privacy & data contains the
  privacy policy, optional impact-sharing controls, and a destructive local reset that erases the saved Wind Down plan,
  NFC pairing, selections, and local history before returning to Welcome; system permissions and remote impact
  records remain outside that reset. Help & app guide contains the guide, practice, sources, feedback, support,
  and app details. Optional feedback
  can use private Supabase delivery only after its release gates pass, and otherwise uses a
  prefilled email fallback.

  App protection is a required, consented readiness condition for every new Wind Down,
  Screen-Free Morning, and Phone Away start. Family Controls authorization and a non-empty opaque
  app/category selection are required; denial, revocation, unavailability, or an empty selection
  routes to repair rather than a timer-only run. A runtime apply/restore failure after a valid
  start fails open and remains factual, but asks for repair before the next start. Routine examples
  are prompts rather than defaults; “Put phone away” remains the fixed first evening step, while
  Phone Away keeps its simple title-and-purpose editor.

**Gated out of normal navigation:** general Friends, the legacy mock Farm/Shop, the legacy keepsake
shelf, and mock-data screens. Debug access requires `-ollie.debug.enableMockScreens YES`;
these screens are never reachable in Release. The shipping Farm and Farm Shop read only real
persisted production data. ADR-0016's production Slumber Party is a separate narrow exception.
TestFlight/Release archives compile it on (`SUPABASE_NIGHT_FLOCK_ENABLED=YES`); ordinary Debug
keeps it hidden and network-silent. The production schema, versioned invitation secret, and
authenticated state/command functions are deployed; that backend evidence does not establish
updated-app distribution, Apple-link recovery, physical-device behavior, moderation readiness,
retention operations, or privacy publication.

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
