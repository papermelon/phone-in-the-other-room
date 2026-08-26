# Shielding-First Wind Down and Screen-Free Morning — Product and Implementation Plan

Status: founder decisions complete; ready for Terra High implementation
Prepared: 2026-08-23
Intended implementer: Terra High through the configured Sol Advisor native lane

## Start the implementation chat with this prompt

> Implement the founder-approved independent Wind Down and Screen-Free Morning design in
> `docs/EARLY_WAKE_WIND_DOWN_IMPLEMENTATION_PLAN.md`. Read `AGENTS.md` and every required
> canonical document first. Invoke `sol-advisor:orchestration`, load its setup status and saved
> preferences, and read the role contracts required by that skill before delegating. Use the exact
> configured `sol_advisor_high` / Terra High role for implementation and a fresh
> `sol_advisor_advisor` / Sol review at the required commitment and final-review boundaries; do not
> substitute a different model or generic worker. Treat the answers recorded in the Founder decisions section
> as authoritative. If any required answer is still marked unresolved, stop and ask rather than
> choosing a reward rule. Preserve unrelated working-tree changes, do not edit generated
> `project.pbxproj`, do not change entitlements/targets/tabs, keep persisted JSON backward
> compatible, add Shared tests, run the repository build/test gates, and report the exact diff and
> verification results. Do not commit or push unless explicitly asked.

## Problem to solve

A person can keep the phone away through the evening and overnight, wake earlier than their saved
wake time, and reasonably want to finish the current Wind Down. Today that action is classified the
same way as abandoning the ritual during wind-down. The factual quiet minutes are saved, but the
release-facing receipt says “Wind Down ended,” the Nights surfaces say “Ended early,” and the run
cannot resolve Ollie's Search. It also does not advance the ordinary completion counter used by
legacy progression and wool regrowth.

The founder has clarified two connected issues. First, **Wind Down and Screen-Free Morning (the
existing `MorningQuiet*` domain internally) must become independently settled mechanisms with
separate reward systems.** Completing Screen-Free Morning must not be required to
earn the benefits of an otherwise qualifying Wind Down. A 420-minute protected Wind Down already
earns its Wind Down benefits. Screen-Free Morning remains valuable, but it can start early, remain at the
usual time, or be skipped without revoking the completed Wind Down settlement.

Second, **shielding the person's chosen social-media and scrolling apps is a required core
behavior-change mechanism, not an optional footnote or a peer choice beside a timer.** The intended habit loop is to interrupt automatic app opening,
add gentle friction at the point of temptation, keep the phone physically away when possible, and
make room for something the person actually values. Platform denial/unavailability must still fail
open for runtime safety, but every new-session path must require app-protection readiness.

## Current implementation evidence

- `FocusRun` has a binary terminal model: `.completed` plus `completedSuccessfully = true`, or
  `.endedEarly` plus an `EarlyEndReason`.
- `FocusSessionCoordinator.finish(run:)` settles rewards, progress, Ollie's Search, history,
  shielding, notifications, Live Activity, Watch state, and Slumber Party publication.
- `RewardEngine.generateReward` creates a legacy `Muddy Paw Print` consolation item for an eligible
  early-ended Wind Down, but `EarlyEndView` does not present that item and the production reward
  shelf is gated.
- `RewardEngine.updatedProgress` advances completed-run progress only when
  `completedSuccessfully` is true.
- `FocusRunRules.qualifiesForProtectedNightSearch` additionally requires a primary Wind Down and a
  protected span of at least 420 minutes. Overnight time is used only for this eligibility span;
  credited minutes remain the two quiet bookends.
- `SheepSearchEvidence` currently gives actual/planned Morning Quiet up to 25 trail-strength points.
  That is an existing reward coupling and must stop for new Wind Down outcomes under the founder's
  independent-reward direction. Retain the fields for historical decoding, but do not let new
  Morning Quiet behavior change Wind Down odds.
- `NightWatchRecord` already saves actual credited wind-down and morning-quiet minutes for an
  early-ended run, but its public outcome is only `.completed` or `.endedEarly`.
- `ActiveRunPresentation` always offers “End Wind Down early”; it does not distinguish wind-down,
  overnight, and morning-quiet intent.
- NFC-protected runs require the registered tag for a normal terminal action. Any new finish action
  must preserve that boundary and the multi-step emergency exit.

## User-research signal and product thesis

