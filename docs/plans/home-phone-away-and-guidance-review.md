# Home, Phone Away, and guidance review

Date: 2026-08-27
Status: Home/social emphasis and contextual guidance direction approved; implementation pending.

**Later founder clarification:** the 2026-08-27 device review supersedes this document's
subordinate/list-only Slumber Party hierarchy. Follow `home-social-recovery.md` for the core
social Home direction and current in-chat implementation ownership. The original bug history
and compatible protection, Purpose, guidance and Active requirements remain relevant.

Implementation handoff: `docs/plans/luna-home-phone-away-implementation-handoff.md` covers all
P0/P1/P2 work and the concrete Active-page recommendations, as requested in the subsequent handoff
request. Follow-up review: `docs/plans/sol-recent-changes-review-handoff.md` covers the broader
recent-change candidate. Neither task has been started by preparing these documents.

## Direction

Home should answer three questions: what is my next Wind Down, how do I put the phone away
now, and where do I find my people? Teaching and explanation should support those actions
without becoming a permanent stack above them.

Founder-approved refinements on 2026-08-27:

- Retain the personal ritual, with one prominent Slumber Party bridge on Home.
- Offer occasional contextual guidance with dismissal, backed by a browsable library.
- Include the reported active-session Purpose refresh defect in the fix scope, and review
  Active Wind Down/Phone Away alongside Home. Detailed Active layout proposals below remain
  recommendations rather than a separately approved redesign.

The recent **Review parent child app positioning** conversation explores a cooperative family
ritual, but does not establish a final parent-administered product pivot. The subsequent
`slumber-party-roadshow-polish.md` plan settles the immediate shared proposition as
“Give your phones some time away — together,” inclusive of families, couples, and friends.
Preserve that work and its list-derived Home bridge; do not introduce family roles, remote
enforcement, a shared Farm, or invented member-completion states.

The recent **Improve Onboarding UX** conversation also explicitly keeps daytime Phone Away
in the proposition and asks for shorter copy with less repetition. Home must fulfill that
promise after onboarding. Suggestions from earlier assistant messages are research context,
not automatically accepted founder decisions.

## Confirmed findings from the current working tree

| Finding | Evidence | Consequence |
|---|---|---|
| Home repeats the Wind Down setup story | `PixelHomeDashboard.swift`: Tonight overview, separate Ollie/purpose copy, protection block, primary CTA with another schedule subtitle | Several components compete to explain one action. Merge their useful facts. |
| Phone Away is suppressed when Wind Down is eligible | Dashboard passes no immediate duration when `canBeginNow`; `UpcomingQuietTimesCard` replaces start controls with “Wind Down is ready. Phone Away can wait until later.” | An idle user can lose the visible Start now action merely because a saved Wind Down is eligible. |
| Manual Phone Away behavior and Home presentation disagree | `startNewOneTimeAdditionalQuietNow` / `immediateAdditionalQuietWindow` currently prepare a transient manual run independently of saved windows; the schedule page still exposes Start now | Repair the inconsistent entry points before redesigning them. |
| Home's Start now can select a different kind of action | Dashboard uses an eligible saved Phone Away context when present, otherwise prepares a manual run | Keep manual Start now and Start scheduled as distinct intents, with explicit source identity. |
| Protection repair loses Phone Away context | Home routes to full `FocusRunSetupView`; schedule page displays a message rather than a repair destination | Offer focused protection repair and return to the intended Phone Away preflight; never silently start on permission grant. |
| Home guidance is stable, not a rotating insight | `WindDownGuidanceLibrary.homeGuidance` returns the first matching evening step, then the first matching morning step | The same routine normally means the same card on every visit. There is no Home history-aware or daily rotation policy. |
| Guide is a long text list | `WindDownGuideView` renders all 10 items under six topic headings | It provides little visual orientation or distinction between choosing an idea and reading its rationale. |
| Sources are labels rather than accessible references | Guide displays `combinedLabel`; URLs exist in `docs/SLEEP_GUIDANCE_SOURCES.md`, not a tappable in-app source register | A source name should open a useful reference detail, with an external link when available. |
| Full explanation follows the user into the active ritual | `ActiveRunView` embeds the same `WindDownGuideCard`, including its guide navigation | Replace the repeated explainer with the chosen phase cue; make source exploration primarily a setup/idle activity. |

