# Future Agent Tasks — Prioritised Backlog

## Shared Farm and contextual cheers — rollout and device gates (9 September 2026)

Production native source now integrates the shared Farm, member update sheets, contextual
cheers, durable queued update-cheer recovery and named recipient entries. The additive backend
source includes optional public head shape, participant-only app acknowledgements and a bounded
projection retaining each member's latest/cheered update. See [plan and validation](plans/slumber-party-shared-farm-and-cheers.md).

- With separate authorization, deploy the matching Edge validator/handler before migration
  `20260909090000_slumber_party_farm_cheer_receipts.sql`; verify advertised capabilities and
  mixed-version profile writes against the deployed catalog. This task deploys nothing.
- Run physical two-account A/B tests: different characters/outfits/head shapes, exact update
  selection, duplicate taps, ambiguous send + relaunch, acknowledgement + sender reconnect,
  account A/sign-out/B/A, leave/rejoin/block, and loss of consent. Use disposable accounts.
- Verify the unchanged active Wind Down boundary with live background/foreground/overnight
  transitions: no new in-app social interruption and no claim of human attention from app receipt.
- Confirm native VoiceOver speech/focus and Reduce Motion on physical iPhones. Simulator
  accessibility-tree/layout inspection is separate evidence from physical assistive technology.
- Operate existing 90-day stream cleanup and verify cascading acknowledgement cleanup;
  legacy round retention continues to require its existing operations review. Receipt metadata
  is participant-only and never a read receipt or a party-lifetime history grant.



The shared work queue for Codex, Cursor, and human sessions. Pick from the top; read
`AGENTS.md` first. When you finish a task, mark it done here (with date + session) and
file any follow-ups as new entries.

Field legend — **Mode**: Codex / Cursor Plan→Build / Cursor Build / Cursor Multitask
(parallel-safe) / Human. **Size**: S / M / L. **Autonomous**: whether an AI agent may
execute without human sign-off mid-task (final merge review still applies per
`docs/PLAYBOOKS/pre-merge-review.md`).

## Current implementation

- **2026-08-29 · Shared-habits agreement repair:** Release Edge date-wire compatibility
  is deployed; founder confirms receipt/summary loading on the installed phone. Compact
  See more disclosure and scoped retry state are local only. Final build, 763 app tests
  and 27 backend tests pass, including an actual Swift/SQL/Edge replay. Next-night sleep
  ingestion, two-member publication, full accessibility and new-build distribution remain
  open. Evidence and capture-tooling gap: `docs/plans/shared-habits-agreement-repair-2026-08-29.md`.

- **2026-08-28 · Minimalist Home hero, partial implementation:** Native personal Ollie welcome,
  compact expandable timing, one factual social highlight, intact round label, and a local-clock
  day/night window are implemented. Shepherd remains out of the native hero; design comparison
  is off by default. Following explicit local-processing authorization, the ear/tongue/flop
  sprites and three cosmetic sets are implemented (64 new imagesets); visible Home's failed
  geometry observation was also repaired. Physical-device performance, full interaction and
  accessibility QA remain before accepting the whole implementation. See
  `docs/plans/ollie-motion-implementation.md` and the earlier Home checkpoint.
  The final scoped source/asset review found no blockers; final build and 721 tests passed.
  Follow up with manual viewport exit/re-entry, drag pause and lowest-control checks (P2),
  and missing-equipped-overlay coverage for each supported accessory's rest group (P3).

- **2026-08-28 · Membership sharing, local source accepted:** Immediate post-join/between-round
  sharing is implemented with capability fallback, membership epochs, durable cheers, mixed-client
  history and independent round grants. Parent reruns: main/QA 698 tests each, recovery 15,
  PostgreSQL migration plus three SQL suites, Deno 20, Python 7. Fresh source review: no blockers.
  Unlocked-Mac retest passes final manual/saved Phone Away → Active, group/history/menu controls,
  accessibility-size layout and bounded iPhone SE interaction. Ordinary swipe/wheel scrolling
  was subsequently confirmed by the founder for that candidate; automation could only prove
  accessibility-driven reachability. The newer hero layout needs its own scrolling check.
  Distribution remains held for that gap, broader accessibility, physical/two-account QA,
  separately authorized hosted rollout, privacy publication and retention operations. See
  `docs/plans/slumber-party-membership-sharing.md`. No deployment or phone build update occurred.

- **2026-08-27 · Home/social recovery in the parent task:** The earlier Home handoff entry
  below is implementation history, not acceptance. The founder rejected its visual hierarchy
  and clarified Slumber Party's core role. `docs/plans/home-social-recovery.md` owns this
  correction; `docs/plans/recent-changes-sol-review.md` records candidate review and remaining
  gates. Parent interaction testing reproduced a nested Phone Away destination surviving a
  successful start despite green tests, and the actual coordinator recovery probe exposed
  expired deferred-Morning shielding replay. Both are corrected: final r3 passed 690 tests in
  each main/QA configuration, 15 runtime probes, and the saved-start interaction retest.
  Physical protection, real two-account sharing/recovery and distribution remain release gates.
  The founder subsequently approved outside-round sharing; implementation and rollout status
  are in `docs/plans/slumber-party-membership-sharing.md`. No new private-data fields or
  unreviewed backend deployment are authorized.

- **2026-08-25 · Slumber Party v4:** The founder-approved canonical contract is documented in
  ADR-0016. Its additive v4 source now includes the schema fence, long-lived named party/round
  model, transactional five-party cap, service-only recoverable invites, canonical curated
  profile, factual activity ledger with per-party fan-out, revisioned status/cheer ledger, and
  tombstone deletion. Following explicit founder approval, all five Slumber Party migrations,
  both JWT-protected Edge Functions, and versioned invitation secrets were deployed to the
  production project on 2026-08-25; the remote migration head, authenticated endpoint behavior,
  and secret names were verified without exposing values. Do not reintroduce v1–v3 goals,
  readiness, aliases, orientation, sharing matrix, or global once-only rewards. Updated app
  distribution, moderation operations, retention policy, privacy publication, Apple-link
  recovery, and physical QA remain human gates.

## Recently completed

- **2026-08-27 · Codex:** Completed the Home/Phone Away implementation handoff. Home now
  consolidates the Wind Down plan and keeps manual/scheduled Phone Away actions visible with
  typed protection preflight, a focused Family Controls repair route, five-to-thirty-minute manual
  duration choices, actual-start anchoring, and saved-occurrence preservation. Active Purpose is
  published immediately and scoped to the App Group registry identity. The contextual guidance
  library now has stable Evening/Morning/Phone Away groups, source metadata and links, optional
  routine insertion with replacement confirmation, and deterministic dismissible Home placement.
  The simulator build and full unit suite pass; physical Family Controls, NFC, background/restore,
  accessibility, and small-device visual checks remain open.

