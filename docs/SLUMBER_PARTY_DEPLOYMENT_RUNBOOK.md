# Slumber Party deployment runbook

The founder explicitly authorized the production Slumber Party backend deployment on 2026-08-25.
The Release/TestFlight production project received all five Slumber Party migrations, both
JWT-protected Edge Functions, and invitation-encryption key version 1. Its migration head is
current, both functions are ACTIVE, unauthenticated requests return HTTP 401, and the public Auth
settings report Sign in with Apple enabled. The repository itself remains linked to the separate
development project, so production commands must always specify the verified production project
reference explicitly. Updated app distribution, actual Apple account linking, physical two-account
QA, moderation/retention operations, and privacy publication remain incomplete.

Ordinary Debug remains `NO`. TestFlight/Release archives compile with
`SUPABASE_NIGHT_FLOCK_ENABLED=YES`.

1. Backup and preflight

   - Confirm the target Supabase project, migration head, Edge Function revisions, Auth provider
     settings, Cron jobs, moderation owner, privacy policy, and App Store disclosures.
   - Take a database backup and record the migration version and function checksums.
   - Confirm ordinary Release resolves `SUPABASE_NIGHT_FLOCK_ENABLED=YES` and does not define
     `SLUMBER_PARTY_QA`.
   - Confirm two Apple-linked test accounts, a support contact, and a rollback owner.

2. Migration ordering

   - Apply, in order, `20260812120000_night_flock_mvp.sql`,
     `20260816100000_night_flock_shared_commitment_v2.sql`,
     `20260816220000_night_flock_social_rewards_v3.sql`,
     `20260824150000_night_flock_invite_recovery.sql`, and
     `20260825110000_night_flock_parties_v4.sql`. Production completed this sequence on
     2026-08-25.
   - Run `supabase db lint`, reset/test on a disposable local copy, and run both Night Flock SQL
     suites before later hosted schema changes.
   - Verify member-only RLS, service-role grants, active-member status/reaction isolation,
     transactional five-party membership, surviving member grants, and v1–v4 compatibility.
     Do not rewrite or drop legacy compatibility objects while older clients may retry.

3. Edge Functions

   - Before deploying the command function, provision `NIGHT_FLOCK_INVITE_KEY_V1` with 32
     cryptographically random bytes encoded as base64. `NIGHT_FLOCK_INVITE_KEY_VERSION` selects
     the active version. Retain old versioned keys until every invitation using them is retired;
     never print, commit, or include key values in evidence.
   - Deploy `night-flock-command` and `night-flock-state` after the migrations, retaining JWT
     verification. Both production functions were deployed and verified ACTIVE on 2026-08-25.
   - Verify legacy schema contracts, strict v4 state/command shapes, idempotent retry, current
     member invitation recovery, group capacity eight, five concurrent parties, late-round
     joining, host-start gates, fixed cheers, and rewards scoped to each eligible party.

4. Apple authentication

   - Configure Sign in with Apple for the exact production App ID and Supabase Auth provider.
   - Confirm manual linking preserves the existing Auth UUID and does not make local Wind Down
     require an account.
   - Do not add entitlements or signing changes from this runbook without human approval.

5. Retention scheduling

   - Approve and schedule the service-role retention job for legacy and v4 invitation, status,
     factual activity, reaction, grant, tombstone, and moderation records. Existing legacy purge
     behavior does not by itself prove v4 retention coverage.
   - Prove deletion of a party and full online account removes social rows while local data stays.

6. Moderation ownership

   - Assign an owner and response window for blocks, fixed-enum reports, abuse review, and account
     deletion requests.
   - Verify service-only moderation actions and audit logging without exposing private routines,
     app tokens, or impact records.

7. Privacy and App Store disclosures

   - Publish the updated privacy policy and App Privacy answers for current-member display names,
     curated Farm looks, rounded Wind Down/Phone Away records, expiring statuses, fixed cheers,
     party-scoped Farm grant delivery, and Apple-linked identity.
   - State clearly that Family Controls tokens/app lists never leave the device and that impact
     sharing is separate from Slumber Party sharing.

8. Two-device/two-account physical QA

   - Run `docs/PLAYBOOKS/slumber-party-qa.md` on two physical iPhones with two Apple-linked
     accounts, including named create/join, member-shareable invitation, repeatable seven-night
     rounds, late backfill, five-party membership, offline outbox, profiles, live cheers,
     block/report/delete, Dynamic Type, VoiceOver, contrast, and reduced motion.
   - Confirm active Wind Down has no social interruption and local shielding remains fail-open.

9. Feature-flag rollout

   - Ordinary Debug stays `NO` during local development.
   - TestFlight/Release compiles with `YES`. Production migration, versioned invitation secrets,
     both JWT-protected functions, and the enabled Apple provider are verified. App distribution,
     actual Apple identity linking, retention, moderation, and physical QA remain separate gates.

10. Rollback criteria and commands

   - Roll back if RLS leaks data, Apple linking changes ownership, invite redemption exceeds eight,
     local Wind Down is blocked, tokens/app lists appear in logs or rows, deletion fails, or the
     physical QA matrix is incomplete.
   - Immediately disable the feature flag and stop new invites. Preserve the database backup and
     incident evidence.
   - Revert the Edge Functions to the last compatible revision, then restore the database only under
     the approved incident plan; do not destructively drop v2 tables while clients may retry.
   - Example commands, to be run only by the deployment owner:

     ```sh
     npx supabase db push --dry-run --project-ref "$SUPABASE_PROJECT_REF"
     npx supabase db push --project-ref "$SUPABASE_PROJECT_REF"
     npx supabase functions deploy night-flock-command night-flock-state \
       --project-ref "$SUPABASE_PROJECT_REF"
     ```

   Production deployment was explicitly approved and completed on 2026-08-25. Subsequent
   production mutations, credential rotation, rollback, or account-setting changes require their
   own scoped authorization.
