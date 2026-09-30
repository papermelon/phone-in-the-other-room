# Shared-text moderation — 30 September 2026

The founder authorized source implementation of the narrow OpenAI moderation policy. The [current contract](../../plans/shared-text-moderation-2026-09-30.md) owns coverage, consent, thresholds and rollout order. Neither Edge deployment nor native distribution occurred. The feature defaults off; no moderation key is configured in this task's shell and no text was sent to OpenAI during validation.

## Local checks

- Final generic iOS Simulator app build passed, including Watch and embedded extensions. Full native suite passed: **1,151 tests, zero failures** on the disposable iPhone SE, iOS 26.5. New shared tests cover account-partitioned consent, bounded review tokens and retryable outages without authentication/outbox mutation. Both final checks ran after the owner capture, configuration injection and outage-copy repairs. An intermediate initializer argument-order compile failure was repaired before this successful rerun. Existing SocialInbox/Watch fixture and AppIntents metadata warnings remain.
- `node --test supabase/tests/*.mjs`: **32 tests passed, zero failures**. Nine moderation tests cover selected categories, malformed/missing scores, exact owner/text/endpoint/command warning binding, rejection despite confirmation, consent before provider calls, text-only provider payloads, all-chunk checks without truncation, rate/provider failures, both HTTP publishing boundaries, shape/auth guards and redacted logs. Provider responses are mocked; these results do not establish language accuracy.
- Applied `20260930130000_shared_text_moderation.sql` only to the disposable PostgreSQL 17 database `wind_down_check_in` on `/tmp:55466`, prepared during the earlier check-in task. Eight rollback-only suites passed with `psql -v ON_ERROR_STOP=1`: `shared_text_moderation`, `shared_pasture`, `wind_down_check_in`, `campfire_buddies`, `campfire_bedtime`, `campfire`, `social_inbox` and `social_alerts`. The new suite checks service-only RPC privileges, caller-owned sheep-name lookup, no write after name mismatch, rename races, compatibility of old/new idempotency receipts and the 30/minute admission limit. The local bootstrap shims cron; it does not send notifications or contact production. The cluster was stopped after validation.
- `node supabase/scripts/evaluate-shared-text.mjs` without `--live` printed the opt-in instructions and sent no request. The synthetic corpus includes ordinary English/Singlish/swearing, identity discussion, reported/quoted abuse, Mandarin, Malay, Tamil, threats and obfuscation. Live results and fluent-speaker assessment remain pending.
- Deno and the Supabase CLI are unavailable in this shell. Pure TypeScript handlers/policy ran through Node's type stripping; a Deno runtime/type check of the composed Edge entrypoints was not performed and remains a deployment preparation check.
- XcodeGen regenerated source membership for the new view and unit test. Existing build-number and Android work was preserved. No package, target, entitlement or signing change was introduced by this feature.
- Final `git diff --check` passed.

Final native commands (derived data `/tmp/wind-down-check-in-derived`):

```sh
xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/wind-down-check-in-derived
xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=60935BFC-7044-4BE8-9712-7D1B6C568A16' -derivedDataPath /tmp/wind-down-check-in-derived -resultBundlePath /tmp/shared-text-complete-tests.xcresult
```

## Screen inspection

Used the disposable **Counting Sheep Review iPhone SE**, iOS 26.5, with the DEBUG `--campfire-buddies-qa` fixture. Its isolated preferences and absent network service prevent shared writes. Inspected consent, author review and definitive rejection screenshots: the complete messages and buttons fit; the rejection has only **Edit first**. Also inspected consent with Simulator `content_size accessibility-extra-large` and fixture `--buddy-large-text`, then restored the prior `extra-extra-extra-large` system setting. UIKit controls the native alert's type sizing.

Screenshots: [consent](../../../output/validation/shared-text-moderation-20260930/consent.png), [consent at accessibility3](../../../output/validation/shared-text-moderation-20260930/consent-accessibility3.png), [review](../../../output/validation/shared-text-moderation-20260930/review.png), [rejection](../../../output/validation/shared-text-moderation-20260930/rejected.png).

The Mac was locked, so computer-use accessibility interaction was unavailable. Button actions, VoiceOver speech, real touch scrolling, Settings withdrawal and authenticated multi-device transport were not physically exercised. Screenshots validate rendering, not network acknowledgement or classifier results.

## Review and rollout gates

Reviewed the touched publishing paths against the applicable pre-merge sections. The initiating owner is captured before asynchronous command work; consent headers cannot follow a replacement JWT/account. Profile extraction includes inventory labels because unknown IDs are displayed verbatim. The sheep transaction locks/rechecks its canonical name. Rejections have a persistent alert so later background successes cannot erase all feedback. Outage wording avoids claiming that an earlier attempt was never accepted when its acknowledgement may have been lost. No timer/reward state machine, audience agreement or account-recovery policy is replaced.

Local source review: **approve with rollout gates**, risk **L** because this changes server publishing boundaries, native queue handling and external processing. Live-language evaluation, secure key configuration, privacy publication, both Edge deployments, native distribution, disposable-account/device checks and operational report/appeal ownership remain required before activation. Existing historical content and login handles are not retrospectively moderated. The [backlog](../../FUTURE_AGENT_TASKS.md) records these concrete follow-ups. No merge, commit or push was performed.

Logs/result bundles remain in `/tmp/shared-text-*`; final app commands use `/tmp/shared-text-complete-build.log`, `/tmp/shared-text-complete-tests.log` and `/tmp/shared-text-complete-tests.xcresult`.
