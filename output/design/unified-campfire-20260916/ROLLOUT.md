# Public Campfire rollout preparation

No steps in this document have been executed against hosted infrastructure. Local source implementation does not authorize deployment, capability activation or TestFlight distribution.

## Reviewed source boundary

Apply `supabase/migrations/20260916120000_global_campfire.sql` after the existing account identity, Slumber Party and Campfire migrations. Publish only `supabase/functions/campfire-global` with its imports. The function configuration uses `verify_jwt = false` to permit the existing auth scheme; the handler still verifies the caller with `auth.getUser()`, rejects guests, matches write ownership and invokes only service-only RPCs. No new secrets or packages are required by the source.

The migration leaves `private.global_campfire_settings.enabled` false. Verify an authenticated read returns `available: false` and an empty participant list before any activation. Private Campfire and local protection continue independently.

## Before activation

1. Verify the full hosted dependencies, actual function auth/owner mismatches, direct-table/RPC denial, per-account rate limits and cron registration/execution. The local fixture records cron scheduling without running that extension.
2. Set an operational owner for reports, support/contact and response handling. Review age eligibility, public disclosure, privacy declarations, the 90-day report retention/default backup retention and suspension/appeal procedure. Only preset names/appearance and fixed encouragement ship in this slice.
3. Use disposable verified accounts to exercise zero-party Global, mixed modes, per-party coexistence, active share-from-now, Off/party narrowing, lost replies/retries, terminal-before-start, account changes, block/report and account deletion. Never use the founder’s Farm as a disposable fixture.
4. Load-test activity-filtered reads, cursor paging and rounded counts at the intended rollout cap. This source uses a 20-second foreground poll; it does not claim global realtime scaling or five-second convergence.
5. Confirm a source-matched app build and physical shielding/background/morning/VoiceOver acceptance. A TestFlight archive needs the repository release workflow and a currently confirmed highest uploaded build, not a guessed bump from local build 51.

## Activation and rollback

An authorized operator can enable the single private settings row after the gates above. Existing users still start Off or retain their accepted private audience; activation never accepts a public agreement for them. Global must be explicitly selected in the app.

Disable that row to stop new publication and return no public participants. Withdrawal, block and report commands remain accepted by the server while disabled. Clients hide stale observations within their freshness window; offline acknowledgements are never presented as successful removal. Disabling the public capability does not alter private groups, local timers or settled Farm rewards.

For suspension, the restricted database operator can mark a public profile `suspended`; public reads and further publication are fenced. Reports are in the private reports table with open/reviewed/removed state and a bounded snapshot. No client role has table access. Verify the operational process before inviting public users.

The daily retention job removes session/command records after eight days, rate buckets after two days and report snapshots after ninety days. Account deletion cascades the owner’s public records. Verify job execution and backups separately from read-time expiry.