- **2026-08-26 · Codex:** Rebuilt first-run Phase 1 around one optional six-question behavioral
  chapter, deterministic explicit-evidence starting patterns, a separate universally eligible
  claimed-on-choice Shepherd welcome gift, real Mabel/Ollie artwork and finite reduced-motion-safe
  reaction, ordered compact routine editing, explicit reminder authorization, and a truthful
  manually started Wind Down summary. Existing onboarding raw steps, reward/storage keys, legacy
  profiles/pending gifts, configured-user routing, and required Screen Time protection stay
  compatible. Notification/Live-Activity routine projection, remote privacy cleanup, physical
  Family Controls/notification verification, and final small-device/assistive visual review are
  Phase-2 or human follow-ups; do not represent them as shipped.

- **2026-08-25 · Codex:** Streamlined first-run setup to an eight-page full path with two varied
  narrative compositions, two explicit profile questions that both affect the result, a combined
  starting-point/three-gift reveal, and route-aware page counts (seven when questions are skipped).
  Onboarding chrome, timelines, schedule rows, summary rows, and actions now use scalable or
  adaptive layouts; AX3 simulator captures confirmed scrollable, reachable content. A physical
  iPhone 12 pass at the affected user's exact text size is still required. The wider app remains
  only partially Dynamic Type-adaptive; audit non-onboarding fixed display fonts, fixed canvases,
  and horizontal control rows before claiming app-wide large-text support.

- **2026-08-24 · Codex:** Replaced the uninterrupted first-run journey with schema-6 Home Basics
  and opt-in Around the Farm chapters. Added deterministic schema-five migration, paused-only
  chapter Resume routing, compact Dynamic Type-safe coach actions, post-render Settings/Nights
  contextual tips, an explicit Moonlit Coat keep-or-wear choice, and owned-gift Shop presentation.
  Generic guide navigation no longer mutates Farm ownership or equipment. Full simulator tests
  pass; physical iPhone 12 layout and VoiceOver proof remain manual follow-ups.

- **2026-08-23 · Codex:** Added the independent Wind Down/Screen-Free Morning settlement
  foundation: `ollie.windDownMorning.settlementJournal` is the local authority for the hidden
  420-minute Wind Down result, delivery/reveal markers, linked Morning occurrences, and Sunrise
  Trail replay. The App Group holds only a revisioned derived shield registry. New starts require
  current Family Controls readiness and an opaque non-empty app/category selection; post-start
  shield failures fail open and request repair. Sunrise fills are isolated from Wind Down and
  Phone Away, and Slumber Party excludes all Screen-Free Morning data. Remaining work is physical
  device validation (authorization/revocation, terminated monitoring, NFC, Watch/Live Activity,
  notifications, accessibility) and final full-suite/release-candidate evidence; no upload or
  final Screen-Free Morning candidate is claimed here.

- **2026-08-26 · Codex:** Added the Settings-only NFC “Reset and pair this tag” recovery path.
  It recognizes the established one-record Counting Sheep external type with a valid UUID across
  reinstalls, updates, devices, accounts, and empty local libraries; blank tags still pair normally.
  Occupied credentials require explicit confirmation and a second scan before a newly generated
  credential is written. Primary/backup slot identity, names, purposes, and old-credential
  retirement are preserved only after a confirmed physical write; foreign/malformed/multi-record,
  unreadable, read-only, undersized, cancelled, and failed-write cases leave registrations alone.
  No tag-locking or password-protection APIs are used. Shared policy and library tests cover
  reinstall/update recovery, forgotten tags, empty-library recovery, primary/backup replacement,
  foreign rejection, and failed writes. Physical NFC QA remains required.

- **2026-08-23 · Codex:** Added a local-only production pasture scene: each sheep, Ollie, and
  Your Shepherd keeps an independently draggable, footprint-clamped settled position outside
  `FarmState`. Calm, single-sequence ambient motion and an occasional short Ollie/sheep chase are
  ephemeral and disable under Reduce Motion. Pure layout/decoding/planning coverage was added.
  Simulator/manual checks still required: ordinary sheep/Ollie/Shepherd taps, long-press drag and
  interrupted-drag recovery, and an immediate horizontal swipe from a character hit target.

- **2026-08-23 · Codex + Luna/High:** Added `group.com.ngawangchime.countingsheep` to the Shield
  Configuration source entitlement, regenerated XcodeGen output, and verified the Release
  simulator build. The development Release archive succeeded for build 11; deep code-sign
  verification and the embedded Xcode-managed development profile both contain Family Controls
  plus the exact App Group. Portal capability assignment and seven valid App Store distribution
  profiles were completed, including corrected main profile `Counting Sheep Main App Store
  Corrected`; manual App Store Connect export succeeded at
  `/tmp/counting-sheep-shield-app-group.fMCmji/Export7/Counting Sheep.ipa`, and the exported
  Shield Configuration profile/entitlements plus deep signature verification passed. Upload and
  physical four-presentation QA remain open.

- **2026-08-23 · Codex + Luna/High:** Moved Brief Access's post-use check-in into the iOS 26.4+
  app/category shield submenu, removed the in-app reflection sheet and redundant Keep Wind Down /
  Keep Phone Away item, and added a run-scoped pause/allotted-minute tracker to the shield and
  active-run UI. The generic iOS Simulator build succeeded, and the iPhone 17 / iOS 26.4.1
  simulator evidence reports 487 tests passed; physical-device QA remains required for shield
  refresh, submenu routing, and accessibility.

- **2026-08-22 · Codex:** Implemented the Farm Shop economy architecture expansion while leaving
  final artwork uninstalled for founder review: a 31-item fixed catalogue with the established
  wool and capacity rules, permanent 3/10/25-Wind-Down-or-4/8/12-discovery unlock tiers enforced
  in `FarmState.purchase`, named pasture-zone exclusivity, four bounded keepsake slots, schema-v3
  migration, item-detail preview infrastructure, and a privacy-minimised aggregate economy export.
  Deterministic collector, decorator, and duplicate-trader simulations cover the stated early,
  14-Wind-Down, and 60-Wind-Down balance targets.

- **2026-08-17 · Cursor:** Addressed legacy schema-three review P1s: overnight terminal publish keeps
  v3 metrics, sleep/restfulness can update after the morning note and HealthKit, join/create
  disclose default-on fields, sharing flags project independently, out-of-bounds minutes are
  rejected rather than clamped, and SQL tests cover leave/delete, retention, seven-night and
  group grants, and grant acknowledgement. Ordinary Debug stays off. No hosted deploy.

- **2026-08-16 · Cursor:** Implemented legacy Slumber Party schema-three social metrics and bounded
  Farm rewards: independently controlled sharing, named seven-night member progress, rounded
  Wind Down and Phone Away minutes, optional sleep/restfulness, server-authoritative grants, and
  an additive migration after v2. Ordinary Debug stays off. No hosted deploy or Release-flag
  change.

