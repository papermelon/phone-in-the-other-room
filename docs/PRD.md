# Counting Sheep — Product Requirements

This PRD summarizes the implemented product. When it conflicts with `AGENTS.md`,
`PROJECT_BRIEF.md`, `PRODUCT_PRINCIPLES.md`, or an accepted ADR, those documents win.

## Product identity

- Shipping name: **Counting Sheep**
- Repository/code name: **Phone in the Other Room**
- Mascot: **Ollie**, a border collie who keeps Night Watch
- Product line: **Put your phone to bed. Wake up before it does.**

## Problem

The last part of the evening and first part of the morning are easy to lose to scrolling.
General screen-time tools offer broad schedules, strict modes, and productivity controls,
but they do not make physical phone separation feel like a small bedtime ritual.

Counting Sheep gives those two periods one memorable shape: tuck the phone into another
room at wind-down, leave it there overnight, and let it wake after the user does.

## Core promise

Counting Sheep helps someone practice a phone-away ritual around sleep. It records completed
Night Watches and quiet minutes in the two bookends. With permission it compares measured
sleep outcomes as context. It does not score sleep, diagnose a condition, or claim that
using the app caused an improvement.

## Primary user

Someone who scrolls in bed or reaches for the phone immediately after waking and wants a
gentler physical boundary, without adopting a productivity system or punitive blocker.

## Release scope

The first release contains three tabs:

- **Home:** understand tonight's saved plan and purpose, then set/start Wind Down or edit it.
- **Nights:** see protected nights, quiet-bookend minutes, recent history, optional sleep
  duration/stages, selected-app Screen Time, and cautious local outcome comparisons.
- **Farm:** see the equal protected-night flock and browse the finite Missing Posters carousel
  for cosmetic/story context; posters do not change progression value.
- **More:** configure Wind Down, manage connections and privacy, send feedback, and see app
  information.

Farm, Friends, Shop, adaptive coaching, social features, and mock-backed features are not
reachable in Release. Their gates are defined in ADR-0003 and ADR-0004.

## Core loop

1. The user saves an intended bedtime and wake time.
2. The user chooses 15–90 minute quiet bookends from the restrained presets presented by
   the UI; defaults are 30 minutes before bed and 30 minutes after waking.
3. The user chooses one evening and one morning phone-free cue. Cues are suggestions,
   never checklists or completion requirements.
4. At wind-down, the user begins Night Watch and physically places the phone elsewhere.
5. New plans default to the registered NFC phone-bed tag. The same tag confirms the initial
   tuck-in and the normal end action; Watch, QR, and the honor timer remain explicit alternatives.
   Automatic Wind Down can send 60/30/10-minute lead-ins and apply the selected-app shield at
   the saved start even while the app is closed; the app reconciles the run when next opened.
6. The same persisted session moves through wind-down, overnight, and morning quiet.
7. At the end of morning quiet, Ollie presents one calm completion receipt and one equal
   sheep settles into the cumulative flock.
8. Ending early remains available at all times and receives kind, non-punitive copy.

## Night Watch phases

| Phase | Starts | Ends | Product behavior |
|---|---|---|---|
| Wind-down | Actual start | Intended bedtime | Show the evening cue and time until bedtime. |
| Overnight | Intended bedtime | Saved wake time | Keep status glanceable; ask for no further interaction. |
| Morning quiet | Saved wake time | Wake time + chosen bookend | Show the morning cue and time until the phone wakes. |
| Complete | Morning bookend end | User dismisses receipt | Show the receipt and one equal flock arrival. |

Night Watch may begin late. A late start protects only the quiet time that remains and is
attributed to the intended-bedtime date, including after-midnight starts.

## Session guards

- **Honor timer:** explicit no-hardware fallback when NFC, Watch, or QR is not desired.
- **Apple Watch assist:** one time-boxed Nearby Interaction placement check at tuck-in.
- **QR phone bed:** one scan where the phone rests, with manual-code fallback.
- **NFC phone bed:** provision and confirm a generic writable NDEF tag; QR/honor fallback
  remains available.

The iPhone is authoritative for timing, persistence, restoration, completion, and flock progress.
No later Watch distance can warn, punish, or end Night Watch.

## Phone-free cues

