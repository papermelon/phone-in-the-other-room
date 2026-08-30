# Slumber Party sharing from membership

Date: 2026-08-27. Founder approved: **Yes** to sharing immediately upon joining, with seven-night rounds organizing progress/rewards rather than gating sharing. Parent orchestrates implementation and acceptance in the current task; no Luna dispatch.

## Scope and preservation

Candidate is the saved checkout on `codex/night-flock-mvp`, HEAD `cce766d1840a850a23d5c47e4a542203c26a728b`, plus all accumulated corrections. Baseline snapshot and hashes: `/tmp/counting-sheep-membership-sharing-20260827/`. Preserve all inherited work. No push, commit, deployment, signing, target/tab changes or user-data reset. Remote rollout remains separately authorized.

This approval changes when already-approved factual activity, statuses and cheers are shared. It does not add private purposes/routines, exact schedules, selected apps, Health data, full Farm inventory, chat, discovery, remote enforcement or new rewards.

## Settled contract

- A member can share live/terminal Wind Down and Phone Away activity before a round, during a round and between rounds. Practice remains excluded. Local sessions and Farm settlement never wait for transport.
- Add a separate membership stream; preserve existing v4 round activity/grant storage and its current-round late-join backfill. That backfill is a legacy round-only exception, not permission to backfill general pre-membership history.
- Membership-stream eligibility uses a fresh server-generated epoch on rejoin and server-checked observation/end time at or after joining. Accept at most 90-day replay and five-minute future clock skew. Leaving/rejoining cannot revive old-epoch records/status/cheers. Current-member/block/party-deletion checks apply to source, reader and reactor. No replay of a terminal source may revive its live status.
- Existing round grants remain independently idempotent. An outside-round activity earns no Slumber Party wool; an expired/non-overlapping round must never be selected by a later retry. New stream rows never mint a grant.
- Membership history has a rolling 90-day retention boundary and a bounded latest-100 projection, labelled recent shared moments. Live status retains current expiry rules. Keep minimal tombstone/idempotency authority long enough to prevent stale callbacks/retries within the accepted source window. Add a real service-only purge path; never purge the existing source ledger as it can cascade earned grants.

## Additive wire interface (schemaVersion remains 4)

Old v4 round JSON stays valid and unchanged. Do not insert null round/day into existing `activities`/`liveStatuses` arrays. New fields are additive:

- `summary.sharingScope`: `membership` when backend supports this contract; absent/unknown means legacy round behavior.
- `detail.sharedActivities`: new activity model with activityID, partyID, memberID, optional roundID/day, kind, status, roundedMinutes, occurredAt. An optional `roundActivityID` references the already-public round record for the exact same factual source. Keep the membership moment primary and suppress only that matched round-history duplicate; never infer identity from timestamps or rounded minutes. Never invent Night 0 or a dummy round.
- `detail.sharedLiveStatuses`: new status model with opaque server statusID, partyID, memberID, optional roundID, status, revision, observedAt, expiresAt. Do not expose a local sourceEventID to other members.
- `detail.sharedCheers`: same activityID/cheer/count/sentByMe shape as existing historical cheer summaries.
- `detail.sharedLiveCheers`: statusID + memberID + cheer/count/sentByMe, scoped to that exact status rather than all historical rounds. Activities and live-cheer summaries may echo an optional `mySourceEventID` only to the source owner. This is an already-uploaded own identifier; friends never receive it. Passive feedback must match the current local run before presentation, so a delayed cheer cannot appear during an unrelated session.
- `publishActivity` and `publishStatus` may include `sharingScope: membership` only after the server advertises it. Live terminal publication retains legacy round fan-out plus the membership stream; `.backfill` commands remain round-only. Old commands retain old behavior.
- `cheerMember` may carry `statusID` only for a membership-stream target. Server validates current exact status/epoch/expiry; no race may silently cheer a replacement. Without statusID keep legacy behavior.
- `react` may carry `sharingScope: membership` for a shared activityID; absent means legacy round activity. Exact request validation rejects unknown fields/scopes; old Edge fallback never receives new fields before capability is known.

## App presentation

Use capability-aware projections in Home, list, detail, onboarding/help and action copy. With membership support, say sharing is available and keep people/recent moments visible even when no round exists. Seven-night host controls are a secondary progress/reward section, not an unlock wall. Preserve compact Home/Ollie and stable start navigation. Keep a truthful legacy fallback while server migration is not deployed.

Member summaries use the latest eligible stream activity/status; current-round recap and rewards use only round data. Avoid duplicate display of the same in-round activity in two sections. Status expiry and terminal supersession remain responsive without polling. Cheer pending/sent/failure state keys include the exact status identity. Recent activity cannot become an implicit sleep score.

