# Product direction — Counting Sheep

Maintained topic reference extracted from AGENTS.md on 7 September 2026. Read the section
relevant to a product change, not this entire file before every edit. Explicit founder
instructions and current superseding ADRs control. Dated implementation statements are
not a substitute for current deployment or device evidence.

## Accounts and persistence

[ADR-0023](DECISIONS/ADR-0023-account-owned-farm-sync.md) and the
[account-owned Farm plan](plans/account-owned-farm-sync.md) replace optional backup
with automatic private account synchronization. Verified immutable UUIDs own Farms;
Apple and username/handle-or-email plus password resolve to that identity. Credential
linking never merges Farms. Sign-in must load/validate the account Farm before publishing
it; lookup failure is not an empty account. Sign-out removes it from active play without
deleting its server data. Guest Farms remain distinct local scopes. Existing declined
upload consent requires migration explanation and acceptance.

Local source includes owner-scoped activation, synchronization, compact Account screens,
and password authentication. Production activation, physical-device acceptance, and
updated distribution are separate gates. Settings → Connections → Account is the compact
entry point; routine manual enable/pause/check/restore controls are superseded.

Preserve ADR-0021's versioned JSON transaction store in Application Support, recovery
copies, idempotent rewards, and the [private payload boundary](plans/farm-save-contract.md).
Other settings and detailed session/history data remain in UserDefaults. Do not upload
local ritual/reflection/Health history or the device-only settlement journal as a Farm
payload. A newer pending local generation cannot be labelled saved merely because an
older upload succeeded. Authentication does not prove Farm activation or server save.

The founder authorized production Supabase deployment, Apple configuration verification,
backup disclosures and physical testing on 5 September for the earlier save slice. This
records that authorization; it does not establish later provider activation or validation.
Use the current plan and deployment evidence for the actual requested action.

## First run and guidance

Fresh first use follows two skippable story pages → schedule and optional reminders →
one optional evening activity → plan review → **Go to Home**. Go to Home commits the plan;
review must not claim it is already saved. A saved plan does not start a session. Family
Controls authorization, a non-empty app selection, and the existing admission checks remain
required for every actual protected start. Someone can reach Home and revise a plan before
completing protection setup.

The optional six-question starting-point chapter, its result, the Shepherd welcome gift,
and account creation remain available after the initial plan. Missing/default answers never
become behavioral claims. Accepting a result saves only the private starting point; it never
replaces the schedule, routines, or notification settings. Questions and gift eligibility
remain independent. **Wear now** claims and equips the chosen gift; **Keep for later** claims
it without changing appearance. Choosing later or generic navigation grants nothing and
preserves eligibility.

The first welcome page retains one returning-user Sign in entrance. Under ADR-0023, a verified
loaded account Farm routes a returner to this phone's remaining setup. Authentication alone
proves neither Farm activation nor confirmed server save. Existing interrupted onboarding
drafts retain their original route and persisted step values, with protection setup explicitly
deferrable before plan review. Settings replay preserves its
existing settings and explicit gift/account semantics. Configured users are not forced through
onboarding again. See the [onboarding account plan](plans/onboarding-account-experience.md)
and [habit-loop plan](plans/wind-down-habit-loop-2026-09-08.md).

Saving a schedule/reminder never starts Wind Down automatically. Automatic Wind Down remains
an explicit opt-in. The Home tour defaults off and can be selected at plan review. Home
guidance is versioned/resumable (`ollie.orientation.state`, schema 6), with Home Basics and
Around the Farm chapters. Practice, Slumber Party, Settings, and Nights help is contextual,
occasional, and dismissible. Practice never gates guide completion.

## Personal wind-down loop

The ordinary independent-user journey is the primary experience. Workshops use that same
journey; Counting Sheep stays optional for platform-agnostic activities. The [8 September
implementation and pilot plan](plans/wind-down-habit-loop-2026-09-08.md) owns the bounded slice.