The founder supplied a screenshot and this
[r/productivity discussion](https://www.reddit.com/r/productivity/comments/1t3q3fx/how_do_you_actually_stop_endless_scrolling/)
as anecdotal user-research context, not clinical evidence or implementation instructions. Recurring
themes in the thread are:

- scrolling often begins as an automatic app open rather than a conscious decision;
- adding friction at entry can be more useful than relying on willpower;
- physical distance, selected-app limits, hidden/deleted apps, and browser-only access create that
  friction at different strengths;
- replacing the reflex with a small valued activity is easier than demanding a perfect overnight
  transformation; and
- gradual reductions and factual progress feel more sustainable than shame or all-or-nothing copy.

Counting Sheep should embody the parts that fit its sleep-bookend niche:

```text
Name what this time is for
    → choose the scrolling/social apps that usually take it
    → put the phone away and start protection
    → interrupt an automatic app open at the shield
    → recall the chosen purpose before any Brief Access
    → return to rest, reading, work, relationships, or another offline value
    → record the phone-away span, Screen-Free Morning minutes, and deliberate pauses honestly
    → settle the appropriate Wind Down / Sunrise / Phone Away Farm progress
```

The product does not diagnose “screen addiction,” promise recovery, or grade discipline. It can say
that it helps interrupt automatic scrolling, makes chosen apps harder to reopen, and supports time
for what matters.

## Shielding-first product requirements

### Protection is the required session path

- First-run setup requires Family Controls authorization and at least one app/category selection
  before it can finish the release-facing ritual setup. The same readiness gate applies to new Wind
  Down, Screen-Free Morning, and Phone Away starts. Do not present “timer only,” “no app limits,” or
  an unshielded start as an equivalent mode.
- Before Apple's picker, recommend the actual kinds of apps that commonly restart the loop: social
  feeds and messaging communities, short-form video, streaming video, news, browsers used for those
  feeds, games, shopping, and any personally automatic app. Localized examples may include services
  such as Instagram, TikTok, YouTube, Reddit, X, Facebook, and Snapchat, but examples are guidance,
  not endorsements or a hard-coded blocklist.
- Apple's Family Activity picker is deliberately opaque. Counting Sheep can require a non-empty
  selection and report its token count, but it cannot inspect, preselect, verify, or later name the
  specific apps chosen. Copy must ask the person to align the selection without falsely confirming
  that a particular social-media app is present.
- Use a two-step alignment flow rather than a generic picker launch:
  1. **Ollie's recommended starting set:** social feeds/communities and short-form video first;
     video/news, games, shopping, and other automatic apps when personally relevant.
  2. Open Apple's picker, then show only the opaque selection count and ask **Does this include the
     apps that pull you back most often?** with **Review selection** and **Yes, continue**. This is a
     private self-confirmation, not app inspection or verification.
- Authorization remains consented and revocable. Denied/revoked/unavailable states show a focused
  repair screen—**Set up app protection**, **Open Settings** where available, and **Why this matters**—
  rather than starting a timer-only session.
- Runtime shielding remains fail-open for safety: if Apple fails to apply or restore a shield after
  an otherwise valid start, never trap the person or fabricate evidence. Show that protection is not
  currently active and offer repair. This safety behavior is not a marketed unshielded mode.
- Start sheets should summarize protection affirmatively—e.g. **App protection ready**—and
  make changing the selection easy. Do not bury the selection under generic technical wording.
- Use one saved selection across Wind Down and Screen-Free Morning in the first slice. A later decision
  may allow different selections, but it must not make onboarding harder now.

### The shield is the intervention point

- The shield should plainly say why the app is unavailable now and what the protected time was set
  aside for. Reuse the already approved pre-Brief-Access purpose check-in and run-scoped pause/minute
  tracker.
- Respect the OS capability boundary. On iOS 26.4 and later, use the native secondary-button submenu
  for the purpose choice before the five-minute grant. On earlier supported iOS versions, the system
  shield exposes only the single secondary action and cannot host an arbitrary Counting Sheep sheet;
  keep the purpose cue visible in the shield copy and label the one-tap grant honestly. Do not claim
  that the richer check-in exists on an OS version where ManagedSettingsUI cannot render it.
- Brief Access remains deliberate, bounded, and factual. It must not silently turn the protected
  period into an ordinary app limit. The person sees how many pauses and allotted minutes have been
  used in this occurrence.
- Shield and active-run copy should return attention to the person's private purpose without
  requiring proof, a checklist, or a moral judgment.
- Use a bounded local `QuietPurposeCue`-style enum in the first slice (for example prepare for
  sleep, read, focus on work, something offline, something else), not free text. Persist only the
  coarse cue needed for the active occurrence/Brief Access ledger, never sync it, never put it in
  Slumber Party or impact data, and clear the App Group presentation value when the occurrence ends.
  The opaque protected-app selection must never be interpreted as proof that a social app was chosen.
- Phase 1 guarantees selected **apps and categories**, not a whole iPhone. Social-media browser
  bypass remains possible because current selection intentionally ignores web domains. The founder
  has nevertheless approved **Screen-Free Morning** as the concise, aspirational habit name. A nearby
  help control must state that chosen apps are paused, Brief Access remains available, and websites
  are not yet included. The product should keep working toward a stricter implementation rather than
  quietly treating the current boundary as the final promise.

### Onboarding teaches the loop before teaching the Farm

The current onboarding mentions social media, but it does not make the causal loop memorable. Add a
short, finite explanation before or within the protection step:

1. **Catch the reflex.** “Choose the apps you open without meaning to.”
2. **Make room.** “When they pause, remember what this time is for.”
3. **Put the phone away.** “The shield catches the reflex. Another room makes space for the habit.”
4. **Start gradually.** “Fifteen minutes still count toward Screen-Free Morning progress.”

The user must make a real picker selection on the successful shielding path. The saved-plan summary
then confirms only opaque app/category token counts, the person's private self-confirmation, the two
independent mechanisms, and when each protection window begins and ends.

### Explain the Farm with three visible sources

Do not make people infer why a sheep or wool appeared. First-run guidance and the Farm's Search
Journal should consistently explain:

- **Wind Down:** a 420-minute eligible phone-away span resolves the nightly Ollie's Search and its ordinary Farm
  benefits, independent of Morning Quiet.
- **Sunrise Trail:** eligible Screen-Free Morning minutes fill a separate 100-minute meter. Every fill
  grants wool and can also produce a separately defined Sunrise sheep-search opportunity; these are
  not mutually exclusive rewards.
- **Phone Away:** retains its existing separate 100-minute meter and search track.

Onboarding should state only the simple rule for each source. Exact odds, guarantees, drought
behavior, and origin history belong in one **How Ollie's searches work** explainer reached from
Ollie's Search and Search Journal. Every result note names its origin—Wind Down, Sunrise Trail,
Phone Away, welcome gift, or Slumber Party—without exposing internal enum names.

## Recommended product design

### 1. Establish two independent settlement tracks

The saved nightly plan may coordinate both experiences, but their qualification and reward state
must be independent:

1. **Wind Down track** — the protected phone-away night. Reaching a 420-minute eligible phone-away
   span entitles the
   run to the full existing Wind Down benefits: one Ollie's Search settlement, first-three/bad-luck
   progression, wool regrowth, Shop progression, and qualifying Slumber Party status. Morning Quiet
   minutes are not a prerequisite and do not increase or decrease this track's entitlement, trail
   strength, encounter odds, guarantee, or drought state.
2. **Morning Quiet track** — a separately scheduled or manually started morning period with its
   own completion record and founder-selected reward system. Completing, shortening, deferring, or
   skipping it cannot revoke an already entitled Wind Down benefit.

Use separate idempotency ledgers/counters. Do not reuse the Phone Away meter, Wind Down guarantee
counter, or Wind Down drought state for Morning Quiet.

The canonical “one session, not two timers” rule is superseded by this explicit founder direction.
The implementation should still avoid two competing app-root coordinators: prefer one phone-side
coordinator that owns a Wind Down occurrence and an optional linked Morning Quiet occurrence, each
with independent settlement.

### 2. Resolve Wind Down at the 420-minute entitlement boundary

Wind Down benefit eligibility is factual and monotonic:

- A primary Wind Down becomes entitled once its eligible phone-away span reaches 420 minutes.
  Screen Time authorization, selection contents, and observed apply/clear evidence do not gate this
  reward. Shielding remains the consented behavioral barrier; it is not progression evidence.
- Resolve the deterministic benefit exactly once per Wind Down run ID at the boundary when the app
  can reconcile it or on the next activation/restore. Resolution is hidden persistence, not user
  delivery.
- Deliver the resolved benefit only when Wind Down reaches an authorized terminal action. Until
  delivery, do not add the sheep to the visible Farm/arrival queue, advance visibly rendered wool
  regrowth or Shop progression, append a visible Search Journal result, publish social completion,
  or expose the outcome through Nights, Home, Watch, Live Activity, widgets, or notifications.
- Reveal the delivered result on the terminal/morning receipt. Persist `resolvedAt`, `deliveredAt`,
  and `revealedAt` independently so termination or navigation cannot duplicate or lose a stage.
- Ending after entitlement does not remove or downgrade the benefit.
- Ending before entitlement saves factual quiet but does not consume a search, guarantee, drought
  step, Farm arrival, wool-regrowth unit, Shop unit, or qualifying Slumber Party night.
- The search outcome may be persisted at hidden resolution, but no overnight notification, clue
  teaser, animation, indirect Farm mutation, or reveal should make the phone interesting.
- Overnight minutes remain an eligibility span, never credited focus/quiet minutes and never a
  sleep-duration claim.
- New Wind Down search calculations ignore Morning Quiet evidence. Retain the Codable evidence
  fields for historical notes and decode compatibility; do not rewrite settled outcomes.

This requires separating **benefit settlement** from **whether the protection is still running**.
A qualifying run may continue shielding until the user ends it or Morning Quiet begins even though
its Wind Down benefit has already resolved invisibly.

### 3. Early-wake choice flow

Add **I'm awake early** throughout the overnight phase. It opens a calm choice sheet:

1. **Start Screen-Free Morning now** — end/close the Wind Down protection as authorized, begin a linked
   Morning Quiet occurrence immediately, and preserve the person's full configured Morning Quiet
   duration.
2. **Keep Screen-Free Morning at its usual time** — end/close Wind Down as authorized and retain tonight's
   Morning Quiet occurrence at the usual saved time. This does not edit the recurring schedule.
3. **Skip Screen-Free Morning today** — end/close Wind Down as authorized, mark only tonight's linked
   Morning Quiet occurrence skipped, and leave the recurring schedule unchanged.
4. **Keep Wind Down running** — dismiss without changing either occurrence.

If the Wind Down has reached 420 minutes, options 1–3 retain all Wind Down benefits. If it has not,
the receipt shows only factual quiet saved. For NFC-protected Wind Down, options that end Wind Down
still require the matching registered tag; the existing emergency exit remains the only no-tag
path.

The handoff deliberately does not add **Finish Wind Down now** as a separate competing choice: choosing
whether Screen-Free Morning starts now, stays at its usual time, or is skipped today already communicates
what happens next.

### 4. Persistence shape

Do not force independent rewards through `completedSuccessfully`. Add versioned, backward-compatible
settlement models equivalent to:

```swift
struct WindDownBenefitSettlement: Codable, Equatable {
    var runID: UUID
    var entitledAt: Date
    var phoneAwaySpanMinutes: Int
    var searchOutcomeID: UUID?
    var resolvedAt: Date
    var deliveredAt: Date?
    var revealedAt: Date?
}

struct MorningQuietOccurrence: Codable, Identifiable, Equatable {
    var id: UUID
    var linkedWindDownRunID: UUID?
    var scheduleOccurrenceID: UUID
    var scheduledStart: Date
    var scheduledEnd: Date
    var actualStart: Date?
    var endedAt: Date?
    var outcome: Outcome
    var rewardSettlementID: UUID?
}
```

Names may change, but the boundaries may not:

- Wind Down and Morning Quiet have different eligibility functions, settlement IDs, counters, and
  persisted outcomes.
- Missing new fields decode safely without retroactively granting or consuming anything.
- Saved `NightWatchPreferences` remain unchanged by an early-wake choice.
- Historical settled runs are not rewritten.
- Restore after termination reconstructs both the Wind Down entitlement and any deferred/active
  Morning Quiet occurrence without duplicate rewards.
- A linked Morning Quiet is not represented as Phone Away and cannot affect its meter.
- A scheduled Morning Quiet can exist without an active linked Wind Down; linkage explains origin,
  not eligibility. Device Activity scheduling and app reconciliation must start/end a deferred
  occurrence even when Counting Sheep is never opened during it.
- Morning Quiet credit is elapsed occurrence time, capped at the configured duration, once the
  occurrence reaches 15 minutes. Brief Access grants are reported separately and do not subtract
  from reward minutes because the app knows the allotted grant window, not actual in-app use. This
  policy remains an explicit founder checkpoint below.

### 5. Receipt and history hierarchy

Presentation should show the two tracks without making the morning feel like a penalty:

| Situation | Wind Down result | Screen-Free Morning result | Receipt emphasis |
|---|---|---|---|
| 420+ minutes, Screen-Free Morning completed | Benefits delivered | Separate reward settled | Two completed records, one calm summary |
| 420+ minutes, Screen-Free Morning deferred | Benefits delivered | Scheduled for usual time | Wind Down kept; Screen-Free Morning is still waiting |
| 420+ minutes, Screen-Free Morning skipped | Benefits delivered | No Screen-Free Morning reward | Wind Down kept; no loss language |
| Under 420 minutes | Quiet saved; no Wind Down benefits | Independent choice remains possible | Actual minutes, no failure framing |

Screen-Free Morning ends normally at its scheduled end or through a calm **Finish Screen-Free Morning** action.
Finishing before 15 elapsed minutes records the occurrence with no Sunrise progress; finishing at or
after 15 banks eligible actual minutes. A deferred occurrence that starts and ends while the app is
terminated settles deterministically on the next extension/app reconciliation.

Do not surface the gated legacy keepsake shelf merely to expose `Muddy Paw Print`. Retain decode
compatibility, but use a factual **Quiet saved** receipt for non-qualifying endings. Do not grant a
reward for opening the app, choosing a sheet option, or merely recording a reason.

### 6. User navigation and teaching flow

The protection choice and the Farm explanation must appear where the person makes decisions, not
only in Settings or an About page.

1. **First-run purpose:** ask what the person wants the sleep edges to make room for—rest, reading,
   a calmer morning, focused work, relationships, or their own private answer. This is a private cue,
   not a scored intention.
2. **Schedule:** configure Wind Down and Screen-Free Morning as related but independently rewarded
   periods. Explain that skipping Screen-Free Morning never takes away a qualifying Wind Down result.
3. **Protection:** request Family Controls and lead into Apple's picker with the concrete instruction
   to choose the social, video, news, or other apps opened on autopilot. A successful protected setup
   requires at least one opaque app/category selection. If authorization or the selection is missing,
   remain on a repair path; do not offer an unshielded timer as a normal continuation.
4. **How progress works:** use one concise, illustrated page to distinguish Wind Down, Sunrise
   Trail, and Phone Away. Do not show odds or economy internals here; link to **How Ollie's searches
   work** for detail.
5. **Ready summary:** show saved times, whether app protection is ready, the opaque selected-item
   count, and the next simple action: put the phone away.
6. **Home before a run:** show protection readiness beside the next Wind Down rather than hiding it
   in Settings. If no selection exists, replace Start with a calm repair action such as **Choose
   apps to pause**.
7. **Start sheet:** confirm that app protection is ready, remind the person to put the phone away,
   and show a fixed, private purpose cue. Do not offer an unshielded start.
8. **Active Wind Down:** keep the screen restful. Show the already approved Brief Access count and
   allotted-minute tracker, but no unresolved reward teaser.
9. **Early wake:** present **Start Screen-Free Morning now**, **Keep Screen-Free Morning at its usual
   time**, **Skip Screen-Free Morning today**, and **Keep Wind Down running**. If deferred, say that
   app protection will pause now and resume at the saved time.
10. **Active Screen-Free Morning:** lead with the offline action—put the phone away—then show the
    protected-app state, end time, private purpose, factual pause
    tracker, and Sunrise Trail minutes. Keep Slumber Party absent.
11. **Morning receipt:** deliver/reveal any already resolved Wind Down result and separately show Sunrise
    Trail minutes, wool, and any independently resolved Sunrise search. One result must never look
    conditional on the other.
12. **Farm and history:** show the Sunrise Trail near the other progression sources. Search Journal
    entries and sheep arrivals name their origin. Nights history keeps Wind Down and Morning Quiet as
    linked factual rows without turning the morning into a second social obligation.
13. **Settings:** put the saved protected-app selection and authorization health inside the existing
    Wind Down configuration route. Do not create a duplicate configuration flow.

Home routing precedence must be deterministic:

| State | Home priority |
|---|---|
| Screen-Free Morning active | Live Screen-Free Morning journey; unread Wind Down result remains queued |
| Screen-Free Morning deferred | Upcoming Screen-Free Morning card plus a recoverable unread Wind Down receipt |
| Screen-Free Morning skipped or finished | Wind Down receipt first, then the Screen-Free Morning factual row |
| Wind Down active with hidden resolution | Active Wind Down only; no Farm/result projection |
| No active occurrence, unread results | Oldest finite unread receipt, idempotently recoverable |

### 7. Product naming and draft copy

**Founder-approved feature name: “Screen-Free Morning.”** Treat it as the habit the product is
helping the person practise: put the phone away and keep the first part of the morning for life
outside the screen. The mechanism is required selected-app shielding plus physical-distance copy.

The name is intentionally punchier than the current platform boundary. Every first-use and nearby
help explainer must therefore say plainly: Counting Sheep pauses the apps/categories the person
chooses; unselected apps and websites remain available; Counting Sheep itself stays reachable; and
Brief Access can be used deliberately. Do not repeat this caveat in every headline, but never hide it
behind legalistic language or claim the whole device is technically disabled.

| Location | Current/option | Verdict | Recommended drop-in copy |
|---|---|---|---|
| Feature name | Morning Quiet | Rename | **Screen-Free Morning** |
| Feature promise | New | Add | **Put the phone away. Keep the morning for yourself.** |
| Protection setup title | App limits | Strengthen | **Interrupt the scroll before it starts** |
| Protection setup detail | Generic selection copy | Strengthen | **Choose the feeds, videos, news, games, or other apps you open without meaning to.** |
| Picker lead-in | New | Add | **Start with social media and the apps that pull you back most often.** |
| Ready state | New | Add | **App protection is ready. Now give your phone a place to rest.** |
| Missing protection | No app limits for now | Replace | **Set up app protection** |
| Missing protection detail | New | Add | **Counting Sheep uses app protection and distance together. Choose at least one app or category to continue.** |
| Overnight utility action | I'm awake early | Keep | **I'm awake early** |
| Early-wake sheet title | Good morning. Plans can change. | Keep | **Good morning. Plans can change.** |
| Sheet detail | New | Keep brief | **Start Screen-Free Morning now, leave it at your usual time, or skip it today.** |
| Immediate action | Start morning quiet now | Rename | **Start Screen-Free Morning now** |
| Deferred action | New | Add | **Keep Screen-Free Morning at its usual time** |
| Cancel | Keep Wind Down running | Keep | **Keep Wind Down running** |
| Qualified result eyebrow | Wind Down kept | Keep | **WIND DOWN KEPT** |
| Qualified result title | New | Keep | **Ollie kept the phone tucked away.** |
| Deferred detail | New | Keep | **Screen-Free Morning will begin at {time}.** |
| Deferred protection detail | New | Add | **App protection will pause now and return at {time}.** |
| Skip action | New | Add | **Skip Screen-Free Morning today** |
| Active Screen-Free Morning | Generic quiet copy | Strengthen | **Phone away until {time}. Your chosen apps are paused.** |
| Help title | New | Add | **What “screen-free” means here** |
| Help detail | New | Add | **Counting Sheep pauses the apps and categories you chose. Other apps and websites may still open, and Brief Access remains available. The habit we're practising is putting the phone away.** |
| Brief Access question | What will you use the phone for? | Replace | **What did you set this time aside for?** |
| Non-qualifying eyebrow | Quiet saved | Keep | **QUIET SAVED** |
| Non-qualifying title | Ollie kept the quiet you made. | Keep | **Ollie kept the quiet you made.** |
| Accessibility | New | Keep factual | **Wind Down completed after a {minutes}-minute phone-away span. Screen-Free Morning is set for {time}.** |

Avoid “disciplined,” “earned despite,” “salvaged,” “partial credit,” “failed,” “broke,” and “lost
rewards.” Also avoid diagnosing “addiction” or promising a “better self.” The interface should
describe the interruption and the time protected, not grade the person.

## Implementation workstreams

### A. Shared domain rules and persistence

Likely owned files:

- `Shared/Models/OllieModels.swift`
- `Shared/NightWatch.swift`
- `Shared/FocusRunRules.swift`
- `Shared/NightWatchHistory.swift`
- `Shared/ActiveRunPresentation.swift`
- `Tests/NightWatchTests.swift`
- `Tests/RewardEngineTests.swift`
- Farm/Search Journal shared presentation and reward-rule files identified during reconnaissance
- new focused Shared test file if it keeps existing files readable

Tasks:

1. Add backward-compatible Wind Down benefit settlement and linked Morning Quiet occurrence data.
2. Centralize pure intents such as `windDownBenefitEligibility`, `startMorningQuietNow`,
   `deferMorningQuiet`, and Morning Quiet reward eligibility; views must not reproduce thresholds.
3. Keep the 420-minute constant in `FocusRunRules` as the single source of truth.
4. Remove Morning Quiet minutes from Wind Down benefit qualification while continuing to record
   actual evening and morning minutes separately.
5. Make both tracks independently idempotent; replay must not append a second search, Morning Quiet
   reward, history record, Farm arrival, or progression unit.
6. Preserve decode compatibility for historical `FocusRun`, `NightWatchPlan`, and
   `NightWatchRecord` JSON.
7. Give Morning Quiet its own ledger/counter and prove it cannot mutate Wind Down or Phone Away
   guarantees, drought state, odds, or meter balances.
8. Add a 100-minute Sunrise Trail with a 15-minute per-occurrence minimum, actual-minute banking,
   configured-duration cap, carried remainder, and idempotent wool settlement.
9. Model Sunrise wool and Sunrise search as compatible outputs from the same source. Do not force a
   mutually exclusive reward enum. Keep the exact search cadence configurable in one tested rule.

### B. Coordinator and side-effect rescheduling

Likely owned files:

- `PhoneInTheOtherRoomApp/Proximity/FocusSessionCoordinator.swift`
- `PhoneInTheOtherRoomApp/ViewModels/FocusRunViewModel.swift`
- `PhoneInTheOtherRoomApp/Services/PhoneNotificationService.swift`
- `PhoneInTheOtherRoomApp/Services/NightWatchUsageMonitoringService.swift`
- `PhoneInTheOtherRoomApp/Services/QuietTimeShieldingService.swift`
- `PhoneInTheOtherRoomApp/Services/FocusRunLiveActivityService.swift`
- `Shared/QuietTimeShieldSchedule.swift`
- `Shared/QuietTimeBriefAccess.swift`
- `Shared/QuietTimeShieldPresentation.swift`
- `Shared/NightFlockModels.swift`
- `Shared/NightFlockSharing.swift`
- `Shared/NightFlockPresentation.swift`
- Slumber Party outbox/projection services and view models found during reconnaissance
- `PhoneInTheOtherRoomDeviceActivityMonitor/`
- `PhoneInTheOtherRoomShieldConfiguration/`
- `PhoneInTheOtherRoomShieldAction/`
- Watch messaging code only if the existing run update is insufficient

Tasks:

1. Add one idempotent coordinator reconciliation path that resolves a hidden Wind Down benefit as
   soon as the 420-minute boundary is reached or on the next restore, then delivers it only at an
   authorized terminal action and reveals it only through the finite receipt.
2. Add authorized intents to start the linked Morning Quiet now or retain its usual start after
   ending Wind Down.
3. Persist the choice and linked occurrence before rebuilding notifications/monitoring/shielding.
   A crash after persistence must restore the same state.
4. When Morning Quiet starts now, transition protection without an unshielded gap. When it is
   deferred, clear shielding after the authorized Wind Down end, reapply it at the saved Morning
   Quiet start, and prevent stale Wind Down callbacks from conflicting with that later schedule.
5. Cancel only obsolete future notifications; install Morning Quiet cues without duplicating past
   notifications or announcing an overnight reward.
6. Revise DeviceActivity schedules so stale callbacks cannot reapply an ended Wind Down or clear
   an active/deferred Morning Quiet incorrectly.
7. Update Live Activity and Watch through phone-authoritative state. Do not reveal a sheep result on
   an overnight surface.
8. Preserve NFC authorization: all three early-wake actions that end Wind Down still require the
   matching tag or the existing emergency path.
9. Preserve automatic Wind Down reconciliation, background settlement, timezone/DST behavior, and
   fail-open shielding behavior.
10. Enqueue a 420-qualified Wind Down to Slumber Party only after its authorized terminal action,
    using rounded final allowed minutes. Never publish at the 420-minute boundary. Keep Morning Quiet
    minutes, choices, progress, and rewards out of Slumber Party in this slice. Preserve legacy raw
    values such as `morningQuietCompleted` for decode compatibility, but new UI/projections describe
    a qualifying Wind Down rather than claiming Morning Quiet completion.
11. Make the discontinuous deferred schedule revision-safe across the app, monitor, configuration,
    and action extensions. Test stale apply, stale clear, Brief Access restoration, revision rollover,
    and termination between the Wind Down and Morning Quiet windows.
12. Persist only bounded purpose cues in the App Group and clear them with terminal/schedule cleanup.

### C. SwiftUI and copy

Likely owned files:

- `PhoneInTheOtherRoomApp/Views/ActiveRunView.swift`
- `PhoneInTheOtherRoomApp/Views/CompletionView.swift`
- `PhoneInTheOtherRoomApp/Views/EarlyEndView.swift`
- `PhoneInTheOtherRoomApp/Views/Components/NightWatchReceiptCard.swift`
- `PhoneInTheOtherRoomApp/Views/FocusStatsRecordSections.swift`
- `PhoneInTheOtherRoomApp/Views/NightsWeekSection.swift`
- `PhoneInTheOtherRoomApp/Views/NightsDayDetailView.swift`
- `PhoneInTheOtherRoomApp/Views/Onboarding/OnboardingProtectionStepView.swift`
- `PhoneInTheOtherRoomApp/Views/Onboarding/OnboardingFlowView.swift`
- `PhoneInTheOtherRoomApp/Views/Onboarding/OnboardingReadyStepView.swift`
- `PhoneInTheOtherRoomApp/Views/Components/AppShieldExplainerSheet.swift`
- `PhoneInTheOtherRoomApp/Views/Components/WindDownStartSheet.swift`
- `Shared/FirstRunJourney.swift`
- production Farm, Ollie's Search, and Search Journal views found during reconnaissance
- `PhoneInTheOtherRoomApp/Copy/AppCopyToken.swift`
- Screenbook fixtures/registry and relevant previews

Tasks:

1. Add the phase-aware early-wake sheet without adding a new navigation stack.
2. Route all strings through a pure presentation model or `AppCopy` tokens; include accessibility
   labels and hints.
3. Render Wind Down settlement and Morning Quiet status as separate, understandable results.
4. Continue showing actual before-bed and Morning Quiet minutes separately; never label protected
   overnight span as sleep or quiet credit.
5. Ensure large Dynamic Type, VoiceOver, dark mode, and Reduce Motion remain usable.
6. Keep the result finite: one combined summary may contain the two factual rows, but at most one
   Wind Down Search Journal action and one Screen-Free Morning reward explanation.
7. Rework onboarding and all new-session starts so non-empty app protection is required. Preserve
   runtime fail-open safety and repair states without presenting an unprotected timer mode.
8. Add the concise three-source Farm explainer and the deeper **How Ollie's searches work** route.
9. Add origin labels to Sunrise Trail wool/search outcomes and keep Slumber Party out of active and
   completed Screen-Free Morning navigation.
10. Provide capability-aware Shield copy/previews: native purpose submenu on iOS 26.4+, and an
    honest single-action fallback on older supported iOS without trying to present arbitrary SwiftUI
    inside the system shield.

### D. Canonical documentation

This founder-directed change supersedes both the rule that every early ending is search-ineligible
and the rule that Wind Down plus Morning Quiet must settle as one reward timer. Add a focused ADR
(suggested: `ADR-0019-independent-wind-down-and-morning-quiet.md`) and reconcile:

- `AGENTS.md`
- `docs/PROJECT_BRIEF.md`
- `docs/PRODUCT_PRINCIPLES.md`
- `docs/ARCHITECTURE.md`
- `docs/REWARDS.md`
- `docs/FUTURE_AGENT_TASKS.md`
- ADR-0014/0018 cross-references where needed
- `docs/PLAYBOOKS/testflight-readiness.md` physical-device matrix

Do not rewrite settled historical outcomes or consume a guarantee retroactively.

## Required automated tests

At minimum, cover:

1. A primary run resolves its hidden Wind Down benefit exactly once at a 420-minute eligible
   phone-away span even when Morning Quiet has not begun; no visible delivery occurs yet.
2. Ending at 419 minutes saves factual quiet and changes no Wind Down search, guarantee, drought,
   Farm arrival, wool-regrowth, Shop, or Slumber Party qualifying state.
3. Ending after 420 minutes cannot revoke or duplicate the already entitled Wind Down benefit.
   Before the authorized terminal action, Farm, Barn regrowth, Shop progression, Search Journal,
   Nights, Home, Watch, Live Activity, widgets, and Slumber Party remain unchanged across relaunch.
4. Wind Down settlement is identical whether Screen-Free Morning starts immediately, remains at the usual
   time, is later shortened, or is skipped.
5. A 23:00–07:00 plan choosing **Start Screen-Free Morning now** at 06:00 creates the linked occurrence at
   06:00, uses the full configured Morning Quiet duration, and leaves saved preferences unchanged.
6. The same plan choosing **Keep Screen-Free Morning at its usual time** retains a linked occurrence at
   07:00 and follows the founder-approved gap shielding rule.
7. Replaying Wind Down or Morning Quiet settlement is independently idempotent.
   Wind Down hidden resolution, delivery, and reveal are each independently idempotent.
8. Old JSON without benefit/occurrence fields decodes and re-encodes safely without retroactive
   grants.
9. Morning Quiet settlement cannot mutate Wind Down or Phone Away counters, guarantees, drought,
   odds, or meters.
10. Early-wake choices are unavailable during wind-down, after stale/terminal state, for Phone
    Away, and for an unrelated run ID.
11. DST/timezone changes cannot create negative, overlapping, or duplicated Morning Quiet
    occurrences.
12. Active-run presentation returns phase-appropriate copy and uses **Screen-Free Morning**, while Phone
    Away remains unchanged.
13. Search outcomes remain deterministic for the same Wind Down run ID and Wind Down evidence;
    changing Morning Quiet minutes alone cannot change a new Wind Down result or score.
14. A Morning Quiet occurrence under 15 actual minutes banks no Sunrise Trail progress; 15 or more
    banks actual eligible minutes up to the configured-duration cap, including when ended early.
15. Sunrise Trail carries its remainder across eligible occurrences and settles each 100-minute fill
    exactly once, including termination/replay at the boundary and multiple fills from one capped
    occurrence. Seed each search deterministically by occurrence ID plus fill index.
16. A Sunrise Trail fill grants its fixed wool output and may also resolve the configured Sunrise
    search outcome; one output cannot suppress the other. Sheep arrivals use the existing capacity
    gate, and each fill has its own replay-safe ledger entry.
17. Sunrise settlement cannot mutate Wind Down or Phone Away guarantees, drought state, odds, or
    meter balances.
18. **Start Screen-Free Morning now** creates a full-configured-duration occurrence; **Skip
    Screen-Free Morning today** changes only the linked occurrence and not saved preferences.
19. Deferring clears the ended Wind Down shield and schedules a clean reapplication at the usual
    Morning Quiet start; stale callbacks cannot create continuous or duplicate shielding.
20. Morning Quiet data never enters Slumber Party payloads, projections, reward grants, or active
    navigation. A qualifying Wind Down publishes only after terminal close, using final rounded
    allowed minutes; legacy social raw values still decode without producing false Morning Quiet copy.
21. Onboarding and every new Wind Down, Screen-Free Morning, and Phone Away start require Family
    Controls authorization plus a non-empty opaque app/category selection. Denied, revoked,
    unavailable, and empty-selection states route to repair and cannot start an unshielded timer.
    The post-picker self-confirmation can be revisited but must never be represented as technical
    verification of named apps.
22. Pure presentation tests distinguish protection-ready, authorization-denied, revoked,
    unavailable, and empty-selection states without claiming which named apps were selected.
23. Shield configuration tests/previews select the role-aware purpose submenu only where the OS API
    supports it and retain a readable tracker/purpose cue in the older single-action layout.
24. A deferred Morning Quiet can start, end, and settle after the app was terminated for the entire
    window; restore produces one occurrence, one set of eligible minutes, and no duplicate reward.
25. Home routing prioritizes an active Morning Quiet over an unread Wind Down receipt, preserves an
    upcoming deferred card, and keeps every unread result recoverable after termination.
26. Bounded purpose cues remain local, are absent from impact/social payloads, and are removed from
    App Group presentation storage when the occurrence ends.
27. A runtime apply/restore failure fails open safely, records no false shielding evidence, and shows
    repair without retroactively invalidating the factual phone-away occurrence.
28. Sunrise Trail uses its own first-three guarantee and isolated 20/30/40/50 chance ladder with a
    fourth-search bad-luck guarantee; it cannot consume Wind Down or Phone Away state.
29. Brief Access grants update the factual pause/minute tracker but do not subtract from eligible
    elapsed Screen-Free Morning minutes or change Sunrise Trail settlement.

## Manual and physical-device acceptance matrix

- App Shielding timer run (no NFC hardware): cross 420 while backgrounded/terminated, reopen, and prove Wind Down settled once
  before Morning Quiet completion.
- NFC run: choose start-now and defer paths; verify the correct tag is still required to end Wind
  Down; wrong tag/cancel leaves it active; emergency exit remains separate.
- App shielding: verify immediate Morning Quiet has no unintended protection gap; deferred Morning
  Quiet follows the chosen gap rule; stale DeviceActivity callbacks cannot conflict.
- Onboarding: verify selection and authorization on a physical device; confirm the primary path
  cannot falsely report protection ready with an empty opaque selection and cannot start Wind Down,
  Screen-Free Morning, or Phone Away after denial/revocation until repaired.
- Shield intervention: verify the purpose check-in appears before Brief Access confirmation and the
  run-scoped pause/minute tracker agrees across the shield and active screens.
- Screen-Free Morning help: verify the nearby explainer accurately states the apps/categories-only
  scope, website boundary, Counting Sheep availability, and Brief Access behavior.
- Notifications: no overnight reward teaser and no obsolete or duplicate Morning Quiet cue.
- Live Activity and Watch: show the current mechanism and time without revealing an overnight Farm
  outcome or creating two phone-authoritative coordinators.
- Receipt/Nights: Wind Down and Morning Quiet have distinct status/reward rows and agree after
  restore.
- VoiceOver, large Dynamic Type, dark mode, and Reduce Motion.
- Two-account Slumber Party QA: the 420-qualified Wind Down is completed with rounded allowed data;
  Morning Quiet is not shared until its separate contract is explicitly approved.

## Repository validation gate

Run the commands required by `AGENTS.md`:

```bash
xcodegen generate
xcodebuild build \
  -project PhoneInTheOtherRoom.xcodeproj \
  -scheme PhoneInTheOtherRoom \
  -destination 'generic/platform=iOS Simulator' | tail -20
xcodebuild test \
  -project PhoneInTheOtherRoom.xcodeproj \
  -scheme PhoneInTheOtherRoom \
  -destination 'platform=iOS Simulator,name=iPhone 15' | tail -30
```

Use an available simulator when iPhone 15 is absent. Also run `git diff --check` and the
pre-merge playbook. Do not claim physical Screen Time/NFC/Watch success from simulator evidence.

## Founder decisions

Raw `.honorTimer`, `.watchPlacement`, and `.qrCode` guard values remain internal persisted-data
compatibility only. Current release flows use the shielding timer or optional NFC + app shielding.

### Resolved on 2026-08-23

1. **420-minute entitlement:** Reaching a 420-minute eligible phone-away span entitles the Wind Down to all existing
   Wind Down benefits: Ollie's Search, first-three/bad-luck progression, wool regrowth, Shop
   progression, and qualifying Slumber Party treatment. Morning Quiet is not a prerequisite.
2. **Independent mechanisms:** Wind Down and Screen-Free Morning require separate qualification and reward
   systems. People do not have to complete Screen-Free Morning to receive a qualifying Wind Down result.
3. **Early-wake choices:** When ending Wind Down early, offer starting Screen-Free Morning now, keeping it
   at the person's usual time, or skipping it for today; keeping Wind Down running remains cancel.
4. **Availability:** **I'm awake early** is available throughout overnight; 420-minute eligibility
   is evaluated separately.
5. **Guarantee sequence:** A 420-qualified early wake uses the same Wind Down first-three guarantee
   and bad-luck sequence.
6. **Schedule scope:** An early-wake choice affects tonight only. Recurring schedule edits remain in
   Settings.
7. **Slumber Party:** After an authorized terminal action, a 420-qualified Wind Down is completed
   socially with rounded final allowed data and no exact wake-time disclosure.
8. **Naming:** **I'm awake early** and **Screen-Free Morning** are approved. Screen-Free Morning is
   the aspirational habit name across release-facing copy. Nearby help explains that the current
   mechanism pauses chosen apps/categories, leaves websites and unselected apps available, keeps
   Counting Sheep reachable, and permits deliberate Brief Access. Existing internal `MorningQuiet*`
   names and persisted raw values remain stable where compatibility requires them.
9. **Implementation lane:** Use Terra High rather than Luna High.
10. **Shielding-required direction:** Interrupting automatic opens of chosen social-media/scrolling
    apps is a core habit mechanism. Authorization and a non-empty opaque app/category selection are
    required for onboarding completion and every new Wind Down, Screen-Free Morning, and Phone Away
    start. Do not offer timer-only as a peer or fallback mode. Runtime failures still fail open for
    safety and route to repair.
11. **Sunrise Trail:** Screen-Free Morning uses a separate 100-minute meter. Every fill grants 1 wool
    and independently rolls an Ollie's Search. The first three Sunrise searches are guaranteed;
    later searches use their own isolated 20/30/40/50 chance ladder and fourth-search bad-luck
    guarantee. Wool and a sheep outcome may occur together.
12. **Minimum and early ending:** An occurrence becomes eligible at 15 actual minutes. Once eligible,
    its actual minutes bank even when Screen-Free Morning ends before the configured end, capped at the
    configured duration and explained during first use.
13. **Start-now duration:** **Start Screen-Free Morning now** uses the full configured duration.
14. **Deferred shielding:** Ending Wind Down and keeping Screen-Free Morning at its usual time clears the
    shield during the gap and reapplies it at the saved start.
15. **Skip:** Add **Skip Screen-Free Morning today**. It changes tonight only and carries no loss language.
16. **Resolve, deliver, reveal:** Resolve a qualifying Wind Down invisibly at 420 minutes, deliver its
    progression only after an authorized terminal action, and reveal the result when the morning
    receipt opens; never use an overnight teaser, indirect Farm reveal, or notification.
17. **Privacy/social:** Screen-Free Morning choices, progress, minutes, and rewards remain private from
    Slumber Party in the first slice.
18. **First-release scope:** Protect selected apps/categories with bounded five-minute Brief Access.
    Web-domain blocking is deferred to a later separately scoped, physically tested slice.
19. **Selection guidance:** Before Apple's opaque picker, explicitly recommend the categories and
    named examples most associated with automatic scrolling, then ask the person to self-confirm that
    their main pull-back apps are included. Counting Sheep must never claim it can inspect, preselect,
    or verify a particular app token.
20. **Phone-away language:** Across onboarding, Home, start sheets, active journeys, shields,
    receipts, and help, lead with putting the phone in another room or giving it a place to rest.
    App blocking catches the reflex; physical separation is the habit being built.
21. **Brief Access credit:** A five-minute Brief Access grant does not reduce Sunrise Trail credit.
    Count elapsed eligible Screen-Free Morning minutes after the 15-minute minimum while showing the
    pause count and allotted minutes separately. iOS does not reveal how much of the allowance was
    actually used, so the app must not convert the full grant into a usage penalty.

### Implementation readiness

All founder decisions required by this handoff are resolved. Terra High may begin after the
repository/skill preflight in the implementation prompt.