- **2026-08-14 · Codex:** Made Phone Away search settlement recoverable and idempotent. Pure
  Shared rules now centralize the 15-minute floor, approved 100-minute per-run cap, practice /
  early-ending exclusions, locked banking, carried remainder, deterministic bonus ladder, and
  isolated Phone Away drought. Each terminal Phone Away run persists a per-run settlement record
  with eligibility, applied delta, meter before/after, and outcome ID before Farm projection;
  launch reconciliation replays missing Farm arrivals from persisted outcomes. Existing
  `SheepSearchState` / `FarmState` data remains backwards-decodable, and no project targets,
  entitlements, App Groups, or backend paths changed.

- **2026-08-13 · Codex:** Implemented the progressive three-step Home guide with one-time
  contextual spotlights that reuse the Home coach-mark language, the capitalized Phone Away mode,
  its carried 100-minute bonus-search meter
  and isolated deterministic odds ladder, plus finite NHLBI-sourced meal and caffeine guidance.
  Future sleep-habit experimentation remains gated: seven local-only nights, passive HealthKit
  wake context, one chosen topic, one end reflection, no checklist/reward/sharing, and qualified
  sleep/CBT-I review before external release.

- **2026-08-13 · Codex:** Reconciled the founder-approved product contract across canonical
  documentation: Wind Down remains the nightly sleep-bookends ritual; Phone Away uses “Put phone
  away,” “Start now,” and “Plan”; internal `additionalQuiet`, `PhoneBreak`, `QuietTime`,
  `NightWatch*`, persisted enum values, and `ollie.*` keys remain backward-compatible; the
  centrally configured Phone Away meter is 100 minutes; Wind Down supports private ordered
  suggestions (up to three evening, two morning, phone away first) without completion claims;
  guidance is general sleep-health education rather than insomnia treatment; and the full source
  register is local under “About these ideas and sources.” Settings, Farm labels, Slumber Party
  contextual-card placement, and privacy boundaries are documented. No clinical review is claimed.

- **2026-08-12 · Codex + human device confirmation:** Redesigned the Apple Watch companion
  around the current storybook Ollie, shared the exact iPhone app icon, and validated current
  timer mirroring on the paired physical Watch plus 46 mm and 40 mm simulators. Fixed stale
  Watch application context so an authoritative no-run reply cannot show Quiet Time before
  iPhone onboarding or after reset. Founder deferred UWB Watch placement and QR from v1; current
  release setup remains App Shielding (timer) or NFC + App Shielding. Prepared four 46 mm Watch
  listing candidates. Dynamic Type and a complete timer/NFC overnight remain physical QA items.

- **2026-08-16 · Cursor:** Founder authorized TestFlight/Release archives to compile with
  `SUPABASE_NIGHT_FLOCK_ENABLED=YES`. Ordinary Debug stays off. The SlumberPartyQA scheme remains
  the local diagnostics lane. No hosted deployment, archive, or TestFlight upload was performed.

- **2026-08-12 · Codex:** Implemented the ADR-0016 invite-only Slumber Party source slice behind
  `SUPABASE_NIGHT_FLOCK_ENABLED=NO`: Apple identity linking that preserves the Supabase Auth UUID,
  normalized schema/RLS/service RPCs, typed functions and app contracts, monotonic local outbox,
  run-boundary callbacks, Home/Farm/completion surfaces, fixed reactions and safety/deletion
  controls, privacy-safe aggregation, retention implementation, and Swift/SQL/Deno tests. Nothing
  was deployed; the external release task below remains mandatory before enablement.

- **2026-08-16 · Cursor:** Addressed first-run review P1s: questionnaire completion owns the
  wearable even if the result screen is skipped; Resume restores the current surface and practice
  sheet; coaches still appear without a spotlight target; claim and equip remain separate Farm
  lessons. Founder review of copy and tour flow remains the D6 merge gate. No `project.yml`,
  entitlement, or hosted backend work.

- **2026-08-16 · Cursor:** Implemented Phase 2 of the first-run journey: narrative welcome,
  Wind Down starting-point questionnaire UI, sourced recommendation result, profile-gift
  announcement, and a versioned resumable in-app guide through Home, five-minute practice,
  Farm, Slumber Party, Settings, and Nights. Existing onboarding/orientation JSON migrates.
  No `project.yml`, entitlement, or hosted backend work.

- **2026-08-16 · Cursor:** Implemented the production foundation for the founder-directed
  first-run journey (ADR-0018): one starter sheep on a fresh Farm, a local non-clinical Wind
  Down starting-point questionnaire domain, a pending shepherd wearable gift, a one-time
  onboarding-practice sheep that consumes neither guarantee counter nor the Phone Away meter,
  independent first-three guarantees for qualifying protected-night and Phone Away meter
  searches, and a 420-minute protected-span rule. Existing settled outcomes remain intact.

- **2026-08-16 · Codex:** Reworked Slumber Party into the now-legacy schema-two shared
  commitment: one bounded goal for 2–8 people, an explicit lobby/start gate, reusable hashed
  invites, named coarse member progress, optional stable guidance IDs, local Family Controls
  confirmation with coarse shielding evidence, separate social/impact controls, persisted
  orientation and replayable contextual tips, and updated copy/privacy/QA contracts. The v1
  outbox and decoder remain compatible; no hosted deployment or production flag change occurred.

- **2026-08-11 · Codex:** Completed the Farm presentation pass: rebuilt the Farm Shop as a
  non-clipping category catalogue with one wool balance, owned progress, compact responsive item
  cards, and explicit affordability/equipment states; clarified Ollie's Search tracking copy and
  metrics; added meaningful Farm destination counts; and replaced twelve generic Shop,
  decoration, wardrobe, and equipment glyphs with transparent pixel-art inventory assets.

- **2026-08-11 · Codex:** Replaced the procedural Shepherd hair overlays with five authored,
  reference-led transparent avatar assets. The compact modular character retains skin and outfit
  tint masks, and the customization screen now presents every hairstyle in an unclipped adaptive
  grid with selected and accessible states.

- **2026-08-11 · Codex:** Consolidated the Farm economy into wool as its single currency.
  Version-two `FarmState` converts retired Farm cash at five-to-one, rounded up once, without
  touching legacy `UserProgress.coinBalance`; capacity, Shop prices, balances, transaction
  deltas, and sheep trading now use wool throughout.

- **2026-08-10 · Codex:** Implemented the production Farm lifecycle and ADR-0015: individual
  migrated flock inventory, permanent discovery and Search Journal history, paged pastures, finite
  Barn capacity and pending arrivals, protected-night wool regrowth, user-directed shearing and
  selling, tracked Ollie's Search leads, the original local dual-currency Farm Shop,
  Ollie/Farm/Shepherd equipment,
  and inclusive local shepherd customization. Production flows use `FarmState` and
  `SheepSearchState`; the legacy mock layer remains isolated.

- **2026-08-10 · Codex:** Tightened the Home orientation into three precise spotlights for
  the complete Tonight card, the actual start action, and bottom navigation using one geometry
  space and collision-aware coach placement. Home and confirmation now preserve the identity
  of practice and additional-quiet periods, and optional app limits can be skipped per run
  without changing the saved preference. Notification settings now preview the next real
  schedule occurrence with stable dates/counts and clearer “Notification messages” language.