Home brings the first chosen evening activity forward and offers a direct, save-only edit.
Plan progressively offers an optional recognizable cue, preparation, smaller activity, and
phone placement. None is a mandatory questionnaire or a completion checklist. A smaller
version replaces the next primary Wind Down's evening invitations only; it preserves timing,
overnight protection, morning invitations, and rewards. Selection survives relaunch and is
consumed only after coordinator admission; a run retains its own immutable snapshot.

Nights offers optional, private starting-ease/obstacle reflections without requiring a session
record. A relevant adjustment link opens the normal editor without starting a session. A note
is a self-report, never proof of the routine, sleep, physical placement, or reward eligibility.
New notes keep their civil calendar date across travel. No new reflection or support field is
shared with Slumber Party or included in private Farm synchronization. These device-local
values follow the active account; existing device schedule/routine preferences keep their
current ownership. An unreadable field must not erase its healthy counterpart on save.

Existing cumulative Farm progression, Ollie's Search, welcome eligibility, and shared
encouragement provide continuity. This slice adds no reward economics, notification pressure,
remote analytics, social fields, or habit-effectiveness claims. Shared-idea borrowing keeps
existing agreements/capability gates and offers an explicit routine-review route when full.

## Morning continuity and completion presentation

Founder direction, 13 September 2026: Screen-Free Morning continues the same Ollie-and-sheep
countdown experience in the sunrise scene. Its clock, shielding, and reward ledger remain
independent. Show chosen morning ideas compactly, surface Brief Access only when used, keep
routine protection explanations in details, and keep actionable repair and exit controls reachable.
Remove the generic active-session Purpose menu. Its compatibility storage is not a personal goal
profile and must not be repurposed as one without the person's confirmation.

Completion leads with an actually saved sheep/clue outcome or carried Farm progress, followed
by one compact timer record and one main destination. Keep Farm credit calculations, Health,
Brief Access, and protection evidence in details. Only the morning linked to the displayed Wind
Down belongs in its receipt. The pre-bedtime timer segment is labelled “Pre-Sleep Wind Down”;
this changes presentation only, not credited minutes or reward accounting.

The [meaningful personalisation implementation](plans/meaningful-personalisation-implementation-2026-09-13.md)
adds one optional, editable goal for Wind Down or Screen-Free Morning, explicit activity review,
shared per-mode/day reflections, and bounded local suggestions based on repeated explicit feedback.
Goals never silently edit timing or protection; feedback and suggestions never affect rewards.
Private goal/reflection data follows the existing device-local account/guest boundary and stays out
of Farm sync and Slumber Party. The [AI assessment](plans/personalisation-ai-pilot-2026-09-13.md)
is a separate proposal: no AI processing, API spend, deployment or distribution is activated.

## Ritual, Farm, copy, and settings


- Copy is warm, clear, and Ollie-voiced. Pressure, urgency, stakes, and anticipation should be
  evaluated for clarity and fit with the bedtime ritual, not accepted or rejected through a
  generic checklist. See `skills/product-copy-review/SKILL.md`.
- No medical claims ("improves sleep", "fixes insomnia"). Say "helps you wind down", "phone-away habit".
- The person is the shepherd/farmer tending the Farm. Ollie is the capable border-collie sheepdog
  beside them: he watches the ritual and searches for missing sheep. Copy must not swap those roles.
- “Put the phone in another room” remains the primary invitation. People who need their
  phone for communication or alerts can explicitly choose an accessible nearby resting place.
  Either placement intention retains the same selected-app protection requirements. Review
  essential access before choosing app restrictions; notification exceptions do not exempt an
  app from Counting Sheep's shielding. Timer completion, shielding authorization, NFC
  confirmation, Watch state, and app history do not prove continuous physical placement,
  sleep, complete screen avoidance, or routine completion.
