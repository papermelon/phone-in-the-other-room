# Privacy and Data Map — App Store 1.0

Cumulative Farm accounting (ADR-0020) retains local run IDs, consumed timer interval unions, meter balances and reward outcomes beyond the 90-day detailed history, until local data reset. Access intervals also travel with the local persisted run and bounded App Group handoff ledger. No new upload or social fields are introduced.

This is the implementation-facing data inventory for Counting Sheep 1.0. It is not a
substitute for the public privacy policy or App Store Connect answers; those must match the
production configuration and this map before submission.

The publication draft is `docs/PUBLIC_PRIVACY_POLICY.md`; App Store field guidance is in
`docs/APP_STORE_SUBMISSION.md`.

## Default local data

**Local-source capability, not deployed collection (2026-08-30):** the founder selected a single
join-time Slumber Party sharing agreement, including the next reviewed habit-data contract,
rather than per-field toggles. Exact app accountability for Singapore/SEA and sleep week/month
summaries are requirements, not implemented exports. New fields require actual participant
consent, permitted platform access, existing-member migration and withdrawal/deletion rules.
Adults can join without Health data. The requested future archive lets later members see earlier
group history and retains approved contributions after ordinary leave. This changes the planned
recipient/retention contract, not existing collection: contributor re-consent, archive duration,
and enforceable privacy withdrawal/deletion need review before rollout. Leaving stops new sends
and access; a deletion request is a distinct operation, not defeated by consent copy.
System permission denial or unavailable data must remain truthful. Do not change the current
inventory below to claim these uploads already occur. See ADR-0016 and
`plans/slumber-party-shared-habits-and-guide.md`; public-policy publication remains held.

### Shared-habits local-source inventory (28–30 August; not yet deployed)

The additive `sharedHabitsVersion: 1` archive and version-2/version-1 shared-night-plan capability
are implemented in local source separately from the old V4 stream. Deployment, migration execution,
and physical multi-account verification remain open. These rows describe the local contract, not a
claim that the live service currently collects them:

| Record | Stored fields | Audience / lifecycle |
|---|---|---|
| Agreement | Party, account and membership epoch, version, acceptance time, contributor timezone, first eligible sleep night | Private authorization receipt; explicit acceptance per party |
| Shared habit | Author/member, kind, derived minutes, known local date/zone, factual completion outcome, optional app-recorded protection minutes, revision | Current and future agreed party members; no raw Health, exact intervals, stages, app identities or tokens |
| Shared night plan (v2) | Immutable rounded next-seven-local-night instance, revision, Wind Down timing, bedtime/wake bookends, ordered bundled idea IDs | Current and future v2-agreed members; recurrence rule and custom routine text stay private; earlier versions remain only for frozen receipt correlation |
| Shared night receipt (v2) | Frozen plan/version reference, factual start/result/protection dimensions and explicit unknown evidence | Current and future v2-agreed members; no app identity, per-app use, raw Screen Time or Health data; ideas remain planned context only |
| Attribution snapshot | Chosen name and bounded character appearance at publication/migration | Retained for former-member contributions; not full Farm state |
| Private publication identity | Contributor source UUID, agreement/epoch, idempotency key | Update/delete authority; peers receive public archive record IDs, not private source IDs |
| Archive | Consented contributions and coarse previously group-shared migration | Local-source candidate only; retention, withdrawal, deletion, and dissolution behavior remain review gates and are not promised by current product copy |
| Deletion marker | Party/account/source identity and deletion time, without retained habit metrics | Prevents retry/rejoin from resurrecting deleted contributions |
| Local privacy journal | Account-scoped pending leave/withdraw/dissolution and publication authority | Blocks local reads/sends before remote completion; never displayed as a successful remote action while pending |

Sleep uses completed contributor-local noon-to-noon windows and available-night arithmetic means;
missing nights are not zero. Wind Down quiet minutes remain distinct from sleep and from Phone
Away. App-recorded protection is not continuous attestation or proof of physical separation.
There is no supported automatic exact-app export for Singapore customers in this candidate.
The live website was inspected on 28 August and still shows the 30 July policy; reconcile and
publish the reviewed policy before exposing new sensitive collection.

