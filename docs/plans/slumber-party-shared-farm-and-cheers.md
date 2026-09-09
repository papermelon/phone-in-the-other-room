# Shared Farm and update cheers — 9 September 2026

Initial authorization covered source implementation and validation. The founder subsequently
authorized commit and push, including required prerequisites only. Preserve unrelated inherited
working-tree changes. Deployment, production activation and release upload remain unauthorized.

Journey: idle Home's existing Open group route → party Farm → chosen member → latest eligible
shared moment → fixed cheer beside that moment → recipient opens their update and sees named
cheers. Four release tabs and the active Wind Down quiet boundary remain unchanged.

Screen hierarchy: a shared meadow with stable join-date/member-ID placement and names; an
accessible member list; a member update sheet with date, factual context, counts and named
participant receipts. Keep existing group controls, plans, history and rounds below the Farm.
Represent two different outfits/characters, all eight members, no update, partial update,
unsupported appearance, old server, stale/offline state, pending, accepted, failed and app-received.
No decorative animation is required; Reduce Motion gets the same stable composition.

Reuse CountingSheepPublicPresentation, production Shepherd/Ollie/sheep renderers, PixelCard,
existing membership/round activities, fixed cheers, NightFlockViewModel, its account/transport
fences and NightFlockOutboxService. Never copy a private Farm into a social payload.

Batches and acceptance:
1. Optional allowlisted public headShapeID, independently advertised capability, revision-safe
   backend update and omission on older servers. Missing/unknown fields render an explained
   fallback without discarding supported outfit fields. Older writes retain the head shape.
2. Farm and member selection: deterministic newest date then stable ID; membership stream takes
   precedence over duplicate round rows. Only visible current members can be selected. Names,
   list controls and targets remain readable at accessibility sizes.
3. Durable cheer recovery: exact update/sender/recipient binding, existing unique reaction keys,
   account and membership admission, pending feedback before transport, useful retry and replay.
   Participant-only receipts extend existing reaction records, not another activity ledger.
   Recipient acknowledgement means received by their app, never seen by a person. Explicitly
   acknowledge after opening the recipient update. Persist acknowledgement server-side; render
   durable rows, without repeating transient recipient toasts on refresh or relaunch.
4. Compatibility/domain tests, isolated database permission/replay tests, generic app build and
   full Simulator suite; capture actual production views with disposable native fixtures.

Consent and rollout: head shape is another curated appearance identifier under the baseline
appearance agreement; fixed-cheer sender identity is bounded to current party participants.
Receipt metadata is visible only to sender/recipient, described alongside cheer controls, and
contains no read/seen timestamp. It does not expand Health, plans, archives or app-data sharing.
Deploy matching additive Edge validation before the database advertises new capabilities, only
with separate authorization. Existing shared-habits agreements and withdrawal fences still apply.
Repository records establish earlier deployments, not deployment of this migration. Physical
multi-account, reconnect, leave/block and overnight quiet checks remain separate release gates.

## Implementation and evidence

Integrated release paths: `SlumberPartyV4PartyDetailView` embeds the Farm and received-cheer
entry. The existing idle Home party button opens this detail. Character selection uses stable
member IDs; received-cheer selection also passes the original activity ID. Existing four-tab
routing closes social navigation when a run starts. No new social/reward/account system or
active-ritual notification was added.

The existing outbox actor now stores bounded update-cheer intent, verifies it was saved before
transport, deduplicates repeated taps, and clears it with the existing social reset epoch.
Reconciliation removes inaccessible parties and validates both participants' membership IDs
and join instants before replay. Ambiguous sends retain the same target/idempotency key;
a confirmed response or matching server summary removes the pending record. Failed attempts
remain retryable without claiming delivery. Named receipt rows render durably; they do not
create a toast replay ledger. Acknowledgement is idempotent and signals the existing sanitized
party revision channel once. Only the recipient can acknowledge.

The optional `memberUpdates` projection prevents the latest-100 feed from hiding a quieter
member's latest update or an update referenced by that viewer's cheers. It uses the existing
90-day membership stream and same membership/block visibility. The main feed remains bounded.

Validation performed:
- Generic iOS Simulator app build succeeded on the final source
  (`/tmp/slumber-farm-20260909/build-exact-final.log`).
- Full standard unit suite: **939 passed, zero failures** (`tests-final.xcresult`).
- Final existing SlumberPartyQA configuration, including final accessibility fixture:
  **939 passed, zero failures** (`qa-capture.xcresult`, `qa-capture.log`).
- Edge command/handler/compatibility suite: **32 passed, zero failures** (`edge-tests.log`).
- All six Slumber Party SQL suites passed on a fresh Unix-socket-only PostgreSQL 17 database
  bootstrapped with minimal Supabase auth roles/helpers and the real Slumber Party migration chain.
  Includes actual role denial, outsider/third-member denial, repeated sends/acknowledgements,
  source linkage, 101 newer updates, legacy profile writes, unsupported head values, blocking
  and leave/rejoin. Logs: `/tmp/slumber-farm-20260909/final-*.log`.
  The new receipt suite was then strengthened and rerun with the exact current account predicates
  extracted from `20260907110000_account_identity_and_farm_sync.sql`: Apple recipient, verified
  email sender, and rejected unverified account despite Apple provider metadata all passed
  (`current-account-receipts.log`). This does not claim a full private Farm/account migration test.
- `git diff --check` passed. New sources and the outbox service under test were added through
  XcodeGen; no manual generated-project edits, new targets, entitlements or dependencies.

Native images and interaction observations are in
[the capture record](../evidence/slumber-farm-20260909/native-review.md).
They render actual release views with isolated synthetic transport/storage, never a founder Farm.
An app-received fixture represents a prepared server state; it does not prove remote delivery.
Early compile/fixture failures and a state-wrapper regression were repaired; successful final
results above supersede those intermediate attempts. Initial fresh Simulator first boots stalled;
existing dedicated QA Simulators were used with newly generated fixture storage.

Deployment evidence reviewed: ADR-0016 and the deployment runbook establish the 25 August V4
backend deployment; the 29 August agreement-repair record establishes the later deployed date-wire
adapter. These records do not establish deployment of the new 9 September migration or modified
Edge validator. No hosted change or release upload was performed. Deployment, physical two-account
reconnect/acknowledgement, account switching, overnight quiet behavior and physical assistive
technology checks remain in the backlog. Source and permission-contract review is complete;
production rollout still requires its separate authorization and review.
