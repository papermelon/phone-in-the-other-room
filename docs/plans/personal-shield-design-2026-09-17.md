# Personal shielding — implementation and acceptance

Design agreed 17 September 2026; implementation requested 19 September. The interaction
below is now implemented locally in Swift. No release upload, deployment or physical-device
validation has been performed. This replaces the earlier design-only status.

## Implementation

- `PersonalShieldSession` stores bounded, occurrence-scoped private self-reports in the
  existing account-local transaction store. Check/uncheck saves first, then projects to
  the App Group. Profile/goal and Campfire data are not repurposed as Phone Away tasks.
- Wind Down freezes its selected evening and morning activities and goal. Phone Away
  accepts up to three optional private tasks in its start sheet. All-checked Wind Down
  leads to sleep; all-checked Phone Away keeps its timer running.
- Shield Configuration renders text and check marks with two direct actions; Shield
  Action only requests a parent-app route and cannot grant access. The obsolete direct
  grant contract was removed. iOS 26.5+ uses Apple's parent-app response; older OS versions
  explain the manual step and consume the same bounded route when the app opens.
- Home owns the checklist and phrase sheets over the existing Ollie journey. Dismissal
  returns there; no third-party app is launched. Routes expire after two minutes, match
  owner/session/schedule revision and epoch, and are consumed once after restoration.
- Brief Access reuses the existing grant/restore monitor and ledger, scheduled before
  clearing selected-app limits. Ordinary intentional early endings consume a fresh coordinator
  challenge. The [20 September refinement](shield-access-and-early-wake-repair-2026-09-20.md)
  gives Start Screen-Free Morning now a dedicated confirmation button; defer/skip use
  intent-specific phrases. NFC authentication and technical failure transitions keep their paths.
- Phrase entry is ephemeral. Matching tolerates case, Unicode forms, whitespace and
  punctuation while retaining words and numbers. No new public/social, Farm-sync or
  remote Live Activity fields are introduced.

## Validation

The final generic Simulator build and all **1,065 unit tests** passed. The isolated
production VM/coordinator/persistence probe passed its checklist, routing, phrase,
failed-access, one-use ending, early-wake, corrupt-list and owner-boundary checks.
The probe uses a shielding spy; it does not establish actual Screen Time enforcement.
See [validation evidence and captures](../../output/design/personal-shield-20260919/README.md).