These findings are code-level observations, not a reproduction on the reported TestFlight device.
The working tree already contains substantial uncommitted onboarding, start-sheet, Farm, and
Slumber Party changes. In particular, a local start-sheet change removes an extra selection
confirmation gate. Do not assume that this local behavior is present in the user's installed build.

### Build 33 report — clarified with three device screenshots

The founder reports the following on build 33, at approximately 1:39 PM on 27 August:

- Home's Phone Away **Set up app protection** opens the Wind Down editor. Saving that plan
  returns without resolving protection readiness.
- The Phone Away schedule has the same setup-labeled action at its top.
- A saved one-time period, 1:39 PM–2:15 PM, shows **Ready now** and a play icon, but tapping
  it produces no visible response in the shown viewport.
- Home repeats protection setup across a status block, the large primary CTA and the Phone
  Away card. The primary CTA's explanation is also truncated in the screenshot.

The current source explains this interaction:

1. Home's Phone Away readiness guard sets `showRunSetup`, opening `FocusRunSetupView` rather
   than requesting Screen Time permission or opening app selection.
2. **Save Wind Down** calls `saveNightWatchPlanForTonight`, which saves preferences and
   reconciles automatic scheduling. It does not request Screen Time authorization or select apps.
3. Both schedule start handlers return early when protection is not ready. They assign a local
   `message`; its UI is after **Usual Wind Down**, below the screenshot's viewport. The setup-
   labeled top button does not actually initiate setup in this branch.
4. **Ready now** and the play icon represent schedule eligibility, not protection readiness.
   Their visible presentation disagrees with the action's guard. The accessible label can
   describe repair while sighted users still see a play affordance.
5. The exact Home explanation matches `.authorizationRequired` in the current source. This
   tells us what the app believes, not whether Apple's actual authorization is missing or stale.
   Published authorization is read at initialization/reset and after an explicit permission
   request; the app foreground handler does not refresh that published state. Include a fresh
   system-state read on return from settings and before preflight in the repair design.

This is the primary reported failure, not evidence of the separate Wind Down-window visibility
issue above. The screenshots establish the user-visible behavior; the current source supplies
the matching code path, but the exact archived build-33 binary has not been inspected or tested.

The founder subsequently confirmed that allowing access and choosing apps through Settings
resolved the start blocker on build 33. This validates a usable protection path on that device;
it does not validate the broken Home/schedule repair routes or establish why access was missing.
Treat those routes as the primary repair rather than asking the user to repeat the workaround.

## P0 — restore trustworthy Phone Away access

1. Use the build-33 case above as the first regression scenario. Determine whether permission
   was never granted or the app's published state is stale. Route both Home and schedule repair
   actions into focused authorization/app selection, refresh readiness on return, and preserve
   the intended manual/scheduled Phone Away action. A ready repair returns to confirmation,
   never starts automatically. Recheck the saved window if it expires during setup.
   Present errors beside the tapped control or in a visible alert, not only at the list bottom.
   A scheduled row must distinguish **Available now · protection needed** from genuinely ready
   to start, using a setup affordance instead of a misleading play icon.
2. Keep **Start now** visible whenever the app is idle. An eligible but unstarted Wind Down
   should not hide it. An active run should offer return-to-session instead of another start.
   Missing protection or NFC setup should lead to a named repair action, not a dead end.
