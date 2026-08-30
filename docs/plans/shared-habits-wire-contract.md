# Shared habits wire contract

Version 2, 2026-08-30. This is an additive V4 capability. An absent
`sharedHabitsVersion` means the server does not support this contract and clients must not send
its commands or state scope.

## Capability and state

`{ "schemaVersion": 4, "scope": "list" }` may return
`"sharedHabitsVersion": 1`. A v2 social-habit-loop server returns
`"sharedHabitsVersion": 2` and `"sharedRoutinePlansVersion": 1`; both are required before
the client offers planned timing/routines or factual plan receipts. Focused archive reads use:

```json
{ "schemaVersion": 4, "scope": "habits", "partyID": "UUID", "cursor": "opaque-or-null" }
```

The snapshot contains `agreement`, `records`, `nextCursor`, `snapshotRevision`, and `periods`.
V2 additionally contains `sharedNightPlans` and `sharedNightReceipts`; they never travel through
Realtime, diagnostics, logs, or notification payloads. Their lifetime archive uses a separate,
additive read so a v1 `nextCursor` can never be misread as a timing/routine cursor:

```json
{ "schemaVersion": 4, "scope": "sharedNights", "partyID": "UUID", "cursor": "opaque-or-null" }
```

`sharedNightsNextCursor` and `sharedNightsSnapshotRevision` advance a stable, party-revision
snapshot of plan/receipt events (100 events per page). A receipt page includes its frozen plan
version even when that version was superseded before the page boundary. A changed party revision,
including deletion, rejects the continuation as stale; clients restart at the first page. V1 or
non-consented members receive empty v2 collections and no v2 cursor.
`records` are ordered by `(localDate DESC NULLS LAST, memberID DESC, recordID DESC)` within the immutable
snapshot revision; `nextCursor` encodes that boundary. `periods` always covers the full eligible
dataset, not the page. It has one row per member and kind for `lastNight`, `last7Nights`, and
`last30Nights`, each with `endingOn`, `availableNights`, `coveredNights`, nullable `averageMinutes`,
and `method:"eligibleMean"`.

## Commands

All commands include `schemaVersion:4`, a 64-character `idempotencyKey`, and no unknown fields.

* `acceptSharedHabitsAgreement`: `partyID`, `agreementVersion:1|2`, and contributor
  `timeZoneIdentifier`.
* `publishSharedHabit`: `partyID`, `agreementID`, `memberEpochID`, `sourceID`, `revision`,
  `kind`, `localDate`, `timeZoneIdentifier`, `minutes`, optional `outcome`, optional
  `protectionMinutes`, and `evidence`. Sleep uses the receipt's contributor time zone exactly;
  Wind Down and Phone Away retain their factual activity zones while travelling.
* `deleteSharedHabitHistory`: `partyID`, `sourceID` (or `allSources:true`). It is available to
  a former member and writes durable source/user tombstones before deleting visible archive and
  legacy/membership stream projections for that author. An all-sources deletion snapshots known
  source IDs and fences that membership epoch; a later leave, rejoin, and new agreement may send
  new source IDs, never the deleted ones.
* `migrateSharedHabits`: `partyID`, `agreementID`. It copies only the caller's existing
  group-shared coarse projections, once per legacy round/membership source, after agreement.

Atomic create/redeem agreement fields are not supported by v1. A successful `createParty` or
`redeemInvite` response now includes optional `resolvedPartyID`, produced by the same transaction
that created or redeemed membership and retained in the idempotency response. Old servers omit it.
Clients may show one agreement UI only after this command-bound ID is present, then send the
separate durable `acceptSharedHabitsAgreement`; they must not infer a party from a list diff or
publish/migrate before the receipt is durable.
Responses are acknowledgement-only (`accepted`, ids/revision where needed); retained metrics are
never echoed by a command acknowledgement.

* `publishSharedNightPlan` requires a v2 agreement and carries one immutable contributor-local
  night instance: opaque IDs/revision, local `nightEndingDate` and timezone, rounded five-minute
  Wind Down/bed/wake/morning-end times, bookend durations, and ordered bundled suggestion IDs.
  It has no recurrence, custom text, notification data, app selection, or device credential.
* `publishSharedNightReceipt` requires the same authority and carries independent factual fields:
  optional frozen plan link/revision and actual times, outcome (`completed`, `partlyCompleted`, or
  `unknown`), optional factual Wind Down/protection minutes, explicit protection evidence, and
  optional emergency-exit evidence. Omission means unknown, never non-adherence.

Agreement v2 explicitly covers this timing/routine bundle, factual receipt dimensions,
former-member/later-joiner lifetime archive, withdrawal/deletion, and the absence of app identity
or usage. Its accepted contributor timezone is part of that frozen contract: travel does not
silently move shared-night anchors, and a different anchor requires renewed agreement before new
v2 publication. A v1 receipt remains readable but cannot publish or render v2 data until
affirmative v2 acceptance succeeds.

## v1 record fields and eligibility

Each returned archive record has an immutable `recordID` UUID, `memberID`, frozen name/avatar
snapshot, `isFormerMember`, and optional `migratedAt`. The contributor-scoped `sourceID` is sent
only in an owner publication or owner read; peers receive no source identity. `kind` is `sleep`,
`windDown`, or `phoneAway`; `localDate` is an ISO local day and may be null
only for migrated legacy activity. Sleep is the completed noon-to-noon window ending on
`localDate`; Wind Down uses that same night-ending anchor; Phone Away uses its local activity day.
`minutes` is derived duration only. `outcome` is `completed` or `partlyCompleted`; `evidence` is
`none` or `appRecorded`. `protectionMinutes` is optional and only allowed with `appRecorded`.
For these v1 shared-habit records, no exact interval, schedule, app identity/token, raw Health
sample/source/stage, or private text is accepted. The additive v2 shared-night plan/receipt fields
below are separately versioned and require affirmative version-2 agreement. For sleep, the
completed noon-to-noon window start must be at or after `acceptedAt`;
the server returns `firstEligibleSleepNight`. Wind Down and Phone Away use separate receipt-time
starts, avoiding a date comparison that could suppress two nights. Migrated unanchored legacy records
remain dated activity and are excluded from night statistics.

The Swift transport surface is intentionally independent from account-wide V4 source activity:
`NightFlockSharedHabitsListCapability`, `NightFlockSharedHabitsStateRequest`,
`NightFlockSharedHabitsCommandRequest`, `NightFlockSharedHabitRecord`,
`NightFlockSharedHabitPeriodSummary`, and `NightFlockSharedHabitsStateResponse` in
`Shared/NightFlockSharedHabitsAPI.swift`.
