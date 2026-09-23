# Private Campfire bedtime — local evidence, 19 September 2026

Source implements the [approved contract](../../../docs/plans/campfire-bedtime-2026-09-19.md).
No hosted migration, Edge deployment, signing change, archive, distribution, commit or push
was performed. Global's public timestamp contract is unchanged.

## Validation

- Full app Simulator build: **passed**. Command:
  `xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator'`.
  See [build log](build.log). Existing SDK/deprecation warnings remain.
- Full iOS Simulator unit suite: **1,075 tests, zero failures**. Command:
  `xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=A0DB65B8-F3FC-4961-8B0C-9689F51C9EA1' -resultBundlePath /private/tmp/campfire-bedtime-tests-verified-20260919.xcresult`.
  See [test log](tests.log); local result bundle is at the command's absolute path.
- Edge command validation: **20 tests passed**, including Campfire, alerts, Global and
  pasture suites. Command: `node --test supabase/tests/campfire_validation.mjs supabase/tests/campfire_alerts_validation.mjs supabase/tests/global_campfire_validation.mjs supabase/tests/shared_pasture_validation.mjs`.
  See [log](edge-validation.log). This does not claim hosted Edge execution.
- PostgreSQL: **11 suites passed**; [results](backend-results.json). The isolated
  [runner](run-isolated-backend.py) applies prior migrations, verifies upgrade over a
  pre-existing legacy session transactionally, then applies the new migration and runs
  regression suites. See [upgrade log](upgrade.log), [migration log](migration-bedtime.log)
  and per-suite logs. Test-only legacy Auth adapters and cron-registration shim are
  inherited from repository fixtures; this does not validate hosted Auth or pg_cron.
  Database used only `/private/tmp/campfire-bedtime-socket:55449`, role `campfire_test`,
  database `campfire_bedtime_test`. The temporary cluster was stopped after testing.
- XcodeGen regenerated source membership. No hand edits to the generated project or
  changes to project.yml/signing/entitlements/dependencies.

## Render checks

The [capture script](capture-native.py) uses the existing isolated DEBUG entry and
release `CampfireSceneView`, `CampfirePersonRow`, `CampfireShepherdView`, and explicit
presentation clock on the iPhone SE Simulator. The fixture has no network events.

Screenshots cover static detail, mixed Wind Down/Phone Away, four/eight people,
large text, dark/light, legacy metadata, unavailable observation, terminal state,
and an uninterrupted before-bedtime → bedtime → expiry sequence. Native inspection
found that the finite explicit timeline could omit its final entry; the clock now
adds one trailing entry beyond the last real boundary, covered by a pure regression
test and the uninterrupted Simulator capture. They do not prove
physical device behavior, spoken VoiceOver or real multi-account transport.

## Review and remaining gates

Review focused on immutable admitted boundaries, latest-source/terminal precedence,
optional decoding, exact local clock behavior, existing consent/owner/party/block
fences, outbox payload preservation and reuse of customized drawing. Risk is M:
shared presentation and additive persistence/protocol metadata; no coordinator,
protection, reward or Watch protocol changes.

Hosted deployment/rollback verification and physical two-account acceptance remain
in the [contract](../../../docs/plans/campfire-bedtime-2026-09-19.md) and
[backlog](../../../docs/FUTURE_AGENT_TASKS.md). Those require separate deployment and
distribution authorization. No Simulator result is presented as physical acceptance.