3. Separate intents: manual Phone Away, a specific scheduled Phone Away, and primary Wind Down.
   Preserve source/occurrence identity through confirmation, cancel, retry, NFC, and restore.
   Do not reuse a single highest-priority eligible occurrence as every mode's availability.
4. Show the duration before committing. Recommend a remembered/default 30-minute manual
   duration with a small Change control; keep the existing supported duration bounds.
   Manual duration begins on actual start; a scheduled run retains its saved end time.
   The current manual plan is prepared before confirmation, so verify/rebase that interval.
5. Preserve the user's schedule. A manual start must not create, consume, move, or delete a
   saved occurrence. Check automatic Wind Down behavior if its start arrives during Phone Away;
   keep one active run and make the resulting schedule state explicit, without silent preemption.
6. Use a typed start result or equivalent small testable policy for readiness/repair/failure.
   Do not infer success merely from a presentation Boolean or display an unrelated stale error.
7. Preserve required consented shielding, fail-open runtime handling, emergency exit, NFC
   purpose assignment, private practice behavior, and isolated Phone Away reward accounting.

Acceptance: both entry routes offer a real start or explain the actual blocker; cancel/retry
leaves no schedule debris; the resulting timer, protection and receipt belong to Phone Away.

### P0-B — Purpose selection must update immediately

Reported on build 33: selecting an item in the active Wind Down/Phone Away Purpose menu leaves
the old label visible until the user switches apps and returns. The latest screenshots also
confirm that Phone Away can now run after protection setup.

The matching source defect is in `FocusRunViewModel.currentPurposeCue` and
`setCurrentPurposeCue`: the getter reads App Group defaults directly, while the setter writes
`QuietPurposeCueState` without changing published state or sending a change notification.
`ActiveRunView.purposeCuePicker` reads that computed property. There is no observable dependency
for the selection change, so a later unrelated redraw can reveal the saved choice. The native
countdown and the journey's own TimelineView can keep animating without refreshing this label.

The getter also ignores occurrence/revision/epoch when displaying the saved cue, unlike the
shield extension, which checks all three. The repair must address both freshness and identity.

Implementation requirements:

1. Publish a main-actor state change when the selected cue changes, using a focused observable
   projection or a correctly scoped change notification. Keep persistence behind the view model/
   service boundary; do not add view polling, artificial delay, forced `.id` recreation, or
   per-second defaults reads to mask the missing observation.
2. Match the active occurrence and its current registry revision/epoch before reading or writing.
   Preserve the existing compatibility policy deliberately; do not invent a revision merely to
   show a successful selection. Missing/stale storage must not silently report a saved cue.
3. Reload/clear the projection when the active occurrence changes, on restore, after terminal
   cleanup and when returning from the background. An old run's choice must not appear on the
   next run or on a different Screen-Free Morning occurrence.
4. Show the selected value immediately after the menu closes, with a selection indicator inside
   the menu and an updated VoiceOver value. Re-selecting the same option is harmless.
5. Keep this bounded current-session cue separate from `OfflinePurposeProfile` (the enduring
   private purpose) and the evening/morning routine sequence. It does not alter schedules,
   timing, rewards, past records, notification consent or Slumber Party data. No new free text
   goes into the App Group. System shield redraw timing is separate from app-label correctness.

Acceptance: choose Read, then Something offline while remaining in the app; each label updates
immediately in Wind Down and Phone Away, survives restore for the same valid occurrence, and
does not carry into another occurrence. Exercise unavailable storage and stale registry identity.
Extend existing purpose/registry tests for identity and restoration; verify actual observable
UI behavior as well, since Codable tests alone cannot catch this regression.

## P1 — consolidate Home

Recommended idle layout, preserving the four existing tabs:

1. **One Wind Down card.** Compact Ollie illustration, next actual Wind Down start, bedtime,
   wake time and phone-wake time in one readable timeline, one Edit action, and the appropriate
   primary action. Keep bookend durations clear without reproducing the whole setup form.
   Ready protection is a small line here; a repair state receives actionable prominence here.