Evening options include reading a paper book, showering, preparing for tomorrow, gentle
stretching, writing on paper, and making a warm drink. Morning options include opening the
curtains, making breakfast, walking, getting ready, stretching, and writing.

Cues must remain optional. The app does not request proof, photos, streak compliance, or a
completed habit before restoring access or granting the Night Watch receipt.

## Progress and the flock

- Each completed primary sleep-bookend Wind Down settles one equal sheep; Farm's Missing Posters
  provide optional cosmetic/story context for named sheep.
- Later completed nights resolve into a persisted search outcome: sheep found or trail advanced.
- Factual receipts and a calm flock record make consistency visible without currency, rarity, or locked collections.
- Optional HealthKit, Screen Time, and self-reported signals only add bonuses; missing data never
  lowers the chance.
- Only elapsed wind-down and morning-quiet minutes appear in the factual receipt. A separate
  story-trail distance can drive search progress but is not a Health or GPS measurement.
- Overnight hours never become quiet minutes or improve flock value.
- Completed Night Watches update the record for the intended-bedtime date.
- An early end advances no search and does not remove prior progress.
- Exact odds are hidden by default and available through a More toggle. Rare sheep are cosmetic
  and story rewards only.

Legacy storage fields such as `totalFocusMinutes`, reward/economy fields, and the persisted
`FocusRun` type retain their names for backwards compatibility. Protected-night count remains
`totalCompletedRuns`; found sheep and search outcomes live in `SheepSearchState`.

## Screen Time reports and optional shielding

Screen Time is the flagship protection/measurement layer:

- Report late-evening and early-morning selected-app use separately and together.
- Reuse one consented app/category selection across both bookends.
- Optional shielding applies only during those windows and lifts overnight.
- Always provide an emergency exit and gentle early-unlock copy.
- Do not infer sleep, shame the user, or block the whole night merely because Night Watch
  is active.

The report, monitor, configuration, and action extensions are embedded and share only the
necessary Screen Time/shield contracts through the App Group. The 2026-07-30 App Store
export produced Family Controls distribution profiles for every Screen Time target;
physical-device QA and App Store server validation remain required.

## Optional sleep context

HealthKit optionally shows sleep interval, duration, and available stages. Empty data is
not presented as permission denial. The local protected-versus-other comparison waits for
two nights per group, reports sample sizes, and never frames correlation as causation.

## Platform behavior

- iOS 17+ and watchOS 10+
- Wall-clock timing survives backgrounding and is reconciled on relaunch.
- A local notification marks requested wind-down and morning completion.
- A Live Activity presents phase and next transition on supported system surfaces.
- WatchConnectivity mirrors the latest run and queues critical start/end/ping messages.
- Unsupported UWB or an unreachable Watch degrades to the honor timer.
- UserDefaults + Codable JSON remain the local persistence layer.

## Privacy

No GPS location or exact room identity is collected. Detailed schedules, history, HealthKit
context, reflections, flock progress, legacy reward records, and placement evidence stay local. Separately
consented impact rows are relative-night, purpose-limited, and deletable; see
`PRIVACY_DATA_MAP.md`.

## Non-goals

- Generic Pomodoro or daytime focus sessions
- A morning routine builder or habit checklist
- Medical sleep tracking or sleep scoring
- Continuous proximity monitoring
- Punitive app blocking, loss-aversion streaks, or shame
- A social network
- Paid randomness or rewards for app opens

## Release acceptance

- A fresh user can configure both bookends and save tonight's plan.
- Inside the start window, one tap begins Night Watch.
- Honor, Watch, QR, and NFC starts all reach the same phone-authoritative session.
- Phase labels and next-transition timers are consistent across iPhone, Watch, and Live Activity.
- Background/relaunch restoration reaches the correct phase and completion state.
- Quiet-minute accounting excludes overnight time, including late starts and DST changes.
- Early end is always available and never uses failure haptics or guilt copy.
- Debug and Release show exactly Home, Nights, and Farm. More is a utility sheet; mock UI requires the explicit Debug
  internal-preview launch argument and is never reachable in Release.
- Optional shields cover only the two selected quiet windows and always clear on early end.
- HealthKit requests only read-only `sleepAnalysis` and labels available stage provenance.
- Legacy persisted runs decode without a Night Watch plan and retain their previous behavior.
