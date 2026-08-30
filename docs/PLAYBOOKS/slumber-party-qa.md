# Slumber Party v4 hosted and physical-device QA

## Shared nightly plans and receipts (v2 capability)

- Verify a v1 server keeps Tonight together, routine borrowing, and receipt UI unavailable while existing shared-habits summaries still load.
- After agreement v2, confirm each account sees only seven local-night instances with five-minute timing precision and bundled IDs, never recurrence/custom text/app data.
- Edit a future plan, then confirm a started/historical plan and linked receipt never change; include timezone, DST, offline replay, leave/rejoin, and deletion-tombstone checks.
- Complete and end early on separate accounts. A receipt must state facts/unknown evidence, never call a suggestion completed, make an app-use claim, rank a member, or mark an unknown night missed.
- Borrow a bundled idea into an empty, duplicate, and full local routine. The source plan must stay unchanged and the local result must explain duplicate/full handling.

## Membership-sharing extension — required before rollout

The founder approved immediate sharing from joining on 2026-08-27. The local implementation/validation record is `docs/plans/slumber-party-membership-sharing.md`; do not treat the older round-only checklist as the complete current acceptance contract. No hosted deployment or physical two-account result is implied by this checklist.

- Join a group without a round. Start/finish a normal Phone Away; the other member sees its status and durable moment. Round grants stay zero.
- Repeat between rounds and across two parties with different round states. Only the eligible round earns its existing independent grant, once.
- Confirm pre-join general history is absent, while explicitly supported current-round backfill remains visible as round history. Leave/rejoin must not revive the old membership epoch.
- Show a terminal/partial record with received live cheers; expire its status and run cleanup after 31 minutes. Cheers remain. Verify 90-day cleanup without removing earned grants.
- Mix old/new app clients: old round history and cheers remain reachable; the same factual record appears once; old and new reactions by the same member count once. Current legacy status fallback and its expiry remain coherent.
- Delay a cheer until the recipient starts a different session. Preserve the historical cheer but do not show it as feedback for the new run.
- Inspect no-round and between-round Home/detail, received cheers, history beyond eight rows, smallest supported phone, and accessibility text. Test actual taps/scrolls as well as screenshots.
- Verify the join disclosure, block/deletion, reconnect and stale response ordering. Deploy matching Edge request support before the database advertises the new capability. Old servers must retain truthful round-only UI/requests.

Slumber Party v4 is an accepted contract with source implemented and locally validated. On
2026-08-25 the founder approved deployment of all five Slumber Party migrations, both authenticated
Edge Functions, and versioned invitation secrets to the Release/TestFlight production project.
The remote schema was verified current and unauthenticated function requests correctly returned
HTTP 401. This does not establish app distribution, Apple-link recovery, physical-device behavior,
moderation readiness, retention scheduling, or privacy publication. The tracked ordinary
Debug default remains disabled. The ignored `Config/Supabase.local.xcconfig` Debug override stays
`NO`; `SlumberPartyQA` is the repeatable local forced-`YES` lane with diagnostics. TestFlight and
Release compiling with `SUPABASE_NIGHT_FLOCK_ENABLED=YES` is not evidence of physical QA,
moderation readiness, or privacy publication. This playbook must not be marked passed until the
physical matrix below is complete.

## Mixed-version rollout order

Never release a v4 client ahead of its explicit v4-fence backend. Apply all historical migrations,
then the existing invite-recovery migration, then the v4 migration that adds the strict version
fence, service-only recoverable invite ciphertext, transactional five-party cap, activity ledger,
per-party fan-out, canonical profile rules, status revisions/expiry, cheer ledger, tombstones, and
retention. Before deploying matching state and command functions, provision the hosted Edge
secret `NIGHT_FLOCK_INVITE_KEY_V1` with exactly 32 cryptographically random bytes encoded as
base64; `NIGHT_FLOCK_INVITE_KEY_VERSION` defaults to `1`. Missing or invalid key material is a
hard rollout blocker because even the first invitation cannot be created.

To rotate later, first provision the next `NIGHT_FLOCK_INVITE_KEY_Vn`, then select that version
through `NIGHT_FLOCK_INVITE_KEY_VERSION`. Keep every earlier version until all invitations
encrypted with it have expired, been revoked, or been replaced; otherwise existing members lose
the ability to retrieve their active code. Never commit, print, screenshot, or include either key
material or decrypted invitation data in support evidence.

Where a dedicated hosted test lane is available, run legacy v1–v3 clients and the v4 client
concurrently. Prove that a legacy client receives only its own safe legacy projection or
`unsupported_schema`, never an arbitrary v4 party. The founder approved production backend
deployment first so an updated TestFlight build can now be distributed for the two-account
physical matrix below. Broader tester rollout remains a separate human-approved gate.