- **2026-08-10 · Codex:** Replaced the dashboard-like orientation card with a distinct,
  two-step shell-level spotlight over the real Tonight plan and bottom navigation. First-run
  onboarding now names the Home handoff, offers an explicit tour skip, makes no-shielding an
  equal protection choice, and keeps the five-minute practice optional and separate from tour
  completion. The version-two orientation state migrates legacy milestones without requiring
  tab visits or real quiet-time actions to finish the tour.

- **2026-08-10 · Codex:** Fixed late-night Wind Down restart anchoring by binding a restart
  to the current calendar-built ritual window through `protectedUntil`, preserved independent
  navigation paths for all four active-run tabs, removed the superseded Quiet Appearance
  runtime/UI, and moved the live journey to a canonical matte-black background. Shield copy now
  keeps the initial reflection uncluttered, uses the iOS 26.4 submenu confirmation when
  available, opens Counting Sheep from Continue Wind Down on iOS 26.5+, and bundles full-colour
  running Ollie in the Shield Configuration extension. Simulator build/tests cover the shared
  schedule behavior; physical proof remains required for app/category/web shields, submenu and
  older-OS behavior, approximately-five-minute restoration, cold/background launch routing,
  fixed-size Ollie rendering, and repeated tab navigation in each phase.

- **2026-08-08 · Codex:** Shipped the completion receipt and first Search Journal reveal redesign. The
  factual receipt now comes first; the single reveal action reads the persisted outcome by run ID
  without resolving again, and the Search Journal entry remains fully scrollable with found and search-only
  branches. Reworked the shipping Farm into pasture/flock overview, latest-arrival or quiet state,
  compact search map, and finite early Ollie's Search with “Still searching” / “Home” language. Added
  idempotent outcome-reopen coverage and Dynamic Type / Reduce Motion previews. Physical-device
  VoiceOver and smallest-device QA remain follow-ups.

- **2026-08-08 · Codex:** Consolidated Upcoming quiet times into a versioned persisted schedule
  with legacy plural/singular migration, multiple dated one-time periods, daily/weekday/custom
  recurrence, finite editing and cancellation, eligible manual claiming, overlap validation,
  passed-period pruning, earliest-occurrence resolution, and notification reconciliation that
  preserves active-run alerts and the iOS pending limit. Additional quiet remains outside
  protected-night and sheep outcomes. Physical-device notification and timezone QA remains part
  of B1.

- **2026-08-08 · Codex:** Added bounded Brief Access for selected apps/categories. The
  shield action persists a versioned pending grant before scheduling a one-shot restore,
  clamps the expiry to the current protected interval, and only then clears the named
  ManagedSettings store. Delayed callbacks restore only for the same run/revision; pending
  or stale callbacks reconcile the current schedule and reapply its shield if still eligible.
  Extension cleanup archives a bounded per-run count for later main-app import. Web-domain
  shields do not advertise Brief Access. Physical-device action routing, termination,
  restore timing, and refreshed Shield Action provisioning remain D1 checks.

- **2026-08-06 · Codex:** Added local, versioned notification copy overrides with a complete
  message library, next-Wind-Down instance preview, optional `{activity}`, `{purpose}`,
  `{time}`, and `{minutes}` placeholders, fixed shielding-failure copy, and legacy-safe
  scheduling. Wind Down setup and onboarding now use separate open-ended evening and morning
  cues with editable suggestions. Physical Lock Screen privacy/truncation and notification
  rescheduling QA remain follow-ups.

- **2026-08-06 · Codex:** Added the static, user-configurable Quiet Note accessory-rectangular
  Lock Screen widget to the existing WidgetKit extension. The note is explicitly entered
  through the widget configuration, normalized and privacy-sensitive; it does not read the
  private Wind Down purpose or duplicate Live Activity state. Settings includes a short setup
  guide. Physical Lock Screen, privacy-redaction, Always-On, and coexistence checks remain
  device QA items.

- **2026-08-10 · Codex:** Repaired Quiet Note setup sequencing and connected the installed
  widget to the existing Settings guide/editor. The widget now opens Counting Sheep through
  its deep link; the editor saves the normalized explicit note to the existing App Group and
  reloads the same widget kind. Physical Lock Screen, privacy-redaction, Always-On,
  coexistence, cold-launch routing, and App Group provisioning remain device QA items.

---

## A. Immediate TestFlight blockers (in order)

### Human-only (parallel, start now)
- Apple Developer enrollment; reserve app name; **submit Family Controls distribution
  request**; decide permanent bundle ID; pick canonical GitHub repo and make it private.

## B. MVP polish (before or shortly after first upload)

### B1. Validate a full Wind Down on physical hardware
- **Why:** the session deliberately crosses midnight and depends on restoration, local
  notifications, ActivityKit, and optional Watch timer mirroring that unit tests and a
  short simulator run cannot fully reproduce.
- **Mode:** Human + Codex · **Size:** S · **Autonomous:** no
- **Accept:** run from wind-down through morning quiet on a physical iPhone; cover locked
  screen, termination/relaunch, notification delivery, Live Activity phase changes, early
  end, Watch reachable/unreachable timer mirroring, and NFC recovery; record results in the TestFlight QA playbook. Repeat one
  schedule across a DST or timezone boundary before broader rollout. For the notification
  expansion, also verify Quiet/Balanced/Supportive counts, tip replacement, tap routing,
  reflection cancellation, three-minute DeviceActivity thresholds in all three phases,
  duplicate suppression, denied/empty Screen Time selections, and a full overnight usage
  reminder path before enabling usage-aware reminders for external testers.

### B2. Establish physical-device overnight energy baselines
- **Why:** the code is event-driven after the 2026-07-27 energy audit, but Live Activity
  display cost, WatchConnectivity cost, optional Supabase transport, and real suspension behavior
  require device measurements rather than inference.
- **Mode:** Human + Codex · **Size:** S · **Autonomous:** no
- **Files:** `docs/ENERGY_AUDIT.md`
- **Accept:** capture at least three comparable Power Profiler traces for idle, honor-timer
  without Live Activity, honor-timer with Live Activity, and Watch timer mirroring; capture one
  full overnight on-device Performance Trace; record selected-range CPU, display, network,
  and per-app power impact plus DEBUG event counts. Confirm there is no one-second
  persistence/Watch stream.

### B3. Design honest HealthKit read-access states — completed 2026-07-26
- **Why:** HealthKit intentionally does not disclose whether read access was denied;
  `authorizationStatus(for:)` only reports share/write authorization and cannot satisfy
  the old read-only acceptance criterion.
- **Mode:** Human decision + Codex · **Size:** S · **Autonomous:** no
- **Files:** `Services/HealthSleepService.swift`, build-2 Health UI copy
- **Accept:** completed with requested/no-data/error states; an empty result never claims
  access was denied. Nights explains that Apple's Sleep Score is not exposed through
  HealthKit.

