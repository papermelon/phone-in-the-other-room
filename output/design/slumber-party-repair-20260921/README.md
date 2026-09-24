# Slumber Party repair — local evidence, 21 September 2026

[Implementation and product direction](../../../docs/plans/slumber-party-repair-2026-09-21.md)

## App validation

- `xcodegen generate` completed after adding source and test files. Generated project membership was not edited by hand.
- `xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/slumber-repair-derived` — **BUILD SUCCEEDED**. Log: `/tmp/slumber-repair-build-final.log`.
- Final source was rebuilt and tested with `xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,name=iPhone 17e' -derivedDataPath /tmp/slumber-repair-derived -resultBundlePath /tmp/slumber-repair-tests-final.xcresult` — **1,109 passed, zero failures, zero skipped**. Log: `/tmp/slumber-repair-tests-final.log`.
- New unit checks cover duplicate acquisition taps, stable command keys after uncertain responses, accepted-party acknowledgement, independent invitation intents, exact search validation and older-server decoding.
- `git diff --check` passed. Unrelated pre-existing work was preserved; no commit, push, archive or upload was performed.

## Backend validation

The new migration was applied transactionally to a disposable PostgreSQL 17 copy of the existing local synthetic schema. The copy contained zero auth users before testing. Its data directory was `/tmp/slumber-invites-pg`, socket `/tmp/slumber-invites-socket`, port `55460`, role `campfire_test`, database `campfire_bedtime_test`. It was stopped after testing. No hosted database or founder account was modified.

`psql -h /tmp/slumber-invites-socket -p 55460 -U campfire_test -d campfire_bedtime_test -v ON_ERROR_STOP=1 -f supabase/tests/slumber_party_invitations_test.sql` passed and rolled back every fixture. Checks include authenticated caller identity, verified accounts, strict request fields, exact lookup, minimal responses, party membership, duplicate send/accept, wrong recipients, blocks, decline cooldown, revoke, expiry, party/member limits and rate limits. Accepting membership does not fabricate an agreement receipt. Log: `/tmp/slumber-invites-test.log`.

Existing v4, shared-habits and membership-sharing SQL suites also passed using temporary copies whose synthetic Apple identities were explicitly email-confirmed to satisfy the current verified-account predicate. The shared-habits unlinked-account case also cleared that confirmation when unlinking. Original repository tests were unchanged. Their unmodified legacy identity fixtures initially failed the current account check; those failures were not counted as passing runs. Logs: `/tmp/night_flock_v4_test-verified.log`, `/tmp/night_flock_shared_habits_test-verified.log`, `/tmp/night_flock_membership_sharing_test-verified.log`.

## Native visual evidence

The final test-built app was installed on the dedicated **Counting Sheep Slumber Repair QA** iPhone 17 simulator, iOS 26.5. The DEBUG `--slumber-repair-qa --repair-mode …` route uses production views with synthetic state and no social network service. These screenshots prove presentation, not live requests or agreement acceptance.

| State inspected | Evidence |
| --- | --- |
| Single collapsed agreement; visibly disabled create action | [Collapsed terms](terms-collapsed.png) |
| Expanded sharing, evidence, privacy and leaving text in one disclosure | [Expanded terms](terms-expanded.png) |
| Receipt-backed confirmation fixture and corrected Campfire icon padding | [Party](party-confirmed.png) |
| Primary Invite people entry; code fallback; light appearance | [Group details](group-light.png) |
| Invited result wrapping at Accessibility 3 | [Invited status](invited-large-text.png) |
| Expiry, cancellation and refresh reachable by scrolling at Accessibility 3 | [Large-text controls](invitation-controls-large-text.png) |
| Invitation error and refresh action in context | [Error](invitation-error.png) |
| Loading sheep with changing eyes/bob | [Still](syncing-sheep.png), [short recording](syncing-sheep.mp4) |

Accessibility inspection exposed the loading operation once with value **In progress**, hid its decorative frames, and exposed labeled navigation/actions and disabled states. Spoken VoiceOver and the system Reduce Motion setting were not physically tested; Reduce Motion and inactive-scene pausing were inspected in source. Earlier `search-empty.png` is an exploratory capture from before the final shared disabled-style adjustment and is not final-state evidence.

## Remaining release boundary

- Subsequent to these local checks, `20260921120000_slumber_party_invitations.sql` was **deployed with explicit founder authorization** on 21 September. [Hosted deployment evidence](../../../docs/evidence/slumber-invitation-deploy-20260921/deployment.md) confirms account-handle integration, invitation checks and `directInvitationsVersion = 1`. The updated native app still needs distribution.
- The screenshot's original server request ID was not diagnosed against hosted logs. Local error-handling repairs do not establish the cause or resolution of that past hosted incident.
- TestFlight distribution and two-account physical checks remain outstanding: create/join and confirmed receipt, invitation delivery/acceptance/decline/revoke, account switching, offline retry and accessible interaction.
- Acquisition command reuse is in-memory. The existing consent outbox is durable, but an interrupted app relaunch still requires canonical-list reconciliation before another create attempt.
