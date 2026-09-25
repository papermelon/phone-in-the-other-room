# Account-owned Farms, automatic sync, and password sign-in

Date: 2026-09-07
Status: **Implementation authorized; local source implemented and validation in progress.**
Founder direction is recorded in ADR-0023. Production configuration, deployment and physical-device
acceptance remain separate release gates. The design below records the intended contract;
the implementation evidence section records what has actually been verified.

Current Profile presentation and handle discoverability follow the [21 September repair](account-and-search-repair-2026-09-21.md). Authentication feedback is distinct from confirmed Farm activation.

### 25 September account-default repair

The account selection action previously called the legacy restore path, which rejects
any pending upload. A failed upload could therefore block the very action meant to
replace the phone branch. Selection now uses the account activation transaction directly,
archives the displaced document before publication, and retains enabled automatic-sync
metadata. Divergent active/cached Farms default to the verified account head; ordinary
same-base local edits continue uploading. Retry reads the durable backup state.

Regression tests reproduced the blocked selection and old divergent-choice behavior
before the fix. The isolated Farm harness passes 90 tests, covering queued uploads,
recovery content, failed disk commits, divergent signed-out caches, pending deletion,
missing remote heads and subsequent uploads. Generic iOS Simulator build and the full
iOS Simulator suite (1,138 tests, zero failures) passed. Commands: `python3 scripts/validate-farm-save.py`,
`xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator'`,
and `xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=A0DB65B8-F3FC-4961-8B0C-9689F51C9EA1'`.
Logs: `/tmp/farm-default-verified.log`, `/tmp/farm-default-build.log`, `/tmp/farm-default-app-tests.log`.
Scoped pre-merge review: approve, risk M; existing account/transport fences and atomic
recovery remain in place. No schema, entitlement or backend contract changes.
No production data was modified and no build was distributed. Physical login, the
reported account's transport failure and two-device convergence remain unverified.

## 1. Outcome

Each signed-in account owns one active Farm. Signing in loads that Farm and enables
automatic synchronization as part of using the account. Users do not separately
enable, pause, check, or routinely restore a backup. Signing out removes the account's
Farm from the visible, playable app; signing into another account loads only that
account's Farm. Signing out does not delete server progress.

Offer native Sign in with Apple and **Username or email + password**. Handle and
username mean the same identifier, not two separate fields. Both methods resolve to
the same immutable Supabase user UUID when linked. Username, email, display name,
and Apple identity are credentials or profile attributes, never Farm ownership keys.

Preserve account-free onboarding as a guest Farm unless the founder separately changes
that choice. A guest Farm is device-local and explicitly distinct from a signed-out
account's inaccessible cache. Local sessions remain usable offline; server confirmation
is still required before describing a change as saved to the account.

## 2. Pre-change implementation and change boundary

Reviewed source:

- `Views/FarmBackupView.swift` shows manual check, enable/pause, restore, branch choice,
  historical copies, and deletion beside full disclosures. Its task already refreshes
  on entry and it disables the entire screen during work.
- `Views/FarmAccountControlsView.swift` retains a playable local Farm after sign-out
  and uses a separate verbose account-management screen.
- `ViewModels/FarmBackupViewModel.swift` signs in and looks up saves separately from
  enabling uploads. Restoring initializes `enabled: false`. `keepThisFarm` also leaves
  future uploads requiring another choice.
- `Services/NightFlockAccountService.swift` and shared account-session policy require
  Apple identity evidence and persist one expected UUID. Recovery, explicit account
  switching, and credential linking need separate operations.
- `Services/FarmSaveStore.swift`, `Shared/FarmSaveDocument.swift`, the private
  `farm_save_v1` RPC, revision checks, and deterministic reward ledgers are foundations
  to retain. Do not replace them with unversioned snapshots or upload the local document.

Reuse the approved Supabase dependency and one shared session. No new tabs, targets,
packages, or entitlements are assumed. Reconcile this draft with concurrent work before
implementation; the working tree already contains extensive app and documentation changes.

## 3. User journeys and Settings

