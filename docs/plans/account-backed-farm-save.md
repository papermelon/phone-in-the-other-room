# Account-backed Farm save — implementation plan

> 7 September update: ADR-0023 and `account-owned-farm-sync.md` supersede the
> Apple-only, optional-backup and routine restore steps below. Local source now shares
> Apple/password sign-in and automatic Farm sync; authentication alone still does not
> prove a successful restore or server save. See that plan for validation and release gates.

Date: 2026-09-05
Status: **Cloud/backend and app candidate implemented; final device acceptance in progress.**
The founder explicitly approved production deployment on 5 September 2026. The
Farm-only migrations and authenticated RPCs are deployed in production; Apple
provider/manual linking/native bundle ID were verified. See
[deployment evidence and remaining acceptance](../FARM_BACKUP_DEPLOYMENT.md).
The detailed phases below retain the approved plan; distinguish them from completed
validation. Source work and hosted schema do not imply a distributed app or a
successfully uploaded player Farm.

## 1. Outcome and release boundary

A player can sign in with Apple, save their Farm, and recover the last successfully uploaded progress after reinstalling or moving phones. Normal updates preserve local progress whether or not the player has an account. Sheep, wool, owned and equipped cosmetics, capacity, search guarantees, partial meters, and previously settled rewards survive together.

The ritual and local rewards work offline. A failed sign-in or upload never resets the Farm or blocks a session or emergency exit. The UI distinguishes local saving, account authentication, and a confirmed remote save. Work that has not reached the server cannot be promised recoverable after device loss.

V1 provides backup, restore, and explicit resolution of divergent saves. It does not automatically combine simultaneous offline play on multiple phones, move an active ritual between phones, implement player-to-player trading, or make the local economy cheat-proof.

## 2. Verified starting point

- `PersistenceService` stores Farm, search, progress, gifts, and social grant ledgers in separate `ollie.*` UserDefaults JSON values. `load` suppresses decoding failures; some getters fall back to empty values and reconcile/write replacements. Preserve unreadable originals before any migration or write.
- `FarmState` includes individual sheep and ownership, discoveries, wool, equipment, Shepherd customization, transactions, and the new `CumulativeFarmCredit`. `SheepSearchState` and the settlement journal carry additional independent progression and replay state.
- ADR-0020 now preserves cumulative Wind Down/Phone Away credit across early endings and excludes Brief Access; Screen-Free Morning remains independently settled through `SunriseTrail`. A backup must preserve this exact separation and legacy-settlement compatibility.
- Social grants are applied to local Farm/search/ledger values before acknowledgement. This is not a full remote wallet or a transactional cross-device reward store.
- `NightFlockAccountService` links a temporary account to Apple or reopens an existing Apple account. Bound recovery checks the expected Supabase UUID, and social queues are fenced before an identity transition. These protections must survive the app-wide account refactor.
- Supabase v4 stores social memberships, curated appearance, activity and grants. There is no complete Farm save API in the reviewed source. Production state was not inspected for this plan.

References: [PersistenceService](../../PhoneInTheOtherRoomApp/Services/PersistenceService.swift), [Farm models](../../Shared/FarmModels.swift), [cumulative credit](../../Shared/CumulativeFarmCredit.swift), [SunriseTrail](../../Shared/SunriseTrail.swift), [account service](../../PhoneInTheOtherRoomApp/Services/NightFlockAccountService.swift), [v4 schema](../../supabase/migrations/20260825110000_night_flock_parties_v4.sql), [ADR-0020](../DECISIONS/ADR-0020-cumulative-farm-credit.md).

## 3. Account and onboarding flow

| Entry | Intended behavior |
|---|---|
| First welcome page | Add “Already have an account? Sign in.” Resolve restore before granting new welcome rewards. |
| New player after welcome-gift choice, before onboarding completes | Offer “Save your Farm” with Continue with Apple and a local-only alternative. Cancellation keeps the already claimed gift and resumes the draft. |
| Returning player with a cloud Farm | Restore owned progress and gift/practice claim history. Continue only the device setup still needed; do not claim schedules, NFC pairing, or permissions were restored. |
| Existing installation after update | Offer saving contextually on idle Home/Farm or in Settings. Existing linked players also see the new backup disclosure; prior social sign-in does not imply Farm-upload consent. |
| Create/join Slumber Party | Use the same app account. Keep the party-sharing agreement separate from private Farm backup. |
| Settings → Connections → Account & backup | Account, backup choice, last confirmed save, pending work, retry/reconnect, restore/conflict access, sign-out and account deletion. Keep privacy deletion controls discoverable from Privacy & data too. |

