# Slumber Party loading investigation — 22 September 2026

Investigation followed by founder-authorized local implementation on 22 September 2026.
No production deployment, account mutation, archive or distribution was performed. Preserve
unrelated working-tree repairs; source presence does not prove inclusion in an installed build.

## The reported incident

The founder confirmed the screenshot was taken today on the latest TestFlight build.
The production invocation identifies that client as **build 57**, supabase-swift 2.51.0,
iOS 27.0.0. The screenshot's exact request was found in the invocation's nested function logs:

- Request: `4ad82a92-d03a-49e7-8023-70d9f3de919e`.
- Time: **22 September, 12:27:30 Singapore time**.
- Endpoint: `night-flock-state`, schema 4, HTTP **500**, `internal_error`.
- Gateway execution time: **352 ms**. Handler duration bucket: **50–199 ms**.
- [Production invocation](https://supabase.com/dashboard/project/sxjlkcccsentmhowgoqe/logs?date=1789973236558-1790059636558&filter=event_message:ilike:night-flock,log_type:eq:edge+function&id=90b4f4ff-ccb7-463c-b05a-e1b626c90e67).

This establishes a fast server-side failure, not a client decoding failure or a 12-second
network timeout for this request. In the deployed handler, schema 4 is recorded only after
authentication and body parsing. The remaining failure area is validation, the database/API
read, or response construction. The log omits read scope, stage and original exception, so it
does **not** establish the precise underlying fault. The screen indicates initial list loading,
but the server record cannot independently distinguish list/detail/habits.

The 24-hour dashboard window ending around 14:47 showed approximately **42.9k Slumber Party
Edge invocations**, including **37 HTTP 5xx records**. Repeated failures appear at 12:27:14,
12:27:26, 12:27:30, 12:28:00, 12:59:49, 13:00:04 and 13:29:18. These are separate observed
failures; they must not all be assigned the screenshot's request ID or an unproven common cause.

## What the checks ruled out, and their limits

- Production has the 21 September invitation migration and its new capability. Missing that
  migration is not the explanation.
- Both current party accounts returned their list and party-detail projections through direct
  SQL in **read-only transactions**. The screenshot account's named-argument list call also
  succeeded as `service_role`. No account identifiers or party content are retained here.
- One `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)` measured **11.506 ms total for both list
  projections**, with 0.398 ms planning. This is one database-only sample after the incident;
  it excludes device networking, Edge startup, authentication and PostgREST transport.
- A public-key-only REST probe returned expected HTTP 401 / SQLSTATE 42501 permission denial
  for anonymous access to `night_flock_v4_state`. This establishes route reachability, not
  successful authenticated Edge-to-database delivery.
- A standalone Foundation probe decoded the live grant timestamps with the service's existing
  `.iso8601` strategy. It was a timestamp compatibility check on this Mac, not a complete
  native response or supported-iOS-version test.
- PostgreSQL/PostgREST log inspection did not identify a matching underlying exception.
  An earlier PostgREST timeout event is not linked to this request and is not its diagnosis.

Production source was downloaded using the authenticated CLI into a temporary directory.
The existing signed-in dashboard supplied request logs. No stored credential was extracted.
Read-only SQL and downloaded source are separate evidence from a real authenticated HTTP
end-to-end reproduction, which remains outstanding.

## Confirmed loading and request amplification issues

1. **Duplicate remote authentication is deployed.** `authenticatedClient()` calls
   `auth.getUser()`, then `night-flock-state/index.ts` calls it again. The command endpoint
   has the same local pattern. Reuse the already verified user; preserve account validation.
   This removes one Auth round trip per affected request. Supabase documents that
   [`getUser()` always contacts Auth](https://supabase.com/docs/reference/javascript/auth-getclaims).
   Switching to locally verified claims is a separate security/identity decision, not required
   for this straightforward saving.
2. **The current native source loads the list twice on first appearance.**
   `NightFlockHubView.task` → `activateEntry` → `refreshState` loads it; once that succeeds,
   `SlumberPartyV4ListView.task` calls `refreshState` again. Both successful reads can launch
   detail, agreement and Realtime-related work. There is no common in-flight list request
   shared by all list callers.
3. **Upload work still delays startup and foreground refresh.** The newer `activateEntry`
   loads the list before flushing its outbox, but `bootstrap` and `handleForeground` still
   await `flushOutbox` first. The entry-in-flight gate can make a visible entry wait on
   bootstrap. `flushOutbox` has many callers and no overall in-flight drain guard; its actor
   storage does not make the whole read/send/remove sequence atomic across awaits.
4. **There is real high-volume command traffic to investigate.** A sampled 00:00:54
   invocation came from **build 55**, returned HTTP 200, and took **1,030 ms**. Its runtime
   logs include repeated `publishActivity` and `publishStatus` requests. This is distinct
   from build 57's incident. Aggregate database idempotency records had only a small number
   of newly keyed commands in the same broad window; this supports investigating replay and
   overlapping drains, but does not identify one specific queue defect by itself.
   [Sample invocation](https://supabase.com/dashboard/project/sxjlkcccsentmhowgoqe/logs?date=1789973236558-1790059636558&filter=event_message:ilike:night-flock,log_type:eq:edge+function&id=03f456a8-2264-434a-b01f-89a643ce0b29).
5. **Diagnostics discard the useful cause.** The Edge handler classifies an exception and
   logs only the generic code. All durations above one second collapse into `1000ms+`.
   The native fallback also uses the same message for unclassified local errors. This makes
   unrelated faults look identical and prevents evidence-based latency comparisons.

Relevant source: [shared auth](../../supabase/functions/_shared/supabase.ts),
[state endpoint](../../supabase/functions/night-flock-state/index.ts),
[handler logging](../../supabase/functions/_shared/night-flock-handlers.ts),
[entry/startup/queue](../../PhoneInTheOtherRoomApp/ViewModels/NightFlockViewModel.swift),
[list task](../../PhoneInTheOtherRoomApp/Views/NightFlock/SlumberPartyV4ListView.swift),
[detail refreshes](../../PhoneInTheOtherRoomApp/ViewModels/NightFlockViewModel+V4.swift).

## Recommended repair order

1. Add bounded, privacy-safe diagnostics: request ID, operation/scope, failing stage,
   upstream HTTP status, allowlisted SQLSTATE/PostgREST code, and numeric elapsed times.
   Keep raw errors, payloads, user tokens, exact activities and private profile data out of
   responses and logs. Reproduce the signed-in read and use the captured cause to fix the
   failing layer. Do not blindly retry a deterministic server defect.
2. Remove duplicate authentication and the child list's redundant initial fetch. Coalesce
   list reads per verified owner and recovery generation. Do not reuse responses across
   sign-out, account changes, membership/privacy changes or authentication recovery.
3. Serialize queue drains, retain stable idempotency keys, and bound retry/backoff. Load
   ordinary entry/foreground lists before background publication. Preserve the existing
   destructive-intent and consent fences; do not move publication ahead of their reconciliation.
4. Keep the last authorized party list visible while refreshing, with a small scoped error.
   Do not render stale Campfire presence as live. Prefer the current in-memory state first;
   a new persistent cache is unnecessary until cold-launch needs justify its privacy and
   invalidation complexity. Defer heavy archives/details until needed while preserving cheers.
5. Measure phone end-to-end list latency and request count before/after, plus Auth, RPC and
   decoding durations. Test healthy/cold/poor-network entry, concurrent foreground/entry,
   queued publication, 500/401/timeout, cancellation, account switch and privacy boundaries.
   The 12-second deadline already in the working tree bounds a stalled read; it does not
   repair this 352-ms server failure. No database scaling recommendation is justified by
   the current query timing.

## Replacement error copy

Use an operation-specific heading and truthful recovery. Keep support IDs collapsed and
copyable; they should not be necessary to understand the message.

| Situation | Heading | Detail / action |
|---|---|---|
| Initial list, server failure | We couldn’t load your parties | Please try again in a moment. You can still use Wind Down. **Try again** |
| Known offline connection | You’re offline | Connect to the internet to see your parties. You can still use Wind Down. **Try again** |
| Read timeout | Your parties are taking longer to load | Please try again in a moment. **Try again** |
| Existing list, refresh failure | Your parties couldn’t refresh | Showing the last update. Try again in a moment. **Refresh** |
| Confirmed accepted command, failed follow-up read | Your change was saved | We couldn’t refresh the party yet. **Refresh party** |
| Uncertain command response | We couldn’t confirm that change | Refresh the party to check. **Refresh party** |

Do not blame the connection for a known internal server error, promise that an uncertain
command was saved, or direct users to repeat party creation after a lost acknowledgement.
The existing “could not open yet” / “could not complete that request” pair repeats the
failure without explaining what is unavailable or what the person can do.

## Local implementation

- Edge callers now reuse the authenticated helper’s verified user, removing their second Auth
  round trip. Existing client-only callers retain the same authenticated-client API. The
  state and command handlers record allowlisted scope, failing phase, numeric total/phase
  timings and bounded upstream status/code; raw error messages, hints and payloads stay out.
- The child list no longer initiates a second load, and concurrent entry calls no longer queue
  a second activation unless their owner/recovery/privacy scope changed. All native v4 list paths share concurrent
  reads only within the same expected owner, local generation, transport epoch and privacy
  epoch. No completed response is cached by the coordinator. Commands invalidate older
  reads before/after their outcome so post-command refreshes cannot join pre-command work.
  Both stale successes and stale errors are discarded after invalidation.
- Ordinary bootstrap/foreground entry reads the list before publication; normal entry releases
  its activation guard before background draining. Destructive reconciliation still precedes
  publication. Queue drains serialize across awaits, coalesce trailing triggers, and apply
  5/10/20/40/80/160/300-second failure cooldowns. A later foreground/publication event retries
  durable work; there is no automatic repeating retry timer. Cooldowns are in memory and reset
  on relaunch or a new owner/recovery/privacy scope. Shared-night work has its own guarded lane.
- V4 acknowledgements and failed-attempt updates match the actual queued source revision and
  key, preserving a newer replacement queued during a send. Existing publication keys remain
  stable across retries; durable queue formats are unchanged.
- Loading errors distinguish server/offline/timeout, and a refresh failure retains the current
  authorized in-memory list with a scoped notice. Background delivery cannot replace a direct
  action’s result. Accepted actions say “Your change was saved”; uncertain actions ask for a
  refresh. Support references remain collapsed and copyable and use the failing request ID.
- Native request-completion logs include a per-service request number, elapsed duration and
  decode duration without payloads. Cancellation stays distinct from an offline error.
  Existing Campfire staleness and consent/owner fences remain in force.

The minimal implementation retains first-page agreement reads and party observations needed
for consent reconciliation and silent cheers. Archive pagination was already on demand; no
new disk cache, timer-based retries, database indexes or infrastructure upgrade were added.
Further fan-out reduction needs measured request traces so it does not suppress those features.

## Validation and remaining release work

- Backend: 34 Deno tests passed, including one-Auth verification/rejection, typed handler
  compatibility, safe diagnostics, scopes and phase timings. Deno type checking passed for
  both Slumber Party endpoints and all six affected/shared-auth caller endpoints.
- Native full generic iOS Simulator build passed. The final complete unit run rebuilt the
  app for the selected simulator and passed **1,120 tests, zero failures**, including read
  coalescing, owner/privacy/transport separation, stale success/error suppression, queue
  serialization/backoff, revision-safe durable acknowledgements, deadline and recovery-copy cases.
  `git diff --check` passed. Existing Watch QA unused-result and AppIntents metadata warnings
  were observed; no new source warning remained.
- [Local UI evidence](../../output/design/slumber-loading-20260922/README.md): normal small-screen
  server/offline/cached-refresh layouts inspected; support disclosure and accessibility labels
  checked. Accessibility 3 timeout strings were present in the accessibility tree, but the
  automation did not scroll reliably to inspect the lower card. Full large-text scrolling and
  spoken VoiceOver remain physical checks.
- Generic Simulator builds hit disk-space failures before validation could finish. Only
  generated Build/Index/ModuleCache folders from an inactive temporary Slumber Party QA cache
  and the Build folder of an inactive older Xcode cache were removed. Source, package checkouts,
  test evidence and release archives were retained. A Swift helper access-level error found
  during the first compile was corrected.

Reproducible validation commands (Deno used the existing cached executable):

```sh
deno test --allow-env supabase/functions/_shared/night-flock_test.ts supabase/functions/_shared/supabase_test.ts
deno check supabase/functions/night-flock-state/index.ts supabase/functions/night-flock-command/index.ts supabase/functions/campfire-global/index.ts supabase/functions/campfire-device/index.ts supabase/functions/submit-feedback/index.ts supabase/functions/live-activity-registration/index.ts supabase/functions/live-activity-cancellation/index.ts supabase/functions/focus-run-sync/index.ts
xcodegen generate
xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator'
xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=A0DB65B8-F3FC-4961-8B0C-9689F51C9EA1' -resultBundlePath /private/tmp/slumber-loading-tests-final.xcresult
```

Final local logs: `/private/tmp/slumber-app-build-final.log`,
`/private/tmp/slumber-loading-tests-final.log`, `/private/tmp/slumber-backend-tests.log`,
`/private/tmp/slumber-backend-check.log`. The unit result bundle is at the path above.
No commit, push, migration, production function deployment or distribution was performed.

Production still needs a separately authorized, scoped Edge deployment and a new TestFlight
build. Prepare that bundle independently of pending Campfire/profile features and migrations
already in the working tree; do not deploy the entire working tree as this repair. Repeat
physical checks of cold/poor-network entry, 500/401/timeout, concurrent foreground/entry,
queued publications, sign-out/account changes, privacy actions and VoiceOver. After deployment,
reproduce the affected signed-in read, inspect numeric Auth/read timings and the original
upstream code, and measure phone end-to-end latency/request count before/after. The original
352-ms HTTP 500 and the build-55 request burst remain unproven at the precise causal layer;
these changes do not establish that either production incident is resolved.


## Build 58 recurrence, Farm sign-in and Campfire (22 September, evening)

The founder tested build 58, then explicitly signed out and could not reconnect the
Farm through Apple. No reinstall or reset was reported. The 19:54 screenshot records
successful account authentication followed by failed Farm connection; the 20:30
screenshot and repeated unresponsive Apple taps require a separate physical check.
Do not interpret those screens as evidence that account progress was deleted.

### Confirmed production failures

- Request `7064e00e-c7c0-4b00-9015-d57ee88e104b` matches build 58 at **19:44:40 SGT**:
  `night-flock-state` HTTP 500, **313 ms**, handler bucket 50–199 ms. The invocation
  is `9f999e48-db69-4c02-b424-7ec32cb06415`.
- Detailed API Gateway logs reveal the previously hidden upstream failure:
  `night_flock_v4_state` requests at 19:44:37, :38, :40 and :45, plus 19:52:17,
  were rejected with **PostgREST `PGRST303`**.
- The Farm RPC `farm_account_sync_v1` returned HTTP 401 repeatedly. The 19:54:42
  request (`ca8d2b20-d2f2-4fa3-8003-20883e0f6c28`) has an authenticated gateway
  identity and `Proxy-Status: PostgREST; error=PGRST303`. Its token was issued at
  19:54:19 and expires at 20:54:19, so it was not expired or issued in the future
  relative to the gateway's request time. The body of this rejection is not yet
  available; do not assert which claim failed.
- Thus Farm connection and Slumber Party share a **database API token validation
  failure**. Direct SQL tests bypass that layer and cannot prove the signed-in HTTP
  path works. [PostgREST's error contract](https://postgrest.org/en/latest/references/errors.html)
  defines PGRST303 as JWT claim validation/parsing failure. A known cached-clock
  defect is a candidate, not yet a confirmed diagnosis; see the
  [upstream changelog](https://github.com/PostgREST/postgrest/blob/main/CHANGELOG.md).
- Read-only preservation check: the affected account remains a verified owner,
  has a server Farm head and **282 stored revisions**, latest **12 September 2026,
  14:21 SGT**. This establishes an older server save, not that recent progress
  synced. The production sign-out implementation archives the active account Farm
  in the local transaction document. Its actual presence on the phone remains
  unverified; keep the installation/data intact.
- Production still runs Slumber Party state/command version 7 (13 September),
  Campfire device version 2, and Global Campfire version 1 (20 September). The
  earlier Auth/diagnostic Edge edits were not deployed. Production RPC grants,
  verified-owner predicate and public-schema usage checks pass.
- Global Campfire has an independent **wire compatibility regression**: build 58
  always sends `channelID: 0`, rejected by the deployed validator; it also sends
  `consentVersion: 2` for withdrawal, which that server rejects. Current database
  state RPC has only the legacy three arguments. Profiles/channels are not deployed.
  Local reproduction against freshly downloaded production source confirms both
  old requests fail and their compatible forms pass.

### Follow-up source repair

- Omit the default channel from the discovery read, preserving explicit channel
  reads after discovery. Keep profile sharing gated by the server capability.
- New withdrawals use the version-1 contract supported by both server versions.
  After a successful legacy state read, repair previously rejected version-2
  withdrawals in the durable queue, preserving their retry IDs and retrying once.
  Acceptances are never downgraded; unknown/unavailable server state cannot repair
  the queue. Regression tests cover these boundaries and persisted round trips.
- Distinguish an unavailable party list from a confirmed empty membership list in
  visibility choices and offer a party reload. Campfire and Farm errors no longer
  blame connectivity without evidence. Apple requests show a waiting indicator.
  This indicator is not a claim that the reported native Apple presentation issue
  has been reproduced or resolved.
- Classify server-side PostgREST JWT errors as retryable service unavailability,
  keeping the verified caller signed in. This is source-only until deployed.

The diagnostic workspace is `/private/tmp/slumber-recurrence-20260922`. Before the
separately authorized restart recorded below, no production mutation, deployment,
restart, archive or upload had occurred in this follow-up.
An in-memory server-key read probe was blocked by automatic approval review because
specific credential-use authorization was required. The founder subsequently
approved this diagnostic; its results are recorded below. Production recovery
still requires separate authorization. The local changes alone do not restore
the production backend.

### Follow-up validation

- Full generic iOS Simulator app build: **passed**.
- Full app unit suite on `A0DB65B8-F3FC-4961-8B0C-9689F51C9EA1`:
  **1,122 tests, zero failures** (`app-tests.xcresult`).
- Isolated Farm host harness, `python3 scripts/validate-farm-save.py`:
  **82 tests, zero failures**, including failed connection retaining verified
  identity and the signed-out account archive.
- Deno `night-flock_test.ts` and `supabase_test.ts`: **35 passed**, including
  server-token rejection remaining retryable rather than signing out the caller.
- Freshly downloaded production Campfire validator: reproduced rejection of
  build-58 default-channel reads and version-2 withdrawals; their compatible
  request forms passed. This is local contract verification, not successful
  production HTTP execution.
- Whitespace/diff check: passed. Logs and the full app result bundle are in
  `/private/tmp/slumber-recurrence-20260922/`.
- Visual verification remains incomplete: the isolated small-iPhone Simulator
  installed the build but stalled launching the Campfire failure fixture. It was
  shut down afterward; no physical Apple sheet, VoiceOver, audience-change or
  account recovery pass is claimed. The earlier initial-loading screen evidence
  does not cover these follow-up presentation changes.

### Authorized token diagnostic: exact failure and recovery boundary

On 22 September the founder explicitly approved using existing production server
keys in memory for read-only diagnostics. The probe captured CLI output only in
process memory and made three `GET /rest/v1/` schema requests. It printed only
status, error code/message, time and the service version; no keys, Farm payloads
or account records were printed or saved. No RPC or production mutation ran.

| UTC time | Existing key type | Result |
|---|---|---|
| 13:37:16 | Secret API key | HTTP 401, `PGRST303`, **`JWT issued at future`** |
| 13:38:13 | Legacy service-role JWT | HTTP 200; **PostgREST 14.5** |
| 13:38:48 | Secret API key | HTTP 401, `PGRST303`, **`JWT issued at future`** |

This reproduces token-time rejection outside the phone. The successful older-token
control establishes that the database API is reachable; it is not evidence that
the current app's authenticated path works. Combined with the earlier fresh user
JWT issued at 19:54:19 SGT and rejected at 19:54:42, this strongly matches
Supabase's active [401/JWT rejection incident](https://status.supabase.com/incidents/6q5902p2xd9f).
Supabase identifies a stale time cache, records its rollback to PostgREST 14.5,
and its 17 September update says a deployment-process change and subsequent
customer project upgrade are needed for the lasting fix. We have not inspected
the validator's internal cached timestamp, so that exact internal mechanism is
inferred from the matching incident, not directly measured.

The same incident lists **Restart project** as a possible recovery step and says
to contact support if failures persist. A single restart followed by the same
fresh-token read probe was proposed as immediate mitigation, not a proven permanent
fix. The founder subsequently authorized it; the result is recorded below.

Read-only inspection of the upgrade dialog found current Postgres `17.6.1.147`,
offered stable `17.6.1.166` and preview `17.6.1.164`. It warns of up to one hour
offline and no downgrade. The dialog was cancelled. The offered build's inclusion
of the incident fix is unconfirmed; do not treat an arbitrary upgrade as verified
remediation or install the preview. Supabase's [upgrade guide](https://supabase.com/docs/guides/platform/upgrading)
requires post-upgrade application checks and describes data migration/downtime.

Next steps: verify Slumber Party and Farm connection on the affected installation,
and arrange the patched service upgrade with Supabase if rejection recurs.
Keep the independent Campfire wire
compatibility repair in scope. Do not rotate keys, weaken JWT checks, restore an
older Farm over newer local progress, or substitute a legacy key in the app.

### Authorized production restart and verification

The founder explicitly authorized restarting `counting-sheep-prod`. One **Restart
project** action was confirmed in the Supabase dashboard on 22 September around
22:02 SGT. The dashboard showed restarting, then **Healthy**. No upgrade, key
rotation, function deployment, migration or app distribution accompanied it.

| UTC time | Check | Result |
|---|---|---|
| 14:02:34 | Secret-key `GET /rest/v1/`, during restart | HTTP 522, expected temporary unavailability |
| 14:03:49 | Same secret-key schema probe, after restart | **HTTP 200**, PostgREST 14.5 |
| 14:05:20 | Secret-key `GET /rest/v1/rpc/night_flock_v4_state`, list scope | **HTTP 200**, valid list response, **387 ms** from this Mac |
| 14:05:55 | Repeat secret-key schema probe | **HTTP 200**, 634 ms; PostgREST 14.5 |

The previously reproducible `PGRST303` rejection cleared in these checks. This is
observed recovery, not proof of a permanent fix: the runtime remains 14.5 and no
patched service upgrade was applied. These timings are individual HTTP requests
from the Mac, not an iPhone loading benchmark or an end-to-end Edge measurement.

A repeat read-only SQL preservation check found the same verified account, Farm
head, **282 revisions**, and latest save timestamp **12 September, 14:21 SGT**.
No Farm restore or overwrite was performed. The founder was asked to close and
reopen the app, retry Apple/Farm connection and confirm their previous Farm; the
result of that retry is recorded below.

An additional **GET** probe of `global_campfire_state` returned HTTP 405 / SQLSTATE
25006 after passing token validation. Its rate-limit counter writes are prohibited
by GET's read-only transaction, as intended. The transaction rolled back; this
probe was not repeated using POST and is not a successful Campfire functional
test. The normal app uses POST. Build 58's separate unsupported `channelID: 0`
and version-2 withdrawal fields still require the compatibility source repair to
be distributed or a separately authorized scoped server repair.

### Post-restart Apple success / Farm decoding failure (22:06 SGT)

The next physical screenshots (`IMG_8131`–`IMG_8133`) show Apple's native sheet and
Face ID completing, followed by the app's Farm-connection failure. Production logs
for build 58 show `POST /rest/v1/rpc/farm_account_sync_v1` returning **HTTP 200** at
**14:06:26.294 UTC** and again at **14:07:52.732 UTC**. The secret-key schema probe
also remained HTTP 200 at 14:07:39 UTC (551 ms). The database rejection therefore
does not explain this new failure.

Each attempt has only one Farm RPC. `completeAccountConnection` first accepts sync
and then looks up the Farm; `acceptAccountSync` validates the head payload returned
by the first request even though it returns no value. A client decode failure there
prevents the second request and matches the displayed stage.

Read-only schema/field-type diagnostics established a separate concrete defect:

- The saved head has supported versions (Farm 3, search 4, payload/economy 1).
- Nested Farm dates are JSON **strings**, including sheep arrivals, transactions,
  consumed interval starts, search outcomes, and reward grants.
- The installed Supabase SDK's default RPC encoder converts nested `Date` values
  to ISO text. `FarmBackupService` previously assumed payload dates stayed numeric
  and used the default Swift decoder, which expects a `Double`.
- A synthetic schema-3 save using that wire encoding failed at
  `farm.sheep[0].arrivedAt`: **expected Double, found string**. This independently
  reproduces a deterministic failure on data shaped like the saved head.
- A metadata-only boolean check confirmed all saved date fields match the UTC
  wire forms covered by the compatibility repair. No Farm contents were exported.

Automatic approval review rejected preparing a query that would return the whole
private payload, even for in-memory validation, because that exceeded the approved
metadata diagnostics. That approach was abandoned. Field names/types and synthetic
data were sufficient to identify and reproduce the incompatibility.

The local repair teaches `FarmBackupPayload.decodeRemote` both numeric local dates
and the deployed ISO date representation. Only typed Date positions are normalized
before the existing lossless comparison. Missing/unknown fields, unsupported
versions, invalid calendar dates and trailing text still fail. This also avoids a
native floating-point edge case where parsing `.456` and formatting again produces
`.455`; the original strict textual round trip would reject that valid timestamp.
The response normalizer then places the validated, numerically encoded payload in
the envelope so the final lookup/receipt decoder can read it.

Outgoing RPC encoding is deliberately unchanged: changing it would change the body
of already queued operation IDs, potentially causing `farm_operation_reused` on a
retry. No account scope, restore selection, local archive, consent or overwrite
rules changed. All backup callers use the repaired common path.

The regression reproduces the previous failure with a synthetic schema-3 Farm,
fractional dates, consumed intervals and rewards. It checks preserved inventory,
wool, duration and fingerprint stability, and rejection of missing/unknown fields
and malformed timestamps. Earlier numeric-date and ownership/replay tests remain
applicable.

Final local validation of the repaired source:

- `python3 scripts/validate-farm-save.py`: **83 tests, zero failures**.
- `xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator'`: **passed**, including the real Supabase service and affected targets.
- `xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=A0DB65B8-F3FC-4961-8B0C-9689F51C9EA1'`: **1,123 tests, zero failures**. Counts overlap with domain tests in the host harness.
- `git diff --check`: **passed**. No project regeneration was needed.
- Logs and result bundle: `/private/tmp/slumber-recurrence-20260922/farm-wire-tests-final.log`, `farm-wire-build-final.log`, `farm-wire-app-tests-final.log`, and `farm-wire-final.xcresult`. The earlier `farm-wire-red.log` records the failing-before-repair synthetic case.

Self-review: the shared decoder and common response path cover accept, lookup,
revision read and write receipts; outgoing wire encoding and owner/consent fences
are unchanged. Risk **M** (shared remote save decoding). The native parser's
[implementation](https://github.com/swiftlang/swift-foundation/blob/main/Sources/FoundationEssentials/Formatting/Date%2BISO8601FormatStyle.swift)
also explains why a successful parse alone does not prove the complete input was
consumed; malformed suffix and calendar-overflow regression cases verify the
additional guards here. No UI strings changed in this final repair.

This repair is **source-only**. Build 58 on the phone still contains the broken
reader. Physical account/Farm recovery, newer local pending changes, Campfire
visibility controls and party loading need verification after an authorized new
TestFlight distribution. No second restart, upgrade, restore, deployment or
distribution was performed in response to these screenshots.