| Situation | Required behavior |
|---|---|
| New guest | Existing local onboarding, gifts and optional practice remain available. |
| Create account | Apple or username/email/password; explain automatic Farm saving before submitting. Attach the guest Farm only after verified identity and authoritative empty-account lookup. |
| Returning account | Authenticate, fetch and validate its Farm, then publish it atomically. Skip completed gift/questionnaire stages; retain device setup requirements. |
| Lookup fails | Keep a loading/retry state. Never infer an empty account or seed a replacement Farm. |
| Signed in and offline | Use that account's validated cache and durable pending writes. Show “Waiting for connection” when needed. |
| Explicit sign-out | Stop account activity, remove active Farm and profile state, show signed-out entry. A separate “Continue as guest” creates or resumes only a guest scope. |
| Account switch | Use the sign-out/sign-in transition; never relabel the old Farm with the new UUID. |
| Expired session | Preserve the inaccessible/pending owner context; reconnect that account. Do not treat expiration as an instruction to create a guest or switch owners. |

**Profile** is the identity entry point (founder direction, 7 September device review).
The main tab headers show a compact outlined Profile icon in a 44-point hit area at the top right;
remove the bottom floating Account link. Settings → Connections → **Profile** opens
the same page. Keep the four release tabs.

Use this hierarchy:

- Shepherd identity first: display name, @username where set, and verified linked methods. Name/appearance editing and sign-in/username management are grouped below Farm status.
- Farm status: Saved / Saving… / Waiting for connection / Needs attention, with last
  confirmed server time. A newer local generation must not display “Saved” merely
  because a previous upload succeeded.
- “Sign-in and username” for adding password credentials or Apple, choosing a username, and managing recovery email.
- “What syncs?” for concise detail; account deletion remains discoverable here and from
  Privacy & data. Advanced recovery appears only when needed or within a recovery detail.
- A quiet text “Sign out” action. “Delete account” uses destructive styling inside an Account management disclosure and retains its separate confirmation flow.
- For prior declined-sync migration, show “Apple connected” separately from “Enable automatic sync”; do not frame acceptance as another login or show the sync disclosure twice.

Remove routine Check account save, Check account connection, Turn on backup, Pause
backup, and Restore account Farm controls. Retry appears for actionable failures.
Remove standalone deletion of the normal account Farm copy: automatic sync would
recreate it. Account deletion removes account data; any future “start a new Farm”
feature needs explicit reset semantics and is outside this plan.

Use Theme/PixelComponents styles with explicit foreground/background pairs for primary,
secondary and destructive controls. Body copy uses regular hierarchy; no large bold
explanatory paragraphs. Disable only conflicting actions during requests. Preserve
Dynamic Type, VoiceOver, keyboard autofill and readable loading/error states. Check
light/dark mode on small screens and at accessibility text sizes without reducing the
user's text-size preference. Target 4.5:1 contrast for normal labels and 44pt hit areas.

## 4. Credentials, usernames and recovery

### Proposed registration contract

- Password registration asks for email, username and password. Verify email before
  activating account Farm sync; preserve guest work while verification is pending.
- Proposed usernames: case-insensitive ASCII letters, digits and underscores, 3–24
  characters, starting with a letter. Strip an optional leading `@` at login only.
  Enforce normalization, reserved names and uniqueness transactionally on the server.
- Keep the Slumber Party display name independent: existing names need not be unique
  and must not silently become login identifiers or newly public account information.
- Apple registration does not require a password or extra username step. Offer adding
  these later. Do not require Apple users to disclose an additional email just to use Apple.
- Password users require a verified recovery email; username-only registration without
  recovery is not proposed. Username lookup must never reveal the associated email.

Supabase supports email/password authentication directly, while username login needs
an additional server-side adapter. Prefer native SDK email sign-in. For username login,
prototype a tightly scoped endpoint that privately resolves the username and delegates
password verification to Supabase Auth, returning the normal session. Do not return the
resolved email to unauthenticated clients, store passwords, implement password hashing,
or issue custom authentication tokens. Verify Swift SDK session adoption/refresh against
the pinned package before selecting this approach. This prototype is a phase exit gate.

The endpoint handles credentials and therefore must suppress request-body logging,
use TLS, enforce IP and identifier rate limits, support the configured abuse challenge,
and give equivalent failure messages for absent usernames and wrong passwords.
Privileged lookup credentials remain server-side with narrowly scoped access. Public
availability checks expose at most username availability, never account/email metadata.
No username is reserved before verification. Verified accounts claim names transactionally;
a collision returns to username choice without losing the verified account. Claiming the
same name is idempotent across verification retries.