| Data | Purpose | Location / retention | Leaves device by default? |
|---|---|---|---|
| Wind Down / Phone Away plan and active run | Run the requested phone-away session and restore it | Standard UserDefaults; latest state | No |
| Ritual records and events | Receipts, quiet-minute history, reliability/evidence | Standard UserDefaults; 90 days | No |
| Morning reflection | Optional personal context | Account-local transaction values on this device; 45 days | No |
| Wind Down routine support | Optional evening/morning cue, preparation, smaller activity, placement, and next-use choice | Account-local transaction values in Application Support (`ollie.windDown.habitPlan`); until revised/reset | No |
| Wind Down / morning habit reflection | Optional starting ease (evening), obstacle, intended-experience answer, bounded personal context, selected plan revision and civil day/zone; no inferred occurrence | Account-local transaction values (`ollie.windDown.habitReflections`); newest 45 mode/day entries, individually deletable | No |
| Meaningful personalisation | One confirmed goal, plan snapshots, exact suggestion evidence IDs, responses and reviewed adjustments; no inferred motivation | Account/guest-local `ollie.windDown.personalisation`; 90-day details on load/mutation, up to 90 plans plus current goal/plan; rejection mask until goal change/clear. Existing local recovery generations and OS backups follow their own lifecycle. | No new transport. Goal/reflection data excluded from Farm sync and Slumber Party. Accepted activity wording uses existing Watch/Live Activity paths, including enabled remote updates. No AI processing. |
| HealthKit `sleepAnalysis` | Sleep interval, duration, core/deep/REM/unspecified/awake where present | Read on demand; derived summaries in memory | No |
| Screen Time selection | Required start readiness, requested selected-app/category barrier, and optional private reports | App Group, opaque Apple tokens | No |
| Settlement journal | Hidden Wind Down outcome, terminal delivery/reveal markers, linked Screen-Free Morning occurrences, and Sunrise replay markers | Standard UserDefaults (`ollie.windDownMorning.settlementJournal`) | No |
| Shield schedule/status evidence | Derived multi-window schedule, bounded purpose cue, Brief Access state, and observed apply/clear evidence | App Group; revisioned/tombstoned bounded entries | No |
| NFC phone-bed registration | Confirm the chosen physical tag | Standard UserDefaults; SHA-256 digest only | No |
| Flock/progress and legacy reward fields | Local ritual feedback and compatible decoding | Standard UserDefaults | No |
| Wind Down starting point | Local questionnaire answers and deterministic recommendations | Standard UserDefaults (`ollie.windDown.profile`) | No |
| Welcome reward ledger | Idempotent starter sheep, pending wearable gift, and practice-sheep grants | Standard UserDefaults (`ollie.welcome.rewards`) | No |
| Slumber Party reward ledger | Applied backend grant IDs for shared-night Farm gifts | Standard UserDefaults (`ollie.nightFlock.rewards`) | No |

Wind Down routine suggestions are a private ordered sequence: up to three evening suggestions
and two morning suggestions, with the chosen phone-placement invitation first. Another-room and accessible-nearby intentions use the same selected-app protection requirements. They are not checklists and
carry no verification, reward, score, streak, or completion claim. Habit support and reflections stay outside the private Farm cloud payload and all Slumber Party projections. They switch with the local account, and neither saving them nor choosing a smaller activity creates session evidence or rewards.

The Wind Down starting-point
questionnaire is local by default and is not a clinical assessment.

Counting Sheep requests **read access only** to HealthKit
`HKCategoryTypeIdentifierSleepAnalysis`. It does not request HealthKit write access,
workouts, activity, heart rate, HRV, respiratory rate, wrist temperature, mindfulness,
medications, or reproductive-health types in 1.0. Adding any type requires a product use,
updated purpose copy, privacy review, portal validation, and an explicit code change.

The sleep query can return:

- sleep window start/end and merged time asleep;
- `asleepCore`, `asleepDeep`, `asleepREM`, and `asleepUnspecified` where the source records them;
- awake intervals used only for the local stage context;
- the source display name, shown locally so the user can understand provenance.

When multiple HealthKit sources overlap, the app chooses one coherent source for a night
based on sleep coverage and available stage coverage. It does not sum Watch and iPhone
copies of the same night.

## Optional impact sharing

Impact sharing is off until the person accepts a dedicated consent prompt. Detailed
history remains local whether sharing is on or off.

Eligible records may contain:

- relative night number from consent (not a date);
- planned/completed quiet minutes, completion status, and start-method category;
- shielding evidence category;
- sleep duration and core/deep/REM minutes where available;
- optional categorical morning restfulness.
- app version, so product changes can be evaluated separately.

