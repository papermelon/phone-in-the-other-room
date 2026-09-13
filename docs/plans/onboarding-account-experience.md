# Onboarding account experience

Current contract updated 8 September 2026. The founder's plan-first direction supersedes the
6 September stage order. [ADR-0023](../DECISIONS/ADR-0023-account-owned-farm-sync.md) and the
[account-owned Farm plan](account-owned-farm-sync.md) own authentication, Farm activation, and
automatic synchronization. Local implementation and current validation are tracked in the
[habit-loop plan](wind-down-habit-loop-2026-09-08.md); historical verification below does not
validate the new flow or establish distribution and physical-device behavior.

## Outcome

An independent new user can save a useful evening plan and explore Home before enabling app
protection, creating an account, answering starting-point questions, or choosing a welcome
gift. The normal first-use route also works in a workshop; it needs no special entry route or
facilitator. Returning-user Sign in remains visible on the first welcome page. Account setup
and existing account controls remain available through Settings afterward.

## Sequence and persistence

1. New drafts follow welcome → schedule and optional reminders → one optional evening activity
   → review → **Go to Home**. The two story pages are skippable. More evening ideas and morning
   routine editing remain available through progressive disclosure.
2. **Go to Home** saves the draft. Review distinguishes the planned schedule, protection
   readiness, and reminder authorization; it does not claim the plan is already saved or that
   protection is active. A short Home tour is optional and defaults off.
3. The additive `OnboardingJourneyRoute` is `.planFirst` for new drafts. A missing stored route
   decodes as `.legacy`. Existing step raw values do not change. Legacy drafts retain their
   questionnaire/result, gift, account, and protection stages, with an explicit option to defer
   protection setup; configured users bypass
   onboarding despite an old draft.
4. A verified loaded returning Farm persists a returner route without questionnaire, gift, or
   account stages, including after Back or relaunch. New returner drafts can save their device
   plan before protection setup. Legacy returner drafts retain their protection stage and can
   explicitly defer it. Do not
   claim schedule, routines, Screen Time selections, NFC registration, or permissions were
   restored from the account Farm.
5. Settings replay retains its existing route and explicit personalization/gift behavior,
   omits account enrollment, and preserves current settings. It cannot grant another welcome
   gift or restart a completed first-use journey.
6. A plan-only state never satisfies admission. Every real session still requires authorization,
   a non-empty selection, and the existing coordinator readiness checks. Declining optional
   notifications does not block saving or using a plan. Saving a plan does not start a session.

## Deferred personalization and gifts

`OnboardingPersonalizationView` exposes starting-point and welcome-gift entry points without
calling `applyOnboardingDraft`. The existing six questions remain optional. Answers produce a
private, non-clinical result only after explicit input; accepting the result saves the existing
profile record without changing schedule, routine, notification, or protection settings. Saved
answers can be revisited. Unsaved questionnaire progress is currently local to the open view.

Gift entitlement is independent of questions and accounts. **Wear now** uses the existing
idempotent gift API to claim and equip the selected wearable. **Keep for later** claims it while
preserving appearance. **Choose later** and closing the view retain eligibility without a grant.
Previously reserved or claimed gifts keep their identity; new navigation must not award a second
gift. Existing appearance controls retain their explicit save behavior.

## Account and recovery contract

Use the existing Apple and password account services and typed committed-operation events.
Authentication alone proves neither loaded Farm nor confirmed server save. Signing in loads
only the verified immutable account UUID's Farm; validate and activate that Farm before
publishing success. A failed lookup is not an empty account. Preserve the explicit path into
new-user setup when no account Farm exists, and preserve the current draft on cancellation or
failure. Loading an account Farm never merges another local or account Farm into it.

Account use includes automatic private synchronization under ADR-0023. A prior declined-upload
choice still requires explanation and acceptance; do not silently enroll it. Sign-out removes
the account Farm from active play without deleting its server copy. Preserve recovery copies,
pending-settlement rules, and account ownership throughout activation and retries.

Use the private Farm payload contract; do not upload questionnaire answers, routines, Health,
selected-app identity, NFC data, active sessions, or local habit reflections. Distinguish offline,
unavailable, failed, pending, and confirmed-save states. Source changes do not authorize hosted
schema changes, production activation, or distribution.

## Current validation and acceptance

- Test fresh and absent-route decoding, interrupted legacy stages, new and legacy returners,
  configured-user bypass, replay preservation, and independent idempotent gift entitlement.
- Verify saving a plan with incomplete protection reaches Home without starting a session;
  actual admission still requires protection readiness. Optional personalization must not
  replace the saved plan or permission choices.
- Inspect first use, declined permission, returning sign-in, optional questions and gifts,
  compact screens, and larger text. Verify useful actions without sound and with Reduce Motion.
- Run the repository's applicable build and test gates, inspect the integrated changes, and
  record current evidence in the habit-loop plan. Historical checks are not reused for new code.
- Physical protection, account activation, notification delivery, and participant accessibility
  remain separate acceptance checks. No simulator result establishes habit-building effectiveness.

## Historical implementation — 6 September 2026

The following record describes the previous dedicated-account-invitation implementation and
its original validation. Its first-run order, Apple-only controls, optional-backup enrollment,
and explicit routine-restore requirements are superseded by the current contract above and
ADR-0023. Keep the recorded outcomes as dated evidence, not current requirements.

