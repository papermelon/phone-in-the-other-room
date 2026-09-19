# Wind Down habit loop improvements

Status: implemented locally with build, unit, persistence, and simulated-admission validation complete, 8 September 2026. Local implementation does not
establish distribution, physical-device behavior, or habit-building effectiveness.

## Intended outcome

An independent person can make a useful evening plan, understand its protection
readiness, begin when eligible, and revise the plan after a difficult evening.
The same ordinary journey supports workshop participation; no facilitator or special
workshop route is required. Ollie, the Farm, and optional shared encouragement remain
part of the experience.

## Pre-change findings

- Onboarding's protection screen blocks navigation even though the underlying plan
  save and all real-session admission checks are already independent.
- The first route contains two welcome pages, an optional six-question chapter and
  result, a Shepherd gift, account invitation, schedule, evening/morning routine editor,
  protection, and a ready page. Drafts resume; verified returning Farms have their own
  device-setup route.
- Home emphasizes timing. Selected activities appear more clearly after admission
  than before it. A personal activity and an editing route can make the plan useful
  before a session begins.
- Existing early-end receipts preserve cumulative credit and a welcoming return.
  Existing shared-plan borrowing needs clearer recovery when a routine is full;
  advanced social capability is still bounded by deployment and agreement evidence.
- `eveningCueText` and `morningCueText` are compatibility projections of custom
  activities, not behavioral trigger fields. New trigger/preparation data must not
  overwrite them.
- Reflections are device-only account-local records. New personal notes must use
  an explicit local ownership boundary and refresh when the active account changes.
- One-time primary schedule overrides omit the ordered routine arrays when making
  the session plan. Repairing this preserves existing intended behavior.

## Confirmed founder decisions

1. Save a plan before optional protection setup. Protection remains required for every real start.
2. A smaller routine changes activities only. Saved overnight timing and protection stay unchanged.
3. Offer outside-bedroom and accessible-nearby placement intentions, with the same selected-app protection.

The implemented scope is plan-first onboarding, smaller activities without timing
changes, and an explicit accessible-nearby alternative with unchanged protection.
Reflection remains optional and private; no new social fields, analytics uploads,
reward economics, dependencies, entitlements, or targets were introduced.

## Ordinary journey

The ordinary flow supports independent use and the workshop; there is no separate workshop entry.

1. **First launch:** meet the ritual and Ollie, choose one evening activity and usual
   timing, then review the plan. Present deeper personalization progressively, with
   returning sign-in always available at the opening and a discoverable later welcome
   gift choice. Existing saved drafts and reward eligibility survive any route change.
2. **Home before the first evening:** retain the timing, Ollie and start hierarchy,
   while showing the chosen activity and a direct route to edit it. Clearly distinguish
   a saved plan from incomplete protection. Declined optional reminders never block use.
3. **Prepare the evening:** optionally add a recognizable cue, something to prepare,
   and a smaller activity. These fields are progressive, not another required form.
4. **Start:** use the existing admission and protection checks. Any smaller-version
   choice is explicitly defined and does not imply a completed activity or changed
   protection. Keep the active plan stable if future preferences change.
   As of 19 September, the active routine also has optional, reversible session checks.
   They are private self-reports, with the same saved check marks projected to the native
   app shield. This does not make the routine mandatory or award completion credit.
   See [personal shielding](personal-shield-design-2026-09-17.md) for the current interaction.
5. **Return:** preserve factual receipts and existing cumulative rewards. Make a short
   optional habit reflection reachable even without a session record. A reflection
   should offer a relevant editing destination; it never starts a session on save.
6. **Difficult evening:** retain progress and give an optional path to make the next
   plan easier. Do not ask for a compulsory explanation or infer a missed routine.
7. **Following weeks:** reuse the saved plan, reduce repeated guidance, and make
   borrowing an available shared idea lead to a complete add-or-review experience.
   Solo use remains complete; advanced social surfaces respect current capabilities.