## Local preparation and repeatable checks

Use `PhoneInTheOtherRoomSlumberPartyQA` with the `SlumberPartyQA` configuration. It loads tracked
development defaults, then an ignored `Config/Supabase.local.xcconfig`, and finally forces the
Slumber Party flag to `YES`. Do not add credentials to tracked files. Run the v4 tests plus:

```sh
xcodegen generate
sh scripts/validate-slumber-party-qa.sh
xcodebuild test \
  -project PhoneInTheOtherRoom.xcodeproj \
  -scheme PhoneInTheOtherRoomSlumberPartyQA \
  -destination 'platform=iOS Simulator,name=Counting Sheep App Store iPhone 14 Plus'
xcodebuild build \
  -project PhoneInTheOtherRoom.xcodeproj \
  -scheme PhoneInTheOtherRoomSlumberPartyQA \
  -configuration SlumberPartyQA \
  -destination 'generic/platform=iOS Simulator'
npx --yes deno check supabase/functions/night-flock-command/index.ts supabase/functions/night-flock-state/index.ts
npx --yes deno test --allow-env supabase/functions/_shared/night-flock_test.ts
```

Capture validation output, diagnostics on each phone, build/test summaries, function-check output,
and redacted request/error evidence. Never include URLs, keys, Apple identity tokens, account IDs,
invite plaintext/ciphertext, invite digests, idempotency keys, app selections, Health data, or
exact schedules in evidence or logs.

## Roadshow polish P0 checks

The following checks validate the presentation and publication rules added for the roadshow slice.
They do not change the V4 wire contract or replace the physical matrix below.

1. With no parties, confirm the landing shows the relationship-first proposition, truthful empty
   explanation, and **Start a party** / **Join with a code**; only the selected form is visible.
2. With existing parties, confirm party cards precede acquisition and account controls, and that
   **Start or join another** reveals only one form at a time.
3. Confirm one-member, pending host/member, active Night 1/Night 7, elapsed, and multiple-party
   states use lifecycle copy rather than round numbers or completion totals.
4. Confirm missing, expired, wrong-party, and wrong-round status data never becomes inactivity;
   `.phoneAwayActive` reads **Phone is away**.
5. Confirm each member shows the latest current-round durable activity when available, otherwise
   **No shared update yet**, and that shared moments count activity records including partial ones.
6. Confirm Home and Farm bridges use list data only, suppress during active Wind Down, route a
   single party directly, and fall back to the hub for zero, multiple, or stale parties.
7. Start a five-minute practice and verify no V4 starting/active/terminal status, activity,
   backfill, or Farm grant is published. A normal Phone Away may publish **Phone is away**.
8. Apply a settled V4 wool grant and confirm the transient banner and Recent Events show the exact
   newly applied wool amount; no upcoming reward is shown.

For the physical proof, use this ordered two-account checklist and record actual device results:

1. Account A creates the party and shares the invitation; account B previews and joins. Joining
   alone must not start the seven-night window.
2. A starts seven nights; both devices show the same Night 1 of 7 context.
3. Either account starts the five-minute practice; prove the other device sees no V4 status or
   record and no Farm grant arrives.
4. B starts and validates a normal daytime Phone Away; A sees **Phone is away**, sends one fixed
   live cheer, and B receives or later reconciles the silent feedback without an in-app interruption.
5. Complete a real Phone Away; both devices show one durable activity with rounded minutes and
   the completed-record cheer path.
6. Reconcile an offline completion and relaunch; verify one durable record and one wool per
   eligible active party, with no duplicate on relaunch.
7. Advance a controlled fixture past the seventh local date; verify elapsed copy and no claim that
   everyone completed.
8. While Wind Down is active, verify neither device exposes a Slumber Party card, route, badge,
   panel, reaction, or in-app social UI.

## 60–90 second roadshow rehearsal

Prepare two Apple-linked TestFlight accounts in one active party, distinct curated Farm looks, one
pre-existing real Phone Away activity with its settled one-wool local receipt, and a currently
validated normal Phone Away on B. Rehearse this exact path:

1. **0–12s — Home A:** explain that each person’s Wind Down is still local; tap the single-party
   bridge into the party.
2. **12–30s — Party:** point to Night N of 7, both names, and their curated Farm looks; say there
   are no parent controls or scores.
3. **30–48s — Live B:** point to **Phone is away**, explain B’s phone is separate, send **Paw print**.
4. **48–65s — Shared moment:** show the pre-existing Phone Away card, rounded minutes, night number,
   completed-record cheer, and no feed/chat/leaderboard/sleep claim.
5. **65–82s — Farm A:** return to Farm, show the private curated-look explanation and exact one-wool
   recent event.
