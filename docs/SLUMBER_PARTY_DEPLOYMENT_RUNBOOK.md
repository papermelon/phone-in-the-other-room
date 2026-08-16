# Slumber Party deployment runbook

Preparation only. This runbook was not executed. The release flag remains `NO`, and no hosted
Supabase project was changed.

1. Backup and preflight

   - Confirm the target Supabase project, migration head, Edge Function revisions, Auth provider
     settings, Cron jobs, moderation owner, privacy policy, and App Store disclosures.
   - Take a database backup and record the migration version and function checksums.
   - Confirm ordinary Release still resolves `SUPABASE_NIGHT_FLOCK_ENABLED=NO`.
   - Confirm two Apple-linked test accounts, a support contact, and a rollback owner.

2. Migration ordering

   - Apply the existing deployed-style `20260812120000_night_flock_mvp.sql` if the target does not
     have it, then apply `20260816100000_night_flock_shared_commitment_v2.sql`.
   - Run `supabase db lint`, reset/test on a disposable local copy, and run the SQL Night Flock
     test before hosted application.
   - Verify RLS, service-role grants, constraints, retention indexes, and the v1 compatibility
     path before accepting traffic.

3. Edge Functions

   - Deploy `night-flock-command` and `night-flock-state` after the migration.
   - Verify schema-one commands still work and schema-two commands reject unknown fields,
     unsupported goal kinds, invalid targets, oversize routine lists, unauthenticated users, and
     non-members.
   - Exercise idempotent retry, reusable invite redemption, capacity eight, and host-start gates.

4. Apple authentication

   - Configure Sign in with Apple for the exact production App ID and Supabase Auth provider.
   - Confirm manual linking preserves the existing Auth UUID and does not make local Wind Down
     require an account.
   - Do not add entitlements or signing changes from this runbook without human approval.

5. Retention scheduling

   - Schedule the service-role retention job for invite rows after 30 days, nightly progress and
     reactions after 90 days, and completed commitments after at most 12 months.
   - Prove deletion of a party and full online account removes social rows while local data stays.

6. Moderation ownership

   - Assign an owner and response window for blocks, fixed-enum reports, abuse review, and account
     deletion requests.
   - Verify service-only moderation actions and audit logging without exposing private routines,
     app tokens, or impact records.

7. Privacy and App Store disclosures

   - Publish the updated privacy policy and App Privacy answers for member-level shared-goal
     progress, optional guidance IDs, fixed reactions, and Apple-linked identity.
   - State clearly that Family Controls tokens/app lists never leave the device and that impact
     sharing is separate from Slumber Party sharing.

8. Two-device/two-account physical QA

   - Run `docs/PLAYBOOKS/slumber-party-qa.md` on two physical iPhones with two Apple-linked
     accounts, including create/join, reusable code, seven nights, offline outbox, private/no
     update, reactions, block/report/delete, Dynamic Type, VoiceOver, contrast, reduced motion,
     and Instagram limitation copy.
   - Confirm active Wind Down has no social interruption and local shielding remains fail-open.

9. Feature-flag rollout

   - Keep `SUPABASE_NIGHT_FLOCK_ENABLED=NO` during migration and QA.
   - After written approval of hosted, privacy, moderation, and physical gates, enable only the
     dedicated staged environment first, inspect logs and support signals, then consider a narrow
     production cohort. Never enable the flag as part of migration deployment.

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
     npx supabase functions deploy night-flock-command --project-ref "$SUPABASE_PROJECT_REF"
     npx supabase functions deploy night-flock-state --project-ref "$SUPABASE_PROJECT_REF"
     npx supabase db push --project-ref "$SUPABASE_PROJECT_REF"
     ```

   These commands are intentionally not run in this task. Hosted deployment, production flags,
   migrations, and function rollout require explicit authorization.