The first upload can include up to 30 recent eligible nights before consent as a date-free
baseline. This is stated in the consent prompt. Later records are added only while sharing
remains enabled.

They do **not** contain:

- exact date, clock time, timezone, or location;
- raw HealthKit samples or Health source/device name;
- selected apps/categories or Screen Time tokens;
- NFC token, digest, tag identity, or scan payload;
- notification text, free-text purpose, or routine text;
- contact details, advertising identifier, or social identity.

Supabase stores the minimised rows under an anonymous authenticated account with row-level
security. Because the record is linked to that account, App Store privacy answers should
conservatively treat the collected Health and Product Interaction data—and the anonymous
User ID used to secure it—as **linked to the user/account**, not “not linked.”

The app provides:

- **Stop future sharing**: disables future preparation/upload without deleting local history.
- **Delete shared data**: calls `delete_my_impact_data`, then clears the local upload cache
  and consent only after the backend confirms deletion.

Before production enablement, define and implement a backend retention period. A suggested
starting policy is delete inactive anonymous impact accounts and their rows after 24 months;
do not promise that policy publicly until the hosted job exists and is verified.

The production privacy policy and processor agreement must identify Supabase as a service
provider acting for Counting Sheep. Impact data is limited to evaluating and providing this
health/fitness bedtime-habit service; it may not be repurposed for advertising, marketing,
data brokerage, eligibility, or unrelated use-based profiling. Obtain a human privacy/legal
review before production enablement. Do not describe this operational impact measurement as
human-subject research; any future research program requires a separate consent and ethics
review path under App Review Guideline 5.1.3.

## Other optional backend data

Supabase may also receive an anonymous device/run identity and ActivityKit push token when
the separately configured Live Activity transport is enabled. Raw push tokens are
credentials, excluded from logs, and governed by ADR-0005. This transport does not receive
HealthKit data.

## Current v4 membership-sharing contract — local candidate, 2026-08-28

This section supersedes the historical v2/v3 mapping below for the new local candidate; it does not assert that the new migration or app has been deployed. V4 already uses Apple-linked accounts, named persistent groups, curated profile snapshots, factual Wind Down/Phone Away source records, fixed cheers and independent per-party grants. The membership-sharing extension changes timing: new activity can be shared from joining, before and between seven-night rounds. Joining discloses that behavior; rounds remain progress/reward boundaries, not general-sharing prerequisites.

Private backend source/idempotency records include the already-uploaded source-event UUID, source timestamps and factual quiet-minute values. Current members receive the bounded recent shared projection, rounded minutes, activity occurrence time, expiring status, curated look and fixed cheer counts. They do not receive another person's local source UUID. `mySourceEventID` echoes only the requesting owner's existing source UUID to correlate passive feedback with their current run; `roundActivityID` references an already-public round row to avoid duplicate cards.

New stream records use membership epochs so leaving/rejoining does not revive old activity or cheers. The projection is the latest 100 moments within 90 days; service-only cleanup removes aged stream rows and their related reactions. Live status display expires separately, without deleting durable received cheers at the 30-minute status boundary. Existing round/source/grant ledgers are not deleted by this new stream cleanup. Their broader retention and hosted operational scheduling still require release review.

The extension adds no upload of Purpose, private routine choices, exact planned schedules, selected apps/tokens, Health data, full Farm inventory or impact records. No new reward comes from joining, viewing or cheering; outside-round activity does not receive a round grant. Local sessions, protection and Farm settlement do not wait for social transport.

See `plans/slumber-party-membership-sharing.md` for compatibility, verification and rollout gates. The public policy must be reconciled before distribution; the historical description below is not a statement that v2 sharing toggles or Health sharing remain part of v4.

## Shared Farm and update cheer receipts — 9 September 2026 source candidate

The public curated appearance gains optional `headShapeID` (pear, round, boxy, triangular),
advertised by `profileHeadShapeVersion: 1`. It is projected from the chosen Shepherd look;
no private Farm document, ownership ledger or inventory is copied. The social-avatar agreement
and capability gate remains unchanged. Older writes preserve the new field; older servers
receive no head-shape field.

`updateCheerReceiptVersion: 1` adds participant-only reaction IDs, original public update IDs,
sender/recipient membership IDs, fixed cheer type, server acceptance time and optional app-receipt
time. The optional acknowledgement means a recipient app received the update's cheer record;
it never proves human attention. No seen/read timestamp, push entitlement or new reward is added.
Current membership epochs and blocking fence both participants. Existing reaction deletion
cascades the private acknowledgement row. Existing 90-day stream retention applies; no
party-lifetime archive of these receipt records is introduced. No third member receives a pair's
delivery metadata.