Founder approved 6 September 2026. Status: implemented locally; independent review passed. Device acceptance remains below.

### Outcome

The first welcome page offers Get started and a single returning-user Sign in entrance.
New users continue through the existing optional starting-point chapter and Shepherd gift,
then see one dedicated account invitation before Wind Down configuration. The final action
is Go to Home. Repeated account prompts disappear from the story and ready screens.

The dedicated screen uses the person's actual Shepherd appearance, Ollie, and starter sheep
where available. A native Continue with Apple control has a clear visual hierarchy, alongside
Continue without an account. Auth cancellation, network failure, and retry preserve the draft.
Welcome gifts do not depend on signing in. No paywall, purchases, new identity provider, or
new analytics uploads are included.

### Sequence and persistence

1. Append an account step without changing existing persisted enum values.
2. First-run sequence: welcome → optional questionnaire/result → Shepherd and gift → account
   invitation → schedule → routine → protection → ready.
3. Keep questionnaire skipping and gift wear/keep semantics. Settings replay omits the account
   invitation and preserves existing settings. Existing drafts resume at their saved step.
4. Present returning-user sign-in separately from new-user account enrollment. After explicit,
   successful Farm restoration, persist a returning-user route to device setup. Skip the
   questionnaire and gift journey, including on Back and relaunch. Do not pretend schedule,
   routines, Screen Time selections, NFC registration, or permissions were restored.
5. If no account Farm exists, retain an explicit path into new-user setup. Authentication alone
   must not trigger a restore, skip a gift, or mark the Farm backed up.

### Account and recovery contract

Reuse FarmBackupViewModel and the existing Apple-linked account service. Add typed operation
completion/presentation state only where necessary; never infer success from message strings.
Show a preview from a fetched account payload (e.g. sheep, wool, appearance and save date)
before asking to restore. Restore needs explicit confirmation; local and account progress
are not combined, and the existing recovery-copy and account-owner checks remain mandatory.
A failed restore keeps the person in the same flow with retry and a safe way back.

Signing in, consenting to backup, and a confirmed server save are distinct. Explain the
existing private Farm field boundary before enabling backup. Retain existing disclosure details
through progressive disclosure; do not upload questionnaire, Health, routines, app selections,
NFC data, or active sessions. Use honest unavailable/offline/failed/pending/confirmed states.
Account management remains in Settings; onboarding need not expose deletion/revision-management
controls as its primary experience. Do not alter hosted schemas or deploy backend changes.

### Ownership and execution

Primary agent: plan, canonical documentation, acceptance criteria, baseline capture, verification,
and acceptance. One Terra/High implementer: onboarding UI/domain and bounded Farm-backup
presentation integration plus tests. Fresh Sol/High reviewer: read-only review after primary
verification. The founder explicitly selected Astra Medium for the primary session, overriding
the orchestration skill's primary-model prerequisite.

Preserve the substantial pre-existing working tree. Review task deltas against
`tmp/onboarding-account/baseline`, not whole-file differences from HEAD. No worker edits to
project.yml, signing, entitlements, tab structure, hosted backend, or unrelated files.

### Validation and acceptance

- Domain tests: stable old raw values/decode; account-step order; questionnaire skip; returner
  routing; Back/relaunch; replay exclusion; gifts remain independent and idempotent.
- Integration coverage where feasible: authentication alone does not restore; restore completion
  is reported only after success; failures do not skip setup; no overwrite without a choice.
- Native previews/captures: fresh account invitation, unavailable/retry, existing Farm preview,
  compact width and accessibility text sizes. Full-width provider actions; no clipped controls.
- XcodeGen regeneration for new files, generic iOS/Watch Simulator build, full iPhone 17e tests,
  and Farm save regression script if the backup integration changes.
- Independent final review of task deltas; resolve material findings and repeat affected checks.
- Physical Apple authorization and production multi-device restoration remain device acceptance;
  no TestFlight upload or production save is implied by simulator checks.

### Local verification — 6 September 2026

- Generic iOS/Watch Simulator build passed, including the final welcome toolbar change.
- Full iPhone 17e simulator suite: 867 tests, zero failures.
- Farm save/persistence harness: 40 tests, zero failures.
- Returning-user sheet inspected on iPhone SE (3rd generation): artwork, native Apple action,
  and local continuation fit at standard text size. Maximum Dynamic Type reflows the heading
  and copy; full scrolling verification was interrupted by the host Mac locking.
- Small-screen inspection found the welcome sign-in link below the fold; it was moved to the
  first welcome page's top bar. A final simulator capture verifies it is visible. The new-user
  invitation's retry state also fits at standard text size. Seeded simulator drafts were used
  to capture account layouts independently of Apple authentication.
- Deterministic previews cover signed-out, unavailable, failed, existing-save, and large-text
  states. Physical Apple authorization and multi-device restoration remain unverified here.
- Independent review identified a status regression after successful backup: a no-op check
  could remain in Checking, and in-flight saves did not publish pending state. Both transitions
  were corrected and covered by tests, including an assertion that no-op checks send nothing.
- Fresh final review verdict: ship, no findings. The host exposed unrestricted permissions;
  review was procedurally read-only, and before/after hashes of all 1,177 repository files
  confirmed no reviewer mutations.