## Implementation boundaries

- **Onboarding lane:** normal route, truthful review/ready text, resumability and later
  access to deferred personalization. Existing grant semantics remain authoritative.
- **Private plan lane:** additive normalized cue/preparation/fallback/placement model
  and optional reflection model, with neutral legacy defaults and local owner isolation.
  Existing routine activity arrays are reused; legacy custom-activity cue fields remain
  unchanged. No cloud payload expansion.
- **Daily UI lane:** focused routine editing, Home preview, reflection and explicit
  next-plan edit. Keep new components small and use existing design tokens.
- **Integration lane:** root owns view-model bindings, account transition refresh,
  snapshot behavior, source membership, documentation, full validation and review.

Concrete acceptance includes relaunching an incomplete draft, viewing a saved plan with
denied protection, later repairing protection, choosing a smaller version, editing while
a session is active without rewriting its snapshot, reflecting without a recorded run,
clearing answers, and switching A → signed out → B without exposing new private notes.

## Validation plan

- Preserve pre-task source in `tmp/wind-down-loop-20260908/baseline` so review can
  distinguish this work from the substantial existing working tree.
- Test legacy and interrupted drafts, guest/returner routes, welcome reward eligibility,
  plan-only state, actual admission, ordered routine snapshots, and any new persistence.
- Inspect ordinary and difficult paths on small screens, larger text, Reduce Motion,
  and without sound. Run the repository's generic Simulator build and full unit suite.
- Obtain a fresh read-only review of the integrated task delta and repair actionable
  findings before completion.
- Record physical protection/notification/account and participant accessibility checks
  separately from Simulator and source evidence.

## Workshop and independent-use pilot

Use the ordinary app journey with a small voluntary group before the workshop. Include
independent downloads, existing users, essential-access needs, and people using a paper
plan or supported built-in device settings. Do not require an account or group for the
learning activity.

The workshop allocation remains 40 minutes: five to choose the intention and essential
access needs, five for a demonstration with interpretation, fifteen for one prepared
setup, ten to test and undo it, and five to share the intended experiment. Prepare
platform-specific visual instructions outside the iOS app for Android participants.

Observe whether someone can explain their plan, recognize what still needs setup,
revise it, and recover without a helper. Invite a voluntary one-to-two-week follow-up
about appeal, ease of beginning, interruptions, and useful adjustments. Use participant
self-report and consented observation; do not infer offline routine completion from
timer records or add remote analytics. This is a usability and motivation pilot, not
proof of lasting habit formation or improved sleep.

## Evidence

- Pre-change generic iOS Simulator build passed on 8 September 2026. Command:
  `xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator'`.
  Log: `tmp/wind-down-loop-20260908/baseline-build.log`.
- CoreSimulator inventory required sandbox escalation; it succeeded. No physical
  device, participant, production-account, or hosted social validation has occurred.

## Why this bounded scope