6. **82–90s — Close:** “Our phones get some time away together, while everyone keeps control of
   their own phone, Wind Down, and Farm.”

If realtime is delayed, say: “Live status is best effort; the durable completed record is what the
party keeps,” and continue with the pre-existing activity. If silent cheer delivery is delayed,
show the sender’s selected cheer and explain that the receiver reconciles it later. Do not narrate
absence as inactivity or make the demo depend on realtime to prove completion.

## Required v4 two-account matrix

Install the QA scheme on two physical iPhones signed in to different Apple accounts. Keep a dated
row for each check with device, build, redacted account label A/B, expected result, actual result,
and screenshot/log reference. Add a third device/account where it is needed to prove capacity,
late joining, or host deletion.

| Check | Required observation |
| --- | --- |
| Feature and identity | Ordinary Debug remains disabled; QA diagnostics are visible only in the QA configuration. Apple linking preserves the same Supabase UUID. A controlled 401 reconnects only the bound account; wrong/new/cancelled identity fails closed without revealing a snapshot. |
| Create, name, and profile | Create a named 2–8 person party. Initial/migration canonical display-name selection is free; the third successful change in 14 rolling days is rejected. Farm and every party show the same canonical name. The curated snapshot accepts only allowlisted/revisioned Shepherd look, Ollie ornament, featured sheep definition, and pasture theme; no inventory, wool, or full Farm is sent. |
| Five-party cap | Create/join five concurrent parties, then race create and redeem for a sixth. Exactly five memberships persist; no oversubscription, partial membership, or duplicate grant is visible. |
| Invitation encryption deployment | The active version selects a configured, base64-encoded 32-byte hosted secret. Creating, retrieving, and redeeming an invitation succeed; after a controlled non-production rotation, older active invitations remain recoverable while their prior version is retained. No key material appears in tracked files, application responses, logs, screenshots, or evidence. |
| Invite control | Every current member can retrieve and share the active invite. Only the host can create, replace, or revoke it. It stays redeemable during an active round. Lost response/relaunch reconciles without mutation; explicit host replacement is compare-and-swap and stale replacement revokes nothing. Ciphertext, digest, and idempotency material are absent from RLS, Realtime, logs, and evidence. |
| Round lifecycle | Host starts only at two or more members. Starting another seven-night round preserves the name and current members. No goal picker, goal acceptance, readiness ceremony, pasture identity, orientation wall, per-party alias, or sharing matrix appears in v4 UI. |
| Late join and backfill | Join during an active round and submit all factual current-round Wind Down and Phone Away history. Repeating upload/relaunch is idempotent, produces no duplicate record/reward, and makes the record visible to all current members. |
| Fan-out and rewards | Complete one eligible local Wind Down and Phone Away while belonging to multiple eligible parties. The local ritual settles with network disabled, then reconciliation creates at most one record/reward per eligible party and no global once-only suppression. Inviting, joining, cheering, or changing settings produces no reward. |
| Statuses and cheers | Realtime status carries `revision`, `observed_at`, and `expires_at`; later runs can restart revision numbering and stale status never replaces a newer run. Sanitized party revision signals refresh membership, invitations, rounded records, and curated profiles. Send a fixed silent cheer while the first Wind Down is active, before any completed record exists. Simulate unavailable Realtime and silent system delivery: durable state and the cheer ledger reconcile accumulated completion cheers without loss or duplication. |
| Active Wind Down boundary | During active Wind Down, show no Slumber Party UI, card, badge, panel, in-app reaction, or social navigation. Best-effort silent Live Activity/Watch feedback is system-surface only. Local timer, rewards, Farm, shielding, and emergency exit remain authoritative when backend delivery fails. |
| Leave, host deletion, and retention | An ordinary member can leave. A v4 host cannot leave and must delete: deletion tombstones/revokes/deactivates for everyone while earned inbox grants survive; ownership transfer is future work. Verify minimum moderation audit and retention behavior once the approved policy is deployed. |
| Safety and account deletion | Report another member using each fixed safety category; block a member and confirm separation across all shared parties and prevention of future shared joins. Delete an Apple-linked account with active v4 membership, hosted groups, profile, source history, grants, and pending outbox work; deletion completes without an Auth foreign-key failure or exposing another account's records. |
| Legacy fence | Exercise v1, v2, and v3 clients against v4 state/functions. Legacy contracts remain explicitly labeled compatibility only; unknown/ambiguous schema fails safely and never resolves another party. |

The production migration/function/secret deployment is complete. Do not mark the remaining v4
release gates complete until all applicable rows pass on physical devices, retention and
moderation operations are approved, privacy materials are published, and the founder approves
broader tester rollout.