## Ownership

- Backend worker: additive migration, affected Edge validators/functions and backend tests; no Swift or canonical docs.
- App worker: Shared membership-stream models/API/presentation/tests, social VM and views, relevant Screenbook fixtures; no SQL/Edge/targets or protection/reward implementation. Narrow integration exception: the existing passive-cheer coordinator guard may reject feedback for another source run; preserve legacy nil-source compatibility.
- Parent: requirements, canonical docs, independent diff/build/test/UI verification and acceptance. Fresh advisor: read-only architecture/final review.

## Acceptance

Cover pending/no-round/active/completed-round sharing, two parties in different round states, join/backfill/leave/rejoin, delayed/replayed and out-of-order source/status, partial end, expired cheer target, blocking/deletion, retention and unauthorized readers. Outside-round grants must stay zero; eligible round grant exactly once independent of stream retries. Decode legacy responses and new nullable association, verify fallback requests omit new fields, and render no-round + between-round screens with real production views and labelled fixture transport.

Rerun XcodeGen, generic/QA builds and full tests, Deno validators/tests, actual local SQL migration/RPC tests if local runtime is available, and relevant Screenbook tests. Do not claim remote deployment, physical protection or real two-account proof from fixtures. Final review must inspect the actual accumulated delta from the preserved baseline.

## Local test environment and earlier failures — 2026-08-28

The parent has independently applied the real additive migration to PostgreSQL 17.11 and run all three repository SQL suites successfully. That first pass was not acceptance: source review subsequently found a retention bug and missing history/cheer presentation, and the app build found a missing import. A suspected terminal/status race was cleared: the public keyed command wrapper already serializes publications by user. Those findings were corrected and the final reruns below completed. Earlier failures remain in the evidence directory rather than being overwritten.

The local SQL environment uses a temporary, Unix-socket-only PostgreSQL cluster with minimal Supabase platform bootstrap (auth users/roles/claim helpers and publication). All application migrations and RPC functions are the repository implementations, not substitutes. PostgreSQL was installed as a local test tool through Homebrew; no project dependency or persistent database service was added. This validates SQL execution and assertions, not hosted Edge authentication, PostgREST, realtime delivery, Apple sign-in or real two-account behavior.

## Rollout and rollback gates

This task performs no hosted migration, Edge deployment, signed archive, push or TestFlight upload. Separate authorization is required for those operations.

1. After local acceptance, deploy the matching permissive-additive Edge validators before the additive database migration advertises `sharingScope: membership`. The old validator must never reject new fields after capability is advertised. Deploy command and state entries together; their shared module is bundled into each.
2. Apply the new migration once, verify service-only RPC/helper privileges and retention operations, then test real two-account no-round sharing, terminal clearing, expiry, cheers, leave/rejoin, block, reconnect and round grants.
3. Publish the revised sharing/privacy explanation and operate the retention purge. Status display expiry must not prematurely delete durable cheer receipts.
4. Distribute the app only after the physical protection/session/recovery gates in the recovery review also pass. Local fixtures do not establish those platform behaviors.
5. If rolling back the app, retain the additive schema and matching validators: older clients ignore additive response fields and continue round-only commands. Do not drop stream tables or remove earned grant data as an app rollback. A server rollback must stop advertising membership capability before removing request support, while still accepting queued membership commands during the transition; do not point a capable cached client at a strict old Edge validator.


## Acceptance findings and disposition

A fresh, behaviorally read-only Sol advisor reviewed only this change against the preserved membership-sharing baseline. Its first verdict was **fix-first**. Parent inspection and actual builds supplemented that review; test success alone did not override source findings.

| Priority | Finding | Required correction |
|---|---|---|
| P1 | New UUID usage failed the actual build | Import Foundation and rerun both complete build/test configurations. |
| P1 | Thirty-minute live-status cleanup cascaded durable cheers | Retain backing rows for 90 days; separately exclude expired statuses from display/actions. Test purge at 31 minutes and 91 days. |
| P2 | Capability enabled a new branch that hid old round/backfill records | Preserve access to distinct round history without duplicating membership moments. |
| P2 | Own membership activity omitted received cheers | Display received counts, including live cheers carried to terminal and partial records. |
| P2 | Only eight of the advertised latest 100 records were reachable | Offer a disclosure for additional returned history. |
| P2 | New cheer controls lost accessibility-size adaptation | Reuse vertical controls at accessibility text sizes and inspect the rendered result. |
| P2 | Uncorrelated legacy passive feedback could bypass source matching on a capable server | Preserve historical data display but avoid delivering unscoped legacy feedback during an unrelated active run. |
| P2 | Hiding a matched old round row could also hide cheers from older app clients | Aggregate old/new/live reactions for the same factual source, with exact reactor deduplication and membership/block fences. |
| P2 | A legacy live fallback showed a title without its state object or expiry | Keep the fallback state, action eligibility and display clock coherent; suppress it when newer stream facts supersede it. |