The `memberUpdates` projection keeps each current member's latest eligible update and the
original updates behind that viewer's cheers accessible beyond the global latest-100 feed.
It uses the same existing allowlisted stream fields, current membership/block checks and
90-day limit. Account/membership-fenced local pending cheer intent is stored through the existing
outbox service and cleared with social account reset or loss of party membership.

This migration is **not deployed by this task**. See
[implementation and validation](plans/slumber-party-shared-farm-and-cheers.md).

## Historical Slumber Party mapping (v2/v3 compatibility)


Slumber Party is independently controlled by `SUPABASE_NIGHT_FLOCK_ENABLED` and is hidden and
network-silent when the flag is off (ordinary Debug). TestFlight/Release archives compile it on. Entering it can create an anonymous Supabase session; before
creating, joining, reading, or mutating a flock, the person must link that same Auth user to Sign
in with Apple. The app requests no Apple name or email scope. Supabase and Apple still process the
provider identity needed to authenticate the account, and the stable Auth user ID is linked data.

Slumber Party stores a separate v2 commitment and lobby, one bounded goal, member acceptance and
local-setup readiness, member sharing preferences, optional stable guidance IDs, coarse nightly
progress, rounded Wind Down and Phone Away minutes, optional sleep duration and restfulness,
server reward grants, coarse shielding evidence, fixed reactions, hashed reusable invite data,
expiry/revocation/redemption state, blocks, fixed-enum reports, service-only moderation actions,
retention metadata, and ordinary security/operational logs maintained by Supabase. Current members
may see approved display names and member-level progress inside the invited group.

Reusable invitation plaintext is kept only in a non-synchronizing Keychain item protected by
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, bound to the local account and lobby. Supabase
stores only the SHA-256 digest; host-only state contains only the active invite UUID and expiry.

The shared projection can say goal accepted, setup ready, phone tucked away, meaningful partial
progress, shared goal completed, qualifying Wind Down completed, or no update shared. The legacy
wire value `morningQuietCompleted` remains decode-compatible but never means or reports a
Screen-Free Morning. No update shared
is not completion. Independently controlled fields may include rounded quiet minutes and, only
with explicit opt-in, sleep duration or restfulness. The projection does not include Auth owner
IDs, local run IDs, exact dates or times, exact schedules, absence explanations, private
routines, private reflection text, or exact shield timestamps.

For an Instagram goal, Apple Family Controls supplies an opaque local token. The member selects
apps in Apple's picker and confirms that Instagram is included. The token and selected-app list
never reach Supabase. The app may share only not requested, unavailable, partial, or observed
shielding evidence; the server does not claim it verified Instagram by name.

Except for the separately agreed rounded v2 plan bookends above, Slumber Party never receives an
exact recurrence schedule, early-ending reason, private routine text, raw HealthKit samples, raw
Screen Time reports, selected-app tokens/lists, per-app use, NFC
information, Screen-Free Morning occurrence/choice/minutes, Sunrise Trail, purpose/cue text,
Brief Access state, notification state, or `impact_nights`. Optional minimized
impact/research sharing is a separate setting and record; neither consent enables the other.
Bounded Farm grants are computed by the authenticated backend and applied locally from a grant
ledger; they are not impact records.

The app provides leave, block, report, sharing, Slumber Party deletion, and full online-account
deletion controls. Blocking removes mutual visibility immediately and removes the blocker from
the shared flock. Invite rows purge after 30 days (codes stop working after seven), nightly
progress, metrics, and reactions after 90 days, and completed commitment summaries and grants
after no more than 12 months unless deleted sooner. The hosted retention schedule and moderation
process must be verified before the feature flag is enabled.

## Optional feedback

The in-app feedback backend is controlled independently by `SUPABASE_FEEDBACK_ENABLED`.
When enabled and the person taps Send, Supabase and Resend may process:

- category and 10–4,000 character message;
- optional reply email;
- up to three specifically selected screenshots, re-encoded as JPEG without photo metadata;
- optional app version, build, iOS version, and device-family details; and
- anonymous Supabase user ID, feedback UUID, notification state, and ordinary service logs.

Feedback never automatically includes app logs, Health data, Screen Time selections,
schedules, NFC data, run IDs, raw photo metadata, or persistent device identifiers. The
private Storage paths use the authenticated user/feedback prefix; clients have no feedback
table reads and receive no public Storage URL. A rolling limit allows five submissions per
anonymous account in 24 hours.

