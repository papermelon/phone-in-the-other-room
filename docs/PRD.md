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
Night Watches and quiet minutes in the two bookends. It does not measure sleep quality,
diagnose a condition, or claim that using the app improves sleep.

## Primary user

Someone who scrolls in bed or reaches for the phone immediately after waking and wants a
gentler physical boundary, without adopting a productivity system or punitive blocker.

## Release scope

The first release contains two tabs:

- **Home:** configure and begin Night Watch; see the saved bookends, Ollie, and local progress.
- **Stats:** see protected nights, quiet-bookend minutes, recent history, and gentle trends.

Farm, Friends, Shop, HealthKit, Screen Time reports/pickers, and mock-backed features are
not reachable in Release. Their gates are defined in ADR-0003 and ADR-0004.

## Core loop

1. The user saves an intended bedtime and wake time.
2. The user chooses 15–90 minute quiet bookends from the restrained presets presented by
   the UI; defaults are 30 minutes before bed and 30 minutes after waking.
3. The user chooses one evening and one morning phone-free cue. Cues are suggestions,
   never checklists or completion requirements.
4. At wind-down, the user begins Night Watch and physically places the phone elsewhere.
5. The default honor timer starts immediately. Optional Watch or QR guards may confirm the
   initial tuck-in, but always offer a timer fallback.
6. The same persisted session moves through wind-down, overnight, and morning quiet.
7. At the end of morning quiet, Ollie presents one calm completion receipt and reward.
8. Ending early remains available at all times and receives kind, non-punitive copy.

## Night Watch phases

| Phase | Starts | Ends | Product behavior |
|---|---|---|---|
| Wind-down | Actual start | Intended bedtime | Show the evening cue and time until bedtime. |
| Overnight | Intended bedtime | Saved wake time | Keep status glanceable; ask for no further interaction. |
| Morning quiet | Saved wake time | Wake time + chosen bookend | Show the morning cue and time until the phone wakes. |
| Complete | Morning bookend end | User dismisses receipt | Reveal the completion record and one reward. |

Night Watch may begin late. A late start protects only the quiet time that remains and is
attributed to the intended-bedtime date, including after-midnight starts.

## Session guards

- **Honor timer:** default, no Watch required.
- **Apple Watch assist:** one time-boxed Nearby Interaction placement check at tuck-in.
- **QR phone bed:** one scan where the phone rests, with manual-code fallback.
- **NFC phone bed:** approved direction, not exposed yet.

The iPhone is authoritative for timing, persistence, restoration, completion, and rewards.
No later Watch distance can warn, punish, or end Night Watch.

## Phone-free cues

Evening options include reading a paper book, showering, preparing for tomorrow, gentle
stretching, writing on paper, and making a warm drink. Morning options include opening the
curtains, making breakfast, walking, getting ready, stretching, and writing.

Cues must remain optional. The app does not request proof, photos, streak compliance, or a
completed habit before restoring access or granting the Night Watch receipt.

## Progress and rewards

- Only elapsed wind-down and morning-quiet minutes count toward progress and reward value.
- Overnight hours never become quiet minutes, stars, sheep, coins, or reward rarity.
- Completed Night Watches update the record for the intended-bedtime date.
- An early end may reveal a Muddy Paw consolation but does not remove prior progress.
- Reward variety appears once at completion. The app does not tease upcoming random rewards
  or reward merely opening the app.
- Streak language is retrospective and warm; a missed night is always a fresh start.

Legacy storage fields such as `totalFocusMinutes` and the persisted `FocusRun` type retain
their names for backwards compatibility. Active customer copy calls them quiet-bookend
minutes and Night Watch.

## Screen Time direction

Screen Time is the flagship post-first-release measurement layer:

- Report late-evening and early-morning selected-app use separately and together.
- Reuse one consented app/category selection across both bookends.
- If shielding is enabled later, apply it only during those windows by default.
- Always provide an emergency exit and gentle early-unlock copy.
- Do not infer sleep, shame the user, or block the whole night merely because Night Watch
  is active.

Shipping this requires Family Controls distribution approval, an App Group, extension
embedding, signed capabilities, physical-device QA, and explicit human approval. The current
report extension is scaffolding and remains unembedded.

## Optional sleep context

HealthKit may later show last-night sleep duration as private, optional context. Empty data
must not be presented as permission denial, and correlations must not be framed as causation.

## Platform behavior

- iOS 17+ and watchOS 10+
- Wall-clock timing survives backgrounding and is reconciled on relaunch.
- A local notification marks requested wind-down and morning completion.
- A Live Activity presents phase and next transition on supported system surfaces.
- WatchConnectivity mirrors the latest run and queues critical start/end/ping messages.
- Unsupported UWB or an unreachable Watch degrades to the honor timer.
- UserDefaults + Codable JSON remain the local persistence layer.

## Privacy

No GPS location or exact room identity is collected. Core schedules, history, progress,
rewards, and placement evidence stay local. Optional backend delivery must remain additive
to the local completion path and be covered by current privacy disclosures before enabling.

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
- Honor, Watch, and QR starts all reach the same phone-authoritative session.
- Phase labels and next-transition timers are consistent across iPhone, Watch, and Live Activity.
- Background/relaunch restoration reaches the correct phase and completion state.
- Quiet-minute accounting excludes overnight time, including late starts and DST changes.
- Early end is always available and never uses failure haptics or guilt copy.
- Release shows only Home and Stats, with no mock or entitlement-gated UI.
- Legacy persisted runs decode without a Night Watch plan and retain their previous behavior.
