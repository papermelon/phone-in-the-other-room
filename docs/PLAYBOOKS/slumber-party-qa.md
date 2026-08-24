# Slumber Party non-production QA

The tracked ordinary Debug default remains disabled. The ignored
`Config/Supabase.local.xcconfig` Debug override should also stay `NO`; the dedicated
SlumberPartyQA configuration is the repeatable local forced-`YES` lane with QA diagnostics.
TestFlight/Release archives compile with `SUPABASE_NIGHT_FLOCK_ENABLED=YES`. This playbook
exercises the local QA lane; it does not deploy hosted backends or upload TestFlight.

## Mixed-version rollout order

Never release the new client ahead of its recoverable-invite backend. Apply all historical
migrations first, then `20260824150000_night_flock_invite_recovery.sql`, then deploy the updated
state and command functions from that same revision. In hosted non-production, run a legacy v2
client and the new digest-based client against the same lobby and exercise create, conflict, and
replacement serialization. Next complete the physical two-account matrix below. A new
app/TestFlight build comes only after those checks; production remains a separate human-approved
gate.

## Local preparation and repeatable checks

Use `PhoneInTheOtherRoomSlumberPartyQA` with the `SlumberPartyQA` configuration. It loads the
tracked development defaults, then an ignored `Config/Supabase.local.xcconfig`, and finally forces
the Slumber Party flag to `YES`. Do not add credentials to tracked files.

```sh
xcodegen generate
sh scripts/validate-slumber-party-qa.sh
xcodebuild test \
  -project PhoneInTheOtherRoom.xcodeproj \
  -scheme PhoneInTheOtherRoomSlumberPartyQA \
  -destination 'platform=iOS Simulator,name=Counting Sheep App Store iPhone 14 Plus' \
  -only-testing:PhoneInTheOtherRoomTests/NightFlockDiagnosticsTests
xcodebuild build \
  -project PhoneInTheOtherRoom.xcodeproj \
  -scheme PhoneInTheOtherRoomSlumberPartyQA \
  -configuration SlumberPartyQA \
  -destination 'generic/platform=iOS Simulator'
npx --yes deno check supabase/functions/night-flock-command/index.ts supabase/functions/night-flock-state/index.ts
npx --yes deno test --allow-env supabase/functions/_shared/night-flock_test.ts
```

For local backend data, start and reset the local stack before the two-account pass:

```sh
npx supabase start
npx supabase db reset
npx --yes supabase db lint --local
docker exec -i supabase_db_counting-sheep psql -U postgres -d postgres \
  -v ON_ERROR_STOP=1 < supabase/tests/night_flock_test.sql
```

Capture the validation-script output, the diagnostics screen on each phone, Xcode build/test
summaries, function-check output, and redacted request/error evidence. Never include a URL, key,
invite plaintext after its intended one-time recipient, or Apple identity token in the evidence.

## Typed error and incident evidence

### Authentication recovery matrix (not yet passed)

Use controlled hosted 401 and `linked_account_required` injection for each v1/v2/v3 state,
direct-command, and outbox lane. For every case, retain a dated redacted row proving the correct
Apple account recovers only its bound UUID, a wrong/new account fails closed without exposing a
snapshot, cancellation/offline does not create an anonymous account, and snapshot/run-context/all
outbox preservation holds. Evidence fields may contain only build, device label, lane, HTTP status,
typed code, result, and a redacted screenshot/log reference.

| Date | Lane and injected result | Account case | Preservation / result | Redacted evidence |
| --- | --- | --- | --- | --- |
|  | v1/v2/v3 state/direct/outbox · 401 | correct / wrong-new / cancel-offline | pending human execution |  |
|  | v1/v2/v3 state/direct/outbox · linked_account_required | anonymous / linked / missing | pending human execution |  |

Authentication recovery is transport-quiescent: while reconnect, anonymous-account link, or
fail-closed presentation is pending, no foreground refresh, reconciliation, direct command, state
read, or v1/v2/v3 outbox lane may send another request. Capture this in the same redacted evidence
rows; a successful same-UUID Apple recovery is the only event that resumes the intentional
refresh/outbox pass. A fail-closed state remains network-silent.

Night-Flock function responses always include a canonical `X-Request-ID` header and the same
`requestID` in the JSON envelope. Error envelopes keep the stable `error` string for older
clients and add a typed `code`, `retryable`, and `recovery`. Capture only the request ID,
operation, HTTP status, and typed code in QA evidence; never copy raw function error data,
account identifiers, invite codes, idempotency keys, tokens, app selections, Health data, or
exact schedules. Unknown database details must appear to the client as a generic internal or
service-unavailable message.

