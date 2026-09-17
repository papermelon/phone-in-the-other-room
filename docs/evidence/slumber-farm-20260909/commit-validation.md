# Scoped commit validation — 9 September 2026

The founder authorized commit/push and then explicitly approved required prerequisites only.
The inherited working tree also contained separate account, reward, habit-loop, shielding,
documentation and release work. Those changes were not swept into the commits.

Prerequisite commit `06b090d` contains the existing production Shepherd renderer, fitted
cosmetics, four head shapes, required customization callers, compatibility tests, the social
capability/consent gate, refresh-failure presentation model and factual rounded-minute labels.
Partial files were staged from a reviewed temporary tree; the working files were preserved.
The following social commit contains the Farm, linked updates/cheers, outbox recovery,
participant acknowledgements, compatible backend extension, tests and native evidence.

The native fixture now uses its unique defaults suite through the existing initializer. It
remains isolated with both the legacy defaults store and the newer defaults-scoped private
store. This avoids pulling the separate account/persistence rollout into the social commit.
The SQL test supports both old Apple-only installations and the current verified-account
predicate, without requiring that separate account migration to accompany this additive one.

The exact combined commit candidate was materialized from Git HEAD plus the selected changes
in `/tmp/slumber-farm-commit-review/candidate`, with its own XcodeGen project and build directory.
This excludes unrelated files that were present during the earlier 939-test working-tree runs.

- Generic iOS Simulator build: **passed**, `build-exact.log`.
- Full standard unit suite for the scoped tree: **823 passed, zero failures**,
  `tests-final.log` and `tests-final.xcresult`.
- Existing Edge suite: **32 passed**, unchanged executable Edge source from the original review.
- Final SQL fixture: **passed** on a fresh legacy migration chain and with the current verified
  Apple/email predicates, `sql-legacy-final.log` and `sql-current.log`.
- Native inspection on iPhone SE: [Farm](commit-farm.png) and
  [named recipient feedback with rounded minutes](commit-recipient.png).
- Staged whitespace checks passed; staged source was compared byte-for-byte with the isolated
  candidate. No founder data or production transport was used.

All log paths above are relative to `/tmp/slumber-farm-commit-review`, except the original Edge
log at `/tmp/slumber-farm-20260909/edge-tests.log`. Earlier intermediate subset builds exposed
missing renderer callers; those prerequisites were included before the final passing checks.

The initial [native review](native-review.md) documents the broader working-tree captures and
physical-device limitations. A prepared app-received fixture still does not prove remote delivery.
Deployment and distribution remain unauthorized; follow the existing rollout backlog.

Git-rule assessment: explicitly permitting minimal required prerequisites and requiring
validation of the staged tree would reduce ambiguity. Keep unrelated-change preservation and
explicit push/deployment/destructive-operation authorization. The Git rules were not changed.
