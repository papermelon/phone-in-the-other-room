# Campfire — local implementation evidence

Source implementation for the founder's 13 September request. No hosted deployment, release
archive or upload. [Current contract](../../../docs/plans/campfire-implementation-2026-09-13.md).
The preceding [Shop/Ollie changes](../shop-ollie-20260913/README.md) and pre-existing build 49
configuration were preserved. The later founder-authorized
[production rollout](../../../docs/evidence/campfire-deploy-20260913/deployment.md) completed on
13 September; this directory remains the preceding local validation record.

## Delivered

Free paper campfire inside the existing party meadow; customized Shepherds gather for explicitly
shared Wind Down/Phone Away sessions. Their visitors use temporary nearby positions. Existing
saved arrangements, personal Shop inventory and 12-contribution lantern progress persist.
Per-party version 1 consent, bounded optional intentions, immutable local account ownership,
start/end precedence, offline durable replay and deadline expiry are implemented. Old/future
capabilities remain readable without silently enabling sharing. Local starts and shielding never
wait on campfire transport. No new social notifications or reward changes.

## Native rendering

The ordinary DEBUG fixture uses the real party view, custom Shepherd renderer and isolated UUID
local defaults with external services disabled. `--campfire-direct` opens that view directly;
it does not simulate Home navigation or an actual server. Capture command is in
[capture-native.py](capture-native.py).

- [Active pair](active-party.png): Wind Down and Reading labels, fire and visiting sheep.
- [Earned lantern](lantern-complete.png): original earned prop remains beside the free fire.
- [Eight members](large-party.png): horizontal meadow and separate shared-session rows.
- [Expired presence](campfire-expired.png): no current gathered sessions, ordinary positions return.
- [Older server](old-party.png): explicit unavailable live sharing with readable meadow.
- [Large-text sharing disclosure](campfire-settings-large.png): scalable opening text in a scroll view.

Initial captures caught a visitor behind the flame and a clipped initial fire in the wide scene;
final layout uses temporary visitor offsets, a smaller fire on the clear foreground ground,
and centers the initial horizontal camera. The
pre-repair `active-se.png` is retained as review history and is not the final layout.
The Mac was locked, so native tap/accessibility automation could not proceed. Direct render
checks do not establish tap/drag, VoiceOver speech, two-device networking or real protection.

## Validation

- Full Simulator build: `build-final.log`.
- Full native unit suite: `tests-final.log`; **1,014 tests, zero failures**.
  Campfire tests cover expiry/stale/version handling, late terminal dominance, bounded temporary
  seats, legacy plan/pasture decoding, account identity, intention persistence and revoked outbox
  recovery. Existing full-suite checks cover the unaffected session/economy/transport behavior.
- Nine isolated PostgreSQL suites pass: campfire, pasture, v4, membership sharing, public avatar,
  contextual cheers, shared habits, private Farm save and account identity. [Results](backend-results.json).
  Campfire assertions include explicit consent, retries, end-before-start, outsider/peer consent,
  pre-consent rejection, bounded validity, block/ended epoch visibility, withdrawal and delayed
  reacceptance. One fixture used an incorrect block-table name; its corrected standalone rerun
  passes, as recorded in `campfire_test.sql.log`. No migration repair was needed.
- Eight Edge validation tests pass in `edge-tests.log`, including all six bounded intentions,
  terminal revision rules, Foundation/ISO date handling and private-text/invalid-time rejection.
- `run-isolated-sql.py` targets only disposable `campfire_release` on `/private/tmp:55439` as
  `pasture_test`. Fresh migrations are in `migrations.log`. It reuses the documented local Auth
  adapter for four legacy suites and the cron-registration shim; production Auth rules and
  scheduler operation are not bypassed or claimed. The local cluster was stopped after testing.
- Source/documentation whitespace checks pass; raw logs and the saved baseline patch retain their original whitespace. Remaining physical/rollout gates are in the linked contract/backlog.