When create-lobby or redeem-invite returns `active_membership_exists`, the app performs one
state reconciliation and does not replay the mutation or delete the existing lobby. A recovered
lobby shows: “You already have a Slumber Party. Ollie brought your lobby back.” If state cannot
be recovered, the Retry action refreshes/reconciles first; it never blindly repeats the mutation.
Verify the same behavior for a transient service/network failure. Only an explicit
`unsupported_schema` response permits v3 → v2 → v1 state fallback; authentication,
membership, network, and 5xx errors do not authorize schema fallback.

## Two physical iPhone / two Apple-account matrix

Install the `PhoneInTheOtherRoomSlumberPartyQA` scheme on two physical iPhones signed in to two
different Apple accounts. Keep a dated evidence row for each check, with the device, app build,
account label A/B, expected result, actual result, and screenshot/log reference.

| Check | Required observation |
| --- | --- |
| QA configuration | Settings → Slumber Party QA diagnostics says flag enabled. Ordinary Debug says disabled. Release/TestFlight has Slumber Party and contains no QA diagnostics destination. |
| Pre-link identity | Record each anonymous Supabase Auth UUID through approved redacted local/server tooling; after Sign in with Apple, each UUID is unchanged. |
| Create and reusable invite | A chooses one bounded goal, creates a pending lobby, creates a reusable legible code, previews it on B, and verifies it works until revoked, expired, started, or capacity reaches eight. |
| Lost response and relaunch | Interrupt A after server acceptance but before the response appears. Relaunch and refresh reveal the same code only after the same account and invite UUID are confirmed; no mutation is sent automatically. |
| Explicit replacement | Remove A's local credential while the invite remains active. Refresh shows no code. Confirm replacement once; the old code stops and the new code works. Repeating the same request leaves one active invite, while a stale expected UUID revokes nothing. |
| Lobby gate | Verify joining does not start the party. The host can start only after at least two members have accepted the same goal and completed required local setup. |
| Locked timezone and seven boundaries | Create with a known IANA timezone, change each phone timezone afterward, and prove days 1–7 follow the locked challenge timezone; day 8 cannot publish. |
| Shared-goal progress | Verify goal accepted, setup ready, phone tucked away, meaningful partial progress, shared goal completed, qualifying Wind Down completed, and no update shared. The legacy raw value remains decode-compatible; Screen-Free Morning is never shared. No update shared is never completion. |
| Instagram boundary | Each member uses FamilyActivityPicker locally and confirms Instagram is included. Verify no token, selected-app list, or server claim that Instagram was independently verified. Coarse shielding evidence may be not requested, unavailable, partial, or observed. |
| Offline outbox and retry | Disconnect B before each allowed check-in, complete local Wind Down, reconnect in foreground, and capture one idempotent eventual delivery. |
| Per-night private reset | Choose Keep tonight private, prove no check-in, then begin the next eligible preflight and prove sharing is offered again. |
| Global sharing off | Disable sharing, verify queued records are purged and no new state is sent; re-enable only through the approved user flow. |
| Completion and reactions | Complete seven days and verify named member progress plus only fixed reactions; no rank, absence explanation, exact time, duration, private routine, HealthKit, or impact data leaks. |
| Active Wind Down suppression | During an active Wind Down, verify no Slumber Party UI, card, badge, or panel; no reactions, notifications, realtime subscription, or novelty. The only permitted shared work is queueing monotonic `phoneTucked` after barrier validation and, after successful completion, `morningQuietCompleted` via the outbox. Local timer, rewards, and Farm remain authoritative; backend failure never blocks them. |
| Backend failure independence | Break backend connectivity or return a controlled function failure. Local start, completion, rewards, and Farm result still finish; social work is retryable or fails quietly. |
| Leave and block | Verify leave removes the local active membership; on a fresh flock verify block creates mutual invisibility and removes the blocker from the flock. |
| Fixed-enum report | Submit each supported report enum, reject an unsupported value through the function/API, and capture no free-text report path. |
| Slumber Party deletion | Delete Slumber Party data and verify challenge/social records are removed while local Wind Down, Nights, Farm, and rewards remain. |
| Full account deletion | Delete the linked online account; verify local ritual data remains, the remote account/session is gone, and a new anonymous session does not inherit deleted party data. |
| Final Release gate | Build/archive the ordinary `PhoneInTheOtherRoom` Release configuration, run the validation script, and capture `Release: SUPABASE_NIGHT_FLOCK_ENABLED=YES` with no `SLUMBER_PARTY_QA` compiler condition. |

Do not mark the release gates complete until every row passes on two physical iPhones with two
different Apple accounts and the ADR-0016 hosted, moderation, retention, privacy, and deployment
requirements have separate human approval.