No new tab or parallel navigation shell. No recurring auth interruption during active Wind Down. An account can use Farm backup with Slumber Party disabled, and can use Slumber Party without enabling Farm backup. A failed restore lookup is never interpreted as “no save exists.”

Use one shared authenticated Supabase client/session and an injected app-level account service, with a compatibility adapter for the existing NightFlock call sites. Avoid an additional singleton and independent accounts for Farm and social features. Preserve existing bindings under their old key until a verified, crash-safe migration has committed; missing/invalid identity evidence must not create replacement accounts during recovery.

## 4. Save contract and data boundary

Introduce an explicit `FarmSavePayload` rather than uploading UserDefaults, `FocusRun`, `UserProgress`, or the entire settlement journal wholesale. Phase 1 must inventory every field read by reward, migration, replay, shop, and welcome code and produce a checked-in field mapping.

| Included in private account backup | Preservation requirement |
|---|---|
| All owned sheep, including pending and sold records needed for reconciliation | Stable instance IDs, rarity, names, favorites, cosmetics, provenance, shearing/regrowth and lifecycle state; restoring must not resurrect sold sheep. |
| Catalogue and Search Journal | Existing outcomes and IDs, discovered definitions and encounter records; never reroll a resolved search. |
| Wool, capacity, shop tier, all item entitlements | Preserve both ownership and equipment, including items whose artwork/catalogue entry is temporarily unavailable. |
| Shepherd, Ollie, pasture customization | Appearance, placements and chosen presentation; reconcile the separate server-controlled social display-name revision rather than overwriting it from a backup. |
| Cumulative Farm accounting | Wind Down/Phone Away remainders, regrowth, migration markers, consumed spans, immutable receipts and outcomes. |
| Independent morning progression | `SunriseTrail` remainder, drought/guarantee counters, fill outcomes, credited occurrence identities and delivered-benefit markers. |
| Welcome/practice and social grant claims | Stable grant IDs, resolved rewards and applied markers, together with the corresponding inventory/balance. |
| Minimum progression dependencies | Only counters/identities required by current and legacy economy rules, with explicit provenance; do not manufacture a restored Nights history from these. |

Exclude raw Health data, reflections, questionnaire answers/result, routine/purpose text, schedules, notifications, NFC credentials, Screen Time selections/evidence, active-run state, social outboxes, impact records and the detailed 90-day ritual history. Assets remain bundled; save stable identifiers, not images. Restored sheep names are private account data, not newly shared social fields.

**Timing requires an explicit decision record:** cumulative credit contains exact consumed intervals used to prevent overlapping credit, and Farm history includes dates. The proposed backup includes only the accounting intervals and Farm event dates necessary to preserve these rules and the journal; it must disclose them as private Farm accounting data. This is a narrow extension of the current local-only accounting contract, not permission to upload raw ritual history. Do not claim a date-free payload, or simply remove the intervals and weaken replay protection. Finalize the field allowlist and disclosure in phase 1 before enabling upload.

Envelope metadata: payload schema version, economy version, Farm lineage UUID, owner scope (guest or verified account), local generation, cloud base revision, account/backup generation, upload operation UUID, payload digest, and server-confirmed revision/time. Server identity always comes from verified authentication, never a client-supplied owner ID. A digest detects corruption; it is not proof of honest rewards.

## 5. Local persistence hardening

Proposed architecture change: retain UserDefaults for settings, but place the unified Farm save in a versioned JSON document under Application Support, using Foundation only. Record this exception to the current UserDefaults-only architecture in the implementation ADR and canonical docs.

