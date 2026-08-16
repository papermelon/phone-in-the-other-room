# Slumber Party non-production QA

The tracked ordinary Debug default remains disabled. The ignored
`Config/Supabase.local.xcconfig` Debug override should also stay `NO`; the dedicated
SlumberPartyQA configuration is the repeatable local forced-`YES` lane with QA diagnostics.
TestFlight/Release archives compile with `SUPABASE_NIGHT_FLOCK_ENABLED=YES`. This playbook
exercises the local QA lane; it does not deploy hosted backends or upload TestFlight.

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

## Two physical iPhone / two Apple-account matrix

Install the `PhoneInTheOtherRoomSlumberPartyQA` scheme on two physical iPhones signed in to two
different Apple accounts. Keep a dated evidence row for each check, with the device, app build,
account label A/B, expected result, actual result, and screenshot/log reference.

| Check | Required observation |
| --- | --- |
| QA configuration | Settings → Slumber Party QA diagnostics says flag enabled. Ordinary Debug says disabled. Release/TestFlight has Slumber Party and contains no QA diagnostics destination. |
| Pre-link identity | Record each anonymous Supabase Auth UUID through approved redacted local/server tooling; after Sign in with Apple, each UUID is unchanged. |
| Create and reusable invite | A chooses one bounded goal, creates a pending lobby, creates a reusable legible code, previews it on B, and verifies it works until revoked, expired, started, or capacity reaches eight. |
| Lobby gate | Verify joining does not start the party. The host can start only after at least two members have accepted the same goal and completed required local setup. |
| Locked timezone and seven boundaries | Create with a known IANA timezone, change each phone timezone afterward, and prove days 1–7 follow the locked challenge timezone; day 8 cannot publish. |
| Shared-goal progress | Verify goal accepted, setup ready, phone tucked away, meaningful partial progress, shared goal completed, morning quiet completed, and no update shared. No update shared is never completion. |
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