2. **Phone Away.** Short explanation, visible duration, **Start now** and **Plan**. If a saved
   period is eligible, give it its own clearly labeled action. Put detailed search-meter rules
   in Farm/schedule detail; at most retain one compact progress line on Home.
3. **Slumber Party bridge.** Preserve recent V4 routing/copy. One party opens that party;
   multiple parties open the list. Keep group/member activity inside party detail. This entry
   can be prominent without claiming that Home is a family management dashboard.
4. **Optional context, only when useful.** One dismissible chosen-routine cue or guide offer,
   below the actions. Never stack a tutorial, practice offer and explanation on the same topic.
   Keep an unobtrusive route to the idea library when no tip is shown.

Merge the purpose into the Wind Down card only when it adds personal meaning; remove the
generic supporting sentence if it repeats the headline. Move “Latest Wind Down” to Nights
unless there is a specific unread receipt to resolve. Do not remove genuine recovery affordances.

### State-specific hierarchy

| State | Home emphasis |
|---|---|
| New user | One resumable guide offer plus the real actions; no permanent teaching stack |
| Daytime, idle | Compact next Wind Down plan and easily reachable Phone Away |
| Wind Down eligible, idle | Wind Down action prominent; Phone Away remains available |
| Protection needs repair | One explanation and focused repair path for the intended action |
| Active Wind Down / Phone Away | Existing live journey, phase cue and emergency exit; no social or tip discovery |
| Active Screen-Free Morning | Existing morning continuation and Sunrise Trail semantics |
| Deferred morning / unread receipt | Existing recovery priority; compress duplicate explanations around it |
| Returned after completion | Settle/acknowledge receipt once, then restore the idle hierarchy |

The structural default remains Wind Down first. Making Phone Away the daytime primary action
is not part of this slice. The founder approved the personal ritual with one prominent shared
bridge; no equal-weight family mode or parent dashboard is proposed.

### P1-B — make the Active page clearer and quieter

Keep Ollie's journey as the visual identity, the existing four-tab shell, and the current
coordinator/phase model. Improve hierarchy rather than adding another feature panel.

| Area | Recommendation |
|---|---|
| Header and timer | One mode title, a clearly named current phase, one primary countdown and one transition/end time. Remove the duplicate rounded time badge from the illustration; 30 MIN versus 29:47 is rounding, not a second timer defect. |
| Journey scene | Retain the artwork, with fewer overlaid labels. Keep text readable without placing multiple badges and a caption over the characters. Adapt height for small screens/large text so session controls stay reachable. |
| Purpose | Replace the abstract row label with “This time is for” and keep the selected choice visible. Make optionality clear in the empty state. Show selection state within the menu; no extra confirmation button. |
| Purpose vocabulary | Keep current stored enum values compatible. Consider app-facing wording “Rest,” “Reading,” “Work,” “Time offline,” and “Something else”; order relevant choices by mode without erasing a user's explicit choice. Do not introduce a custom text editor in this repair. |
| Chosen routine | During primary evening/morning phases, show only the chosen phase-appropriate suggestions, without completion controls. Keep these distinct from the current-session Purpose. Phone Away needs its selected Purpose, not a bedtime checklist. |
| Protection | One concise status line from actual protection state. Make failure/recovery visible; never imply that a scheduled shield has already applied. Do not repeat the same end time in multiple full cards. |
| Exit | Keep the mode-specific early-end action accessible. For NFC, distinguish normal tag completion from the existing emergency exit; do not add friction or move that exit behind guidance. |
| Guidance | Remove the permanent explanatory/source card from the live session. The selected cue can remain; general idea discovery lives on idle Home/setup/the library. No social panel during the session. |

Phase clarity:

- Phone Away: a countdown to its actual end and a daytime-neutral Purpose. It has no bedtime,
  overnight or morning progression narrative.