### B3 follow-up. Contextual connections and observed Health status — local implementation, QA open 2026-08-28

- **Why:** Connections still says “Access requested” while Nights displays readable sleep;
  disconnected Nights routes require a Settings detour and Health lacks foreground refresh.
- **Implementation:** two configured Terra High lanes, parent validation, and fresh configured
  Sol-advisor review completed the independent local source slice. See
  `docs/plans/shared-habits-independent-implementation.md`. Builds and 734 Swift tests pass;
  native request/declined-data flow was checked. Final corrected-help/accessibility interaction
  checks stopped when the Mac locked. Physical permissions and return/cancellation QA remain.
- **Accept:** one truthful observed-data status across screens, native Connect/Refresh/picker
  actions in place, no inferred Health read denial, no silent protection disable, physical
  permission/return/cancellation checks, and joining without Health data.

### B3b. Shared-habits rollout and sensitive-data feasibility — open 2026-08-28

- Single-character Slumber Party cards, Group details, and the topic/source library are implemented
  locally. The additive avatar migration/Edge validator passed local SQL and Deno tests but are
  not deployed. Prove old/new-client and two-account avatar propagation before rollout.
- Complete final native feedback/help checks after unlocking the Mac, plus physical Health and
  Family Controls consent, revocation, foreground return and error states.
- Verified exact-app export for Singapore still needs a sanctioned customer route. Do not replace
  automatic verification with self-labelled categories or export report-extension content.
- Shared sleep averages, new sensitive-history transport and party-lifetime archives remain gated
  on attribution, consent migration, deletion/withdrawal and dissolution/operations review.
- No TestFlight or phone update is implied by the local implementation.

### B3c. Slumber Party social habit loop — local source complete 2026-08-30

- **Result:** additive v2 capability/agreement local source now publishes immutable rounded
  next-seven-night plans, frozen factual receipts, cooperative coverage, fixed cheers, and bounded
  idea borrowing. It excludes recurrence rules, custom text, exact app identity/per-app use, raw
  Health, and credentials; unknown evidence is not failure.
- **Plan:** `docs/plans/slumber-party-social-habit-loop-implementation.md`.
- **Remaining gate:** apply/verify the hosted migration and Edge source, publish the matching privacy
  disclosure, and complete physical two-account validation before calling the capability available.
  Exact app identity/use stays independently blocked pending written Apple permission and a
  supported Singapore customer route; do not substitute self-labelled apps or report extraction.
- **Accept:** two physical adult accounts can share versioned nightly plans and factual receipts,
  see coverage-aware group progress, borrow bundled routine ideas, leave/delete safely, and retain
  independent local ritual/Farm authority. No hosted rollout, entitlement, or app-data upload is
  authorized by the draft alone.

### B4. Decide and prove the production feedback route
- **Why:** the in-app backend is intentionally launch-gated; email fallback is already the
  safe default.
- **Mode:** Human + Codex support · **Size:** S · **Autonomous:** no
- **Accept:** deploy `20260801090000_app_feedback.sql`, `submit-feedback`, and
  `feedback-email-delivery`; configure verified Resend sender/recipient/secrets and a
  ten-minute Cron; approve privacy/App Store answers and 180-day support-mail retention;
  prove zero/one/three private screenshot uploads and one idempotent Gmail delivery on a
  physical iPhone. The schema and functions are deployed and the Release flag is now YES
  by explicit launch approval; finish the remaining external gates before enabling
  production notification delivery or calling this item complete.

### B5. Apply the Phone Away contract in release copy and balance code — completed 2026-08-27
- **Result:** user-facing Home, schedule, active, receipt, Farm, and Search Journal surfaces use
  Phone Away terminology and the “Put phone away,” “Start now,” and “Plan” action vocabulary.
  The existing `additionalQuiet`, `PhoneBreak`, `QuietTime`, `NightWatch*`, persisted enum values,
  and `ollie.*` keys remain compatible. The Home/schedule repair path, bounded manual duration,
  source-preserving start context, active purpose publication, and source-linked guidance library
  are covered by focused Shared tests plus the full suite.
- **Remaining gate:** physical Screen Time/NFC start and end, failure/retry, background/restore,
  accessibility, and small-device UI evidence remain human/device checks; do not treat simulator
  coverage as physical protection evidence.

## C. Architecture cleanup (post-first-upload, opportunistic)

### C2. Split AssetReadyScreens.swift (gated code)
- **Mode:** Codex · **Size:** M · **Autonomous:** yes
- **Accept:** one screen per file under `Views/MVP/`; still DEBUG-gated; builds.

### C3. Inject services into FocusSessionCoordinator
- **Why:** `.shared` coupling makes the core state machine untestable.
- **Mode:** Cursor Plan→Build · **Size:** M · **Autonomous:** no — core-loop refactor,
  human reviews
- **Accept:** coordinator constructible with test doubles; first coordinator unit tests
  exist; behavior unchanged.

## D. Product experiments (gated — check the ADR before starting)

### D1. App Store 1.0 entitlement and physical-device release proof
- **Gate:** code implementation complete; human Apple account and hardware required.
- **Mode:** Human + Codex support · **Size:** L · **Autonomous:** no
- **Accept:** Family Controls distribution profiles exist for monitor/configuration/action;
  a Release archive validates; generic NDEF lifecycle, registered-tag ending plus emergency
  bypass, terminated-app bookend transitions, HealthKit stages, and impact-data deletion pass
  `docs/PLAYBOOKS/testflight-readiness.md`. Deploy both pending production migrations and
  the versioned Live Activity registration endpoint; linked database lint must no longer
  report the registration-overload ambiguity.

### D2. Transparent behavioural experiments (post-1.0)
- **Gate:** enough real, consented local history and qualitative feedback from 1.0.
- **Mode:** Product decision before code · **Size:** M · **Autonomous:** no
- **Accept:** at most one rule-based, confidence-qualified experiment at a time; the user
  can dismiss/correct it; no composite score, opaque AI, medical claim, or extra nighttime
  interaction.

### D3. Curated educational Live Activity notes — completed 2026-08-01
- **Gate:** source register and locally bundled guidance surfaces are shipped in onboarding, Home,
  the active run, completion, and More. Live Activity remains limited to a single phase cue.
- **Mode:** Product + Codex · **Size:** S · **Autonomous:** no
- **Accept:** satisfied by `docs/DECISIONS/ADR-0008-wind-down-guidance.md` and
  `docs/SLEEP_GUIDANCE_SOURCES.md`: short static notes, authoritative source IDs, user goals
  first, no diagnosis or sleep-quality promise, no notifications/feed/novelty loop, and no
  nighttime interaction requirement. Any future expansion still needs product review.