Behavioral evidence motivates testing a familiar cue and repetition in a stable context; it
does not establish a fixed number of days or guarantee habit formation. Lally et al.'s
[prospective study](https://onlinelibrary.wiley.com/doi/10.1002/ejsp.674) is a reason to test
repeatability and recovery over time, not to award verified habit completion. Choosing an
appealing activity, offering a smaller invitation, and linking a reflection to an edit are
product hypotheses. They require participant evidence. Apple protection constraints and the
existing coordinator/admission tests are technical facts, not behavioral evidence.

The Farm and Ollie already provide cumulative progress and anticipation, including progress
retained after early endings. Replacing their economy or adding a new streak layer would not
resolve the immediate gap between a saved activity and a repeatable evening. This slice joins
those existing systems through a visible personal invitation and a manageable revision path.
More elaborate progression or new shared data is deferred until the pilot shows a concrete need.

## Pilot observation sheet

For each participant, record device/route, intended activity, access requirement if voluntarily
shared, and which tasks they completed independently, with a hint, or with direct assistance.
Ask them to explain what is saved and what is protected; locate the activity; change a choice;
test the setup; undo the restriction; and repeat the revision without the original helper.
A simulated example is labeled simulated and is never counted as a protected session.

At a voluntary follow-up, ask what felt worth repeating, what happened on an interrupted
evening, and whether they changed the plan themselves. Record an example of a useful adjustment
or why the app was set aside. Separate app usability from workshop support and built-in device
settings. Use no participant names in shared workshop notes without separate consent. Report
observed use and self-report separately; neither establishes lasting habit formation or sleep
improvement.

## Completed local validation — 8 September 2026

- XcodeGen generated source membership from the existing project.yml; no new target,
  dependency, entitlement, signing change, or tab was introduced.
- Generic Simulator app build passed, including the Watch/extension sources containing
  the backwards-compatible plan fields. Command: `xcodebuild build -project
  PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination
  'generic/platform=iOS Simulator'`. Evidence: `tmp/wind-down-loop-20260908/final-build.log`.
- Complete unit suite: **918 tests, zero failures** on iPhone 17e / iOS 26.5. Command:
  `xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom
  -destination 'platform=iOS Simulator,id=71CF8F3E-9E9A-449D-93A8-B73F64869A5E'`.
  Evidence: `tmp/wind-down-loop-20260908/final-tests.log`.
- Isolated Foundation persistence harness: **74 tests, zero failures**, via
  `python3 scripts/validate-farm-save.py`. Covers real file writes/reopen, A → sign-out → B → A,
  stale ownership inside a staged transaction, reset/lineage, malformed bytes, failed writes,
  and retry. Evidence: `tmp/wind-down-loop-20260908/final-persistence-tests.log`.
- Simulator-only actual-view-model probe: **all three cases passed**. Manual primary
  preflight → cancel → changed retry → coordinator admission retains timing and the chosen
  nearby/smaller snapshot, consumes that choice only after admission, and does not consume a
  later choice on replay. The other two cases verify healthy reflections survive corrupt plan
  data and healthy support survives corrupt reflections, without overwriting unreadable bytes.
  Evidence: `tmp/wind-down-loop-20260908/habit-probe.json`.
- Native small-screen walkthrough used the dedicated iPhone SE review simulator with sound
  muted: skip introduction, schedule review, choose a book, review the unsaved plan; configured
  Home → routine editor → cue/smaller activity/nearby choice → save → Home. Declining the
  notification prompt left the saved plan accessible. This was isolated fixture navigation,
  not physical protection or a production onboarding/account test.
- Large-text fixture inspection used `.accessibility3` on iPhone SE. The access-edit link
  reaches the placement controls directly and the bottom Save action remains reachable.
  Reduce Motion was enabled and verified in Simulator Settings. Native accessibility labels,
  selection state, buttons, and save hints were inspected; this is not a complete human
  VoiceOver audit. The final expanded reflection was exercised at large text: select an
  obstacle, save it explicitly, observe success feedback, and follow the adjustment link
  directly to placement controls. A selected-answer layout issue was repaired and re-inspected;
  evidence is `tmp/wind-down-loop-20260908/final-reflection-saved-accessibility.png`. A temporary
  Mac lock interrupted interaction; checks resumed after access returned.
- A fresh reviewer identified and rechecked repairs for primary preflight capture, legacy
  protection deferral, separate malformed-value loading, reflection dates after travel,
  and competing drafts of the same reflection. Final source review approved with no remaining
  actionable findings. Earlier failing runs are retained in the logs; the passing evidence
  above includes the relevant repairs.

No commit, deployment, distribution, production-account mutation, or remote analytics was
performed. The app’s habit support and reflection state stays private on this device within
its account scope; it is not included in automatic Farm synchronization. Physical shielding,
alerts/transcription availability, automatic scheduling, Watch behavior, notification delivery,
and participant experience remain in the owning backlog and pilot plan.