- Phone Away makes room beyond doomscrolling apps for reading, making, movement, cooking,
  conversation, rest, work, or anything else the person values. It is not a productivity timer or
  specifically an escape from work.
- Habit formation is intentional: a new Farm starts with one starter sheep. An optional six-question
  local behavioral check-in derives one deterministic, non-clinical starting pattern and, only
  when independently supported, one secondary pattern; missing/default answers never become
  behavioral claims, and the result never silently changes the schedule or routine. Every person
  may independently choose and immediately claim one of three finished Shepherd welcome wearables,
  then explicitly wear it now or keep their existing appearance. The first
  successful five-minute onboarding practice grants one additional sheep without consuming a
  protected-night or Phone Away guarantee. The first three qualifying Wind Down
  searches, the first three completed 100-minute Screen-Free Morning searches, and the first
  three completed 100-minute Phone Away meter searches each guarantee a sheep; later searches
  use their source's independent chance and bad-luck protection. Wind Down and Phone Away
  searches use cumulative credit under ADR-0020: 420 eligible Wind Down minutes or
  100 independent Phone Away minutes, including eligible early-ended time and excluding
  Brief Access. Wind Down includes overnight timer time through actual/planned end;
  Screen-Free Morning remains a separate ledger. Farm progression is not a claim about
  sleep or verified screen avoidance. Factual before-bed minutes and completed-night
  counts remain distinct. **Screen-Free Morning** is the release-facing name;
  `SunriseTrail*` names remain compatibility-safe internals.
- Search outcomes are deterministic after resolution, persisted once, and protected against
  unreasonable bad luck. Missing data never lowers the search chance.
- The Farm progression direction separates a permanent discovery/history record from the
  currently owned flock. A found sheep can remain recorded in the catalogue and Search Journal
  even if its owned instance is later sheared, traded, released, or otherwise cycled.
- The active flock has finite capacity. Players may prioritize collecting and capacity expansion,
  wool production, trading sheep to other farms, catalogue completion, or cosmetic customization.
  Do not assume that every collected sheep must occupy the Farm forever.
- Wool is the single Farm currency. Shearing and trading sheep to other farms produce it, and the
  Farm Shop exchanges it for capacity upgrades, collectibles, farm decoration, Ollie cosmetics,
  and the customizable human avatar foundation. Economy values and lifecycle timing must be explicit,
  testable balance rules rather than incidental constants embedded in views.
- Shearing is a deliberate flock-management action, not merely a loss state: it retains a
  sheep while its wool regrows. Trading or releasing may remove the owned instance while keeping
  its discovery and history. ADR-0015 records the current returns and timing.
- Early-ended runs keep factual receipts and eligible cumulative Farm credit. The product
  does not require automatic sheep deletion after a missed night; later lifecycle mechanics
  remain product decisions. Old settled rewards remain intact, and supported early history
  is backfilled idempotently.
- Phone Away opens one search per 100 cumulative eligible minutes without a three-night
  gate. The first three meter searches guarantee sheep; later searches retain the isolated
  20/30/40/50 ladder and four-clue bad-luck guarantee. They never change Wind Down odds.
  Practice has its separate welcome reward rather than regular meter credit. Legacy
  `trailDistance`, `trailStrength`, `trailMap`, `pendingMappedMinutes`, and odds fields
  remain decodable; release copy does not present those obsolete fields as current progress.
- The user-facing action labels are **“Put phone away,” “Start now,”** and **“Plan.”** Copy does
  not force the mode name into awkward verbs.
