# Campfire Buddies — local evidence, 13 September 2026

Implemented source: [current contract and activation checklist](../../../docs/plans/campfire-buddies-implementation-2026-09-13.md).

## Scope

Explicit per-party intentions at admission; version 2 consent; live buddy cards; volunteer support and encouragement; optional return check-ins; ordinary APNs registration, account/revision fencing, quiet-hour delivery and durable dispatch source. The existing meadow, Shepherd outfits and native paper campfire are reused. No external assets or dependencies were added.

This work shares an uncommitted tree with earlier Fetch, Shop and live-campfire repair work. Those changes were preserved. No commit, push, backend deployment or new app distribution was performed during that source implementation pass. The founder subsequently authorized [backend deployment and push configuration](../../../docs/evidence/campfire-buddies-deploy-20260913/deployment.md), which are now complete; physical push receipt and app distribution remain pending.

## Validation

- Full generic iOS Simulator app build: passed.
- Full unit suite on `Counting Sheep Pasture Unit QA` (`A0DB65B8-F3FC-4961-8B0C-9689F51C9EA1`): **1,038 tests, zero failures**. This includes earlier changes in the shared tree, plus nine new buddy tests covering consent/schema compatibility, explicit plan persistence, bounded text, quiet-time reflection, support eligibility, retention and withdrawal outbox cleanup.
- `node --test supabase/tests/*.mjs`: **13 tests passed**. Includes strict command/device contracts, generic payload privacy and mocked APNs topic/environment/expiry/retry behavior. The APNs test generates a disposable signing key and replaces fetch; no credentials or network delivery are used.
- `node --check` for both new Edge entrypoints: passed. This checks syntax, not a Deno deployment or hosted execution. Deno is not installed in this environment.
- Ten isolated PostgreSQL suites: passed; see [backend-results.json](backend-results.json) and accompanying suite logs. Test database `campfire_buddies_test` runs only on the dedicated local socket `/private/tmp:55439`, user `pasture_test`. The runner recreates only that disposable database. Existing fixture bootstrap and legacy Auth adapter are recorded by the runner. Cron is shimmed; no production/network data is used.
- `git diff --check`: passed. Current documentation references checked locally.

Commands:

```sh
xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator'
xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=A0DB65B8-F3FC-4961-8B0C-9689F51C9EA1' -resultBundlePath /tmp/campfire-buddies-ui-verified.xcresult
node --test supabase/tests/*.mjs
node --check supabase/functions/campfire-device/index.ts
node --check supabase/functions/campfire-dispatch/index.ts
python3 /tmp/run-campfire-buddies-sql.py
git diff --check
```

Full local build/test logs remain at `/tmp/campfire-buddies-build-verified.log` and `/tmp/campfire-buddies-tests-verified.log`; the final xcresult is outside the repository. [The isolated backend runner](run-isolated-backend.py) records migrations, fixtures and individual suites used.

## Native visual review

Captured on the disposable iPhone SE Simulator (`60935BFC-7044-4BE8-9712-7D1B6C568A16`), using DEBUG `--campfire-buddies-qa` fixtures with isolated defaults and release UI components. These demonstrate rendering, not live authenticated transport or successful taps. The fixture's buddy-card actions are intentionally inert.

| State | Screenshot | Inspected result |
| --- | --- | --- |
| Two live sessions | [Live scene](native-small-live.png) | Existing paper meadow/fire and separate clothed Shepherd seats, with explicit intention cards below. |
| Supporting a friend | [Buddy card](native-small-card.png) | Separate join, volunteer and encouragement actions; readable goal and planned end. |
| Returning | [Check-in](native-small-return.png) | Explicit outcome choices, optional party note and no inferred task completion. |
| Manual audience/intention choices | [Start choices](native-small-start.png) | Selected party, authored intention, start announcement and buddy request. |
| No shared sessions | [Empty](native-small-empty.png) | No fire or characters; clear empty-state explanation. |
| Unknown freshness | [Stale](native-small-stale.png) | No false live presence; refresh explanation. |
| Accessibility text | [Large text](native-small-card-large.png) | Multiline labels and scrollable content, without horizontal truncation in the captured viewport. |

## Remaining acceptance

This pass does **not** prove hosted migration/function activation, APNs delivery, notification permissions/Focus behavior on a physical device, VoiceOver interaction, real shielding, or two-account synchronization. See the linked activation checklist and backlog. Default quiet hours and recipient preferences intentionally prevent some start alerts. An offline sign-out cannot guarantee immediate remote token revocation; generic push previews expose no name or task. APNs acceptance is not a delivery receipt.
