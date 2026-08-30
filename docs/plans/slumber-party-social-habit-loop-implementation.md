# Slumber Party social habit loop — implementation plan

Date: 2026-08-30
Status: **Local source implementation candidate.** The additive v2 agreement, plan/receipt,
and cancellation paths are implemented in this repository behind capability negotiation. Hosted
migration/deployment, physical multi-account validation, TestFlight distribution, and any new
participant-data upload remain separate gates. This does not authorize an entitlement change or
an attempt to bypass Apple's Screen Time boundaries.

## 1. Outcome

Make Slumber Party feel like a shared nightly ritual rather than a party list with activity
metadata. A member should be able to understand:

1. what each person intends to do tonight;
2. when each person's Wind Down is planned;
3. what Counting Sheep factually observed afterward;
4. how the group is progressing through its current seven-night round; and
5. how to encourage or learn from another member without creating a feed, chat, or shame loop.

The intended habit loop is:

```mermaid
flowchart LR
    A[See tonight together] --> B[Commit to own Wind Down]
    B --> C[Put phone away]
    C --> D[Counting Sheep records factual outcome]
    D --> E[Morning group receipt]
    E --> F[Quiet cheer or borrow an idea]
    F --> A
```

Success is more completed phone-away rituals around sleep, not more time spent browsing Counting
Sheep. The social surface should create anticipation before Wind Down and a short payoff afterward,
then get out of the way.

## 2. Founder direction and non-negotiable boundaries

- Sharing planned Wind Down timings, selected routine ideas, and per-night factual follow-through
  is a core Slumber Party capability, not an optional analytics appendix.
- Slumber Party remains invite-only and adult-first. A leader coordinates invitations and rounds;
  the leader cannot alter another adult's plan, permissions, protection, Health access, or sharing.
- One versioned party agreement discloses the shared bundle. There is no per-field toggle matrix.
  Leaving stops future publication; privacy withdrawal/deletion remains separately accessible.
- Routine suggestions remain suggestions. Sharing a suggestion never claims it was performed and
  never gives it a checkmark, score, streak, or reward.
- Missing, stale, revoked, or unsupported evidence is **unknown**, never non-adherence or misconduct.
- The iPhone remains authoritative for local Wind Down, protection, emergency exit, Farm rewards,
  and factual history. Social transport never blocks or alters the local ritual.
- Active Wind Down continues to have no in-app social navigation. Fixed cheers may use the existing
  quiet Live Activity/Watch path without waking or interrupting the person.
- Automatically identified shielded apps and per-app use remain a separately gated requirement.
  Manual labels, OCR, report-extension relay, hidden views, token uploads, and private APIs do not
  satisfy it.

## 3. Current foundation and the gap

The current v4 implementation already provides:

- up to five long-lived invite-only parties with membership epochs;
- sharing before, during, and between fixed seven-night rounds;
- canonical member identity and a selected Shepherd/Ollie/sheep social avatar;
- factual Wind Down and Phone Away records, live statuses, fixed cheers, and independent round
  reward ledgers;
- a separately versioned shared-habits capability with agreement receipts, lifetime party archive,
  sleep/Wind Down/Phone Away duration summaries, deletion, former-member history, offline privacy
  fences, and idempotent publication;
- app-recorded pre-bed protection minutes with explicit evidence limitations; and
- a responsive Home Slumber Party preview backed by the membership-filtered detail cache.

What it does not yet provide is the coherent social ritual:

- no shared nightly plan or historical plan version;
- no shared bedtime, wake time, bookends, or routine sequence;
- no comparison of planned versus actual behavior;
- no group-level “tonight together” or morning receipt;
- no safe way to borrow a member's routine idea into one's own plan;
- no approved definition of adherence or friendly competition; and
- no permitted Singapore route for automatically verified app identity or per-app usage.

The new work should extend the existing v4, membership-stream, and shared-habits contracts. It
must not create a parallel social backend, a second run state machine, or a new general feed.

## 4. Product experience

### 4.1 Home: Tonight together

Keep the approved personal timing card, Ollie hero, and prominent green start card. Immediately
below that start path, the Slumber Party section becomes a compact **Tonight together** preview:

- up to three recognizable member avatars, with overflow count;
- each member's next shared local Wind Down time, translated for the viewer only when useful;
- a factual state: `Planned`, `Winding down`, `Phone away`, `Morning quiet`, `Completed`,
  `Ended early`, or `No shared update`;