- Wind Down setup may hold up to three ordered evening suggestions and two morning suggestions.
  These are private by default, optional ideas with no checkmarks, verification, reward, score,
  streak, or claim that a suggestion was completed. An accepted versioned Slumber Party agreement
  may share the stable selected ideas and their planned order without changing that evidence
  boundary. Guidance appears beside those choices, on Home, and at phase-appropriate moments. The
  source library is bundled locally and reached from the secondary **“About these ideas and
  sources”** link; “finite guide” is an internal description only.
  Following the 7 September device review, Live Activity cues use complete action wording and
  show the selected ideas together, without pairing the first idea with an unrelated tip.
  Ideas do not rotate on a timer or imply step completion. The bedtime display should move
  to the saved overnight countdown without opening the app. This is a clock-based display
  requirement, separate from protected-session admission, reward settlement, and actual sleep.
  After the final timer boundary, the Live Activity should show a checkmark and a warm
  completion message. Opening the app dismisses the completed activity and presents its
  receipt regardless of the previously selected tab; dismissing the receipt restores the
  four-tab shell. Founder approved the existing APNs update path on 12 September 2026.
  See [copy and Live Activity repair](plans/live-activity-and-app-copy-2026-09-07.md) for local
  implementation, platform limits, and remaining device acceptance.
- Settings is organized as **Your Wind Down**, **Connections**, **Privacy & data**, and **Help &
  app guide**. The compact root leads to focused detail screens with contextual help and progressive
  disclosure; there is one Wind Down configuration route, not a duplicate Review Wind Down route.

## Shop and Ollie’s wardrobe

Founder direction on 13 September 2026: use simple paper-textured illustrations throughout
Shop inventory and its purchased appearances. Ollie’s accessories must look fitted and follow
the equipped choice across Home, personal Farm and active Wind Down/Phone Away chases.
The local implementation uses one pose-registered garment renderer and native paper objects,
with actual worn/placed previews and reversible equipment actions. Preserve inventory IDs,
prices, unlocks and ownership. The seven existing fitted Shepherd items remain in the same style.
See [collection review and implementation](plans/shop-ollie-and-campfire-2026-09-13.md).

## Slumber Party

Founder authorized campfire implementation on 13 September 2026. Campfire is a free gathering
place inside each existing meadow; the 12-contribution lantern remains an earned improvement.
Customized Shepherds gather for explicitly shared app-reported sessions. Optional bounded Phone
Away intentions require a separate per-party version 1 consent receipt and advertised capability;
private task text never uploads. Default Wind Down validity ends at planned wake, Phone Away at
its planned end, with terminal precedence and a 24-hour ceiling. Temporary gathering positions
restore saved arrangements. Source is implemented; hosted activation remains pending. See
[current campfire contract](plans/campfire-implementation-2026-09-13.md).


Founder correction during implementation (12 September 2026): retain the existing shared
meadow artwork and its wide, open framing. It already matches the characters; the scenery
refresh belongs to the personal Farm, barn and related previews. New shared interaction,
visits, hierarchy and lantern improvement remain in scope, without replacing this backdrop.
Lantern pacing approved: 12 contributions, at most one existing completed-session round
grant per member per party-day; progress carries across rounds and membership changes.


Farm art clarification: personal and shared farms, barns, meadows and related environment art
should use paper-textured illustration consistent with the approved characters. This changes
the remaining pixel scenery, not the four tabs, persisted inventory IDs or fitted character
renderers. Retire replaced artwork after reference/recovery checks rather than accumulating
unused runtime variants. See [migration and asset lifecycle](plans/farm-art-retirement-2026-09-12.md).

The v4 baseline supports up to five concurrent long-lived invite-only parties with fixed
seven-night rounds. Completed local Wind Down/Phone Away can fan out to every eligible
party, with an independently idempotent grant per party. Members see app-recorded,
self-reported records, expiring revisioned statuses, curated snapshots and fixed cheers.
Every current member can retrieve/share the active invite; host-only invite management
remains. The canonical profile has a rolling name-change limit, not a public directory.
Local sessions never wait for social transport. The 12 September founder redesign permits the
interactive shared pasture during active Wind Down; Home now routes into the shared Farm and back to the running session. Protection and local settlement remain independent. Existing silent
Live Activity/Watch feedback reconciles from durable cheer records.
Recovery never creates an anonymous account. Bind identity and account-scoped social
queues to the verified expected UUID; use ADR-0023 for provider-neutral account transitions.
Do not carry another owner's pending work into the newly activated Farm.

