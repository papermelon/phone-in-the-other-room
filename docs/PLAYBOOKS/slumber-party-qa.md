# Slumber Party non-production QA

The tracked ordinary Debug default and Release remain disabled. The ignored
`Config/Supabase.local.xcconfig` Debug override should also stay `NO`; the dedicated
SlumberPartyQA configuration is the repeatable forced-`YES` lane. This playbook exercises that
non-production lane only; it does not authorize deployment, TestFlight enablement, or production
launch. Release must continue to resolve `SUPABASE_NIGHT_FLOCK_ENABLED = NO`.

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
| QA configuration | Settings → Slumber Party QA diagnostics says flag enabled; Release build says disabled and contains no QA destination. |
| Pre-link identity | Record each anonymous Supabase Auth UUID through approved redacted local/server tooling; after Sign in with Apple, each UUID is unchanged. |
| Create and one-use invite | A creates a flock; create one invite, join it once on B, then prove the same invite cannot join again. |
| Locked timezone and seven boundaries | Create with a known IANA timezone, change each phone timezone afterward, and prove days 1–7 follow the locked challenge timezone; day 8 cannot publish. |
| Positive check-ins | On eligible primary runs, observe only `phoneTucked` then `morningQuietCompleted`; prove additional quiet and early endings publish nothing. |
| Offline outbox and retry | Disconnect B before each allowed check-in, complete local Wind Down, reconnect in foreground, and capture one idempotent eventual delivery. |
| Per-night private reset | Choose Keep tonight private, prove no check-in, then begin the next eligible preflight and prove sharing is offered again. |
| Global sharing off | Disable sharing, verify queued records are purged and no new state is sent; re-enable only through the approved user flow. |
| Completion and reactions | Complete seven days and verify factual group completion plus only fixed reactions; no names, rank, absence, exact time, or duration leaks. |
| Active Wind Down suppression | During an active Wind Down, verify no Slumber Party UI, card, badge, or panel; no reactions, notifications, realtime subscription, or novelty. The only permitted shared work is queueing monotonic `phoneTucked` after barrier validation and, after successful completion, `morningQuietCompleted` via the outbox. Local timer, rewards, and Farm remain authoritative; backend failure never blocks them. |
| Backend failure independence | Break backend connectivity or return a controlled function failure. Local start, completion, rewards, and Farm result still finish; social work is retryable or fails quietly. |
| Leave and block | Verify leave removes the local active membership; on a fresh flock verify block creates mutual invisibility and removes the blocker from the flock. |
| Fixed-enum report | Submit each supported report enum, reject an unsupported value through the function/API, and capture no free-text report path. |
| Slumber Party deletion | Delete Slumber Party data and verify challenge/social records are removed while local Wind Down, Nights, Farm, and rewards remain. |
| Full account deletion | Delete the linked online account; verify local ritual data remains, the remote account/session is gone, and a new anonymous session does not inherit deleted party data. |
| Final Release gate | Build/archive the ordinary `PhoneInTheOtherRoom` Release configuration, run the validation script, and capture `Release: SUPABASE_NIGHT_FLOCK_ENABLED=NO`. |

Do not mark the release gates complete until every row passes on two physical iPhones with two
different Apple accounts and the ADR-0016 hosted, moderation, retention, privacy, and deployment
requirements have separate human approval.
