# Social upgrade — 29 September 2026

The founder authorized implementation, a researched wider cheer range, Associated Domains for www.countingsheepproject.com, and production backend deployment after validation. Native distribution and live website publication remain separate.

## Implemented

Slumber Party remains a private group, including two-person groups. Exact handle lookup has independent loading/errors, explicit Paste/Clear, stable result confirmation, and shareable own handles. Invitations and For you are prominent on party entry; Home Inbox provides invitations, named private cheers, anonymous Global aggregates, source details and notification choices. The nine permitted messages have contextual defaults, exact-text previews, persistent sending/retry identity, confirmed Sent and explicit removal. Old gestures retain their historical meaning. Arrival time drives received-message ordering and Home freshness.

An account-bound local journal preserves uncertain sends and party acquisitions. A known rejection releases acquisition; an uncertain response preserves its command UUID. Source authorization is rechecked on opening, sending, reading and dispatching; blocks, membership epochs, consent withdrawal and deletion fence visibility. New messages do not change the legacy Watch reaction enum or add a new Watch/Live Activity transport.

## Backend rollout

Production: `counting-sheep-prod`, `sxjlkcccsentmhowgoqe`. Applied only `20260928120000_social_inbox.sql` and `20260928130000_social_alerts.sql`, then the existing `campfire-dispatch` revision. The repository's development link was not changed. The unrelated shared-night-plan migration remains absent.

A single production transaction rehearsed the exact migration source and migration-history inserts, ran four SQL regression scripts with randomized disposable identities, and rolled back. Follow-up inspection confirmed both new schema and migration records absent and both replaced functions unchanged. Deployment repeated the guarded transaction with five-second lock and 90-second statement timeouts, stored exact source in migration history and reloaded the API schema. Post-deployment synthetic tests rolled back successfully. No real notification was sent by validation.

APNs delivery reuses the current device registry and dispatcher secret. Defaults are off; Global is a separate opt-in. Cheers batch for two minutes and are bounded to one alert/hour and three/local day; registered active/scheduled quiet windows suppress dispatch. The worker rechecks eligibility and token ownership immediately before each send. APNs acceptance is recorded per token; no claim of physical receipt or reading. Invitation alerts can exist before membership. Cleanup is scheduled; dispatch functions remain service-only and Inbox requires a verified matching account.

Hosted migration records match both source hashes. `campfire-dispatch` version **3** is **ACTIVE**, retaining its existing internal secret authentication (`verify_jwt=false`).

Source MD5: Inbox `e9f42c7b266b7461c2468a63a50fa337`; alerts `6cbf95b6a6db2073b3f06a501014e690`.

## Validation

- Full app build succeeded. Final full unit suite: **1,146 tests, zero failures** (`/tmp/social-upgrade-picker-tests.xcresult`, `/tmp/social-upgrade-picker-tests.log`), after the final picker first-open and accessibility fixes.
- Deno check passed for `supabase/functions/campfire-dispatch/index.ts`; social/APNs tests: 5 passed.
- Clean PostgreSQL 17 migration application and four SQL suites passed: social Inbox, social alerts, existing invitations and existing cheer receipts. The same suites passed in hosted rollback rehearsal and post-deployment rollback checks.
- SQL coverage includes owner spoofing, anonymous/raw access, invitation read versus pending state, late cheer on old source, idempotency/removal, permitted wording, block/leave fences, two-minute dispatch, concurrent leases, privacy, quiet hours, account-wide quiet state, token reassignment, hourly throttling, Global opt-in and withdrawal, invitation revocation. Daily cap and daylight-saving behavior are implemented but not separately physically validated.
- Dispatcher without its secret returned HTTP 401. Anonymous Inbox and authenticated dispatch execute grants are absent. Retention cron is active.
- Large-text Inbox inspected in the iPhone SE Simulator: cards wrap and source/arrival labels remain readable; accessibility exposes complete message labels. After unlocking, the final picker was inspected at accessibility3: its default is visibly selected on first open, selecting another phrase updates the exact Send wording, all choices and Send remain reachable by scrolling, and accessibility exposes the selected trait. Selection itself does not send. Screenshots: `output/validation/social-upgrade-20260929/cheer-picker-large-text.png` and `cheer-picker-send-preview.png`. Physical VoiceOver speech remains untested.
- `git diff --check` passed. No commit, push or app archive was created. Unrelated account/shielding/Screenbook edits were preserved.