Current shared-pasture source contract (12 September; implemented locally, not deployed):
Shepherds represent people, with owned sheep contributed separately until recalled while private
ownership/progression persists. Visiting sheep appear together with their owners in the party's
shared pasture. Accepted starting limits are one active sheep per member per party and one
party per owned sheep; retain its private flock/progression entry with a visiting badge, without
also drawing it in the private scene. Everyone may arrange earned group decorations and structures.
Personal Farm navigation uses one rule: tapping a resident opens that resident's details and
actions. Sheep open their existing Barn detail; the Shepherd opens personal appearance and
wardrobe; Ollie opens play and owned accessories, with an explicit Shop link. Fetch/gather
returns to the visible pasture. The Shepherd model stays pinned above scrolling customization
controls, showing changes immediately. The Shop remains a named destination.

Founder confirmed after the working eight-person study: keep Ollie on the personal Farm for this release. Fetch/gather remain personal play; the shared companion experiment is DEBUG-only. Retain the existing wide shared meadow and add a movable earned lantern. Everyone can
move any character/sheep with persisted placements shared across the party; full live multiplayer
is later scope. Timely app-reported Wind Down/Phone Away cues support body doubling now. Shared
decorations/improvements come from eligible participation through the existing reward foundation;
the first completed-session round grant per member per party-day contributes once toward a 12-contribution lantern. Early endings keep personal Farm credit and add no project contribution. This supersedes the earlier interchangeable identity choice and
active-Wind-Down pasture exclusion, without exposing private data or changing shielding.
See [the redesign plan and founder answers](plans/slumber-party-pasture-redesign-2026-09-12.md).

Accepted navigation/copy direction: retain both Home and Farm entry points, with timely social
context on Home and a stable Farm connection. The retained Farm card must preserve its title “Your Farm look travels with
you” and detail “Your curated Farm look appears in your parties. Completed shared moments can
bring wool home.” Retain its “SLUMBER PARTY · YOUR FARM” eyebrow and appropriate no-party variant.
Consolidate duplicated rosters and activity presentations within party detail while preserving
the accessible list equivalent and all permitted member details. Investigate apparently repeated
activity cards by source identity before treating them as duplicate records.

Accepted additive local-source agreements may share rounded immutable next-seven-night
plan instances, comparison bookends, bundled idea IDs and factual receipts. They do not
share recurrence rules, custom text, app identity/per-app use, device credentials, impact
records or raw Health samples. Consult the exact versioned capability before publication.

- Founder clarification after device review (2026-08-27): Slumber Party is a core reason to
  return, and Home must give it substantial, responsive presence rather than only a metadata
  bridge below a large personal-plan card. Existing member-visible profiles, factual activity,
  statuses, and cheers may inform idle Home as well as party detail. Keep the personal Wind Down
  readable and quick to start, Phone Away reachable, and guidance occasional/contextual/dismissible.
  The prior hierarchy and list-only Home restrictions are superseded; see
  `docs/plans/home-social-recovery.md`. The founder subsequently approved sharing immediately
  upon joining, before and between seven-night rounds. Rounds organize progress and rewards;
  they do not unlock social activity. The local source implements the additive membership-stream
  contract in `docs/plans/slumber-party-membership-sharing.md`, preserving old-server fallback,
  membership epochs and independent round grants. No new private-data uploads or remote family
  enforcement are authorized. Local implementation and hosted deployment remain distinct.