Supabase stores the report before Resend is attempted. Pending notifications retry at most
five times. The scheduled delivery job removes feedback rows and Storage objects after 180
days. Before production enablement, the support-mailbox owner must approve and follow a
matching process that removes delivered messages and attachments within 180 days. If any
backend, privacy, sender-domain, retry, or physical-device gate is incomplete, the release
flag remains off and the form uses the person's Mail app instead.

## App Store Connect disclosure checklist

Review the exact App Privacy taxonomy shown by App Store Connect at submission time. For
the 1.0 implementation, expect at least:

- Health & Fitness → Health (separately consented impact sharing and Slumber Party duration summaries);
- Usage Data → Product Interaction (quiet/completion/shield evidence);
- Identifiers → User ID (anonymous Supabase identity);
- User Content → Other User Content (Slumber Party display name/character, shared habit records,
  fixed cheers, blocks, and fixed-enum safety reports when Slumber Party is enabled; private
  routine text is not part of the current V4 shared-habits contract);
- Identifiers → Device ID (app installation ID and ActivityKit delivery identity);
- Contact Info → Email Address (optional feedback replies);
- User Content → Customer Support and Other User Content (feedback text);
- User Content → Photos or Videos (specifically selected feedback screenshots); and
- Diagnostics → Other Diagnostic Data (optional feedback app/build/iOS/device-family context).

Declare collection purpose as Analytics/Product Personalization only where the shipped
behavior genuinely uses it. Do not mark tracking: the data is not used to follow people
across other companies' apps/sites and must never be used for advertising or data brokerage.

## HealthKit and ethical boundaries

- HealthKit-derived data is used to show the person their own context and, only with the relevant
  separate agreement, evaluate Counting Sheep's impact or share derived party sleep summaries.
- It is never used for advertising, eligibility, sale, or disclosure to data brokers.
- Insights report sample sizes and associations. They do not diagnose, score sleep quality,
  or claim the ritual caused an improvement.
- A denied or missing HealthKit read is not treated as failure and does not change rewards.
- HealthKit is optional. Current release Wind Down starts use required selected-app shielding
  with either the timer guard or NFC + app shielding; legacy honor-timer, QR, and Watch guard
  values remain local decode compatibility only and are not release-facing paths.

## Private Farm backup candidate — 5 September 2026

ADR-0021 authorizes a separate opt-in Farm payload, including private sheep names,
Farm event dates and cumulative-credit accounting intervals. See the candidate
backup section in `PUBLIC_PRIVACY_POLICY.md`, `FarmBackupPayload` and
`farm_save_v1`. The endpoint verifies Apple-linked Auth identity and exposes no
private table to client roles. Account deletion cascades through every Farm table.
Deployment/physical QA and public policy publication must be reported separately.


## Account-owned Farm and credentials — 7 September 2026 candidate

ADR-0023 replaces separate backup enrollment for new account use. The private Farm
payload above is unchanged. The additive `farm_account_sync_v1` acceptance/capability
supports verified Apple and verified email accounts; old RPC semantics remain available.
Existing declined/paused uploads require migration acceptance. No private history fields
are added to the cloud payload.

| Data | Purpose and boundary |
|---|---|
| Immutable Auth UUID | Sole Farm and social-account owner; credential changes do not move ownership. |
| Verified email, linked provider identities | Supabase Auth credentials and recovery; Apple requests no additional name/email scopes. |
| Normalized username | Private unique server registry, claimed only after verification; login lookup never returns email to an unauthenticated caller. |
| Password | Sent to Supabase Auth for verification; neither app defaults nor the username registry stores it. |
| Keyed IP/identifier digests and attempt counts | Server-only login throttling, with stale windows cleaned by the rate-limit function. |
| Pending email verification/change metadata | Device-local email/username/phase without password or code; removed on explicit logout/deletion. |
| Account-scoped local archives | Farm, profile, private Nights/reflections and other scoped local context; inaccessible after logout and visible only to matching verified owner. Never uploaded as a document. |

Account deletion purges that owner’s local recovery and redundant pre-migration copies,
in addition to the existing server cascades. Guest scopes remain separate. Local source
and tests do not imply hosted deployment, policy publication or physical-device acceptance;
see `plans/account-owned-farm-sync.md` and `ACCOUNT_AUTH_DEPLOYMENT.md`.