### D4. Slumber Party v4 production follow-through and two-account proof — backend deployed, human gates pending
- **2026-08-28 activation update:** reviewed membership/avatar/shared-habits migrations and
  both matching Edge handlers are deployed to Release; the expanded public policy is live;
  build 37 shows Testing in internal and external QA. See
  `docs/plans/home-restoration-build37.md`. Physical two-account proof is still open.
  A read-only Cron metadata query found no job directly invoking
  `purge_night_flock_retention`; establish the actual retention operator/schedule and secure
  approval for any new cleanup job before claiming automated cleanup. Do not purge lifetime
  shared-habit archives as transient data. The public App Store draft still selects build 2
  and has obsolete reviewer instructions; reconcile before public submission.
- Include v4 recoverable-invite evidence: lost response, relaunch without mutation, host-only
  explicit compare-and-swap replacement, stale-CAS preservation, and no ciphertext, plaintext,
  digest, or idempotency material in logs or support captures.
- **Gate:** ADR-0016 v4 source implementation reviewed, production migration/function/secret
  deployment explicitly approved and verified on 2026-08-25; updated app distribution and
  physical/operational release evidence are still pending.
- **Mode:** Human + Codex support · **Size:** M · **Autonomous:** no
- **Accept:** enable Sign in with Apple for the main App ID and regenerate provisioning; configure
  Supabase Apple Auth/manual linking. Roll out in this fixed order: apply every historical
  migration, the existing invite-recovery migration, then the reviewed v4 fence/service-only
  ciphertext/five-party-cap/activity-ledger/fan-out/profile/status-cheer/tombstone migration;
  provision hosted Edge secret `NIGHT_FLOCK_INVITE_KEY_V1` with 32 cryptographically random
  base64-encoded bytes before deploying matching v4 state and command functions; validate legacy
  v1–v3 and v4 clients together where an appropriate hosted test lane exists; then complete
  physical two-account QA against the deployed production backend.
  `NIGHT_FLOCK_INVITE_KEY_VERSION` defaults to `1`; retain older `NIGHT_FLOCK_INVITE_KEY_Vn`
  secrets through any rotation until every invitation using their version is retired. The founder
  owns updated app/TestFlight distribution and the remaining physical release decision.
  Establish retention and a staffed moderation/deletion runbook, publish privacy materials, and
  pass physical proof for the five-party cap, active-round invite and late backfill, per-party
  reward fan-out, status expiry, durable silent cheers, host deletion, and the no-social-UI active
  Wind Down boundary. TestFlight/Release compiles with `YES`; keep ordinary Debug `NO`. Do not
  infer multi-device or Apple identity success from simulator tests.

### D5. Workshop reward decision gate — superseded 2026-08-16
- **Gate:** Founder choice required before any workshop copy promises a reward.
- **Mode:** Human · **Size:** S · **Autonomous:** no
- **Accept:** superseded by ADR-0018. The approved first-run contract is one starter sheep, an
  independently chosen and immediately claimed Shepherd welcome wearable, and one onboarding-practice
  sheep that does not consume protected-night or Phone Away guarantees. Do not grant extra
  sheep for a five-minute Wind Down test as part of Slumber Party work.

### D6. First-run questionnaire and Farm tutorial UI
- **Gate:** ADR-0018 domain, persistence, Search Journal/Barn/completion origin copy, and tests accepted.
- **Mode:** Cursor Build · **Size:** M · **Autonomous:** no — user-facing copy and tour flow
  require founder review
- **Accept:** The current first-run journey contains narrative welcome, one optional six-question
  starting-point chapter, a separate sourced explanation, an independently chosen immediately
  claimed Shepherd welcome gift, explicit schedule/reminder choices, private ordered routines,
  required app protection, then a resumable in-app guide across Home, practice, Farm, Slumber
  Party, Settings, and Nights. Skipping the questions never removes gift eligibility. Wear now
  equips through the correct effect-aware slot; keep for later preserves appearance. Resume
  restores the current surface. Founder review of copy and tour flow remains the merge gate. No `project.yml`,
  entitlement, or backend changes. Screenbook remains the five-scenario spike; additional
  first-run states are covered by `#Preview`s.

### D7. Review the expanded Farm economy after four weeks of TestFlight data
- **Gate:** at least four weeks of real TestFlight use with user-initiated economy exports.
- **Mode:** Product decision before code · **Size:** M · **Autonomous:** no
- **Accept:** review first-purchase timing, balances, ownership, shearing, and duplicate trading
  against the checked-in simulations. Prefer repricing only new items if progression is slow. If
  balances accumulate too quickly, consider permanent 30/45/60-wool environment themes before
  changing established wool yields or trade returns.

## E. Later / explicitly postponed (do not start; citable refusals)

- **Expanded Shop art installation** — generated exploration drafts remain outside the asset
  catalogue pending founder review for pixel style, palette, lighting, outline weight, transparent
  bounds, avatar fit across all five hairstyles, and pasture scale. Do not delete or replace the
  existing production assets until the approved inventory, equipped-overlay, and scene-prop set is
  selected and visually verified.
- **Screenbook Phase 2+** — after founder acceptance of the five-scenario technical spike,
  separately approve production hardening, the broader iPhone catalogue, copy application,
  localization, secondary Apple surfaces, and any private hosting. Keep investigating simulator
  profile changes that could invalidate the home-indicator canonicalizer, dependency-map
  omissions, browser-storage backup ergonomics, and equipped Farm decorations inheriting a
  transient `TabView` pre-layout position without expanding the Phase 1 registry or checking
  generated screenshots into Git.
- **General Friends / broader social** — Slumber Party is the sole ADR-0016 exception; every feed,
  chat, discovery, friendship graph, leaderboard, or other social surface still requires its own
  founder decision and ADR (ADR-0003).
- **Design-system convergence** (retire `GameComponents`) — opportunistic only.
- **New persistence layer / CoreData / SwiftData** — not needed at this scale.
- **CI pipeline** — valuable, but after first TestFlight; local gate suffices now.
- **Android / iPad / web** — out of scope (brief §non-goals).
- **Any analytics/tracking SDK** — conflicts with the privacy posture; needs human decision.

---

*Maintenance: keep sections ordered by priority; completed tasks move to a dated
"Done" list at the bottom; new tasks must include all fields.*

## Done

- **2026-08-01 · Founder-approved direction:** Replaced the equal-sheep-only reward model with
  Ollie's lost-sheep search loop. First three protected nights guarantee homecomings; later
  searches use transparent qualitative odds, exact-odds opt-in, wanted posters, rarity, positive-
  only optional bonuses, persisted trail progress, and distinct sheep identities.

- **2026-08-01 · Codex + human-approved plan:** Replaced ordinary Debug and Release
  navigation with Home/Nights/Farm and More as a utility sheet; moved setup and connection controls into More; kept
  Farm/Friends/Shop and the legacy shelf behind the explicit Debug preview argument; and
  made the then-release presentation derive its flock from `totalCompletedRuns` (superseded by
  ADR-0015). Added the validated feedback form, metadata-stripped screenshot
  preparation, automatic email fallback, private Supabase schema/Storage policies,
  authenticated idempotent submission, five-per-day enforcement, Resend delivery/retry,
  180-day cleanup, privacy declarations, release docs, and ADR-0007. Backend enablement,
  sender/domain/Cron configuration, public-policy publication, and physical-device delivery
  remain the human B4 gate; Release stays on email fallback until it passes.