- Slumber Party founder decisions (2026-08-28; implementation varies by capability as
  described below, and local source is not deployment evidence): the original mixed social
  identity choice is superseded by the 12 September Shepherd-and-separate-sheep direction above;
  its existing fields remain compatibility data during migration. The initial audience is adults, with a coordinating group leader;
  actual child accounts and negotiated parent/child bedtime flows are later scope. Accountability
  and friendly competition are approved directions, with exact leader powers/scoring still to be
  specified. Automatically identified exact shielded apps, then category grouping, are essential
  for the primary Singapore/SEA audience; self-described categories are not an accepted substitute.
  No supported Singapore customer export path has yet been established. Prove a permitted route
  before claiming this feature works; EU-only APIs do not satisfy this market requirement.
  Sleep presentation should show last night and week/month means with coverage and drill-down.
  One explicit sharing agreement accompanies joining each party; sharing is then on for the
  agreed contract, without per-field toggles, and withdrawing party sharing means leaving that
  party. Consent is not an automatic iOS permission grant, and missing data is not misconduct.
  Adults may join without Health data. Offer contextual Health/Screen Time connection controls;
  distinguish request completion, observed data and actual system authorization. Later joiners
  should see all previously shared group history, including earlier contributions from leavers.
  Ordinary leave stops new sharing and access but should not redact approved existing history.
  These are requirements, not proof of hosted capability: existing contributors need agreement to expanded fields and
  audiences; archive retention, meaningful privacy withdrawal/deletion and platform review remain
  gates. The founder selected retention for the lifetime of the party, subject to legitimate
  deletion requests; this duration still needs the stated privacy/operations review. A joining
  clause does not make sensitive history irrevocable. This changes product
  direction, not the current deployed wire contract or permission to upload anyone's data.
  See `docs/plans/slumber-party-shared-habits-and-guide.md` and
  `docs/plans/slumber-party-singapore-app-data-feasibility.md`.
- Slumber Party habit-loop implementation (2026-08-30; local source complete, deployment and
  physical multi-account validation pending): sharing each
  member's planned Wind Down timing, agreed routine ideas, and factual per-night comparison to the
  frozen plan is a core capability. Build it as additive versioned plan instances and member-night
  receipts on the existing v4 membership/shared-habits foundation, not as a feed or parallel run
  state. Suggestions remain unverified ideas; missing evidence is unknown; leaders cannot alter
  another adult's plan or permissions. Automatically verified exact shielded-app identity and
  per-app use remain separate Apple/Singapore gates and must not be replaced by a manual label or
  inferred from protection evidence. See
  `docs/plans/slumber-party-social-habit-loop-implementation.md`.
## Home hero

- Home design approval (2026-08-28; native composition implemented, acceptance incomplete): personal Ollie
  leads a minimalist hero with 1–3 home ornaments, a bordered Tonight timing card above it, and
  a connected Slumber Party member/status preview with one recent highlight. Keep the round
  label on one line. Photo-based ear and tongue poses are approved references for animation
  in both Home and Farm; registered frame sets and the three finished cosmetic layers are now implemented. The
  shared hero scene is deferred. A personal Shepherd companion, its art refresh and a logo
  replacement are explorations, not selected defaults. Preserve clothing/cosmetic customization.
  The native hero remains Ollie alone; the Shepherd is off by default in the optional design
  comparison and, when enabled there, the pair is centered together. The window follows local
  iPhone time (day 06:00–18:00, night otherwise), without location access. Home and Farm share
  brief head-tilt, ear-tuck and tongue gestures plus a five-second rest. The first greeting
  should be visible promptly on entry, with quiet pauses between the later gestures. Local image cleanup was explicitly authorized; sources and deterministic
  processing provenance are retained. Physical-device performance and interaction acceptance
  remain separate gates. No updated phone build or distribution is implied by source work.
  See `docs/plans/home-hero-approved-direction.md` for sequencing and acceptance checks.
  Founder correction at 20:37 on 28 August: restore the older bordered Tonight design with
  bedtime/wake time and separate Before bed/After waking inset cells above Ollie. Restore one
  prominent green start card beneath the hero, choosing eligible Wind Down or Phone Away.
  Keep the rest of current Home and current character art; do not revive obsolete combined
  quiet-minute claims or the old five-tab navigation.