1. Add typed load results: missing, valid, migration-required, unsupported-newer-schema, corrupt, or storage-unavailable. Never collapse these into an empty Farm.
2. Read legacy keys without invoking getters that can mutate them. Preserve their original bytes, validate the complete dependency set, then build the initial unified save. Missing legacy keys follow documented migrations; malformed keys trigger recovery.
3. Serialize all Farm mutations through an injected local save store. Commit inventory, meters, deterministic outcomes, gift/grant markers and the pending-upload identity in one document generation. Keep device-only settlement data local, and reconcile its delivery through stable benefit IDs.
4. Write and validate a staged file, atomically replace the current generation, and retain at least two prior validated generations plus the migration original. Recover interrupted commits using generation/digest checks. Define and fault-test the actual filesystem durability guarantees; a renamed file alone is not evidence of every power-loss scenario.
5. Update observable Farm state only after local commit succeeds. If storage fails, retain the prior view state and a recoverable pending terminal settlement; never present an unsaved purchase or reward as committed. Shield cleanup/emergency exit remains independent and fail-open.
6. Change `PersistenceService` Farm accessors to delegate to the store. Remove competing production write authorities after migration. Keep old keys for recovery, not ongoing independent dual writes.
7. The social grant acknowledgement occurs only after the unified save commits. Retrying any local settlement or grant becomes a no-op with the same result.

The new store must be testable with temporary directories and injected storage failures. Keep new files below approximately 400 lines and extract responsibilities from oversized coordinator/view-model files where needed.

## 6. Supabase schema and API

Use additive migrations and a separately negotiated `farm_save_v1` capability. Do not extend the social profile payload to carry the Farm. Proposed private tables:

| Table | Purpose |
|---|---|
| `farm_save_heads` | One active lineage/head revision per user, backup generation, supported contract metadata. |
| `farm_save_revisions` | Immutable versioned payloads, parent revision, operation ID, digest, server timestamp, origin metadata. |
| `farm_save_operations` | Idempotent command receipts keyed by user + backup generation + operation ID. Same ID with different payload is rejected. |
| `farm_save_conflicts` | Preserved divergent candidate and its base/head references, awaiting explicit resolution. |
| `farm_save_controls` | Backup enable/disable/deletion generation and revocation fences preventing stale devices from recreating deleted backups. |

Expose authenticated read-head, read-revision, commit, resolve-conflict, disable, and delete-backup commands through a small Edge Function/RPC boundary. A transaction locks the user's head, verifies the expected revision/generation, records the operation and revision, and advances the head together. Initial creation also uses conditional creation; concurrent first uploads cannot overwrite each other.

Return explicit unsupported-schema, conflict, backup-disabled/deleted, authentication-required and retryable-failure results. A timeout after a server commit is recovered by the same operation ID. Do not retry with a new ID or rely on device clocks for ordering.

Apply least-privilege grants and owner isolation. Private tables have no direct client grants; narrowly scoped functions validate ownership and generation. If a client-readable surface is introduced, enable owner-only RLS. Service-role credentials stay server-side and every service-role path independently verifies the requester. Test anonymous, wrong-account, expired-session and cross-account revision access. Supabase's [RLS guidance](https://supabase.com/docs/guides/database/postgres/row-level-security) explains the identity boundary; RLS must not be assumed to protect a bypassing service-role path.

Validate payload schema, bounded size/depth, IDs, nonnegative balances and referential integrity. Preserve unknown catalogue IDs for forward compatibility rather than stripping ownership. Reject unsupported schemas without replacing local or remote saves. Treat the imported legacy Farm as client-recorded state; structural validation is not server verification of all past earnings.

Set tested operational limits before deployment using long-lived Farm fixtures. Do not prune consumed-span or settlement identities to fit a payload limit. If a complete save exceeds the limit, keep it locally and report backup failure; introduce a versioned larger/chunked contract before promising indefinite capacity.

## 7. Upload, restore and conflicts

**Upload:** local commit first, then coalesced upload while the app has execution time. Reconcile at foreground, successful account connection and after meaningful Farm mutations. Background execution is best effort. The acknowledged generation is distinct from the current local generation: if another mutation occurred during upload, the newer work remains pending. Cancel/fence stale callbacks by account and backup generation.

