# Privacy and Data Map — App Store 1.0

This is the implementation-facing data inventory for Counting Sheep 1.0. It is not a
substitute for the public privacy policy or App Store Connect answers; those must match the
production configuration and this map before submission.

The publication draft is `docs/PUBLIC_PRIVACY_POLICY.md`; App Store field guidance is in
`docs/APP_STORE_SUBMISSION.md`.

## Default local data

| Data | Purpose | Location / retention | Leaves device by default? |
|---|---|---|---|
| Wind Down / Phone Away plan and active run | Run the requested phone-away session and restore it | Standard UserDefaults; latest state | No |
| Ritual records and events | Receipts, quiet-minute history, reliability/evidence | Standard UserDefaults; 90 days | No |
| Morning reflection | Optional personal context | Standard UserDefaults; 45 days | No |
| HealthKit `sleepAnalysis` | Sleep interval, duration, core/deep/REM/unspecified/awake where present | Read on demand; derived summaries in memory | No |
| Screen Time selection | Reports and optional shield | App Group, opaque Apple tokens | No |
| Shield schedule/status evidence | Apply/clear the two bookends and avoid claiming unobserved protection | App Group; bounded 40 status entries | No |
| NFC phone-bed registration | Confirm the chosen physical tag | Standard UserDefaults; SHA-256 digest only | No |
| Flock/progress and legacy reward fields | Local ritual feedback and compatible decoding | Standard UserDefaults | No |

Wind Down routine suggestions are a private ordered sequence: up to three evening suggestions
and two morning suggestions, with putting the phone away fixed first. They are not checklists and
carry no verification, reward, score, streak, or completion claim.

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

## Optional invite-only Slumber Party

Slumber Party is independently controlled by `SUPABASE_NIGHT_FLOCK_ENABLED` and is hidden and
network-silent when the flag is off. Entering it can create an anonymous Supabase session; before
creating, joining, reading, or mutating a flock, the person must link that same Auth user to Sign
in with Apple. The app requests no Apple name or email scope. Supabase and Apple still process the
provider identity needed to authenticate the account, and the stable Auth user ID is linked data.

Slumber Party stores:

- a preset flock identity and server-generated member aliases;
- current membership/role and the member's sharing setting;
- a locked IANA timezone and one seven-day challenge date range;
- only positive `phoneTucked` and `morningQuietCompleted` state by challenge day;
- fixed reactions, hashed invite tokens, expiry/revocation/redemption state;
- blocks, fixed-enum reports, and service-only moderation actions; and
- ordinary security/operational logs maintained by Supabase.

Peer projections include roster aliases and positive aggregate state. Shared-pasture completion
entries are unnamed. They do not include Auth owner IDs, local run IDs, exact event timestamps,
private-night state, or any list of who did not check in. For a two- or three-member flock, copy
suppresses an exact positive count where it would reveal an individual's absence.

Slumber Party never receives exact bedtime, wake time, run duration, early-ending reason, additional
quiet, routine steps, schedules, absence, HealthKit or raw sleep data, Screen Time selections,
selected apps, NFC information, purpose/cue text, notification state, Farm inventory, sheep, wool, transaction data, or
`impact_nights`. These sources remain logically and permission-wise separate.

The app provides leave, block, report, sharing, Slumber Party deletion, and full online-account
deletion controls. Blocking removes mutual visibility immediately and removes the blocker from
the shared flock. Invite rows purge after 30 days (codes stop working after seven), raw check-ins
and reactions after 90 days, and completed aggregate summaries after no more than 12 months unless
deleted sooner. The hosted retention schedule and moderation process must be verified before the
feature flag is enabled.

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

- Health & Fitness → Health (optional impact sharing);
- Usage Data → Product Interaction (quiet/completion/shield evidence);
- Identifiers → User ID (anonymous Supabase identity);
- User Content → Other User Content (Slumber Party positive check-ins, fixed reactions, blocks,
  and fixed-enum safety reports when Slumber Party is enabled);
- Identifiers → Device ID (app installation ID and ActivityKit delivery identity);
- Contact Info → Email Address (optional feedback replies);
- User Content → Customer Support and Other User Content (feedback text);
- User Content → Photos or Videos (specifically selected feedback screenshots); and
- Diagnostics → Other Diagnostic Data (optional feedback app/build/iOS/device-family context).

Declare collection purpose as Analytics/Product Personalization only where the shipped
behavior genuinely uses it. Do not mark tracking: the data is not used to follow people
across other companies' apps/sites and must never be used for advertising or data brokerage.

## HealthKit and ethical boundaries

- HealthKit-derived data is used to show the person their own context and, only with
  separate consent, evaluate Counting Sheep's impact.
- It is never used for advertising, eligibility, sale, or disclosure to data brokers.
- Insights report sample sizes and associations. They do not diagnose, score sleep quality,
  or claim the ritual caused an improvement.
- A denied or missing HealthKit read is not treated as failure and does not change rewards.
- The honor timer, QR, NFC, shielding, and the entire ritual work without HealthKit.