Interactive review resumed after unlock. Checks/unchecks, completion copy for both modes,
exact task phrases, fresh/cancelled/confirmed gates, Ollie/receipt routing, early-wake handoff,
light/dark appearance, keyboard entry and accessibility-size wrapping were inspected.
Phrase/task touch targets and disabled-button appearance were refined, followed by a
successful final build, full unit suite and integration probe. Accessibility values/hints
were inspected; spoken VoiceOver, dictation and large-text touch scrolling remain open.
The disposable iPhone SE had repeated boot/app-launch failures, so small-screen acceptance is not claimed.
These and physical-device follow-ups are tracked in
[the backlog](../FUTURE_AGENT_TASKS.md#personal-shield-device-acceptance-19-september-2026).

## Accepted experience

The shield should recall what this time was set aside for immediately. Keep Ollie and
the sheep, a short mode title, a read-only routine/task summary in the subtitle, the
protection end time, and two direct buttons. No Options/submenu layer is needed.
Move explanations about Brief Access to the moment someone requests it.

- Before bed: show **this run's** chosen routine directly as text. Read-only check
  marks may reflect existing self-reports; tapping the text does not toggle them.
  For long titles, show the next exact activity plus a remaining-step count instead
  of shrinking text or producing a wall of copy. The full checklist is one button away.
- Overnight: lead toward sleep. Do not imply the person still needs to finish a
  checklist after bedtime or claim that unchecked steps happened.
- Phone Away: show the private task list explicitly chosen for this run, with the
  same compact fallback for long titles.
- Screen-Free Morning: use its own morning activity/goal and occurrence.
- When every Wind Down activity is checked: show **Time for sleep** and **Put your
  phone away for the night**. Do not fall back to a broad goal such as “Time for myself”.
- When every Phone Away task is checked: show **Tasks checked off** and let the person
  keep the remaining time phone-free or deliberately end via the phrase gate.
- Checking the list never ends the timer or removes protection.
- Without personal text: keep the shield factual; do not invent a motivation.

Example before-bed shield:

> My Wind Down
>
> ✓ Brush my teeth
> 2. Read 10 pages
> 3. Set out tomorrow’s clothes
>
> Selected apps blocked until 7:30 AM.
>
> **My routine** · **5-min access**

Both actions are visible immediately. **My routine** (or **My morning** / **My tasks** in those modes)
opens the interactive checklist; **5-min access** opens the phrase gate directly.
Neither grants access on its own. These use the two system button slots, replacing
the prior Close app / Options arrangement. The normal Home gesture remains available
to leave the blocked app. The interactive checklist still requires one deliberate tap.

## What the actual iOS shield can support

Apple's [ShieldConfiguration](https://developer.apple.com/documentation/managedsettingsui/shieldconfiguration)
provides an icon, title, subtitle, button labels/colours and system-owned layout.
It does not provide arbitrary SwiftUI content, text entry, or inline tappable rows.
Routine text can be included in its subtitle when the blocked app opens. The full
custom **My Wind Down** screen cannot replace the native shield, and the documented
parent-app opening response follows a user button action; it does not provide an
automatic app-launch redirect. Do not imply the static routine text is interactive.
The prototype's shield geometry is illustrative, not a promise of pixel-level control.
Shorten button labels and verify contrast on a signed device; do not assume custom
button widths, font sizes or vertical positioning are available.

The installed Xcode 26.6 / iPhoneOS26.5 SDK confirms:

- `secondaryButtonSubmenuItems`: iOS 26.4+, unused in the revised design.
- `ShieldActionResponse.openParentalControlsApp`: iOS 26.5+.

Apple documents the [parent-app response](https://developer.apple.com/documentation/managedsettings/shieldactionresponse/openparentalcontrolsapp).
Use a bounded pending route in the existing App Group, revalidated by the parent
against the active occurrence. Opening the parent must leave selected apps shielded.
On older iOS versions, provide honest instructions to open Counting Sheep manually;
the same routine and access entry points must exist on the active Home journey.
Do not silently preserve direct five-minute grants as an older-OS bypass of the phrase.

The subtitle uses plain text for any saved check marks, not drawn checkbox controls.
Read the current occurrence-scoped projection each time configuration is requested;
actual shield refresh/caching after returning from Counting Sheep needs device testing.

## Shared checks, dynamic labels and the active Home journey

Checks in the app and tick marks on the shield represent the **same occurrence's
saved state**. A check/uncheck first updates the authoritative local checklist and
its minimal App Group presentation projection. The shield reads that projection
when iOS requests configuration; it does not keep a second editable checklist.
If saving fails, do not present an unsaved check as durable success. Keep step IDs,
account/guest scope, occurrence ID and revision aligned and clear expired projections.

The intended visible result is that reopening a blocked app shows the updated checks.
Immediate redraw of an already displayed/cached shield remains a physical-device
acceptance requirement. Apple's documented `.defer` redraw occurs in response to a
shield action; it does not establish an app-triggered live-refresh guarantee.
Do not briefly clear protection as a cosmetic refresh technique.

Use mode-specific labels consistently on the shield and active Home:

| Session | Button | Checklist sheet title |
| --- | --- | --- |
| Wind Down | My routine | My Wind Down |
| Phone Away | My tasks | My tasks |
| Screen-Free Morning | My routine | My morning |

“Routine” suits a repeatable bedtime/morning sequence; it is a poor umbrella for
one-off Phone Away tasks. Do not relabel the Phone Away list as a routine or force
its tasks into the Wind Down model. Empty lists retain their mode's label and show
an honest empty state. Existing personal goal text remains distinct from the tasks.

The Ollie-chasing-sheep Home screen stays the primary active-session destination.
The checklist and phrase gate are **sheets over that same active journey**, not new
Home replacements or separate session screens.

| How the person enters | What they see | Done / cancel |
| --- | --- | --- |
| Open Counting Sheep normally during a run | Existing Ollie chase screen | Stays on active Home |
| Tap My routine / My tasks on the shield | Counting Sheep with the relevant checklist sheet already open over Ollie | Returns to Ollie |
| Tap 5-min access on the shield | Counting Sheep with the phrase sheet already open over Ollie | Returns to Ollie; no grant on cancellation |
| Tap My routine / My tasks within the Ollie screen | The same checklist sheet and the same saved checks | Returns to Ollie |

Opening via an explicit shield action must honour that request rather than landing
on Ollie and asking for another checklist tap. The underlying active Home is restored
first, but the requested sheet is presented as part of the initial routed state.
The prototype's prior Back/Close-to-shield behaviour is superseded: closing a sheet
does not automatically reopen the originally blocked third-party app. The person
can use the app switcher/Home gesture to return there. Likewise, granting access
makes selected apps available; it does not silently launch a specific external app.

The current `HomeView` routes active foreground sessions to Home, and its active
Wind Down surface contains `ActiveRunView` → `NightJourneyView`. During implementation,
restore/reconcile the run through the existing coordinator, then consume a short-lived,
one-use shield route carrying the action and matching owner/occurrence/revision/epoch.
Present the Home-owned sheet after that reconciliation. A generic foreground redirect
must not erase this explicit route; do not add a parallel run state machine.

Consume or discard the route exactly once. A subsequent ordinary app opening shows
Ollie, not the last checklist/access sheet. If the run ended, the occurrence changed,
the account changed, or the request expired, discard it and use the authoritative
Home/receipt route. Terminal receipts keep precedence. Older-iOS manual handoff may
consume a fresh explicit pending request, but stale requests never hijack app opens.
The checklist sheet must also be reachable directly from active Home, including
when a shield handoff was unavailable.

## Checklist behaviour

Use the existing ordered evening routine (currently at most three optional activities)
and morning routine (at most two). Retain the selected words and order. Show a checkbox
beside each activity and a quiet “1 of 3 checked · optional” summary.
Phone Away also supports an ordered task list; its prototype includes three tasks.
The completion message changes immediately when the last box is checked and reverts
if a step is unchecked. Checked rows remain available to undo.

Checks are private self-reports, reversible and scoped to the active occurrence.
They survive relaunch for that occurrence and reset for the next one. Never infer
them from elapsed time, NFC, a shielding event, or a previous night. Do not auto-check
the phone-placement invitation. An empty routine does not block this experience.

The user can return to the routine later or put the phone away without checking
anything. No completion gate, Farm reward, missed-step penalty, social signal or
completion animation is added. Existing timers and terminal routing remain authoritative.

## Deliberate five-minute access

1. Show one exact short phrase from the active task, next activity, or relevant goal.
2. Ask **Type this phrase to continue**. No generated affirmations, guilt, paraphrasing,
   reason scoring or AI judgement. Examples: “Read 10 pages” and “Finish the project outline”.
3. Keep **Allow 5 minutes** disabled until the words match. Normalise case, spacing,
   Unicode forms and punctuation; preserve the words and numbers. Keep normal
   accessible text entry, including dictation. This is deliberate entry, not proof
   that someone physically typed or performed the activity.
4. Require a fresh entry for each new request. Opening the view, entering text, or
   ticking routine steps never grants access. Cancellation leaves protection intact.
5. After explicit confirmation, use the existing bounded grant and restore ledger:
   up to five minutes, capped at an earlier session end, timer continues, Farm credit
   excludes Brief Access. Do not introduce a parallel access timer or grant path.

The typing screen needs just one supporting line: **Selected apps unlock for up to
5 minutes.** Remove the static capitalisation/punctuation hint and timer/Farm paragraph;
normalisation and the underlying accounting remain unchanged. Do not imply only the
attempted app unlocks: current Brief Access lifts the consented selection.

After the Wind Down routine is checked off, and overnight, use an explicitly saved
sleep-focused phrase if available; otherwise **Put my phone away for sleep** is a plain
mode-specific default. It is not presented as a verbatim user-authored goal. Do not send
the person back to a completed activity or a generic “Time for myself” prompt.

If no personal text exists, use “Put my phone away”. For long personal
text, choose a short saved activity where available. Otherwise show the exact goal;
offer an explicit short-phrase edit during future plan setup, never silently truncate
or rewrite it into a new assertion.

## Ending early / emergency exit

The original prototype's ungated emergency exit was misleading and is superseded.
The inspected native NFC exit already requires a self-authored reason followed by a
matching confirmation (`EmergencyExitChallenge`). The revised proposal replaces that
generic challenge with the same personal phrase source used for Brief Access, and
applies a fresh phrase gate to deliberate early ending in the illustrated app-shield flow.

The entry is labelled **End Wind Down** or **End Phone Away**, making its consequence
clear. Its screen shows the relevant exact task/routine/goal phrase, **Type this phrase
to end the session**, and one consequence line: **Ends the session and unblocks selected
apps.** The final end button stays disabled until a fresh matching entry is made.
Brief Access confirmation cannot be reused for ending. Cancelling or returning and
reopening requires a fresh entry. No duplicate easy-exit link appears on the access form.

This gate never requires every routine/task to be completed. Preserve authenticated
NFC exit and platform emergency calling. Technical failure still follows the existing
fail-open/repair contract; it is not an easier user-facing bypass labelled “emergency”.
The implementation uses the existing coordinator’s one-use exit authorisation,
including intentional early-wake choices, without creating an independent timer state machine.

## Original source analysis (17 September; historical)

- `QuietTimeShieldConfiguration` currently joins a generic/purpose cue, end time and
  access explanation. It can consume a bounded personal presentation projection.
- `QuietTimeShieldAction` currently grants access directly from the secondary action
  or submenu. This path would have to be replaced with an app handoff.
- `NightWatchPlan` already freezes routine steps; `WindDownRoutineSequenceCard`
  currently presents them as noninteractive invitations. New completion state should
  be separate from the immutable plan and should not create another session machine.
- `RitualGoal.wording` provides exact optional personal goal text. Current goals are
  scoped to evening or morning, not a general Phone Away task profile.
- The inspected `FocusRun` does not contain a dedicated private Phone Away task list.
  Its prototype examples therefore represent proposed input capture at setup, not an
  already-wired field. Campfire's separately authored party intention and legacy
  `QuietPurposeCue` must not be silently repurposed as this private task.
- App Group presentation currently excludes free text. Implementation needs an explicit
  minimal local projection with occurrence, owner scope, revision and epoch, stale-data
  rejection and clearing on account switch/end. Never project a whole profile or send
  new goal/checklist/typed-response data to Farm sync, Slumber Party, remote Live Activity
  registration or analytics. Do not retain the user's duplicate typed response.

The product direction and habit-loop documents were updated with the 19 September
implementation to describe optional private checks. The analysis above records the
pre-implementation state.

## Mobbin references inspected

- [Jomo's shield](https://mobbin.com/screens/9b6008e9-c25c-45b0-bf1e-72756afca2f5)
  names the active routine. Borrow the connection to context, not its usage-count nudge.
- [Brick's shield](https://mobbin.com/screens/0338aaef-88cd-4ef4-b4e9-6e5cf45c4126)
  uses a short message and clear next action. Borrow the economy of copy.
- [Tiimo's evening plan](https://mobbin.com/screens/995c52a8-9632-42e1-b45e-f8d951e95d17)
  groups concrete ordered evening activities. The inspected screen is a plan preview;
  it does not establish that Tiimo runs this inside an iOS shield.
- [Jomo's unlock-method selection](https://mobbin.com/flows/9a509fcd-cf4d-4c6d-82df-0c9bd99d8d92)
  includes giving a reason and copying text as alternative unlock methods.
- [Jomo's reason-based unlock](https://mobbin.com/flows/09987e4a-f391-4d0d-b12e-7443d24c6b77)
  separates the intervention from the eventual unlock action. Our proposal fixes
  the duration at five minutes and uses already-chosen words. Screens do not establish
  behavioural effectiveness; that remains a product hypothesis.

## Prototype and validation boundary

The conversation prototype contains sample content, a system-shield approximation
with a read-only routine/task summary and two direct actions, interactive routine/task
checklists in Counting Sheep, sleep and task-list completion states,
phrase matching for both access and early ending, and simulated access/early restore.
Its example controls switch Wind Down / Phone Away;
design controls additionally expose overnight, morning and empty states.
**Open Counting Sheep** and **Reopen blocked app** simulate the two distinct entry
paths without resetting checks. The in-app sheets show a static schematic of the
existing chase scene behind them; it is not a redesign or replica of its animation.

All state is temporary and local to the prototype. It does not read an account,
start a real session, unlock an app, persist checks, or validate native shielding.
The original mascot asset is embedded unchanged. JavaScript syntax and fragment
structure were checked. The actual prototype script passed state/handler checks
using a minimal DOM facade. The revised checks cover checklist updates, next-step and
sleep-state projection, multi-task Phone Away, wrong/empty phrase rejection for both
access and ending, case/spacing/punctuation tolerance, grant/restore, fresh requests,
ordinary app-open versus shield-request routing, sheet dismissal back to active Home,
shared checks when returning to the shield, and overnight/morning/empty scenarios.
This is logic validation only. Browser file-URL preview was blocked by the browser's
URL policy; no browser rendering or physical-device validation is claimed.

Before source implementation is accepted, validate the handoff on iOS 26.5+ and older
OS instructions, background/terminated automatic runs, stale/account-switched routes,
fresh phrase matching per access/end request, no direct extension bypass, grant/restore
failure, occurrence reset/relaunch, larger text/VoiceOver/keyboard, preserved authenticated
NFC exit, and coordinator-backed emergency exit with the new personal challenge.
Also validate warm/cold shield handoffs, ordinary reopens after a consumed request,
receipt precedence, and shield refresh without temporarily lifting protection.
The in-conversation rendering is a design review surface, not native acceptance evidence.