- **2026-08-01 · Codex:** New Wind Down plans default to NFC, with the honor timer still
  available as a fallback. Added an opt-in automatic schedule with 60/30/10-minute lead-ins;
  selected Screen Time apps can be shielded by repeating DeviceActivity windows while the
  app is closed, and the main app reconstructs the run when next activated. iOS cannot
  silently launch the app from a local notification, so the active run remains visible on
  next open and the NFC tag remains required for normal ending.

- **2026-07-31 · Codex:** Added an explicit NFC replacement recovery flow. From setup or a
  failed active tuck-in scan, people can confirm that they want to pair a new writable tag;
  the existing Wind Down is preserved, the new tag confirms placement when appropriate,
  and a replacement during a running Wind Down becomes the only normal end credential.
  The old tag is superseded only after the new write succeeds; emergency ending remains
  available. Physical-device replacement and lost-tag QA is still part of D1.

- **2026-07-30 · Codex + human approval:** Prepared build 3 after physical NFC start
  feedback. The registered NFC tag now authenticates normal early ending, the Watch cannot
  bypass it, and a multi-step emergency exit remains available and records the bypass.
  Home presents the four Wind Down methods at the bottom of its configuration flow; the
  active-screen count-up is a bounded elapsed row; the taller Live Activity separates its
  timer, chosen activity, and one readable cue; optional impact consent uses a sheet; and
  customer-facing ritual copy is
  Wind Down while persisted `NightWatch*` identifiers remain compatible. Renamed generated
  permission copy and Screen Time extension display names, produced a valid signed archive,
  installed build 3 on the connected iPhone, and passed 74 tests. The matching-tag end
  barrier is physically confirmed; wrong-tag, Watch, shield-lift, and revised Lock Screen
  proof remain under D1.

- **2026-07-30 · Codex + human direction:** Implemented the App Store 1.0 NFC/shielding
  increment and sleep-outcome measurement foundation. Generic writable NDEF tags can be
  provisioned/replaced/forgotten and confirmed without retaining the raw token. Optional
  ManagedSettings shields cover only wind-down and morning quiet through dedicated monitor,
  configuration, and action extensions; observed status evidence feeds a 90-day local
  session/event history. HealthKit reads only `sleepAnalysis`, preserves duration and
  available stages from one coherent source, and powers a sample-qualified local comparison.
  Separately consented impact rows omit dates, raw samples, source names, selected apps, NFC
  identity, and free text, with stop/delete controls and RLS migration. No Foqos source was
  copied, so no NOTICE was added. The App Store export produced Family Controls distribution
  profiles for all Screen Time targets. Hosted migration, archive upload/App Store server
  validation, and physical-device proof remain D1.

- **2026-07-27 · Codex + human direction:** Added an ADR-gated development preview for
  NDEF phone-bed registration/confirmation and ManagedSettings shielding. The shared
  policy applies only to wind-down and morning quiet and clears overnight or whenever a
  run ends/resets. Release controls remain hidden until the first TestFlight gate passes.
  Reliable suspended/terminated transitions still require a separately registered and
  approved DeviceActivityMonitor extension.

- **2026-07-27 · Codex:** Removed Home CTA truncation by giving its title and schedule room
  to wrap, reducing fixed icon chrome, and shortening the schedule to the bed and phone-wake
  times. Before-bed and after-waking settings now share the same duration choices—15, 30,
  45, 60, 90, 120, or 180 minutes—through readable menus that preserve independent values.

- **2026-07-27 · Codex:** Made Nights data provenance explicit. The latest quiet-time card
  now shows an early-ended attempt when it is newer than the last protected night, and all
  key records show their date. Apple Health summaries retain their night-ending date, so an
  older sample is labelled as older instead of appearing as last night. Screen Time reports
  now use iPhone-only data, combine matching hourly streams, keep quiet hours visible, show
  selected-app time against the full report window, and allow each hour to be tapped for its
  exact duration. Removed the ambiguous unattributed-pickup count.

- **2026-07-27 · Codex:** Added a deliberately small CBT-I-informed context layer to Nights:
  an optional, collapsed three-question morning note with no score or rewards; a seven-night
  Apple Health wake-time range; and Screen Time report timing for Apple's exact first pickup
  plus the latest active reporting hour. Morning reflections stay in local UserDefaults and
  retain at most 45 days. Physical-device HealthKit and DeviceActivity QA remains required.

- **2026-07-26 · Codex:** Decoupled the Nights Screen Time report ranges from Quiet Time.
  People can now choose separate start and end times for late-evening and after-waking
  reports, see every selected app or category through Apple's privacy-preserving labels,
  and add, remove, or replace the shared selection. Added persisted preferences and interval
  coverage, including a report window that crosses midnight.

- **2026-07-26 · Codex:** Reworked the shipping reward loop into rotating keepsake
  families plus cumulative, never-losable protected-night milestones. New rewards retain
  a factual snapshot of the two credited bookends and selected offline cues; duration,
  warnings, streaks, placement method, and optional health/report data do not improve the
  keepsake tier. Completion now reconnects the reveal to the person's offline purpose, and
  the finite shelf explains each keepsake without rarity pressure or locked-slot teasing.
  Added legacy-decode and reward-selection coverage plus `docs/REWARDS.md`.

- **2026-07-26 · Codex + human decision:** Renamed the shipping Stats tab to Nights and
  replaced its Nights/Trends/Sleep/Insights segmentation with one finite scroll. Simplified
  Home to tonight's plan, an optional offline purpose, and one primary action; removed the
  manual Screen Time prompt and economy-heavy dashboard row. New plans retain 30/30 quiet
  defaults with selectable durations. Custom purpose text is local and in-app by default,
  with a separate opt-in before it can appear in reminders. Added read-only Screen Time
  report contexts for the configured before-bed and after-waking windows; physical-device
  report QA remains required.

- **2026-07-25 · Codex + human portal confirmation:** Completed C5 after Family Controls
  Distribution and `group.com.ngawangchime.countingsheep` were assigned to the containing
  app and report extension. The DeviceActivity report is embedded, both targets carry the
  approved entitlements, the main app compiles the reporting UI, and scoped selections
  migrate into App Group defaults without moving unrelated local progress. This enables
  read-only reporting only; shielding, NFC, and all-night blocking remain gated by ADR-0004.

- **2026-07-18 · Codex + human approval:** Enabled the existing read-only HealthKit sleep
  integration for Release, restored its prior authorization state, and refreshes last-night
  sleep on launch. Added a Debug-only immediate Night Watch start for backend/device QA and
  made the gated Farm preview derive its sheep count and occupied slots from authoritative
  `UserProgress` instead of the hardcoded 28-sheep mock.

