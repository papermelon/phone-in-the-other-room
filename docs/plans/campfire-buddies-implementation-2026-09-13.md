# Campfire Buddies — implemented source, 13 September 2026

The founder approved implementing the [researched refinement](campfire-buddies-research-2026-09-13.md), with all assets consistent with Counting Sheep. This is the current source contract for the second Campfire iteration. It supersedes the version 1 restriction to preset activity categories **only for members who explicitly accept agreement version 2 on a supporting server**. Existing version 1 presence remains compatible. The founder separately authorized backend deployment and push configuration. Both completed on 13 September: [production evidence](../evidence/campfire-buddies-deploy-20260913/deployment.md). App distribution and physical notification receipt remain pending; the earlier [version 1 deployment](../evidence/campfire-deploy-20260913/deployment.md) is a separate record.

## Experience

1. At a manual Wind Down or Phone Away start, choose whether to share, which already-consented parties receive the session, a separately authored intention (80 Unicode scalars), whether to announce the start, and whether a volunteer check-in buddy is welcome. Phone Away retains its preset activity category. Private routine/task text is never used as the public intention. Choices are captured into the admitted plan and its exact consent receipts, so a retry cannot acquire a later audience or newly granted consent.
2. A newly admitted automatic Wind Down uses its currently consented parties and may announce its start. This is disclosed in version 2 settings. It carries no inferred task text and does not automatically request a buddy. Private Wind Downs remain private.
3. Only current sessions appear around the existing paper-textured fire. The familiar Shepherd art and outfits remain unchanged. An active session card shows the shared intention, planned end, accepted buddy and encouragement. A person can start their own session or volunteer to check in afterwards. Volunteering and encouragement never add inactive characters to the fire. Departed or withdrawn buddies free the spot.
4. Party notifications are independently opt-in per recipient/party. Ordinary APNs alerts use generic lock-screen copy without names or intentions. One start event is queued per recipient/source across overlapping parties, with a ten-minute per-party/recipient cooldown. Start invitations expire after five minutes or session expiry, whichever comes first. They are dropped while the recipient is quiet, not replayed after the session is irrelevant.
5. On return, an optional check-in offers **Did it**, **Made progress**, or **Changed plans**, with an optional 160-scalar party note. Completion and early-end receipts include the current session's check-ins when synced; Home offers a route to eligible outstanding check-ins. Wind Down check-ins wait until the planned morning quiet ends. Finishing a timer never marks a task done. The first accepted check-in wins against queued replays.
6. An accepted buddy can ask once how it went after the agreed time. A shared result can notify the accepted buddy. These follow-ups wait through synced active quiet periods and device-local quiet hours, and expire within 24 hours of their due time. Encouragement and buddy acceptance stay in-app.

All core gathering and support actions remain free. The earned lantern, persistent Shared meadow, Farm economy and Ollie's existing equipped appearance are unchanged. No external art, UI library, dependency, entitlement, signing configuration or tab was added for Buddies.

The implemented first iteration uses **one volunteer buddy per session per party**. Named invitations, chat, cooperative mini-games, additional shop charms, and richer notification batching remain later product choices. The research examples showing names in push previews were tightened to generic copy.

## Consent, identity and freshness