- one recent group highlight or one quiet cheer action; and
- a single tap to the selected party.

Do not show a live countdown for another person, a red late state, or a missing-person failure
badge. Home reads existing cached party state and does not introduce a second polling loop.

### 4.2 Party detail: one cohesive hierarchy

Recompose party detail in this order:

1. **Tonight together** — each member's planned timing and current factual state.
2. **People and routines** — compact member rows; tapping opens the member's shared routine.
3. **Recent nights** — one row per member-night with planned and actual facts kept distinct.
4. **Seven-night progress** — cooperative round progress and existing rewards.
5. **Shared habits** — sleep and duration means with coverage and source explanations.
6. **Group details** — people, invite, leader controls, agreement, leave/delete, safety.

The current separate “recent shared moments” and “quiet summaries” presentations should converge
into the same member-night story instead of asking users to interpret multiple ledgers.

### 4.3 Member routine

A member detail shows:

- planned Wind Down start, intended bedtime, wake time, Before bed, and After waking windows;
- the ordered evening and morning suggestions they agreed to share;
- app-protection identity only when a permitted evidence adapter exists;
- last night's factual result followed by 7- and 30-night coverage;
- a short historical list of planned-versus-observed nights; and
- **Add this idea to my routine** for a bundled suggestion ID.

Borrowing an idea opens the existing local routine editor. It never edits the source member's
plan, silently replaces a local slot, or publishes a completion claim.

Initially share only stable bundled suggestion IDs. Bounded custom routine text is a later slice
because it creates user-generated-content moderation, reporting, localization, and deletion work.

### 4.4 Morning receipt and encouragement

After a terminal Wind Down, publish one member-night receipt. Other members may send one of the
existing fixed cheers. The source member sees a compact receipt on the next daytime visit and may
open the Farm result separately; Slumber Party does not duplicate or delay sheep settlement.

Recommended receipt language is factual:

> Planned 10:30 PM · Started 10:42 PM · Completed · Protection recorded for 30 min before bed

Do not say “used no apps,” “slept on time,” or “kept the phone in another room” unless a future
evidence source can actually prove that specific fact.

## 5. Evidence and adherence model

Do not reduce adherence to one opaque Boolean in the domain model. Persist independent dimensions
and let presentation explain them:

| Dimension | Source | Values |
| --- | --- | --- |
| Plan availability | shared nightly plan | planned / not planned / unavailable |
| Start relationship | local run timestamps vs frozen plan | early / within tolerance / late / unknown |
| Run outcome | Counting Sheep history | completed / partly completed / unknown |
| Wind Down minutes | factual local ledger | integer minutes / unavailable |
| Protection | apply/clear/failure evidence | observed / partial / unavailable / failed open |
| Emergency exit | Counting Sheep run event | used / not recorded / unknown |
| Routine suggestions | plan snapshot only | listed; never completed/not-completed |
| Exact app identity | gated adapter | verified / member-provided / unavailable |
| Per-app usage | gated OS data adapter | measured with window / unavailable |

For the first release, present start difference and outcome directly. Add a user-facing **Met
plan** summary only after the founder approves a transparent tolerance rule. Recommended initial
rule for testing is “started within 60 minutes of the frozen planned start and completed the
Wind Down”; protection remains a separate evidence row and the 420-minute sheep-progression rule
is never reused as social adherence.

Seven- and thirty-night summaries must expose numerator, eligible observed denominator, and
coverage. An unknown night is excluded rather than counted as a miss.

## 6. Shared nightly plan contract

### 6.1 Publish instances, not the person's whole recurring schedule

The server should receive versioned **night instances**, not the complete local recurrence rule.
On agreement acceptance, plan save, relevant timezone change, and foreground reconciliation, the
iPhone projects the next seven eligible nights. This gives the party a reliable Tonight view while
avoiding upload of notification settings, recurrence internals, NFC data, or unrelated dates.

Each `SharedNightPlan` contains:

- opaque `planID`, party/member/membership-epoch/agreement IDs, revision, and idempotency key;
- contributor-local night-ending date and captured timezone;
- planned Wind Down start, intended bedtime, intended wake time, and morning-quiet end, rounded
  to five-minute precision;