- **2026-07-18 · Codex:** Decoupled Supabase Night Watch identity/history from ActivityKit
  token delivery. Starting a local run now restores or creates anonymous auth and syncs the
  device/run independently; terminal status follows completion or early end. Fixed XcodeGen
  xcconfig attachment, added the development push entitlement, extended the hosted schema
  for overnight end times, hid phone-finding UI outside Watch placement, and relabelled the
  reward shelf affordance.

- **2026-07-18 · Codex + human confirmation:** Aligned project-level Night Watch
  presentation. Both Nearby Interaction prompts now describe the optional tuck-in check,
  and the iPhone launch screen uses an adaptive warm neutral color asset instead of the
  generated empty launch dictionary. Regenerated the project and verified Debug, Release,
  packaged plist/assets, simulator presentation, and all 33 tests.
- **2026-07-18 · Codex:** Repositioned the active product around one phase-aware Night
  Watch spanning wind-down, overnight, and morning quiet. Added persisted bedtime/wake
  preferences, configurable quiet bookends, gentle offline cues, wind-down reminders,
  phase-aware iPhone/Watch/Live Activity surfaces, morning completion, and quiet-minute
  reward accounting that excludes overnight hours. Legacy runs still decode and retain
  their prior behavior. Added schedule/reward/compatibility tests and ADR-0006. Family
  Controls reports and shielding remain behind C5/D3 and human entitlement approval. Added
  an adaptive night palette and reconciled README, PRD, architecture, implementation notes,
  asset map, and TestFlight QA with the implemented product and ADR-0005 dependency.
- **2026-07-11 · Codex + human decision:** Added the embedded WidgetKit/ActivityKit
  Live Activity. A Focus Run now starts a glanceable Lock Screen/Dynamic Island status
  (also available to the paired Watch Smart Stack) using the system timer; it ends when
  the run is finished in-app. `NSSupportsLiveActivities` is enabled and a signed archive
  confirms the extension bundle is embedded. Completion-only intermittent reward variety
  is now the documented habit-formation direction.
- **2026-07-11 · Codex:** Focus Run feedback fixes. Starting from setup now returns
  directly to the active run, an unavailable Watch placement check automatically falls
  back to the timer, and completed Watch/timer runs now reach the reward + one gentle progress note.
  The return-to-phone copy explicitly welcomes a progress check without claiming to infer
  physical distance. Watch Ollie now uses the same pixel-art assets as iPhone.
- **2026-07-11 · Codex + human decision:** Focus Run architecture reset (steps 1–10).
  The iPhone now owns timing, restore, completion, and local notification scheduling.
  The default phone-away timer does not require the Watch or either app to stay open.
  Watch/UWB is a short optional placement assist; its old continuous warning, sampled
  check, demo, and fallback-coordinator paths were removed. A non-blocking QR phone-bed
  guard with manual fallback is available; NFC and Family Controls shielding remain gated.
- **2026-07-11 · Codex + human:** A3-remainder. Confirmed permanent bundle root
  `com.ngawangchime.countingsheep`, configured Team ID `4KZQPZR47B`, generated Xcode-managed
  iPhone/Watch provisioning profiles, and completed a signed Release archive.
- **2026-07-11 · Codex:** A6. Release Stats now exposes only Today and Trends backed by
  native `UserProgress` and reward data, with bedtime-framed nights, streak, minutes,
  stars, and recent history. HealthKit, Screen Time, manual logs, QA, analytics history,
  and export remain Debug-only. Removed the remaining Screen Time cards from Release Home.
- **2026-07-11 · Codex:** A7b + B2b. Added Watch VoiceOver labels/hints across setup,
  running, warning, completion, and early-end flows. Replaced framework jargon, warning
  pressure, productivity framing, and punitive early-end presentation with gentle copy.
- **2026-07-11 · Codex:** B4a. The third-run sheep cycle now holds a `3 / 3` celebration
  state with “A new sheep joined the flock!” before progress rolls forward.
- **2026-07-11 · Codex:** B4. Analytics export is unreachable in Release because the
  Insights surface is Debug-only; the known relative-date issue cannot ship in build 1.
- **2026-07-07 · Codex:** A4. Fixed hardcoded dashboard values. `PixelHomeDashboard`
  now reads Watch reachability from `WatchConnectivityManager.isReachable`, derives next
  sheep reward progress from `UserProgress.totalCompletedRuns`, and includes a
  disconnected-Watch preview.
- **2026-07-07 · Cursor/Fable:** A1. Working tree committed in 10 logical commits
  (shared → services → iOS UI → Watch → extension → assets → docs → agent OS).
  Nothing pushed; canonical-repo decision still with the human.
- **2026-07-07 · Cursor/Fable:** A2. Two-tab release scope. `MainAppTab.visibleTabs`
  and `FocusStatsTab.visibleTabs` gate Farm/Friends/Shop, the sleep tab, all MVP mock
  screens, `MVPMockData`, mock-backed components, and Screen Time UI behind DEBUG.
  Removed fake values (45m claim, 28-sheep floor, "/ 60" capacity). Bugbot reviewed
  (finding filed as B4a). 18/18 tests; Debug + Release builds green.
- **2026-07-07 · Cursor/Fable:** A3 (prep). Bundle IDs → `com.papermelon.countingsheep`
  (pending human confirmation), automatic signing, entitlement files wired (empty),
  MARKETING_VERSION 0.1.0 / build 1. Team ID still needed — see A3-remainder.
- **2026-07-07 · Cursor/Fable:** B1. Doc drift fixed across README/PRD/
  IMPLEMENTATION_NOTES/CHARLIE_AUDIT_ROADMAP; AGENTS.md §16 register cleared.
- **2026-07-07 · Cursor/Fable:** A7 (iOS) + B2 (run flow). VoiceOver labels/hints on
  the run flow, decorative scenes hidden, 44pt stepper targets; early-end screen made
  shame-free (happy Ollie), jargon removed. Watch views remain — see A7b/B2b.
## Pending human gates — 2026-08-23

- Obtain explicit approval before adding the proposed NFC usage description: “Counting Sheep reads the NFC tags you pair to start and end Wind Down and Phone Away.”
- Execute hosted and physical-device Slumber Party authentication recovery evidence for controlled 401 and `linked_account_required` across legacy v1/v2/v3 and v4 state, direct-command, and outbox lanes. Do not record account IDs, tokens, or unredacted snapshots.
- The v4 production schema, invitation secrets, and authenticated functions were explicitly
  approved/deployed on 2026-08-25. Approve and collect the remaining retention/minimum-moderation
  policy, updated privacy materials, Apple-link recovery, and physical two-account/three-account
  QA evidence before broader tester rollout.
- Brief Access has no `BriefAccessReflectionSheet` and no app-side reflection persistence key. It uses the existing extension/system purpose confirmation and run-scoped tracker; preserve emergency-exit reason storage separately.