The initially suspected terminal/status race was **cleared**, not counted as a reproduced bug: the existing keyed public command wrapper serializes a user's HTTP commands. The added narrow epoch lock is defensive consistency, with deterministic party ordering; the keyed terminal replay test does not claim a concurrent HTTP reproduction.


### Verification limits recorded during execution

The first rendered no-round Home → Open group interaction succeeded on the r5 app: people and live status remained visible without a round, own early-ended activity carried two received cheers, and the additional-history disclosure was present in accessibility output. The Mac then locked before its disclosure/scroll checks. The parent asked for manual unlock and continued automated validation; no unlock bypass was attempted. These intermediate captures are not asserted as final-binary interaction acceptance. Full small-screen, accessibility, mixed-client and real two-account verification remain distinct checks.


## Final acceptance — 2026-08-28

**Verdict: SHIP the reviewed local source; HOLD distribution. Risk L (shared protocol and coordinator integration).** A fresh read-only Sol advisor reviewed the membership delta and re-reviewed its corrections and final evidence. No confirmed source blocker remains. Parent concurs with that bounded verdict; it is not TestFlight/production or complete visual-interaction acceptance.

The final manifest `candidate-parent-r4-hashes.json` contains **878 paths**, SHA-256 `0d96bee1d52e5b2ebcdf8c111c8eb4fb1ad126657d3e96246eba1554170b6ec5`. There are **34 changed paths** against the preserved start baseline. All 878 hashes remained unchanged through final validation. Only documentation closeout changes follow that freeze; all inherited application work is preserved.

Evidence is under `/tmp/counting-sheep-membership-sharing-20260827/`:

| Independent parent check | Final result | Evidence |
|---|---|---|
| XcodeGen and generic iOS Simulator build, including embedded targets | Exit 0 / BUILD SUCCEEDED | `xcodegen-r4.log`, `build-r4.log` |
| Main scheme full suite, iPhone 17e | **698 tests, 0 failures** | `test-r4.log`, `tests-r4.xcresult` |
| Slumber Party QA configuration and build | Exit 0 / BUILD SUCCEEDED | `qa-configuration-r4.log`, `qa-build-r4.log` |
| QA scheme full suite | **698 tests, 0 failures** (same suite in QA configuration) | `qa-test-r4.log`, `qa-tests-r4.xcresult` |
| Actual app/coordinator/service recovery probes | **15 cases, all pass** | `recovery-probe-final.json` |
| Deno type check / Edge validator tests | Exit 0; **20 passed, 0 failed** | `deno-check-r4.log`, `deno-test-r4.log` |
| Screenbook Python suite | **7 passed** | `screenbook-python-r4.log` |
| Fresh PostgreSQL 17 clone: actual migration plus legacy, v4 and membership SQL suites | All exit 0 | `sql-runtime/parent-r5-results.json`, corresponding logs and `parent-r5-tested-hashes.json` |
| Whitespace and frozen-source verification | Exit 0; no changed manifest paths | `git diff --check`, `source-freeze-check.json` |

`validation-r4-results.json` retains every exact app/QA command and exit code. The installed iPhone 17e substitutes for the unavailable iPhone 15. Earlier failed builds/assertions and the deliberately interrupted r3 QA run remain recorded; they are not counted as passes. The temporary socket-only PostgreSQL server was stopped after validation. No Homebrew service was started, no project dependency was added and Docker was not restarted/reset.

The final Debug binary produced `final-ui/final-no-round-home.png`, `final-between-rounds-home.png` and `final-between-rounds-accessibility-home.png`. Parent inspected these actual rendered Home fixtures: the social surface remains available outside rounds, the personal times are separated, and Ollie is proportionate. Accessibility text wraps in the visible viewport, but the larger page needs scrolling; lower controls and detail accessibility remain unverified. The simulator content-size setting was restored to its original `large` value.

The earlier r5 **actual** Home → Open group tap and detail PNG/AX are retained separately. They show no waiting wall, a current Phone Away status, own partial-record received cheers, and the history disclosure. They do not prove final-binary disclosure/scroll interaction. The Mac locked and the parent requested manual unlock; no subsequent tap, small-device/detail interaction, or real two-account result is claimed. Fixtures use production views but synthetic social transport and explicit test readiness. Recovery probes use real production intents with isolated persistence/dependencies, not physical Screen Time/NFC enforcement.

### Remaining release gates