**First account attachment:** fetch the remote head before uploading. If definitively absent, conditionally seed from the preserved local Farm. If a remote Farm exists and the local installation is untouched starter state, preview and restore the remote Farm. If the player has chosen a different gift or earned/spent anything locally, preserve both and use conflict resolution. The same guest lineage cannot be silently attached to multiple accounts.

**Returning restore:** authenticate → fetch → validate schema/digest and complete payload → stage locally → commit → hydrate Farm and recompute presentation → reconcile social grants. Gate welcome/practice issuance until restoration is resolved. On a fresh phone, continue required local setup without reclaiming gifts. A network error leaves a retryable restore state; the user may explicitly continue locally as a separate guest branch without overwriting the account save.

**Active session:** do not replace the Farm underneath a running/settling ritual. Keep auth lookup non-destructive, finish/persist the local settlement, then reconcile restore or conflict. No imported run starts shields, notifications or Watch activity.

**Two changed phones:** if the local base revision differs from the remote head and local work exists, preserve the candidate and stop automatic head advancement. Show both saves with server save time, sheep, wool, owned item counts and pending local work. Let the user choose which Farm to continue; retain the unselected branch as a recoverable archive. Warn clearly that selecting a branch does not combine its balances or items. Resolution is itself conditional on the head reviewed by the user, so another upload forces a refreshed comparison.

There is no last-write-wins merge, balance addition, or automatic union of inventories: those can recreate spent wool or sold sheep. “Keep both” means preserve both branches, not mint a combined Farm. V1 does not offer arbitrary historical rollback as an economy shortcut.

**Social grants and older revisions:** acknowledgement alone is not a restore ledger. The selected snapshot carries its applied grant IDs and corresponding result. Reconcile issued server grants against those IDs, even if an acknowledgement was sent by a now-lost device. Ensure one grant applies once per selected lineage and do not upload until reconciliation commits. Older-snapshot recovery is explicitly a recovery to that point; it cannot guarantee unbacked-up spending survived. Retain existing grant provenance needed for recovery when parties are deleted, without expanding party access to the Farm.

## 8. Account lifecycle, deletion and retention

