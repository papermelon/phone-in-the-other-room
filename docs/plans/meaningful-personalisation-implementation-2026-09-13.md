# Meaningful personalisation — local delivery

13 September 2026. Local source implementation for the founder's
[detailed handoff](meaningful-personalisation-handoff-2026-09-13.md).
No commit, push, distribution, backend deployment, AI processing or API spend.
The [AI assessment](personalisation-ai-pilot-2026-09-13.md) is a separate proposal.

## What answers now change

One optional active goal focuses on either Wind Down or Screen-Free Morning.
Settings → **What I’m working toward**, Plan, and Home → **Make it yours** reach
the same loop. Nothing blocks onboarding, a start, an active countdown or a reward.

| Answer / choice | Visible consequence | What is actually saved |
| --- | --- | --- |
| Less automatic morning scrolling | Offers a small first action before checking the phone | Confirmed goal; activity remains a proposal until review |
| A less rushed start | Offers one simple activity to leave less to fit in | Same explicit goal/plan association |
| Time for myself | Offers a quiet personal moment | No inferred activity completion |
| Being present with others | Offers a small connection that can be edited for household/schedule | No assumption about who lives with the person |
| Making room to unwind (evening) | Offers reading one page | No sleep/health claim |
| Putting my phone down when intended (evening) | Offers preparing an appealing alternative | No automatic start/reminder |
| My own reason | Preserves up to 120 characters without classification; asks the person to choose their action | Exact bounded personal wording, never automatically sent anywhere |
| No goal / Not now | Leaves the routine usable and stops goal-dependent suggestions | No default motivation or negative observation |
| Reviewed activity/cue/preparation | Updates the existing future routine's activities and optional habit support | Exact old/new plan snapshots plus reviewed-change record |
| Yes / Partly / Not today / Not sure | Answers whether the intended experience happened; Yes quiets invitations for 28 days | Explicit self-report, selected plan revision or general/unassociated note |
| Optional obstacle | Can support a bounded rule below; needed-phone/timing offers the existing review route | Existing obstacle type, including new “It felt rushed” |
| Optional context | Preserves what worked or got in the way for later review | Up to 240 characters; never parsed into a rule or sent to AI |

Goals and activities remain distinct. Saving a goal sets a reflection target and
an explainable proposal; it does not change timing or silently replace an activity.
The review shows the existing ideas and the exact proposed single activity. The
person can choose a familiar existing activity or edit a custom one. Saving uses
`NightWatchPreferences` / `WindDownRoutineStep` and the existing schedule projection.
An optional morning cue extends `WindDownHabitPlan`; it is visible in plan review
and the saved plan, not an automatic notification or timer transition.

Routine activities continue to use existing Watch/Lock Screen paths. Enabled remote
Live Activity registration includes activity titles through the existing backend.
The review discloses that boundary. Goal wording, reflection context, proposal
history and cues are not added to those transports, Farm sync or Slumber Party.

## Screen density revision

After the founder's preliminary review, the new UI was shortened: the goal editor
keeps one question, choices and a brief next-step cue; review leads with one action;
goal/current-activity context and data details expand on demand. Repeated explanations
and the goal page's self-link were removed. Reflection labels and suggestion reasons
were shortened without changing their evidence requirements or save boundaries.

## Representative flows

1. **A less rushed morning.** Choose the morning goal, review its rationale, replace
   the existing ideas with one personally useful activity, optionally add “After
   opening the curtains,” and save. The existing Screen-Free Morning countdown
   later freezes its usual activity snapshot. No question appears during the timer.
2. **Reflect later.** Home may show one passive invitation after seven days. Nights
   offers a manual morning/evening reflection for any chosen day; the goal page
   offers today's relevant reflection. These use the same per-mode/day record.
   The person explicitly selects which saved plan they mean, or leaves it as a
   general reflection. No occurrence ID is guessed from a day's session list.
3. **A useful adjustment.** Two dated Partly/Not today notes for the current plan
   explicitly mention too much to fit in or feeling rushed. If that plan has more
   than one activity, offer “Try just one activity,” with the actual two evidence
   dates available under “See my reflections”. Review change opens an editable
   draft. Keep my plan records rejection; Later defers for seven days.
4. **An irregular schedule or caregiver.** Keep a custom goal in the person's own
   words. Choose any practical activity/cue; there is no fixed 7 AM assumption.
   Needed-phone feedback links to existing app-protection review and does not
   infer lack of motivation or automatically reduce protection.
5. **Successful, uncertain or sparse feedback.** Yes delays passive invitations to
   28 days. Not sure, missing answers, one matching note, old/future dates and
   unrelated plan versions produce no trend suggestion. No target escalation.
6. **Offline, stale, or unavailable.** All new logic is local. An account/plan/note
   change invalidates stale write tokens. A failed save remains visible and asks
   the person to reopen saved choices. Corrupt/newer-schema journal bytes are kept;
   their editors are disabled. A healthy original evening-note/support field stays
   independently writable. Account changes reset/dismiss private drafts.
