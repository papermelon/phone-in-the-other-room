# ADR-0021 — Account-backed Farm save

Date: 2026-09-05. Founder direction accepted; implementation in progress.

Product-model update, 2026-09-07: [ADR-0023](ADR-0023-account-owned-farm-sync.md)
supersedes optional backup enrollment and playable account Farms after sign-out.
The durable store and private payload boundary below remain applicable.

## Decision

Offer an optional private Farm backup attached to the existing Apple-linked Supabase
account. Returning players can sign in at welcome; new players can choose to save
after their welcome gift, before finishing onboarding. Account and backup controls
belong in Settings and do not depend on joining Slumber Party. Social sharing and
Farm backup have separate disclosures. Existing social sign-in does not enroll a
player into Farm uploads automatically.

Offline play remains supported. Restore checks the server before uploading a local
Farm. Divergent progress is preserved in separate branches for explicit selection;
balances and inventories are not automatically added together. Only a confirmed
server revision permits a claim that the current Farm is backed up.

## Local foundation

Farm persistence moves from independent UserDefaults values to a device-only JSON
transaction document in Application Support. `FarmSaveDocument` carries progress,
rewards, Farm, search, welcome/social grant ledgers, and the private Wind Down/morning
settlement journal. Three validated generations are retained, plus the original
legacy JSON values and any corrupt generations. All remain local.

`FarmSaveStore` validates before publication, writes a new generation atomically,
and publishes its memory state only after the write succeeds. Nested transactions
fail together even when a compatibility setter catches an error. Purchases and
grants roll observable state back on failure; social acknowledgements wait for a
successful commit. Morning delivery is retried using its immutable fill IDs.

Missing legacy values can migrate using existing compatibility rules. Unreadable
data never becomes a committed empty Farm. A newer schema is an update-required
condition, not a reason to fall back to an older save. A missing store after a known
migration cannot silently re-import stale defaults. A local reset publishes an empty
generation before removing older files and clears the legacy values only after the
file reset succeeds. Defaults remain the store for other app settings and history.

This is an explicit exception to the prior UserDefaults-only architecture. It adds
no dependency, target, entitlement or parallel run state machine. Atomic file writes
protect process-interruption boundaries; they are not a claim of guaranteed recovery
from storage hardware failure or loss before a successful write.

## Private backup boundary

The local transaction document is **not** a network payload. It contains private
daily records, active/deferred morning scheduling and terminal authorization data.
The remote contract must be projected through the field allowlist in
[the save contract](../plans/farm-save-contract.md).

Minimal consumed reward intervals and Farm event dates are necessary to preserve
ADR-0020's overlap protection and Search Journal. Disclose their private backup
purpose; do not claim the backup is date-free. Detailed ritual history, raw Health,
reflections, questionnaire data, app selections, NFC credentials and social outboxes
remain outside this contract. This decision does not make inventory or wool visible
to Slumber Party members.

## Delivery and remaining gates

Follow [the implementation plan](../plans/account-backed-farm-save.md). Local save
protection, cloud contract/API, account flow, hosted deployment and physical update/
reinstall validation are separate milestones. No new data upload or deployed Farm
backup is implied by the local persistence implementation.

## Production authorization — 5 September 2026

The founder explicitly approved production Supabase deployment, verified Apple
sign-in configuration, updated backup disclosures and physical-device testing.
The implementation uses a private authenticated Postgres RPC (`farm_save_v1`)
with account identity derived from Auth, rather than an additional Edge Function
or an object-storage bucket. This keeps revision publication, operation receipts,
conflicts and deletion fencing in one database transaction. No service key ships
in the app. Deployment evidence belongs in `docs/FARM_BACKUP_DEPLOYMENT.md`.