Use Supabase password policy and recovery primitives. Support password-manager autofill,
paste, show/hide password, email confirmation resend, “Forgot password?”, expired-link
retry and cold-launch recovery. Use a configured production mail sender and allowlisted
app/web redirects; never place session tokens in analytics or logs. Recovery submits email
with a generic acknowledgement. Validate replay, cancellation, link scanners and wrong-device
handling. Specify refresh-session revocation after password reset and test it.

### Linking sign-in methods

Adding a method requires a signed-in account, recent authentication as appropriate,
and verification of the new credential. Assert that the resulting UUID remains the
original owner. An existing Apple user can add a verified recovery email/password and
username; a password user can connect Apple. Apple private relay and a different personal
email must not create an accidental second Farm. Test the deployed provider's automatic
email-linking behavior rather than assuming all links are manual.

If a method already belongs to another UUID, stop with account-recovery guidance; do
not merge Farms or repoint identities. Avoid offering unlink until the account has another
verified usable method. Never remove its last recovery/sign-in method. Existing duplicate
accounts need a separately designed ownership-verified recovery process, not automatic merge.

Primary references checked for this draft:
[password authentication](https://supabase.com/docs/guides/auth/passwords),
[identity linking](https://supabase.com/docs/guides/auth/auth-identity-linking), and
[identity types](https://supabase.com/docs/guides/auth/identities).
Provider documentation is architectural guidance; native linking and reset behavior must
be proven using this app's pinned Swift SDK and hosted configuration.

## 5. Ownership, local storage and automatic synchronization

Introduce explicit persisted guest/account owner scopes and an app account coordinator
injected at the root. Keep the run state machine in FocusSessionCoordinator. Separate
authenticated identity, active Farm owner, sync state and a pending account transition.
The service must accept verified supported non-anonymous accounts, not just Apple accounts.
Update both client policy and server checks that currently equate membership eligibility
with Apple linking; preserve the independent party-sharing agreement.

Account-scoped local documents, recovery generations, pending mutations and presentation
caches belong to the immutable UUID. A durable activation record publishes a validated
owner/document pair atomically, surviving interruption before/after any transition.
Migrate the existing single store without invoking getters that seed defaults. Keep
unknown/corrupt state recoverable; no account lookup or storage error becomes a new Farm.

Save each Farm mutation locally with its deterministic result and pending operation
identity, then coalesce uploads. Sync on sign-in/activation, eligible local commits,
foreground and connectivity recovery with bounded retry/backoff. iOS background execution
is best effort; do not promise continuous real-time sync while terminated. Serialize
owner-scoped work and ignore callbacks from an earlier account/transition epoch.

Keep conditional revision/generation writes and idempotent receipts. Refresh the remote
head before initial publication and detect another device's changes on activation. Adopt a
newer remote head automatically after preserving any divergent phone branch in recovery,
once active settlement permits replacement (founder clarification, 25 September 2026).
The account Farm is the default; routine sign-in/retry must not require a Farm choice.
Same-base offline edits still upload normally. Never add wool/inventory together or
overwrite a newer server head with an unselected local branch.

The cloud payload remains the existing Farm allowlist, including necessary reward timing
and claim ledgers. Detailed Nights, Health, questionnaire data, app selections, NFC and
active timers remain device-local. This work must not accidentally upload them under
“sync.” Inventory and accounting state must stay transactionally consistent.

## 6. Sign-out, active runs and data removal

For sign-out, fence account work, durably move the active account into inaccessible
UUID-scoped recovery, remove credentials and clear active presentation, then publish
the signed-out screen. The current implementation retains the recovery cache even when
clean; it is consumed only by matching verified account activation. Server Farm data is retained. Clear account identity from
widgets, Watch snapshots and social UI; don't leave a previous account's avatar visible.

If unsynced data cannot upload, offer “Keep changes for next sign-in” or cancellation.
Choosing it signs out immediately after a durable owner-scoped recovery commit. Recovery
is inaccessible to guest mode and other accounts and resumes only after matching verified
sign-in. Disclose that this device-only recovery cannot survive device loss. Protect it
with iOS file protection; it is not an active playable cache. Purge it after successful
reconciliation, or after explicit account/local-data deletion. A later disk-cache deletion
must not silently erase pending progress.

Do not switch Farm ownership during an active Wind Down/Phone Away or unresolved terminal
settlement. Prompt to finish/end through the existing run flow, preserving the emergency
exit. Anchor delayed run/morning settlements and social grants to the owner at their origin.
They must never settle into a newly signed-in account or fresh guest Farm. Include automatic
scheduled starts and morning continuation in this policy, not only an onscreen timer.

Audit every separate local value read by Farm, profile, welcome/practice, reward, social,
widget and Watch presentation. Device settings/permissions can remain, but private history
must not appear attributed to a different account; use owner-scoped local visibility where
necessary without expanding cloud scope. Specify guest-to-account history attribution
explicitly in the field inventory. Account deletion clears that owner's local recoveries
and credentials as well as online data, and fences stale devices from recreating it.

## 7. Migration and disclosure

| Existing state | Migration |
|---|---|
| Unbound local Farm | Preserve as guest. No automatic upload. |
| Linked and backup enabled | Preserve UUID, lineage, revisions and claims; migrate to automatic account sync. |
| Linked but backup never consented/paused | One transition screen explains that account use now includes private Farm sync. Accepting resolves local/remote state and starts sync; defer preserves existing data without silently uploading. |
| Previously signed out with bound Farm | Move to inaccessible owner recovery; require that owner's sign-in before activation. |
| Existing remote Farm plus guest Farm | Load the signed-in account’s Farm and retain the separate guest scope for guest continuation. Never relabel guest progress as an existing account. |
| Divergent cached account and remote Farm | Preserve the phone branch in recovery and load the verified account Farm by default; resume automatic sync without combining progress. |
| Pending action, corrupt save, unknown schema | Finish/reconcile supported pending commands or show recovery/update-required; do not seed or discard. |

The earlier user agreement does not authorize silently enabling formerly declined uploads.
For new registrations the concise account disclosure includes automatic Farm saving, with
details available before continuing; there is no separate backup toggle. Update ADR-0021/22,
AGENTS, architecture, onboarding plan, privacy copy, retention docs and release notes.
Authentication success remains distinct from successfully loading/saving the Farm.

Add a versioned account-sync capability and explicit migration marker. Preserve old-client
RPC semantics until upgraded; exercise old pause/delete commands against new clients.
Generation fences must prevent an old queued upload from resurrecting a deleted Farm.
Do not silently reinterpret an old client's backup-disable consent as auto-sync acceptance.
If mixed-client semantics cannot be safe, require an update for affected account writes.

## 8. Implementation phases and acceptance gates

| Phase | Work | Exit evidence |
|---|---|---|
| 1. Contract and prototype | Owner/session/transition state tables; full field/cache inventory; username adapter, native credential linking and recovery prototypes; mixed-version policy | Password-only and Apple accounts resolve to the correct UUID; no email disclosure or duplicate Farm; signed-off migration fixtures and transition rules. |
| 2. Backend identity | Private normalized username registry, transactional claims, password/verification/reset configuration, linking controls, abuse protection, provider-neutral account checks | Concurrent name claims, expired reservations, recovery, owner isolation and throttling pass integration tests; production SMTP/redirect setup documented. |
| 3. Local ownership | Account coordinator, partitioned save stores, activation journal, owner-scoped settlement/caches, crash-safe migration | Fault injection across every transition preserves progress and prevents cross-account display or rewards. |
| 4. Sync lifecycle | Automatic upload/download, revision conflicts, dirty-state truth, offline recovery, logout, deletion and old-client fences | Two-device edits, lost response, concurrent writes, logout races and account deletion converge without duplication or silent replacement. |
| 5. Product UI | Shared Apple/password forms, guest association, migration disclosure, concise Account page, sign-in methods, conflict/recovery flows | Full flow fixtures in light/dark, Dynamic Type and VoiceOver; visible controls and no manual normal-path backup steps. |
| 6. Rollout | Reconcile docs/privacy, deploy additive capability to test cohort, staged client activation, production configuration and recovery runbook | Physical upgrade/reinstall/two-account evidence, backend tests and repo build/tests recorded separately from deployment/distribution. |

Use existing service/domain test harnesses and Screenbook where suitable. If meaningful
integration coverage requires target/project changes, follow the repository's approval
rule at that point. This draft does not request or perform deployment or app distribution.

Required regression matrix: Apple-only/password-only/linked methods; guest/new/existing
accounts; verified/unverified email; duplicate username/email; private-relay email; wrong
password and reset; account A → logout → B → A; offline logout; token expiration versus
explicit switching; relaunch at every activation stage; overlapping offline progress;
active run/morning/deferred/social settlement; welcome/practice replay; unknown save schema;
deleted account and stale device; password change on another device; local cache leakage;
social feature disabled; migration from each row above. Assert stable IDs, wool, inventory,
meters and applied-grant sets, not only screenshots.

Run required XcodeGen/build/unit tests after code changes and SQL/endpoint integration
tests for backend changes. Physical QA must cover native Apple auth, password autofill,
mail verification/reset cold launches, two devices, offline work and dark-mode controls.
Rollback must preserve owner partitions and pending saves; never downgrade them into a
single shared playable Farm. Disable new migration via capability if necessary while
retaining recovery access for already migrated users.

## 9. Definition of done and selected defaults

A player can create an account, sign in by Apple or username/email/password, use the same
Farm across supported devices, earn/spend offline, and sign out without leaving that Farm
playable or leaking it into another account. Normal use needs no backup setup or restore
button. Unsynced work and conflicts remain recoverable without duplicated rewards. Settings
is concise and legible in both themes. Only server-confirmed state is called saved.

Selected implementation defaults: retain guest mode; require a
verified email for password accounts; use the username format above; preserve offline
sign-out work only in inaccessible owner recovery; defer ownership transitions during
active/deferred ritual settlement. Username rename policy and exact abuse limits are
phase-1 specifications, not reasons to omit username login from the delivered feature.

## 10. Implementation evidence — 7 September 2026

Local source now includes:

- Schema-3 Farm documents with explicit guest/account/signed-out scopes, account-owned
  recovery archives, and a durable scope fence that prevents older generation recovery
  from reopening a signed-out account. Activation and all recovery data remain device-local.
- Automatic account-sync acceptance and revision-aware loading/uploading through additive
  RPCs, with existing generation fences and explicit divergent-Farm choices retained.
  The old Apple-only optional-backup RPC retains its original semantics.
- Shared native Apple and username/email/password account entrance in onboarding, Settings
  and Slumber Party. Verified email codes, password recovery and method-management screens
  use the pinned Supabase SDK. Username lookup and password verification stay server-side.
- Compact themed Account controls, direct sign-out, collapsed sync details, and a root
  signed-out gate that removes the prior navigation shell. Explicit sign-out keeps only
  inaccessible UUID-scoped recovery, including unsynced changes; guest continuation cannot
  access it. Account deletion removes that owner’s recovery and obsolete disk generations.
- Owner-scoped local profile, appearance, Nights/history, reflections, private check-in and
  impact records. Device permission/setup settings remain local. The Farm cloud allowlist
  is unchanged; the whole local document is never uploaded.

Validation so far: the Xcode suite passed 872 tests; the standalone persistence/sync
harness passed 60 tests, including corrupt-generation logout recovery. Backend endpoint
checks passed six tests, and local SQL checks covered both legacy Farm and new account
identity contracts. A local HTTP exercise completed email signup, code verification,
username claim/login, recovery and password change against one unchanged UUID.
These are local results, not hosted production or physical-device evidence.

Release work remains: production SMTP and code-template setup, edge rate-limit secret and
trusted-proxy verification, selected CAPTCHA/client challenge integration if enabled,
physical Apple/password linking and secure email-change flows, autofill/VoiceOver,
and two-device upgrade/offline/reinstall acceptance. See `docs/ACCOUNT_AUTH_DEPLOYMENT.md`.
No production deployment or app distribution was performed by this implementation task.

Final local checks: XcodeGen regeneration and the iOS simulator Xcode suite passed
(872 tests, zero failures). A separate parent rerun of the persistence/sync harness
passed 60 tests, and the endpoint suite passed six tests. Parent reruns of both SQL
scripts also passed. Enabled button foreground/background contrast computed from the
actual theme tokens is 8.08:1 or higher in both light and dark modes. Physical-device
and assistive-technology acceptance remains part of rollout.

Review corrections also add persistent credential-field labels, automatic connection-recovery
retry with bounded backoff, and committed-owner fencing for social transport, mutations and
Farm grants. Native Apple account callbacks publish only after Farm activation succeeds.
Local manual identity linking is enabled; hosted activation remains a release gate.

Impact-data deletion now clears the active owner’s scoped upload ledger and consent together,
with a scope/lineage check around remote completion. Regression coverage confirms that
another account’s ledger survives and stale deletion completions are rejected.

The Profile header shortcut is shared by all four tab roots where the normal header is visible; active Home rituals retain their existing compact journey chrome. The shortcut uses a quiet person icon, with the Shepherd artwork reserved for the Profile identity section. Sync acceptance shows Connecting while busy, surfaces failure and session-wait messages inside the consent card, and disappears after successful connection.