- Sign-out stops uploads, fences callbacks and clears remote caches. Preserve the Farm under its original local owner scope; it may continue offline for that owner and must not silently upload to a different account. Account switching uses the same restore/branch rules and existing social queue isolation.
- Disabling backup stops new uploads and explains whether the existing restore copy remains. Provide a separate delete-backup action. Re-enabling after deletion requires an explicit current-generation request, not an old queued operation.
- Deleting the online account deletes Farm heads, revisions, branches and operation data through the shared deletion flow, as well as the existing account-owned online data. Leaving a party does not delete the Farm. Do not create a second, conflicting account-deletion UI/API.
- Local reset never uploads an empty Farm over an existing account save. Update the centralized storage/reset contract for files, legacy keys, queues, owner scopes and deletion fences. Define “reset this phone” separately from “delete online account.”
- Proposed retention default: keep the latest good save for the life of enabled backup; keep prior validated revisions for 30 days with at least the latest 10 retained; keep unresolved/explicitly archived conflicts until the user resolves/deletes them. Coalesce routine saves to control growth. Finalize retention, quotas and purge operations in phase 1; never silently remove a branch promised recoverable.
- Confirm the actual hosted database-backup configuration and perform a restore drill. Application revisions do not replace disaster recovery. Supabase backup availability depends on project configuration/plan; see [database backups](https://supabase.com/docs/guides/platform/backups). Document how deleted data ages out of operational backups and prevent recovery procedures from republishing deleted accounts' data.
- Record operational errors/counts/schema versions without logging save payloads, sheep names, tokens, or accounting intervals. Cloud saving is not end-to-end encryption unless separately implemented; do not describe it as such.

## 9. Implementation sequence and exit criteria

| Phase | Work and likely locations | Exit criterion |
|---|---|---|
| 1. Contract and fixtures | New ADR; field map; migration fixtures; `Shared/FarmSave*.swift` contract/state rules; privacy and retention choices | Every reward/replay dependency mapped, excluded fields tested, legacy/current/unknown-schema fixtures defined. Reconcile AGENTS/architecture's local-only wording as a planned exception. |
| 2. Local durability | `Services/FarmSaveStore.swift`, persistence adapters, coordinator/Farm intent integration, welcome/social/morning settlement integration | Fault injection at each commit boundary preserves a valid Farm and no duplicate grants; update/relaunch migration proven without network. |
| 3. Backend | Additive SQL migration, Farm API functions, SQL/Deno tests, capability response | Owner isolation, conditional initial create, retry idempotency, stale revisions, deletion fencing and retention tested locally. No production deployment implied. |
| 4. Shared identity and transport | App account service/adapters, `FarmBackupService`, account-scoped queue and restore state | Existing Apple-linked social accounts recover unchanged; backup works with social feature off; wrong-account/401/late callbacks preserve local work. |
| 5. User flow | Onboarding returning-user/save steps, Account & backup detail, status and conflict views using Theme tokens | Guest, restore, cancel, offline, corrupt, pending, conflict and update-required states are readable and resumable; no accidental reward regrant. |
| 6. Integrated validation and rollout | Privacy documents, backend runbook, local reset/deletion changes, staged backend/client release | Full test gates plus physical update/reinstall/two-device evidence pass; server backup restore drill and feature rollback proven. |

Each phase depends on the preceding contract and invariants. Do not build UI that says “backed up” before the confirmed-save path exists. No additional packages, entitlements or tabs are expected; any required build configuration changes follow AGENTS.md's explicit approval rule. Use a separate Farm capability rather than coupling availability to Slumber Party release configuration.

## 10. Required evidence

Automated tests must cover:

- Legacy migration containing rare sheep, sold and pending sheep, custom names, sheared/regrowing sheep, all cosmetic slots, spent wool, capacity, cumulative remainders, morning progress and welcome claims.
- Missing versus malformed keys; interrupted migration/commit; encoder/write failure; corrupt current save with good prior generation; unknown future schema and unknown item IDs.
- Replay of terminal runs, overlapping credited spans, early endings, Brief Access exclusions, practice, welcome selection, morning fills and social grants after restore. No rerolls or duplicate wool.
- Lost upload response, duplicate operation with changed body, offline edits, a newer mutation during upload, two simultaneous seed attempts, conflict resolution racing a new head, and clock skew.
- Sign-in cancellation, existing Apple identity, invalid binding, refresh failures, 401 recovery, account switching during requests, social feature disabled and no accidental new anonymous identity in recovery.
- Restore lookup failure never seeding over a server Farm; returning onboarding never issuing a second welcome/practice gift; restore deferred during an active run.
- Save allowlist excludes local-only information; cross-account access denied; service-role route identity checks; stale uploads after disable/delete/reset; account deletion cascades and backup recovery fences.
- Payload growth and retention on a long-lived Farm without dropping durable settlement identities.

Run repository build/tests on an available iPhone simulator after code implementation, regenerate XcodeGen when source/project structure changes, and run SQL/Deno suites using the repository backend test tooling. The unit target currently compiles Shared logic; use an existing app/service test harness where possible or obtain the required project-configuration approval to add meaningful filesystem and service integration coverage.

Physical acceptance: install an older build with a populated Farm, update in place, confirm exact progress; save and reinstall, sign in and restore; repeat on a second phone; exercise offline earnings and conflicts; reconnect with the wrong Apple account; verify local Wind Down continues during an outage. Compare canonical save values and IDs, not only screenshots or aggregate counts.

Roll out local migration first, backend capability second, and backup enrollment last through an internal/test cohort. On rollback disable new uploads/enrollment while retaining local saves and safe restore reads. An older binary that cannot understand the new local schema must not replace it. Ordinary upgrades are supported; arbitrary app downgrades need an explicit tested policy.

## 11. Definition of done

An existing player can update without losing local progress, explicitly enable backup, earn and spend offline, confirm the latest revision is saved, reinstall, sign in and recover the same Farm and future reward behavior. An older cloud revision, competing phone, corrupt save, auth failure or deletion request never silently replaces valid progress or duplicates rewards. The UI states exactly what is saved locally and what is recoverable online. Hosted deployment and physical-device results are recorded separately from source completion.