- Wind Down evening: make clear that the countdown is to bedtime, while selected-app protection
  continues beyond it. A compact phase strip may show Evening, Overnight and Morning with the
  current phase highlighted; it is navigation-free status, not a second state machine.
- Overnight: calm scene, a short status and next transition. No routine prompt or new tip.
- Screen-Free Morning: its own real end time and chosen morning cue; preserve independent
  Sunrise Trail settlement and the existing deferred/early-wake paths.

The scene currently derives “clues mapped” from elapsed-time thresholds (20%, 55%, 82%), not
settled search data. Replace those counts and their VoiceOver claims with atmospheric journey
copy. Keep the charming companion sheep, but do not imply it is a newly earned sheep. This is
presentation honesty; no reward/economy or search behavior changes are needed.

Avoid filling the lower empty space merely to fill it. Prioritize a readable timer, chosen
cue, protection status and reachable exit. Profile the existing animation before changing its
frame rate; retain Reduce Motion and pause unnecessary scene work when not visible. New audio,
interactive clues, live social content and elaborate animation controls are outside this slice.

## P2 — make ideas useful and sources inspectable

### Distinguish three content types

- **Your chosen idea:** a reminder of something the person selected. Example: “After the phone
  goes away: read a few pages.” No claim that it happened; no checkbox or reward.
- **General guidance:** an optional explanation with a source. It is not a personal finding.
- **Your observations:** actual history or explicitly answered check-in context, labeled as
  such. Keep outcome analysis in Nights; do not disguise a generic tip as an insight.

Remove the permanent **WHY THIS MAY HELP** framing from Home. Put the rationale behind the
specific idea's detail screen, where “Why this idea” has a clear referent. On Home, prefer a
compact cue selected for the current evening/morning context, dismissible and below actions.

Recommended freshness policy: stable within a day/phase, eligible to change when the phase,
chosen routine or relevant context changes; no random change on every app open. If a broader
rotating tip surface is wanted, define seen/dismissal state, repeat spacing and a disable
control explicitly. Do not add LLM generation, HealthKit inference, or notification delivery
as part of this content-layout change.

### Guide presentation

- Open on a small visual index organized around **Evening**, **Morning**, and **Phone-away
  space**, with icons or existing pixel art and one-line descriptions. These are navigation
  groupings, not new source-backed claims. Avoid a carousel of large paragraphs.
- An idea detail has: a concrete suggestion, a short rationale, how it could fit an offline
  routine, and a Sources disclosure. Provide **Add to my evening/morning ideas** only for
  content that maps to a real routine step. Respect three/two limits and require confirmation;
  never silently replace an existing step or alter the schedule.
- Separate choosing an offline activity from background education. A caffeine/light-timing
  explanation need not become a task, timer, compliance target or routine checkbox.
- Build a local source registry containing stable ID, organization, title, URL where available,
  source type and editorial review metadata. Distinguish external guidance from Counting Sheep
  product rationale/internal reference material; do not style them as equivalent evidence.
- Preserve the existing **About these ideas and sources** link as the reliable route from
  routine setup and Settings. Deep-link a tip to its own detail, not the top of the full list.
- Keep offline content readable. Opening an external reference is optional; verify external
  links and claim-to-source fidelity before shipping revised content. Existing clinical-context
  references need particular editorial care; do not imply qualified clinical review has happened.
- Carry the same stable idea IDs through onboarding result, routine picker, Home cue and active
  phase cue. This is consistent presentation, not repeated full cards on every screen.

Audio/NSDR, new family-specific guidance, new behavioral experiments and personal outcome
insights are separate scope decisions. This plan should not quietly introduce them.

## Copy review examples

