# Slumber Party invitations production deployment — 21 September 2026

Founder authorization: “Yes, please proceed with deploying the invitation backend.”

Deployed only `20260921120000_slumber_party_invitations.sql` to **counting-sheep-prod**, `sxjlkcccsentmhowgoqe`, Singapore. The existing authenticated CLI reported ACTIVE_HEALTHY, and the Release app configuration resolved to that same production host. No blanket migration push, Edge Function deployment, invitation-key change, app archive or TestFlight upload was performed.

## Deployment and verification

- [Preflight](preflight.json) confirmed the existing account username table/RPC, verified-account guard, party/block contracts and Global rate limiter. The new migration had not already been applied. Unrelated pending shared-night, private-bedtime and Campfire-profile migrations were not applied.
- [Rollback rehearsal](dry-run.json) applied the exact migration and ran the invitation SQL suite against hosted dependencies inside one transaction, then rolled everything back. Four fresh randomized primary fixture IDs and a unique handle were checked for collisions before use; additional test users were generated randomly. Every mutation remained within those synthetic accounts and their parties.
- The rehearsal exercised **the existing authenticated `account_username_v1('claim', …)` path**, then found that same account through exact invitation handle search. A real authenticated database-role invocation of the invitation state RPC also succeeded.
- [Deployment](deploy.json) applied the migration and recorded its exact text in `supabase_migrations.schema_migrations` in one transaction, using a five-second lock timeout and sixty-second statement timeout. A preflight function fingerprint guarded against concurrent changes. PostgREST schema reload was requested after commit.
- [Post-deployment tests](post-tests.json) passed against the installed schema: capability `directInvitationsVersion = 1`, exact lookup, caller validation, duplicate send/accept, blocks, recipient checks, decline cooldown, revoke, expiry, capacity limits and rate limits. Membership acceptance did not fabricate an agreement receipt. All test data was rolled back.
- [Postflight](postflight.json) confirmed the migration text matched local source, RLS was enabled, direct table access remained denied, the public invitation RPC allowed authenticated callers and denied anon, and the existing state RPC remained service-only. No fixture users or handles remained; zero invitation rows were present at verification.
- [HTTP check](http-anonymous-check.json) reached the published production RPC and received the expected HTTP 401 / PostgreSQL `42501` permission denial for anonymous access. No private credential was printed or stored in the evidence.
- [Source hashes and fixture identities](source-sha256.json) record exactly what was checked. CLI 2.117.0 used `db query --linked --project-ref sxjlkcccsentmhowgoqe --file <reviewed SQL>`. Prepared scripts remain at `/private/tmp/slumber-invitation-deploy-20260921`.

## Account setup integration

The invitation handle is the existing account **username**, stored in `private.account_usernames`; it is not the editable Shepherd display name. Email/password registration asks for a username and claims it after verification. Existing Apple accounts may choose one through **Sign-in and username → Choose a username**. A handle is optional for those existing accounts; their verified immutable account UUID is already available for exact user-ID invitations. The app's new invitation inbox exposes **Your handle and user ID** for sharing.

## Remaining boundary

The backend is live; the repaired native app has not been distributed by this task. Its new controls appear when the updated app sees the deployed capability. Existing released clients retain their code flow. Native signed-in HTTP delivery and two-account physical create/join/receipt/invitation checks remain outstanding, as do spoken VoiceOver and system Reduce Motion checks. The prior screenshot's unrelated hosted error was not diagnosed from historical request logs.

If containment is needed, preserve invitation records and use an authorized additive change to remove the advertised capability and revoke the new RPC's execution grant. Do not drop tables, rewind accepted membership or revoke existing group agreements as a rollback shortcut. No rollback was performed after deployment.