- `campfire` stays schema version 1 with additive `buddies` schema version 1; clients ignore unknown buddy capabilities without losing legacy presence. Agreement version 2 separately covers authored text, support and check-ins. Version 1 readers receive no buddy text. Later joiners/consenters receive no earlier intentions.
- New plan fields are optional Codable additions: party IDs and explicit intentions with their exact agreement IDs. Older stored plans decode without them. The existing coordinator and owner-bound outbox remain authoritative; social transport does not block starting or ending protection.
- Server actions recheck active membership, exact consent, source, recipient, block rules and permitted time. Withdrawing consent removes the member's sessions/text, encouragement and buddy commitments when acknowledged. Failed/pending transport remains visible. A stale party observation does not imply current presence.
- Intentions/reflections disappear from projections at seven days. Daily pruning removes expired underlying buddy metadata, so physical deletion can lag by one daily cycle. Withdrawal deletes it sooner. No reward, sleep, placement or task-completion evidence is inferred.
- Device registrations contain a token, authenticated owner, installation ID, environment, quiet-until time, local time zone/hours and monotonic revision. Tokens are private; no party projection exposes them. Registration/revocation revisions and installation locks fence delayed writes, including sign-out before first registration. Foreground refresh handles token rotation. Account switching cannot use the old caller to revoke the new owner's token.
- Tokens expire after 30 days without registration; private revocation tombstones are retained up to 90 days plus the daily cleanup cycle. A logout that cannot reach the server cannot instantly revoke an already registered token. Generic previews limit exposure; do not claim guaranteed immediate remote revocation while offline.
- Default scheduled quiet hours are 23:00–07:00 in each device's current time zone. Matching start/end hours disable the scheduled window. Synced active quiet periods silence invitations across that account's registered devices. iOS Focus and notification settings remain in control. App-reported presence and APNs acceptance do not prove physical offline behavior or actual delivery.

## Backend source and activation

New migrations:

- `20260913140000_campfire_buddies.sql`: version 2 consent, explicit metadata, support/check-in commands and additive state projection.
- `20260913150000_campfire_alert_delivery.sql`: private device registry/revocation fences, durable notification outbox, eligibility/quiet-time checks, bounded leased dispatch and retention/scheduler functions.

New Edge functions are `campfire-device` (validates the caller itself) and `campfire-dispatch` (requires `x-dispatch-secret`). The existing `night-flock-command` must also be deployed with the revised shared validators/handlers. Existing state projection reads the migrated SQL contract; deploy matching `night-flock-state` source with the release for consistency.

The following activation steps were authorized and completed for production on 13 September (device checks in step 5 remain pending):

1. Apply both migrations after the existing Campfire migrations. Verify pg_cron and pg_net in the intended project; isolated tests shim cron registration and never execute network delivery.
2. Deploy the two new functions with gateway JWT verification disabled because their handlers apply the intended authentication. Deploy the matching existing command/state functions using their established gateway configuration.
3. Configure `APNS_ENVIRONMENT`, `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY_P8`, and **`APNS_ALERT_TOPIC` equal to the main app bundle ID**, separate from the existing Live Activity topic. TestFlight uses production APNs. Existing app push entitlements are reused.
4. Configure the dispatcher `DISPATCH_SECRET`; set Vault `campfire_dispatch_url` to the deployed endpoint and `campfire_dispatch_secret` to the same secret. The minute cron job deliberately does nothing until Vault and pg_net are ready. Verify actual job and Edge execution, not just registration.
5. Verify isolated test accounts/devices: consent upgrade/withdrawal, two-party dedup, blocked/departed members, private and automatic Wind Downs, end-before-dispatch, quiet hours spanning midnight, token rotation/account switch, notification denial, offline reconnection and expired deep links. Do not reset or use the founder's Farm as a disposable fixture.

The worker claims at most ten events together, revalidates each leased payload and sends independent device requests concurrently with an eight-second APNs request timeout. Accepted token receipts prevent sibling retries from resending normally acknowledged deliveries. Crashes between APNs acceptance and receipt storage can still replay an event; the stable APNs collapse ID mitigates duplicates but is not an exactly-once guarantee.

## Validation and limits

See [local validation and native screenshots](../../output/design/campfire-buddies-20260913/README.md). Unit/SQL/Node results and Simulator rendering are separate from hosted Edge execution, real APNs delivery, physical VoiceOver, shielding and two-account device acceptance. The backend is now deployed and its empty-queue scheduler responses are verified. Actual APNs receipt and physical acceptance still require a new authorized device build.
