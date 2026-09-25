# ADR-0023 — Account-owned Farms and multiple sign-in methods

Date: 2026-09-07
Status: Founder direction accepted and implementation authorized; local source implemented, validation in progress.

## Decision

Each account owns its Farm. Account use includes automatic private Farm synchronization;
users do not separately enable optional backup. Signing in loads the account's Farm.
Explicit sign-out removes that Farm from the active, playable app; it does not delete
the server Farm. Another account must never inherit its progress.

Founder clarification, 25 September 2026: the account Farm is the default even
when the phone has a divergent saved branch. Archive the displaced phone branch
before atomically loading the verified account head, then resume automatic sync.
Do not routinely require a Farm choice or combine balances. Same-base offline
edits still upload normally; failed lookups never imply an empty account.

Support native Apple sign-in plus username/handle or email and password. Handle and
username are one login identifier. The immutable verified account UUID remains the owner
regardless of sign-in method. Linking credentials must not create or merge Farms.

This supersedes ADR-0021's optional-backup product model and playable bound Farm after
logout, and ADR-0022's Apple-only/separate backup-enrollment and routine explicit-restore
steps. Preserve their durable local store, private payload boundary, accurate save claims,
reward idempotency and device setup separation. Existing declined upload consent requires
a migration explanation and acceptance, not silent enrollment.

## Plan and limits

See [the implementation plan](../plans/account-owned-farm-sync.md) for account
isolation, guest handling, password recovery, linking, migration, sync conflicts and UI.
Retaining guest mode, email-backed password recovery and inaccessible offline sign-out
recovery are the implemented defaults. Authentication does not prove the Farm
has finished loading or syncing. Detailed local histories are not newly authorized uploads.

The founder approved proceeding with implementation. Local implementation and automated validation
are recorded in the plan. Production provider configuration, deployment, physical-device checks
and app distribution are not represented as complete.