Early validation repairs: removed an invalid test-target module import; corrected a membership fixture whose sample activity predated joining; added fresh-arrival and rejection-recovery tests. A temporary local SQL harness omitted the tests' transaction boundary, retaining only disposable fixtures and causing a later assertion collision. The clean harness and hosted rehearsal used explicit rollback transactions and passed; production rehearsal left no data behind.

## Website and remaining acceptance

Companion theme source: `/Users/ngawangchime/Desktop/Developer Projects/Counting Sheep Landing Website/counting_sheep_project`. Theme 3.4.1 adds a generic invitation fallback, copyable code, the existing beta download CTA and Apple association JSON for Team `4KZQPZR47B`, bundle `com.ngawangchime.countingsheep`. No private party lookup is performed on the website. App links open review, never automatic joining. Canonical app links use apex; apex and www are accepted because the live website redirects www to apex.

WordPress staging confirmed “Theme updated successfully.” The runtime-only ZIP has 58 files, SHA-256 `ae672b037ec3442f3f0919643d998588704c490c54bf0252b1798b1c776216d7`; rollback theme 3.4.0 has 57 files, SHA-256 `718cbf7c5452e25f74d34f941e6c8146e4943273bd9a477502906894fac28b96`. Both are preserved in `output/validation/social-upgrade-20260929/` (initial upload copies are in `/tmp/social-upgrade-website/`). Website forms, settings, plugins, uploads and database were not copied or changed.

**Manual staging evidence:** the founder supplied screenshots showing the complete invitation fallback rendering with its code, Open/Copy controls and TestFlight CTA. The association URL initially displayed SiteGround's 404 page. After the guided static-file installation, a follow-up screenshot shows the exact `/.well-known/apple-app-site-association` URL displaying the expected JSON, including `4KZQPZR47B.com.ngawangchime.countingsheep` and `/invite/*`. The visible 404 is resolved. Copies are preserved in `output/validation/social-upgrade-20260929/staging-invitation-user.png`, `staging-aasa-404-user.png` and `staging-aasa-json-user.png`. On 30 September, the founder followed the Copy code check and pasted `ABCDEFGHJKLM`, exactly matching the displayed sample. Copy is confirmed through this assisted check. The screenshots and paste do not verify the Open app action, HTTP headers/status, redirects, Apple CDN access or mobile breakpoints.

Prepared an extensionless [static association file](hosting/apple-app-site-association) and [staging installation instructions](hosting/README.md). Its JSON matches theme 3.4.1 and the app's configured identity/scope; SHA-256 is `df3230de3976123107955112418304335d275d7278d5e74a1cb80b3d18309233`. The founder's File Manager screenshot confirmed the staging document root at `staging3.countingsheepproject.com/public_html`; the subsequent browser screenshot confirms the expected file content is now served there. No hosting configuration was inspected or changed by the agent. Live publication remains pending.

**Access remains blocked:** the founder's full-address screenshot confirms `https://staging3.countingsheepproject.com` with Browsing → Always allow. Tool access still reported a saved block after the founder quit and reopened Codex. An earlier attempt was also rejected by automatic approval review. No alternate browser or network workaround was used. Still validate the association HTTP response, incomplete invitation page, responsive layout and existing homepage before seeking live scope approval. Check apex and www serve association JSON without redirects when live deployment is authorized.

Native app remains undistributed. Verify physical two-account APNs, signed universal links, onboarding handoff, VoiceOver speech and complete invitation/search flows. No physical shielding, sleep, placement, message reading or delivery proof is inferred from these tests. Follow-ups are in `docs/FUTURE_AGENT_TASKS.md`.

**30 September branding revision:** the founder subsequently supplied the incomplete-link and narrow-layout screenshots for staged 3.4.1, confirming the expected recovery message and no visible clipping. Requested website-brand consistency is implemented in local theme 3.4.2; its complete/incomplete static previews and Copy behavior were checked. It is not installed on staging or live. See [the revision evidence](../social-upgrade-20260930/website-branding.md) for the new ZIP, screenshots and remaining WordPress validation. The prior staging evidence applies to 3.4.1.