7. **Clear/review.** Review saved plans, notes and response history. Delete an
   individual mode/day reflection; remove the goal; clear suggestions; disable
   invitations; or clear goals, reflections and suggestions together. Existing
   routine settings, timer history and Farm remain. No remote deletion is implied.

## Deterministic adaptation and cadence

`RitualPersonalisationRules` v1 has no timer, shielding, Brief Access, sleep, Farm,
or social inputs. It requires two distinct Gregorian civil days, explicit Partly
or Not today, the current goal/plan revision, matching mode, valid original-zone
context, and reports within the preceding 28 days. Future/undated reports are
excluded. Rules do not parse personal context, combine unrelated plans, or claim
statistical significance or causation.

- Too much / felt rushed + more than one activity → review a single activity.
- Wanted something else → review a replacement activity.
- Slipped my mind + no saved cue → review a familiar cue.
- Timing, needed phone, unclassified obstacles, success or unknown → no inferred
  automatic adjustment. Existing review routes remain available. Preparation can
  still be edited explicitly; “something else” alone does not justify that guess.

Only one proposed/deferred suggestion exists at a time. Each has a stable ID,
rule version, exact evidence IDs, target plan ID, explanation and 14-day expiry.
A rejected action is suppressed for the active goal even with newer evidence or
expired detailed history. A goal change resets that small rejection mask; a plan
change alone does not. Clearing suggestions suppresses all action types until a
new goal. Expired/superseded evidence is not immediately regenerated. Editing or
deleting cited feedback retires the old offer. Accepting stores the chosen old/new
values and leaves later notes free to name the new plan without rewriting old ones.

There are no modal auto-prompts. A single passive Home invitation remains available
for the current period until acted on; dismissal or any saved reflection postpones
it seven days. Successful feedback postpones it 28 days. Invitations and reflection
forms are suppressed during either an active run or independent active morning.
Manual entries stay available afterward. No completion/reward UI was extended.

## Storage, migration and authority

The audit found three different existing concerns:

- `OfflinePurposeProfile` is device-scoped reminder/display wording, partly activity
  categories. `QuietPurposeCue` is occurrence-scoped shield context. Neither is a
  confirmed longitudinal goal. Their values are not migrated or offered as an
  account's private goal because ownership/meaning cannot be established.
- `OnboardingDraft` and account-local `WindDownProfileRecord` retain the optional
  starting-point questionnaire. Its accepted result does not change a routine.
  That compatibility flow/copy is preserved; Home's main optional route now reaches
  the useful goal loop. No older answer is silently adopted as a goal.
- Existing habit support/reflections already use owner-scoped transaction values.
  Existing routine/timing preferences remain device settings. The new journal
  joins that local habit boundary rather than creating a cloud profile.

`RitualPersonalisation` schema 1 lives at `ollie.windDown.personalisation` in
`FarmSaveDocument.localValues`, partitioned by verified account UUID or guest and
save lineage. It is explicitly absent from the Farm payload whitelist. Goal and
plan revisions are immutable historical snapshots; goal edits archive the previous
choice. Existing reflections gain optional `experience` plus a backward-compatible
mode (missing means evening). Morning/evening share the existing 45-entry bound,
with distinct per-mode civil-day identities and deterministic ordering across ties.
Existing absent support fields default to nil. Unknown/corrupt fields do not trigger
silent replacement of the stored journal.

Write tokens capture owner/lineage, the original journal and reflection bytes,
preferences and support. The service compares them under the transaction lock.
Journal, reflection and support edits commit together. Reviewed plan changes first
persist a durable intention with exact old/new preferences. The existing device
preferences are then projected idempotently; relaunch completes an interrupted
projection only if the same owner and old/new preferences still match. Otherwise
the newer device plan wins and the record marks that the projection was not applied.
This is source-level save evidence, not evidence the person followed the routine.
No run snapshot, coordinator state machine or settlement algorithm is changed.

Detailed goals/plans/suggestions/adjustments retain 90 days on the next local load
or mutation, capped at 90 plan revisions, plus the current goal/plan. Up to 45
existing mode/day reflections remain until replaced/deleted. Minimal rejection
memory lasts for the active goal. Live app clearing does not claim forensic
removal from OS backups or the existing transaction recovery generations; those
follow the store's existing rotation/recovery policy. No remote retention was added.

## Verification

See [validation evidence](../evidence/personalisation-20260913/validation.md) for
actual final commands, results and captures. Domain tests cover neutral/missing
legacy data, custom goals, evidence dates/zones/modes, conflicting/unknown feedback,
plan changes, rejection/deferral/expiry, successful cadence and serialization.
Temporary-store tests exercise owner A/sign-out/guest/B, stale journal/preferences/
support/notes, corruption/newer schema, atomic sibling writes and relaunch.

The isolated in-app habit probe additionally exercises accepted activity updates,
unchanged timing/protection/Farm/settlement, preserved old feedback associations,
interrupted projection replay without duplication, and stale/account-switched drafts.
The merge gate includes the complete app/Watch build and full unit suite. Simulator
results do not establish physical shielding, NFC, Watch delivery, sleep, physical
placement, habit effectiveness or production readiness.