1. The unlocked-Mac follow-up below closes bounded group/history/menu and Phone Away navigation checks, including accessibility and iPhone SE cases. Ordinary swipe/wheel scrolling remains unverified pending manual confirmation; broader accessibility/state coverage and physical Phone Away/protection/Purpose/overnight gates remain open.
2. Separately authorize hosted migration/Edge rollout; verify real two-account no-round/between-round and mixed-client behavior, Apple recovery, reconnect, block/leave/rejoin and independent grants. Local PostgreSQL tests are not hosted authentication or realtime proof.
3. Reconcile and publish the public privacy policy, and operate retention/moderation. The repository policy still describes an older contract and is explicitly marked publication-blocked; the technical data map is updated.
4. Produce and verify the signed archive/TestFlight build only after these gates. This task did not change the installed phone build.

No commit, push, deployment, target/tab/signing change or user-data reset occurred. Work was orchestrated in this task; no further implementation was sent to Luna.

## Unlocked-Mac interaction addendum — 2026-08-28

The founder unlocked the Mac and the parent resumed actual interactions with the final Debug
binary. Source revalidation found no application-source drift from `candidate-parent-r4-hashes.json`;
only the four previously recorded documentation closeout paths differ. The checks did not rebuild
or edit application code. Evidence below is relative to `/tmp/counting-sheep-ui-checks-20260828/`.

| Check | Observed result | Evidence |
|---|---|---|
| Home → Plan → manual Start now → confirmation → Start now | Active appears without Back, switching tabs or leaving the app | `manual-confirmation-ax.txt`, `manual-start-active.png`, `manual-start-active-settled-ax.txt` |
| Home → Plan → eligible saved After dinner → Start Phone Away | Active appears immediately, preserving the saved 8:30 PM end | `saved-plan-ax.txt`, `saved-confirmation-ax.txt`, `saved-start-active.png`, `saved-start-active-settled-ax.txt` |
| Between-round Home → Open group | People/current Phone Away remain available; own early-ended moment displays two received Warm waves | `between-detail-top-ax.txt`, `between-current-ax.txt` |
| All recent shared moments (10) disclosure | Ninth and tenth records become accessible | `between-more-expanded-ax.txt` |
| Round history disclosure | Distinct older Clover record remains available: Phone Away, 15 quiet minutes, Night 6, ended early | `between-round-history-expanded-ax.txt`, `between-bottom-reachable.png` |
| Historical cheer control | A coordinate tap changes the button to Try again, exposing fixture transport failure | `between-coordinate-cheer.png`, `between-coordinate-cheer-ax.txt`; this is not successful remote delivery |
| No-round group at accessibility-extra-large text | Home → group, live-cheer menu and additional-history disclosure operate; menu text fits and historical cheer controls stack vertically | `no-round-accessibility-home.png`, `no-round-accessibility-detail.png`, `no-round-accessibility-live-cheers.png`, `no-round-accessibility-history-expanded.png` and matching AX files |
| iPhone SE, default text | Home → group and additional-history disclosure operate; visible labels wrap without clipping | `no-round-small-home.png`, `no-round-small-detail.png`, `no-round-small-history-expanded.png` and matching AX files |

The larger simulator was `329535CB-D901-434D-BE9D-7BA64A3BE900` (iPhone 17 / iOS 26.5),
and the smaller was `60935BFC-7044-4BE8-9712-7D1B6C568A16` (iPhone SE / iOS 26.5).
The larger simulator's text setting was restored to its original `large` value. The SE already
existed and was booted for this check. All fixtures use an isolated defaults suite, production
views/navigation/start intents, synthetic social transport and test protection readiness. No
hosted group or real user session was created or changed. The fixture's `None selected` while
ready is not evidence that production admits an empty Screen Time selection. Purpose publication
and persistence retain their existing 15-case runtime-probe evidence; these UI checks do not
replace real-device Purpose, Screen Time or NFC verification.

### Open scrolling check — do not count as passed

Repeated direct Sky swipe/drag and wheel attempts did not visibly move the page, on both simulator
sizes. Accessibility activation of offscreen controls automatically scrolls them into view and
proved reachability, but does not prove ordinary touch scrolling. The parent corrected its earlier
commentary claim and asked the founder to try scrolling the open simulator. No manual result has
been received. Ordinary ScrollViews are present in source and no relevant disabling modifier was
found; that inspection is insufficient to distinguish an automation limitation from a real gesture
defect. Preserve this as an interaction verification gap. Do not deploy on the strength of these
fixtures or mark complete accessibility/gesture acceptance.

**Verdict remains SHIP reviewed local source / HOLD distribution**, pending the above interaction
gap and the physical-device, two-account, hosted rollout, policy and operations gates. The earlier
locked-Mac paragraphs are execution history, superseded only for the checks explicitly passed here.