| Location | Current | Verdict | Proposed direction |
|---|---|---|---|
| Idle Phone Away | “Wind Down is ready. Phone Away can wait until later.” | Replace | Restore Start now; explain only an actual active-session conflict |
| Home guide eyebrow | “WHY THIS MAY HELP” | Move | Use the chosen activity as the cue; keep rationale in its detail |
| Repeated protection UI | Ready/selection detail in separate block and start flow | Consolidate | Compact “App protection ready” beside the action; full control in preflight/repair |
| Source navigation | “About these ideas and sources” | Keep | Make the destination a visual idea index with inspectable references |

## Implementation boundaries and verification

Likely files: `PixelHomeDashboard.swift`, `UpcomingQuietTimesCard.swift`,
`WindDownScheduleView.swift`, `WindDownStartSheet.swift`, scoped start handling in
`FocusRunViewModel.swift`, `WindDownGuidance.swift`, and guide/routine UI currently colocated
in `WindDownGuideCard.swift`. Split touched view responsibilities rather than growing already
large files. Preserve Home shell routing and existing orientation target identifiers.

Active scope additionally touches `ActiveRunView.swift`, `NightJourneyView.swift`,
`ActiveRunPresentation.swift`, purpose handling in `FocusRunViewModel.swift` and the existing
`QuietTimeShieldPresentation`/registry contracts where shared identity checks are required.
Do not grow the already large ActiveRunView; extract the timer/status/purpose presentation only
as needed, preserving behavior and preview coverage.

Start policy/presentation decisions belong in pure Shared logic with injected time and tests.
Extend `WindDownStartSourcePolicyTests`, `WindDownStartContextTests`,
`QuietPeriodSchedulingTests`, `WindDownSchedulingTests`, and `WindDownGuidanceTests` where
appropriate. The existing unit target does not test SwiftUI presentation; manually exercise
actual navigation and sheet presentation rather than treating pure tests as UI evidence.

Required matrix: idle inside/outside the Wind Down window; manual versus saved one-time versus
repeating Phone Away; active run; pending/terminal receipt; permission missing/revoked; empty
selection; runtime protection failure; timer versus NFC; wrong-purpose/missing tag; cancel,
retry and double tap; delayed confirmation; automatic-start collision; foreground/background;
small iPhone, large Dynamic Type, VoiceOver, Reduce Motion, light/dark; no/multiple matching
guidance items; deep links and offline source details; feature-gated Slumber Party and practice.
Add in-app Purpose selection without backgrounding, rapid reselection, same-session restore,
new-session isolation, registry revision/epoch changes, missing storage, VoiceOver selection,
and all active phase presentations. Extend `ShieldingReadinessTests`,
`QuietTimeShieldScheduleRegistryTests`, `ActiveRunPresentationTests` and
`NightJourneyProgressTests` where the changed behavior belongs.

After code changes, run XcodeGen as required, full simulator build and unit tests, then physical
Phone Away shielding/NFC QA. No targets, entitlements, signing, dependencies, backend contract,
reward balance, or tab changes are proposed. If approved behavior changes, update AGENTS,
architecture, ADR-0017/other affected decisions and guidance source documentation together;
some existing Phone Away prose predates V4 and the transient manual-start implementation.

Review-only validation: repository/source inspection and successful `xcodegen generate`.
No app code was changed by this review, and no simulator or physical-device pass is claimed.

## Decisions and remaining verification

1. Build-33 protection workaround succeeded on the founder's device. The replacement direct
   repair path still requires implementation and device verification.
2. Personal ritual plus one prominent Slumber Party bridge: approved.
3. Occasional contextual guidance with dismissal and a browsable library: approved.
4. Active Purpose refresh and cross-occurrence isolation: included in the requested fix scope.
5. Active hierarchy, wording, phase strip and scene-label recommendations are specified above;
   they are not claimed to be implemented or separately approved in every visual detail.

Suggested delivery order: Phone Away repair and Purpose correctness first; Home and focused
Active-page consolidation second; guide/source redesign third. For the imminent roadshow,
complete the correctness fixes and essential hierarchy changes with device QA before expanding
the guidance content system.