- Before bed and After waking durations;
- ordered bundled evening and morning suggestion IDs;
- optional capability-gated app-protection disclosure reference; and
- `supersededAt` or deletion tombstone authority for changed/cancelled future nights.

Historical night plans become immutable when their eligibility window begins. A later plan edit
must not rewrite what the party saw for an earlier night.

### 6.2 Member-night receipt

Add a separate `SharedNightReceipt` rather than overloading the current duration record. It links
to the frozen `planID` and carries:

- stable source ID/revision and contributor-local night key;
- actual start and terminal times at five-minute precision;
- completed/partly-completed outcome;
- factual Wind Down minutes;
- app-recorded protection minutes and evidence state;
- emergency-exit-used Boolean when factually known;
- independent start-relation derivation inputs or server-validated derived value; and
- frozen member profile snapshot.

The existing shared-habits duration record remains readable for older clients. A capable client
correlates it by an explicit server-issued source link—never by timestamp or rounded minutes—and
suppresses duplicate presentation without deleting either compatibility record.

## 7. Additive protocol and backend design

Keep `schemaVersion: 4` and add explicit capabilities:

- `sharedHabitsVersion: 2` — agreement and member-night receipts;
- `sharedRoutinePlansVersion: 1` — plan instance publication/state;
- `sharedAppIdentityVersion` — absent until the Apple/platform gate passes; and
- `sharedAppUsageVersion` — separate from identity and absent until independently proven.

Agreement version 2 must enumerate the newly shared timing, routine, historical-audience, and
retention fields. Existing agreement-v1 members publish nothing new until they affirm v2. Joining
or creating a party must not complete the sensitive publication step until the durable v2 receipt
is reconciled.

Recommended additive storage:

- `night_flock_shared_plan_instances` — current/future and frozen historical plan versions;
- `night_flock_shared_night_receipts` — planned-versus-actual factual records;
- `night_flock_shared_plan_tombstones` — deletion and stale-retry authority where needed; and
- later, separately deployed app identity/usage tables only if their gate passes.

Reuse existing membership epochs, agreement IDs, account binding, privacy fences, outbox
serialization, RLS membership checks, former-member archive behavior, deletion commands, and
sanitized revision signalling. Do not put exact timings or routine content in Realtime payloads,
logs, diagnostics, idempotency strings, push payloads, or support captures.

## 8. Exact app identity and usage gate

There are two separate desired claims:

1. **Which apps were selected for protection?**
2. **What usage occurred during the defined window?**

Neither may be inferred from the other. The current non-EU picker returns opaque tokens; local
system labels are not an exportable identity contract. The report extension cannot be used as a
network or App Group relay. Apple's current Developer Program License Agreement also restricts
sharing device/usage data obtained through Family Controls beyond the relevant family control or
the individual and their device.

Before app-identity implementation:

1. Obtain written Apple clarification that this adult, invite-only, user-consented accountability
   use is permitted under section 3.3.3(P), including off-device party presentation.
2. Ask Apple for a supported Singapore customer route for both exact selected-app identity and
   defined-window usage. API availability in development or for EU customers does not pass.
3. Only if Apple permits the purpose, run a separately approved physical-device probe:
   - current opaque picker + shield path;
   - a curated known-bundle-ID path using documented `Application(bundleIdentifier:)` and
     `ApplicationSettings.blockedApplications`, verifying whether its different hide/block UX is
     acceptable and whether it preserves Counting Sheep's emergency exit;
   - signed TestFlight behavior on a Singapore device/account;
   - revocation, app uninstall/update, token stability, category mapping, and two-account delivery.
4. Return one of: `supported with written evidence`, `documented unsupported`, or `unresolved`.

Do not ship `sharedAppIdentityVersion` or `sharedAppUsageVersion` while the result is unresolved.
Member-provided app names may be modeled distinctly for future product consideration, but they are
not the automatic verified capability and are not an acceptance substitute.

Primary platform evidence for this gate:

