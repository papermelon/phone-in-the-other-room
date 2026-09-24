# Farm save contract and migration inventory

22 September 2026 compatibility repair: the deployed Supabase RPC encoder writes
payload Dates as ISO text, while local Codable documents use numeric reference-date
values. Remote decoding accepts both. It converts only fields decoded as `Date`
before the existing lossless object comparison; all other fields, schema gates,
receipts and migration requirements remain checked. ISO text is restricted to the
deployed UTC forms and rejects calendar overflow/trailing garbage. Comparing
reformatted ISO strings is unsafe because fractional-date parsing/formatting can
truncate another millisecond. Transport envelopes carry the validated payload in
local numeric-date form before lookup/receipt decoding. Upload encoding is unchanged
so retries of durable pending operations keep their existing request identity.
See [the investigation](slumber-party-loading-investigation-2026-09-22.md).

20 September 2026 extension: Farm schema 4 carries a separate bedtime search-bonus
remainder, immutable per-night grant identities and per-run bonus receipts. These
minimal economic records join the existing private Farm payload; raw bedtime-plan
evidence remains local. Wire schema/economy version stays 1. New clients losslessly
accept Farm 3/4; older clients' existing local and remote version gates reject Farm
4 before dropping bonus data. Decoded schema-3 Farms retain their wire version until
a version-2 settlement so pending upload fingerprints remain unchanged. There is no
retroactive bonus migration. See [the scoped plan](ollies-next-search-2026-09-20.md).

Date: 2026-09-05. Local format v2 (v1 readable) and `FarmBackupPayload` v1 implemented.
The private backend is deployed; native app acceptance is in progress. See
`../FARM_BACKUP_DEPLOYMENT.md` for current evidence.

## Local transaction document

The checksummed envelope contains `schemaVersion`, stable `lineageID`, monotonic
`generation`, and a fixed dictionary of original JSON values. Keeping the inner
values preserves existing Codable compatibility while one file commit covers all
reward effects. Keys are identifiers inside a document, not separate write stores.

| Local component | Fields/dependencies preserved | Remote treatment |
|---|---|---|
| `ollie.farm.state` / `FarmState` | Every sheep instance ID/definition/name/status/rarity/provenance, pending/sold instances, favorites, shearing count and remaining regrowth; discoveries; wool balance; capacity/shop tier; owned IDs; equipment, Shepherd; Farm transactions; tracked sheep; cumulative credit | Explicit private Farm payload, including stable IDs and Farm event dates; retain unknown catalogue IDs. |
| `FarmState.cumulativeCredit` | Migration marker, consumed interval union, Wind Down/Phone Away seconds, per-run immutable receipts and resolved outcomes | Include accounting-only intervals/IDs/amounts; never prune identity or overlap protection to meet a size limit. |
| `ollie.sheepSearch.state` / `SheepSearchState` | All resolved outcomes, discovered IDs, independent drought counts, compatibility map remainder/credited IDs, Phone Away settlement receipts, exact-odds presentation choice | Include; old compatibility values do not regain user-facing progression meaning. |
| `ollie.welcome.rewards` / `WelcomeRewardLedger` | Starter, preexisting Farm marker, chosen/claimed wearable, practice grant and stable claim IDs | Include to prevent second gifts after restore. |
| `ollie.nightFlock.rewards` / `NightFlockRewardLedger` | Applied IDs and immutable granted effects, including older-schema grants | Include private claim provenance. Never infer full wallet state from the server's acknowledgement alone. |
| `ollie.progress` / `UserProgress` | Local completed count, factual minutes/streaks, reward count/level, daily records and legacy balances | Export only the completed Wind Down count required by current economy rules. Already migrated Farm inventory/wool carries legacy value. Keep dated daily records, factual minute/streak history and obsolete balances local. Restore must separate economic continuity from Nights presentation. |
| `ollie.rewards` / `[RewardItem]` | Local keepsake/reward history, descriptions, source context | `FarmBackupKeepsake` preserves identity/type/rarity/title/date/demo marker. Descriptions, detailed source context and factual run minutes do not enter this projection. |
| `ollie.windDownMorning.settlementJournal` | Benefits, hidden/resolved results, delivered projections, deferred/active occurrences, `sunriseTrail`, delivery markers, authorized terminal decisions | Never serialize whole journal. Include settled `SunriseTrail` meters/fills/claims; delivered Wind Down outcome/run identities and delivered effect markers. Exclude full runs, pending authorizations, recurrence and scheduled/active occurrences. |

Wardrobe additions on 23 September 2026 keep optional `ShepherdProfile.shirtItemID` and
`FarmEquipment.ollieCoatID` inside the existing private profile/equipment payload. Missing
fields use the cream shirt and Classic coat; unknown identifiers survive round-trip with
known rendering fallbacks. These additions do not extend the public Slumber Party contract.

Fetch progression added 25 September 2026 uses optional `FarmState.fetchPracticeBest`
(0–15, absent until a completed practice round) and `FarmEquipment.fetchBallItemID`.
They remain inside the existing private Farm projection and account archives. Missing
ball IDs use the original ball; unknown IDs round-trip with that same rendering fallback.
Missing fields remain omitted when encoded, preserving old queued-payload fingerprints.
Malformed/out-of-range bests are rejected. This adds no public appearance field or reward ledger.
Older strict remote decoders reject these unrecognized fields without overwriting either save.

