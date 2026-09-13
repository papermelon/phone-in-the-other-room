# Final-build release acceptance — Counting Sheep

Prepared 5 September 2026 after the Farm backup release review. This is the execution
checklist for the final release candidate, not a claim that the tests have passed.
Use alongside [TestFlight readiness](testflight-readiness.md), which owns the detailed
NFC, shielding, Health, feedback and Slumber Party matrices. ADR-0020 supersedes old
completion-only Farm expectations in historical checklists. Updated 7 September 2026:
[ADR-0023](../DECISIONS/ADR-0023-account-owned-farm-sync.md) and the
[account-owned Farm acceptance matrix](../plans/account-owned-farm-sync.md#8-implementation-phases-and-acceptance-gates)
replace optional backup enrollment, Apple-only accounts and a playable Farm after sign-out.
Follow [the root validation policy](../../AGENTS.md#validation); this is a release-candidate
checklist, not mandatory work for every repository edit.

## Acceptance record and test setup

Record the exact source revision (or frozen source manifest), app version/build,
archive hash, configuration flags, device model/OS, Apple account test alias, backend
project/migration versions, tester, date and evidence location. Never record tokens,
raw Health samples, selected-app tokens or NFC credentials in the report.

Use at least two disposable accounts and two installations for cross-account and
conflict tests. Cover Apple-only, password-only and linked sign-in methods. Preserve an existing installation for the upgrade leg. Reinstall,
reset and account deletion legs must use disposable data; never erase the founder's
Farm. Retain a reference inventory before each destructive test: sheep instance IDs,
names/rarities, catalogue, wool, capacity, owned/equipped cosmetics, pasture layout,
search meters/outcomes, regrowth, welcome/practice grants and social grant IDs.

Test the oldest supported iOS release and the current supported release on physical
hardware, including a small supported screen, a paired Watch and an unpaired phone.
If a device/OS combination is unavailable, record that gap explicitly. Run critical
save/restore and overnight tests on the actual distributed TestFlight candidate.
A new binary or backend change after acceptance requires affected tests again.

## 1. Automated regression and packaging

- [ ] Generated project matches its inputs (regenerate when needed); no hand-edited project file, accidental dependency,
  test fixture, mock account or QA feature in the release build.
- [ ] Debug and Release Simulator builds and full app unit suite pass. Run
  `python3 scripts/validate-farm-save.py`: actual persistence and backup view-model
  tests run in the host harness; Apple/Supabase are test doubles in that harness.
- [ ] Restore fault injection: archive/commit failure preserves the original Farm;
  post-commit appearance acknowledgement failure still publishes the restored Farm;
  subsequent spending and reopening use the restored balance; pending appearance
  cleanup can retry. No false success for a failed Farm commit.
- [ ] Account deletion gate tests: initialization before journal restoration,
  deletion preflight, pending/ambiguous deletion and accepted tombstone all block
  Farm traffic. Pause during account/session acquisition or request preflight
  invalidates old work. A failed durable pause prevents starting account deletion.
- [ ] First save and existing-head selection both work; pending operation IDs survive
  timeouts; old-generation requests cannot recreate deleted backups.
- [ ] `git diff --check`, plist/entitlement lint, approved migration validation and
  relevant Deno checks/tests pass. No credentials or personal fixtures in the diff.
- [ ] Signed Release **archive**, not only build, succeeds; inspect all embedded
  extensions and Watch app, provisioning, bundle IDs and production feature flags.
  Build number exceeds the last uploaded build. Validate the distribution artifact.

## 2. Existing-player upgrade and local durability

- [ ] Upgrade an existing supported version in place. Reference sheep, wool,
  purchases, equipped items, pasture and progression match after migration/relaunch.
- [ ] Repeat with a starter-only Farm, a large established Farm and legacy data.
  Welcome/practice gifts and settled social grants are not issued a second time.
- [ ] Terminate/relaunch around earning, shearing, trading, purchasing, equipping,
  search resolution and settlement. Each action is committed once or not at all;
  no partial currency/inventory combination and no rerolled search outcome.
- [ ] Exercise low-storage/write failure using the fault harness; corrupt latest
  save, recover previous generation; unsupported newer schema stays preserved.
  UI distinguishes recovery from a fully current save; originals remain available.
- [ ] Reset local data while automatic sync is active or a request is in flight. No empty
  Farm overwrites the account copy. An old request cannot bind the new local Farm.
- [ ] Farm restores do not invent Nights, sleep data, permissions, NFC registrations,
  an active timer or a completed routine. Replayed local receipts cannot duplicate
  restored Farm rewards. Document supported upgrades and the downgrade policy.

## 3. Account identity, ownership and disclosure

- [ ] Execute the current account plan's required regression matrix and rollout gates,
  including username privacy/rate limits, verification/reset redirects and credential linking.
  Native Apple nonce verification and password-manager autofill work on the signed build.
- [ ] Guest onboarding remains usable. Returning sign-in loads and validates only that
  account's Farm, skips completed questionnaire/gift stages, and preserves device setup.
  Authentication or lookup failure never seeds/relabels an account Farm.
- [ ] Apple-only/password-only/linked methods resolve to stable UUIDs. Credential linking
  creates no duplicate Farm and preserves independent social-sharing consent.
- [ ] Account A → sign-out → B → A never leaks Farm, profile, queues, widgets, Watch
  state or delayed rewards. Explicit sign-out removes the Farm from active play;
  offline pending work remains inaccessible owner-scoped recovery, not a guest Farm.
- [ ] Automatic sync is explained during account use. Prior declined upload consent gets
  explanation and acceptance; test every supported migration row and older-client fence.
- [ ] Account Farm use works with Slumber Party disabled and with no party membership.
  Account use does not authorize new party fields or grant iOS permissions.

## 4. Automatic sync, offline work and recovery

- [ ] Use an accepted account with automatic sync. Wait for server confirmation;
  inspect that only the approved private payload was stored for the signed-in owner.
  Last-confirmed status must not imply offline changes are already recoverable.
- [ ] Earn sheep/wool, shear/trade, buy/equip cosmetics and change pasture offline.
  Reconnect and verify the confirmed revision contains the exact final state.
- [ ] Interrupt a request before send, after server commit but before response, and
  during local receipt persistence. Retry the same operation without duplicates.
- [ ] Make more local changes during a slow upload. The older acknowledgement must
  not mark newer changes as backed up; a subsequent upload preserves those changes.
- [ ] Reinstall on a disposable installation, sign in to the same account and load its Farm.
  Compare the reference inventory and then earn, shear and purchase again. Verify
  regrowth, search guarantees, bad-luck protection and grant replay protection continue.
- [ ] Ownership changes and recovery are deferred during active or unresolved ritual
  settlement, including scheduled starts and morning continuation. Delayed rewards stay
  with their origin owner; the active run is never silently replaced.
- [ ] Ordinary account use has no manual enable/pause/check/restore controls. A clean
  account adopts a validated newer head; divergence preserves both branches for explicit
  choice. Recovery keeps the local archive and never adds balances together. Cancel
  recovery/conflict confirmation without changing the Farm; verify safe sync resumption.
- [ ] Test malformed/unsupported payloads, unavailable backend, expired auth and the
  2 MiB limit on disposable fixtures. Original local data remains readable; retry or
  update messaging is actionable, and no false backed-up status appears.

## 5. Multiple devices, deletion and backend isolation

- [ ] Two devices start at the same revision and diverge offline. Concurrent uploads
  keep both branches; no silent last-writer win. Choose each branch in separate runs.
- [ ] Another device changes the head during branch selection/deletion. Reject the
  stale choice, preserve both copies and request a fresh decision.
- [ ] Sign out offline after choosing owner-scoped recovery; cancel once as well.
  Only the matching verified account can reconcile pending work. Server Farm remains.
  No standalone delete-online-copy action silently recreates a Farm through automatic sync.
- [ ] Delete the entire account from each supported entry point, including Slumber Party.
  Fence account work before the request; accepted deletion clears that owner's local
  recovery/credentials and online data. Disclosures accurately describe affected data.
  Stale requests/devices cannot recreate the deleted account Farm.
- [ ] Interrupt account deletion before/after server acceptance; relaunch while
  offline and online. Pending or accepted deletion permits no Farm upload, lookup,
  restore, retry or re-enrollment. Confirm cleanup/recovery without account recreation.
- [ ] Account A cannot read/write/select/delete account B's revisions. Anonymous and
  unauthenticated calls are rejected; authenticated clients have no direct table access.
- [ ] On an isolated database matching the release migration set, run all relevant
  SQL suites, including Farm and social/account integration. Record expected legacy
  incompatibilities separately; do not call a mixed-schema run a full regression pass.
- [ ] Verify retention job success: current head, unresolved branches and at least
  ten resolved copies retained; resolved copies beyond policy pruned. Test account
  cascade and operation-receipt cleanup. Verify provider backup coverage and perform
  a recovery drill in an isolated project; revision history alone is not disaster recovery.

## 6. Ritual, economy and device integrations

- [ ] Full physical overnight Wind Down, terminated app and morning handoff: correct
  phase, reminders, Live Activity, shield apply/clear and factual receipt on reopening.
- [ ] Cumulative Farm credit: Wind Down opens a search at 420 eligible minutes;
  Phone Away uses its independent 100-minute meter without a three-night gate.
  Early endings preserve eligible credit; both sources grow wool. Brief Access is
  excluded; morning credit remains separate. Backfilled and replayed history is idempotent.
- [ ] Brief Access while foregrounded/backgrounded/terminated: actual app-limit
  removal and reapplication agree with observed evidence; permission/runtime failure
  fails open and routes to repair. Authorization is never presented as observed protection.
- [ ] Midnight, DST, timezone change, delayed callback, reboot, late start, schedule
  revision and update during a run preserve timer/accounting boundaries.
- [ ] Complete the detailed NFC matrix: primary/backup, wrong/retired/lost/replaced
  tags, resync, cancellation, unavailable NFC and emergency exit, including offline.
- [ ] Watch paired/unpaired/unreachable, background/reconnect: mirrors the phone;
  cannot authorize or end NFC protection. Lock Screen/Dynamic Island states agree.
- [ ] Optional Health reads/no-data/denial show truthful coverage and durations;
  no medical claims or raw samples in Farm backup. Notifications respect saved choices.
- [ ] Run the release-enabled Slumber Party matrix with two real accounts: invite,
  linking, sharing agreements, old-server capability fallback, receipts, grants,
  leave/deletion and retained-history access. Keep unvalidated optional transports
  disabled. If feedback/impact/push are enabled, complete their separate playbook gates.

## 7. VoiceOver, layout and usability

VoiceOver is Apple's built-in screen reader, not an abbreviation. On the iPhone,
open Settings → Accessibility → VoiceOver. A swipe moves between accessible items;
a double tap activates the focused item. Test with a person familiar with it where
possible; automated accessibility inspection alone does not establish usability.

- [ ] With VoiceOver, complete onboarding, sign-in/cancel, enable/pause backup,
  identify local vs confirmed online state, restore/cancel, conflict selection,
  sign-out and both account-deletion routes. Controls have clear labels, state and
  reading order; destructive confirmations state consequences without relying on color.
- [ ] Configure/start Wind Down and Phone Away, understand phase/time/protection,
  use Brief Access and emergency exit, read completion and Farm balances. Decorative
  artwork does not overwhelm navigation; meaningful status changes are discoverable.
- [ ] Largest accessibility text sizes on a small screen: all text and confirmations
  readable, controls reachable by scrolling, no clipped balances or trapped navigation.
- [ ] Reduce Motion, light/dark presentation and quiet nighttime use: no essential
  information exists only in animation, color or audio. Review contrast/touch targets.
- [ ] Check cancellation/back navigation, loading/offline/retry states and repeated taps;
  no duplicate requests, dead ends or confirmation that selects the wrong revision.

## 8. Disclosure, operations and acceptance decision

- [ ] Publish the reviewed policy at the live app privacy URL; verify the deployed
  page and in-app link. Reconcile App Store privacy answers, purpose strings,
  manifests and review notes with actual release-enabled data flows. Do not publish
  unrelated future-policy sections accidentally.
- [ ] Assign an owner for backup/retention failures, deletion/support requests and
  recovery incidents. Confirm alerts/logs omit payloads and credentials. Rehearse
  disabling uploads without dropping Farm data; preserve a supported recovery path.
- [ ] Run a small TestFlight cohort through upgrade → offline earning/spending →
  confirmed backup → disposable reinstall → restore, plus at least one real overnight.
  Record failures and retest fixes on the final candidate.
- [ ] Accept only when all release-enabled gates pass with evidence, no unresolved
  data-loss/ownership/deletion defects remain, and the human release owner signs off.
  Pending physical testing, policy publication or distribution validation is not a pass.