- [Apple Developer Program License Agreement, section 3.3.3(P)](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/)
- [FamilyActivityPicker opaque-selection contract](https://developer.apple.com/documentation/familycontrols/familyactivitypicker)
- [DeviceActivityReport sandbox](https://developer.apple.com/documentation/deviceactivity/deviceactivityreport)
- [FamilyActivityData customer-region requirements](https://developer.apple.com/documentation/familycontrols/familyactivitydata)
- [ApplicationSettings.blockedApplications](https://developer.apple.com/documentation/managedsettings/applicationsettings/blockedapplications-swift.property)
- [Singapore PDPC data-protection obligations](https://www.pdpc.gov.sg/overview-of-pdpa/the-legislation/personal-data-protection-act/data-protection-obligations)

## 9. Privacy, audience, and safety

- Treat exact routines and sleep-adjacent timings as sensitive personal data even though they are
  not HealthKit samples.
- Agreement v2 must preview the actual audience, five-minute timing precision, routine fields,
  app-data availability, lifetime-of-party archive, former-member attribution, late-joiner access,
  withdrawal, deletion, and party dissolution behavior.
- Existing contributors must affirm the expanded audience before their old eligible records are
  exposed to later joiners. Never backfill private pre-join plans or routine history.
- Ordinary leave immediately fences local sends and cache access. It may retain previously
  published history under the approved archive contract; privacy deletion must still remove the
  requesting person's plan/receipt history and prevent replay.
- A leader has no additional data access and cannot make sharing mandatory outside the agreement.
- Use fixed bundled routine IDs in the first slice. If custom text is later shared, add length and
  character limits, report/block coverage, service moderation operations, and deletion tests first.
- Lock-screen notifications should not reveal another member's routine or exact timing by default.

## 10. Motivation without coercion

The first implementation uses cooperative visibility rather than a leaderboard:

- “3 of 4 observed plans completed last night,” with coverage beside it;
- a seven-night group mosaic that fills only from observed completed member-nights;
- one fixed quiet cheer per target event per member;
- **Borrow this idea** as the practical social payoff; and
- existing per-party round rewards unchanged.

Do not rank members, maintain a public failure streak, remove sheep, punish missing data, or send
urgency notifications. A competitive score, leader-set target, or new reward is a separate founder
decision after the factual loop is physically validated.

Measure success using ritual outcomes: time to first shared planned night, eligible observed
completion coverage, number of parties with two or more members contributing in a week, and
14-night Wind Down continuation. Do not optimize raw opens, session length, or notification taps.

## 11. Implementation phases

### Phase 0 — decisions and platform evidence

**Deliver:** accepted field/evidence glossary; adherence tolerance decision; agreement-v2 copy;
Apple written inquiry; app-identity decision result; approved wire examples.

**Files:** this plan, ADR-0016, privacy/data map, public policy draft, shared-habits wire contract,
and an Apple inquiry record. No entitlement or target change.

**Gate:** founder approves the social bundle and adherence language; privacy review approves the
agreement/archive; Apple result is recorded without being allowed to block the independent plan
and factual-receipt work.

### Phase 1 — domain and additive backend contract

**Deliver:** pure `Shared/` plan/receipt models and projections; agreement-v2 and capability
types; additive SQL tables/RPCs/RLS/deletion; strict Edge validators; backward decoding; durable
outbox records and membership-epoch/privacy-fence integration.

**Tests:** plan versioning, edit/cancel, five-party fan-out, duplicate/out-of-order retry, old
agreement suppression, leave/rejoin, late joiner audience, deletion tombstones, former members,
timezone/DST/travel, legacy v1 responses, SQL RLS, and Edge unknown-field rejection.

**Gate:** no UI claims and no hosted capability advertisement until Swift, SQL, and Edge wire
fixtures pass through the actual encoder/decoder boundary.

### Phase 2 — Tonight together and shared routines

**Deliver:** plan publication from the existing local schedule/routine source; Home preview;
recomposed party detail; member routine view; bundled **Add this idea to my routine** handoff;
agreement-v2 create/join/existing-member affirmation.

**Tests:** 1/2/8 members, five parties, long names, no plan, stale plan, changed plan, different
timezones, accessibility text, smallest iPhone, Reduce Motion, offline pending agreement, and an
active Wind Down with all social navigation absent.

**Gate:** real two-account TestFlight proof that each member sees only agreed plan instances and
that a local plan edit cannot rewrite a prior night.

### Phase 3 — factual nightly comparison

**Deliver:** member-night receipt publication at the existing terminal run boundary; planned and
actual presentation; coverage summaries; emergency-exit and protection-evidence rows; deduplication
with current shared-habits records; morning receipt and fixed cheers.

**Tests:** on-time/early/late start, completed/early-ended, automatic scheduled start, runtime
shield failure, missing evidence, app termination/reconciliation, corrected source revision,
offline replay, no false continuous-enforcement claim, and independent local Farm settlement.

**Gate:** physical overnight proof on two accounts, including terminated app, NFC and timer paths,
permission revocation, timezone change, no network, reconnect, and deletion.

### Phase 4 — cooperative habit loop

**Deliver:** seven-night member-night mosaic, coverage-aware group summary, daytime recap, routine
borrowing, leader proposal UI limited to invitations/rounds and a separately accepted optional
timing proposal, and notification cadence controls.

**Gate:** founder review confirms the loop feels motivating rather than supervisory. No ranking or
new reward ships without a separate scoring/economy decision.

### Phase 5 — exact app adapter, only after Phase 0 passes

**Deliver:** the narrow permitted identity adapter, independently versioned usage adapter if
available, provenance/category mapping, revocation and deletion, and precise App Store/privacy
disclosures. Keep owner-local reports available when social export is unavailable.

**Gate:** written Apple permission/clarification, documented Singapore customer API behavior,
signed physical proof, App Review notes, privacy review, and two-account delivery. A simulator,
EU-only account, or manually named app cannot pass.

### Phase 6 — rollout and operations

Deploy permissive Edge validators before advertising additive database capabilities. Apply
additive migrations, verify service-only privileges, then enable capability for internal accounts.
Progress through two-account, three-account, mixed-client, leave/rejoin, block, deletion, archive,
and retention-operator checks before external TestFlight.

Rollback disables capability advertisement and publication first while retaining additive tables
and accepting already queued commands through the transition. Never drop archived data or earned
round grants as an app rollback.

## 12. Verification matrix

Every implementation phase must include:

- `xcodegen generate`, generic iOS build, main full Swift tests, and Slumber Party QA build/tests;
- actual Swift encoder -> Edge validator -> SQL/RPC -> state adapter -> Swift decoder replay;
- Deno validator/function tests and fresh PostgreSQL migration/RPC/RLS tests;
- Screenbook and native navigation checks for Home, party, member, agreement, empty, stale,
  partial, former-member, and deletion states;
- VoiceOver order, 44-point controls, accessibility text, iPhone SE, dark appearance, and reduced
  motion;
- two physical accounts for membership visibility and three for leader/late-joiner behavior;
- overnight background/termination, NFC, Watch/Live Activity, Screen Time revocation, offline
  publication, reconnect, DST, and travel; and
- log/support-capture inspection proving no exact routines, app tokens, raw Health data, or
  identifiers leak outside the reviewed contract.

No fixture proves physical shielding, Apple authorization, hosted authentication, Realtime,
moderation operations, or customer-distribution eligibility.

## 13. Founder decisions needed before Phase 1 implementation

Recommended defaults are shown for a focused first implementation:

1. **Adherence:** show factual start difference + completion first; test a transparent 60-minute
   start tolerance before naming “Met plan.”
2. **Routine content:** share bundled suggestion IDs initially; defer custom text until moderation
   exists.
3. **Leader power:** invitations, round start, and optional timing proposal that every affected
   adult accepts; no unilateral change.
4. **Competition:** cooperative member-night mosaic first; no ranking or new reward.
5. **Notifications:** fixed cheers remain quiet during Wind Down; one optional daytime group recap;
   no another-member timing on the lock screen by default.
6. **App identity:** retain automatic verified identity as the requirement; do not ship a manual
   declaration as if it completes the feature.

## 14. Definition of done

Slumber Party represents the intended capability only when:

- two real adult accounts can agree, share tonight's plans, recognize each other's routines, and
  see a truthful per-night planned-versus-observed receipt;
- routine changes and historical nights remain version-correct across timezone, offline, and
  mixed-client cases;
- missing evidence never becomes failure and no UI overclaims app use, sleep, or physical distance;
- leaving, deletion, late joining, blocking, account recovery, archive, and retention behavior are
  physically and operationally proven;
- the loop is prominent on Home but absent from the active ritual;
- current Farm settlement and per-party round grants remain independent and idempotent; and
- exact app identity/use is either supported with the required Apple/Singapore evidence or clearly
  marked as an unresolved product dependency rather than quietly substituted.