## Shared-habits implementation records

These dated records identify authorized slices and their evidence sources. Verify current
deployment and physical validation in the linked plans before making capability claims.

- Independent shared-habits refinement (2026-08-28, local candidate): Ideas & sources uses a
  topic library with focused idea/source details. Nights and Connections share observed Health
  status and contextual connection/help controls. Slumber Party member cards show one chosen
  Shepherd, Ollie or discovered sheep; the new optional avatar wire field is capability-gated and
  requires separate backend deployment. This does not enable sensitive Health/app-data sharing
  or implement the approved party-lifetime archive. See
  `docs/plans/shared-habits-independent-implementation.md` for validation and remaining gates.
- Remaining shared-habits implementation is now authorized (2026-08-28): add separately
  consented duration summaries and a party-lifetime archive with current/former-member deletion,
  existing-member affirmation, and offline publication fencing. This is an additive capability;
  it does not reinterpret older agreements or allow private pre-join backfill. The founder also
  approved build 36 and Health purpose-text changes for the beta candidate. Backend deployment,
  public disclosure, native validation and beta processing remain distinct gates. No Singapore
  exact-app export capability is implied by this authorization. Follow
  `docs/plans/shared-habits-implementation-20260828.md` and its reviewed wire contract.
## Farm labels

- Farm's user-facing task labels are **Ollie's Search** (the missing-sheep board) and
  **Search Journal** (history). Do not call a completed Wind Down or Phone Away note a
  “search” or a “protected night.” First-run sheep and the independently chosen Shepherd wearable are
  **welcome gifts**. After a completed Wind Down or Phone Away, a found sheep is “Ollie
  found a missing sheep.” Existing internal search/history type names may remain stable
  while copy migrates.
- Use the belonging test in `docs/PRODUCT_PRINCIPLES.md` to clarify how a feature supports the
  product. It is a decision aid, not a veto over explicit founder direction.


## Release capability boundaries

- Four tabs: Home, Nights, Farm, Settings. Farm/Shop/lifecycle/customization use real
  persisted production data; general Friends and mock MVP remain behind their debug gates.
- Slumber Party v4's production schema/functions were deployed on 25 August. Ordinary
  Debug remains off; TestFlight/Release uses `SUPABASE_NIGHT_FLOCK_ENABLED=YES` as authorized.
  Later additive capabilities still require their own deployment/consent evidence.
- Optional read-only Health duration/stages, Screen Time reports/pickers, the selected-app
  barrier, optional NFC, and the timer-mirroring Watch are included in 1.0. Physical reads,
  extension signing/Family Controls distribution, privacy disclosure, and terminated-app
  overnight behavior need device evidence. UWB and QR placement remain deferred.
- ActivityKit remote delivery remains separately gated by ADR-0005 and disabled by default.
  Do not conflate authorization, local implementation, deployment, distribution, or QA.
- Release priorities are physical overnight/restore/notification/Live Activity/Watch/NFC
  and timezone/DST checks, accurate disclosures, signed archive and embedded-extension
  validation, plus current account/Farm acceptance. Use the release playbooks for execution.

## Documentation drift

ADR-0020 supersedes completion-only Farm searches and three-night Phone Away gating;
ADR-0021 preserves the local transaction-store and payload boundaries; ADR-0023 supersedes
optional backup and Apple-only account journeys in ADR-0021/0022. Slumber Party v1–v3
and old goal/readiness/per-field-sharing models are historical compatibility records,
not the current v4 membership contract. The 26 August onboarding direction superseded
older two-question, combined-reveal, profile-matched pending gifts. The old guide's full
chronology is retained only in the [historical snapshot](history/agent-guide-before-cleanup-2026-09-07.md).
