# Unified Campfire implementation — 16 September 2026

Founder-authorized local source implementation of **Off / My Slumber Party / Global**. No commit, deployment, public activation, archive or distribution was performed. Existing unrelated work and the Fable DEBUG study are preserved.

## What changed

- One Campfire panel is reachable from Home, Farm and private groups. The Viewing menu controls browsing; My visibility controls publication. Existing private sharing migrates to the private choice, never Global.
- Both Wind Down and Phone Away appear in the live scene/list with explicit mode labels. Join actions enter the correct existing start flow. Group membership, Shared Meadow, visiting sheep, lantern and group history stay private.
- One visible choice sheet integrates the relevant sharing agreements. Explicitly sharing a running session starts the new projection from the accepted change; it does not restart protection or copy earlier private activity. Off/narrowing persist withdrawal; pending removal is explained. A saved preference is distinct from confirmed delivery.
- Public source supports verified accounts with zero parties, activity filters, eight-person pages, rounded counts, preset aliases, a minimal Shepherd appearance, coarse time-left bands, fixed encouragement and owner receipt counts, block and report. There is no new chat, mutual-connection feature, public activity history or WebRTC.
- Account-partitioned JSON journals, exact agreement/command binding, membership epochs, terminal precedence, bounded queues, owner matching at the Edge boundary and stale-snapshot handling fence retries. Future journal formats fail closed rather than restoring an older sharing choice. Legacy plan decoding remains compatible.
- The public migration defaults disabled. RPCs are service-only; participant cards omit account/source/party identifiers, private text, exact session times, Health and Farm inventory. Existing account blocks are reused. Daily retention and account-delete cascades are included in source.

## Native inspection

`capture-native.py` renders actual release components through the pre-existing DEBUG fixture dispatcher, using isolated local defaults and no live service/account. Sixteen scripted iPhone SE captures cover mixed private sessions, eight public participants, zero-party browsing, unavailable/empty/stale/failed state, visibility, public participant cards, light/dark and `.accessibility5`. Names, counts and sessions in these screenshots are fixtures.

The inspection prompted these repairs: explicitly label Phone Away beside its activity; keep eight seats separated; place start actions before tall controls at accessibility sizes; stack visibility choices, preserve full-width explanatory text, keep decorative icons bounded and add padding inside the choice button. The accessible participant list retains scalable text even though scene name tags are bounded. The accessibility tree exposes named viewing/visibility controls and separate mode-specific actions. A native accessibility action also selected Global and exposed the public alias/Shepherd preview and disclosure; Save was not invoked. Physical VoiceOver interaction remains a device check.

Representative captures:

- [Private mixed sessions, light](party-mixed-light.png)
- [Private mixed sessions, largest text](party-mixed-light-ax5.png), [lower content](party-mixed-light-ax5-bottom.png)
- [Eight public participants, dark](global-eight-dark.png)
- [No party required; visibility remains Off](global-zero-parties-light.png)
- [Visibility choices, largest text](visibility-light-ax5.png)
- [Public participant card](public-card-dark.png)

## Validation

Final validation passed against the source hashes in `source-sha256.json`:

| Check | Result | Evidence |
| --- | --- | --- |
| `xcodegen generate` | Passed after source/test membership changes | `project.yml` remains the source of truth |
| Generic iOS Simulator app build | **BUILD SUCCEEDED** | [build-final.log](build-final.log) |
| Full iOS unit suite, simulator `A0DB65B8-F3FC-4961-8B0C-9689F51C9EA1` | **1,054 tests, zero failures** | [tests-final.log](tests-final.log); `/tmp/campfire-visibility-delivery-tests-20260916.xcresult` |
| Node validation suites: Campfire, alerts, Global | **14 tests passed** | [edge-validation.log](edge-validation.log) |
| Actual Global migration plus isolated SQL suite | **Passed**, data tests rolled back | [migration-validation.log](migration-validation.log), [sql-validation.log](sql-validation.log) |
| Native UI | Sixteen scripted captures plus a Global-choice preview; representative layouts and states inspected | PNGs and `capture-native.py` |
| Whitespace and changed local document references | Passed | `git diff --check`; local link check |

The isolated database server was stopped after validation. No hosted accounts or databases were used. The full test target includes migration, receipt binding, account isolation, JSON recovery, future-version fencing, consent withdrawal, terminal-before-start and queue capacity cases.

The isolated PostgreSQL 17 suite applies the actual new migration, with synthetic fixtures for the existing verified-account/block contracts and a cron scheduling recorder. It checks disabled-by-default behavior, both session kinds, zero-party reads, consent/idempotency, no private fields, encouragement, blocking/reporting, terminal ordering, withdrawal conflicts, eight-person pagination, account deletion, retention and privilege restrictions. The data tests end with rollback. This is **not** a full hosted Supabase/Edge test and does not prove pg_cron execution in production.

## Remaining external gates

Deploy the reviewed migration and `campfire-global` only with deployment authorization. Verify hosted integration, cron execution, operational moderation/support ownership, age/disclosure requirements, retention/backups, load limits and rollback before enabling the global capability. A separate rollout request is needed for a new TestFlight archive/distribution.

Repeat the original two-phone scenario and active audience transitions on disposable physical accounts after distribution. Validate offline early end/Off, relaunch, account switches, two-device consent conflicts, shielding and morning check-in timing; preserve the founder’s Farms. Current Simulator evidence does not prove physical phone placement, shielding or real multi-account transport.

Mutual connections, free text/chat, worldwide realtime and the broader bedtime/morning-loop redesign remain subsequent slices. The prepared [rollout notes](ROLLOUT.md) identify the deployment and activation boundary. See the [current contract](../../../docs/plans/global-campfire-2026-09-15.md) and [backlog](../../../docs/FUTURE_AGENT_TASKS.md).

## Source review

Local source review found no remaining blocker within this implementation slice. Risk is **L** because audience persistence and admission capture touch the core loop. The full local build/unit gate passed; founder review remains required before a merge, and the external activation/device gates above remain open. No physical or hosted acceptance is claimed.