Personalisation added 13 September 2026 follows `AccountFarmLocalKeys`, not the remote
payload: `ollie.windDown.personalisation` stores explicit goals, plan revisions and
suggestion/review history; optional experience feedback extends the local habit
reflection key. Never serialize `localValues` wholesale. Ownership, retention,
clear behavior and interrupted preference projection are specified in the
[local implementation record](meaningful-personalisation-implementation-2026-09-13.md).

Other local sources required by the later backup projection:

- `ollie.farm.pastureScene`: cosmetic placement snapshot, privately restorable.
- `ollie.userProfile` and explicit-avatar-selection marker: project the chosen
  appearance; keep server-controlled social display-name revision/limits authoritative.
- Minimum guide completion needed to avoid presenting restored users with duplicate
  gift/practice grants must derive from restored claim ledgers, not completion of
  schedule/permission setup on the previous device.

## Never upload through the Farm endpoint

No `FocusRun` or whole UserDefaults dump; no `NightWatchHistory`, raw Health samples,
reflections, questionnaire/profile result, routines/purpose/custom notification text,
Screen Time tokens/evidence, NFC digests, social transport queues, impact records or
active-run/morning scheduling. Account backup and party sharing remain separate.

`FarmBackupPayload` projects from a validated local document only after cumulative
credit migration has completed. Its explicit root fields are schema/economy versions,
lineage, Farm, search, welcome, social rewards, sunrise, completed Wind Down count,
keepsakes, delivered Wind Down IDs/effect markers, and optional pasture/appearance.
The account service uploads this allowlisted payload only after explicit backup
consent. `FarmBackupSync` stores ownership, backup generation, cloud base revision,
pending operation and confirmation metadata atomically with the local Farm. Strict
remote decoding rejects lossy normalization and incompatible schemas. A restored
Farm uses `UserProgress.restoredFarmCompletedRuns` for economy continuity while
keeping the device-local factual completed count and dated Nights records separate.

The remote decoder must preflight supported versions before permissive domain
decoding can default, normalize or drop unknown fields. Newer incompatible payloads
require an app update and preserve the original local and remote bytes. Missing
required remote fields are errors, not migration-to-empty signals. The permissive
legacy migration policy applies only to explicitly identified local legacy saves.

## Migration and failure boundaries

1. Read legacy bytes directly, without getters that reconcile or rewrite them.
2. Validate every present component and its supported schema.
3. Keep old defaults and an additional `legacy-original.json`; commit generation 1.
4. Mark the installation migrated only after commit. A known migration with no files
   reports unavailable rather than accepting older legacy values as current.
5. Existing starter/Farm reconciliation runs inside the transaction store. New saves
   have no cloud owner or backup status until the account layer implements them.
6. A failed encoder/write leaves the previous committed generation and values intact.
   Failures in nested/caught setters poison the outer transaction. Unsupported-newer
   saves prevent writes. Corrupt newest files can recover the prior valid generation,
   with explicit UI disclosure that the latest changes may be missing.
7. Keep each failed terminal receipt available through the existing device-local
   terminal recovery path; resource cleanup remains independent of storage success.

The minimum guarantees tested by `scripts/validate-farm-save.py` are real filesystem
relaunch, multi-field rollback/retry, nested error propagation, corruption recovery,
stale-legacy exclusion after a valid generation, reset before first load and retention.
The normal Xcode suite checks domain round-trip, unknown schema and checksum failure.
Physical power-loss, full device-backup restore and account restore are separate checks.

## Copy review

| Location | String | Verdict |
|---|---|---|
| Farm save notice | “Your Farm save could not be read. The original has been kept.” | Keep: only shown after a read failure; no recovery guarantee. |
| Newer schema | “This Farm was saved by a newer version of Counting Sheep. Update the app to open it.” | Keep: distinguishes schema incompatibility from corruption. |
| Previous generation | “An earlier Farm save was recovered. Your latest changes may be missing.” | Keep: does not claim exact/latest recovery. |
| Failed mutation | “Your Farm could not save this change. Your previous save has been kept. Please try again.” | Keep: does not present an uncommitted reward/purchase as saved. |
| Unavailable files | “Your Farm save is unavailable. The app has not replaced it. Please try again.” | Keep: does not claim an unreadable or missing file was recovered. |
| Failed reset | “Your Farm could not be reset. Please try again.” | Keep: no false deletion claim. |

## Validation — 2026-09-05

- `xcodegen generate`: succeeded.
- Generic iOS Simulator build: succeeded on the final source.
- Full app suite on iPhone 17e / iOS 26.5: **855 tests, zero failures**.
- `python3 scripts/validate-farm-save.py`: **22 tests, zero failures**, covering
  the actual Foundation store and PersistenceService adapter as well as the domain
  document/payload. Seven domain tests also run in the app suite; counts overlap.
- Actual app recovery probe, run ID `farm-save-final`: **15 cases passed**. This
  exercises existing terminal/morning recovery and protection-spy paths with isolated
  defaults and the production coordinator. It does not prove device shielding.
- `git diff --check`: clean. New files are below the repository's 400-line guideline.

Commands used for the final build/test gates:

```sh
xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator'
xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,name=iPhone 17e'
python3 scripts/validate-farm-save.py
```

Physical update/reinstall, disk/power-loss behavior, manual accessibility/layout
acceptance, cloud restore and hosted disaster recovery remain unclaimed. Source work
is not distribution. No account backup endpoint, enrollment or upload is enabled by
this milestone.
