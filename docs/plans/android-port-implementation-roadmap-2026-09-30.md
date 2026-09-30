# Counting Sheep Android implementation roadmap

Date: 30 September 2026

Status: **AND-001–008 implemented and verified locally on 30 September 2026. The founder authorized AND-007 independent local domain/persistence work, then AND-008 usual-plan setup, guest start/live flows, separate overnight/Morning receipts and minimal Farm progress, followed by the guest introduction/starter/welcome and one real shearing action. Physical protection acceptance remains pending for the later consolidated pass. Build, unit, current-Swift semantic/codec and isolated API-36 UI/storage instrumentation evidence exists. Physical gates still control protection claims and release readiness. Account/services, broader launch parity and distribution remain separately authorized work.**

Build a native Android client in Kotlin and Jetpack Compose alongside the existing SwiftUI app. Reuse Counting Sheep's product rules, approved artwork and backend contracts. Prove selected-app protection and cross-platform Farm compatibility before committing to the full interface. The intended outcome is the same Wind Down ritual and account-owned Farm, with clearly described Android capabilities.

This is the working plan for starting an Android port. It defines proposed scope, technical defaults, ordered work packages, acceptance gates, device validation, release preparation and the decisions needed to begin. The project/protection/timing/codec foundation and integrated guest domain now exist under `android/`. [AND-001–006 evidence](../evidence/android-port/2026-09-30/README.md) remains historical; [AND-007 evidence](../evidence/android-port/2026-09-30-and-007/README.md) records current-source reconciliation, local settlement, migration/replay and semantic results. [AND-008 evidence](../evidence/android-port/2026-09-30-and-008/README.md) records the guest journey, v3 migration, fresh confirmations, current Swift routing/phrase parity and local UI validation. The [guest welcome/shearing follow-up evidence](../evidence/android-port/2026-09-30-guest-welcome-shearing/README.md) records fresh/existing Farm reconciliation, v4/Farm-v2 migration, real wool harvests, four-rarity regrowth parity and interrupted atomic actions. The [consolidated physical checklist](android-port-physical-acceptance-checklist-2026-09-30.md) owns the founder's later acceptance pass. Later feature and release checkboxes remain pending. Emulator evidence does not establish physical overnight enforcement, real account synchronization or Google Play approval.

## 1 Authority and source baseline

Founder direction and [AGENTS.md](../../AGENTS.md) control. Preserve the current [product direction](../PRODUCT_DIRECTION.md), including the four tabs and the distinction between requested protection, observed behavior and unknown evidence. This roadmap replaces the backlog's blanket Android deferral with an authorized bounded implementation; it does not expand iPad or web scope.

The main source contracts are:

| Topic | Current reference | Port requirement |
| --- | --- | --- |
| Session authority and routing | [Architecture](../ARCHITECTURE.md), [FocusSessionCoordinator](../../PhoneInTheOtherRoomApp/Proximity/FocusSessionCoordinator.swift), [HomeView](../../PhoneInTheOtherRoomApp/Views/HomeView.swift) | One phone-authoritative coordinator, anchored occurrences, reachable tabs, finite terminal receipts. |
| Farm credit and bonus | [ADR 0020](../DECISIONS/ADR-0020-cumulative-farm-credit.md), [current search plan](ollies-next-search-2026-09-20.md), [CumulativeFarmCredit](../../Shared/CumulativeFarmCredit.swift) | Port current versioned accounting, search guarantees and replay behavior. |
| Independent morning | [ADR 0019](../DECISIONS/ADR-0019-independent-wind-down-and-morning-quiet.md), [IndependentMorningSettlement](../../Shared/IndependentMorningSettlement.swift) | Linked Wind Down and morning occurrences retain separate clocks, rewards and receipts. |
| Account ownership | [ADR 0023](../DECISIONS/ADR-0023-account-owned-farm-sync.md), [account plan](account-owned-farm-sync.md) | Verified UUID ownership; automatic sync; account Farm defaults; displaced branches are archived. |
| Persistence and cloud payload | [Private save contract](farm-save-contract.md), [FarmSaveDocument](../../Shared/FarmSaveDocument.swift), [FarmBackupPayload](../../Shared/FarmBackupPayload.swift), [FarmBackupSync](../../Shared/FarmBackupSync.swift) | Atomic local transactions and recovery; strict, allowlisted cloud data; conditional writes. |
| Personal protection experience | [Personal shield plan](personal-shield-design-2026-09-17.md), [access and early wake repair](shield-access-and-early-wake-repair-2026-09-20.md) | Preserve routine access, confirmation intent, bounded Brief Access, early wake and emergency exit. |
| Shared ritual | [ADR 0016](../DECISIONS/ADR-0016-invite-only-night-flock.md), [social upgrade plan](slumber-party-social-upgrade-2026-09-28.md) | Accepted sharing agreements, invitations, inbox, consent boundaries and server capabilities. |
| Visual system | [Theme](../../PhoneInTheOtherRoomApp/Design/Theme.swift), [PixelComponents](../../PhoneInTheOtherRoomApp/Design/PixelComponents.swift), [asset naming](../ASSET_NAMING.md) | Reproduce the current illustrations, character roles, fitted cosmetics and accessible hierarchy. |

Pin an iOS source commit, relevant backend migration versions and an asset manifest at implementation kickoff. Reconcile later founder decisions before each milestone. Historical documents may describe completion-only rewards or optional manual backup; those rules must not reappear in Android.

The kickoff inspection established three important boundaries:

- No Android application existed at kickoff. The independent protection prototype now lives under `android/`; SwiftUI, Apple app extensions and watchOS features still need native Android implementations.
- The push registration validator accepts APNs-shaped hexadecimal tokens and Apple environments. Reusing the social event pipeline still requires an Android delivery adapter and compatible registration contract.
- The Shepherd uses the current native canvas renderer. Artwork reuse includes porting that rendering behavior; importing retired Shepherd raster assets would produce the wrong visual system.

Existing iOS changes and outstanding physical-device acceptance remain independent. The Android roadmap is not evidence that an iOS production or device issue has been resolved.

## 2 Proposed technical decisions

Founder approved Kotlin/Compose, one module under `android/`, minSdk 29, distinct debug identity, narrow foundation dependencies and a consented AccessibilityService prototype for AND-001–006, then authorized AND-007 local domain/persistence and the bounded AND-008 guest journey using that same module/dependency/permission scope. Actual pins and permission limits are in the [evidence](../evidence/android-port/2026-09-30/README.md). Backend/push and later release defaults below remain proposals.

| Decision | Recommended default | Reason and review point |
| --- | --- | --- |
| UI and language | Implemented Kotlin, Jetpack Compose and AndroidX lifecycle; navigation deferred | Native access to the platform features central to this app. Compose is Android's recommended UI toolkit. |
| Project location | Independent Gradle project under `android/` in this repository | Keep product contracts close to both clients without changing Xcode target membership. |
| Initial structure | Implemented one application module with `domain`, `data`, `platform`, `ui` packages | Add modules only when build times or independent delivery justify them. |
| Application identity | Prototype `com.ngawangchime.countingsheep.prototype.debug`; proposed public ID remains unconfigured | Confirm ownership and permanent release identity before the first Play upload. |
| Supported devices | Authorized/configured Android 10+, `minSdk = 29`; API-36 emulator tested, physical/minimum-OS gates pending | Confirm audience coverage, SDK requirements and device results in Phase 0. Large screens must remain usable even without dedicated tablet layouts. |
| Target SDK | Configured API 36 under official requirements verified on 30 September 2026 | Recheck at submission. Target SDK and minimum supported OS are separate decisions. |
| State and async work | Kotlin coroutines, immutable UI state, one session coordinator, manual dependency injection | Keep side effects outside composables and avoid an additional state-machine framework. |
| Farm storage | Versioned JSON transactions in private internal storage with checksums and recovery generations | Preserve the existing durable-store contract; do not introduce Room or a second ledger authority. |
| Small preferences | One native preference store with retained `ollie.*` identifiers where applicable | Preferences must not become the Farm transaction store. |
| Backend client | Review and pin `supabase-kt` and only needed modules, with owner-bound transport verified | Supabase documents this Kotlin client as community maintained. Approval of `supabase-swift` does not automatically approve it or its transitive packages. |
| Android push | Proposed Firebase Cloud Messaging delivery only | Add after explicit dependency/service approval; do not add Firebase Analytics or tracking as part of push setup. |
| Monetization | Preserve the current wool economy and Shop | No new real-money purchase system, ads, subscriptions or billing SDK in this port. |

The Compose recommendation follows [Android's UI guidance](https://developer.android.com/compose). The Kotlin SDK's maintenance status is documented by [Supabase](https://supabase.com/docs/reference/kotlin/introduction). The current submission floor is specified in [Google Play's target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en).

Keep the existing iOS application in SwiftUI. A simultaneous Flutter, React Native or Kotlin Multiplatform migration would enlarge this project. Revisit shared executable domain code only if maintaining two implementations creates measured drift that shared fixtures cannot control.

## 3 Feature scope and parity

An internal prototype can have narrow scope. A public release needs an explicitly accepted parity matrix; an incomplete prototype must not silently become the launch product.

| Feature | First usable internal build | Proposed first public release | Platform work |
| --- | --- | --- | --- |
| Home, Nights, Farm, Settings | Four-tab shell with real state | Full routing and relevant help/settings | Compose navigation, back handling, restored navigation state. |
| Wind Down | Manual protected start through terminal receipt | Saved routine, scheduling, overnight continuity, early wake | Android admission, scheduling and protection evidence. |
| Screen-Free Morning | Linked and standalone tested occurrences | Independent morning journey, defer/skip/start-now behavior | Separate settlement inside the same coordinator. |
| Phone Away | Protected start, tasks and receipt | Full secondary mode and independent search meter | Reuse shared timing and reward rules in Kotlin. |
| Brief Access and deliberate exit | Bounded access, restore and emergency exit | Intent-specific confirmations and personal routine/task access | Accessible blocker surface and one-use owner/occurrence handoffs. |
| Guest onboarding | Real guest Farm and plan setup | Current story, schedule, optional steps, gifts and returning-user routes | Permission setup remains deferrable before an actual protected start. |
| Account and private Farm sync | Fixture round-trips; isolated account build later | Password/handle login, Apple-account access, recovery, switching and deletion | Shared UUID, strict payload codec and owner-bound requests. |
| Farm and The Barn | Starter sheep and real earned progress | Lifecycle, capacity, wool, shearing, owned sheep, Barn and approved interactions | Transactional reward mutations and native scene rendering. |
| Ollie's Search and Search Journal | Deterministic result and carried progress | Current odds, guarantees, bonus rules and independent meters | Port accounting and discovery receipts, not visual-only progress. |
| Shop and customization | Limited real catalog for integration | Current approved equipment, wardrobe and fitted appearances | Stable item IDs and fallback rendering. Shop uses wool. |
| Fetch and Farm interactions | Add after core progression | Current approved phone interactions | Native input, animation and optional persisted best/equipment fields. |
| Slumber Party | Add after account identity is safe | Invite-only parties, supported shared Farm/meadow, agreements and bounded metrics | Reuse versioned server contracts and durable outboxes. |
| Campfire and Inbox | Add after the solo journey | Current private/Global visibility, buddies, invitations and cheers | Preserve explicit presence, moderation/withdrawal boundaries and server truth. |
| Invitation links and social push | Link parsing; in-app Inbox works without push | Verified Android links and optional approved push delivery | Website association file and additive FCM backend transport. |
| NFC plus app protection | Feasibility test with existing tags | Proposed inclusion after capability gate | Hardware detection, current NDEF format, provisioning and retired credentials. |
| Session notification | Accurate local status where permission permits | Platform-appropriate quiet notification and relevant actions | No assumption of Apple Live Activity or Dynamic Island parity. |
| Health sleep context | Deferred | Proposed post-launch slice | Separate Health Connect assessment, consent and available-data behavior. |
| Watch companion | Deferred | Proposed post-launch slice | Separate Wear OS work; the phone remains authoritative. |
| Exact-app social reporting, analytics and new AI | Excluded | Excluded | New data processing or sharing requires its own decision. |

NFC, Health and wearable release choices need founder confirmation before scope is frozen. Deferring Health or wearables must remove unsupported choices and claims from Android flows. Slumber Party remains a core feature; a solo-only public beta would require an explicit reduced-scope decision. Approved current social features do not authorize a new Friends graph, chat or general discovery.

## 4 Contracts that must survive the port

### Session and protection

- The person is the shepherd; Ollie is the capable border collie. Wind Down is primary, Phone Away secondary, and Screen-Free Morning is the release name.
- Adapt Family Controls readiness to Android's approved protection mechanism: valid consent, a non-empty device-local selection and operational readiness are required for each new protected start. Plan editing remains available before protection setup.
- One coordinator owns admission, the anchored evening/overnight/morning transition, Brief Access, technical interruption and terminal settlement. UI, accessibility callbacks, alarms and notifications send intents to it.
- Requested protection, schedule registration and observed blocker activity are separate facts. An enabled service is not proof of continuous blocking. Neither platform proves sleep, continuous physical placement, complete screen avoidance or routine completion.
- On a runtime protection failure, fail open, retain recoverable accounting, record the failure or unknown state, and route to repair before another protected start. Do not invent missed behavior during periods when the process or service was unavailable.
- Preserve emergency exit. Selected apps must not trap a person outside Counting Sheep, system permission repair, essential system controls or emergency access.
- Private routine/checklist/goal data stays local. Typed confirmations are not persisted, logged or uploaded. A stale owner, occurrence or revision cannot authorize a new action.

### Progress and economy

- Wind Down uses its 420-minute cumulative search trail; Phone Away uses its independent 100-minute meter with no three-night gate. Eligible early-ended time carries forward.
- Union and clip Brief Access intervals before subtracting them from cumulative Farm time. Preserve fractional carry, consumed interval unions, immutable receipts and idempotent replay.
- Include eligible overnight Wind Down time up to actual/planned end; exclude its separately rewarded morning window. Eligible timer credit grows wool under the current lifecycle rules.
- Version-2 bedtime bonus contributes 20 percentage points once per anchored night only when the current timing contract qualifies. It adds no factual minutes or wool growth. Retain old run versions and never backfill historical bedtime bonuses.
- Screen-Free Morning retains its existing eligible-elapsed and Sunrise Trail policy. Do not accidentally apply Wind Down's credit formula to the morning ledger.
- Retain independent search guarantees, odds, deterministic resolution, found-versus-clue outcomes, gifted-item eligibility and settled legacy rewards. A full trail opens a search; it does not promise a sheep.

### Ownership and data

- A verified immutable account UUID owns each Farm. Authentication, validated Farm activation and confirmed server save are separate states.
- Sign-in loads the account Farm. Archive displaced divergent phone progress before activation; do not combine balances. Same-base offline edits retain the existing conditional upload path.
- Sign-out removes the account Farm from active play without deleting it. Another account cannot inherit any local document, pending request, reward, profile cache or active selection context.
- Account use includes automatic private sync. Guest scope remains distinct. An existing declined upload agreement requires explanation and acceptance.
- Only the private Farm payload travels between platforms. Device-local Nights details, routines, reflections, Health data, app selections, NFC credentials and active settlement journals are not added to sync.
- The Android phone owns its local session. Changing phones does not resume a timer, transfer authorization or make the other phone a remote controller. Concurrent account edits use the current conflict policy, not an invented progress-merging system.

## 5 Android platform design

### Protection feasibility

An Android implementation cannot treat Apple's Family Controls types as portable. [UsageStatsManager](https://developer.android.com/reference/android/app/usage/UsageStatsManager) exposes usage information, while [managed-device app suspension](https://developer.android.com/work/dpc/security) has device/profile-owner requirements. Those are different capabilities from a normal consumer app's opt-in blocker.

The first candidate is a deterministic, explicitly consented AccessibilityService that observes the minimum package/window events needed and presents a Counting Sheep blocking surface for selected packages. Prefer an accessibility overlay if the prototype proves it covers the required interactions; do not assume a separate draw-over-apps grant or unrestricted background activity launch is necessary. The [AccessibilityService API](https://developer.android.com/reference/android/accessibilityservice/AccessibilityService) supports accessibility overlays; the design and its coverage are proposals requiring device proof.

Do not request window-content retrieval, text capture, screenshots or notification content for package blocking. Keep package identity and observed events local. Test selected apps launched from the launcher, notifications, recent apps and deep links, plus already-open apps, split screen and picture-in-picture. Explicitly record unsupported paths. Package selection is the canonical Android model; category shortcuts cannot claim equivalence to Apple's opaque categories. Website and embedded-browser coverage must not be implied.

Counting Sheep is not proposed as an accessibility tool for people with disabilities. The candidate therefore needs a separate prominent disclosure, affirmative consent, a Play declaration and review demonstration. Self-control does not justify preventing service disabling or uninstall, bypassing Android controls or silently changing settings. These requirements follow [Google's accessibility declaration guidance](https://support.google.com/googleplay/android-developer/answer/10964491?hl=en) and [sensitive API policy](https://support.google.com/googleplay/android-developer/answer/16558241?hl=en). Passing a prototype does not guarantee approval.

Start app discovery with scoped visibility for launchable apps. Document missing or unsupported packages and critical exclusions. Do not request `QUERY_ALL_PACKAGES` by default: Google restricts broad installed-app visibility and requires justification where allowed. See [scoped package queries](https://developer.android.com/training/package-visibility/declaring) and [Play package visibility policy](https://support.google.com/googleplay/android-developer/answer/10158779?hl=en).

If the candidate fails required coverage or policy fit, produce the evidence and a capability comparison. A timer-only fallback changes the current product contract and needs a founder decision; it is not a silent implementation shortcut. Device-owner enrollment, root access and a VPN are not default consumer-port solutions.

### Timing and background execution

Persist absolute planned boundaries and immutable occurrence identity. Derive UI countdowns from timestamps instead of writing a counter every second. Use a monotonic clock for live durations where appropriate, with explicit recovery behavior for reboot, timezone changes and manual clock changes. Preserve civil-date ownership of nights and reflections.

Reconcile desired protection from current durable state on relevant package events, foregrounding, service reconnection and supported system events. A delayed callback cannot extend an expired session or restore an old Brief Access grant. Persist an access interval before temporarily lifting protection; check its bounded expiry before allowing the next selected-app interaction.

Use OS alarms only where the tested user-facing boundary requires them. Prove whether lazy reconciliation covers session/access expiry and whether automatic starts require an alarm grant. `SCHEDULE_EXACT_ALARM` is user-granted and revocable; `USE_EXACT_ALARM` has narrower use cases. Do not assume eligibility or an exemption. Inexact delivery must not be described as an exact automatic start. See [Android alarm guidance](https://developer.android.com/develop/background-work/services/alarms).

Use WorkManager for eligible deferred sync/retry, never as the authority for precise five-minute restoration or session boundaries. Do not choose an overnight foreground service until its service type, launch conditions, user visibility and policy eligibility are established. Avoid constant polling and long-held wake locks. Android documents [persistent work](https://developer.android.com/develop/background-work/background-tasks/persistent), [foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types) and [Doze constraints](https://developer.android.com/training/monitoring-device-state/doze-standby).

Distinguish process death, recent-app dismissal, force-stop, service disabling and uninstall in the device matrix. Do not promise recovery during force-stop. On the next supported entry, reconcile stale state, preserve rewards and show repair without blaming the person. Boot behavior before first unlock must respect credential-protected storage; private routines and tokens must not be copied into device-protected storage just to run earlier.

### Local storage and backend compatibility

Use one serialized writer for the Farm transaction, with native atomic-file operations, checksums, recovery generations and unsupported-version preservation. Stage terminal snapshots before protection cleanup; replay reward effects once after interrupted writes. Keep guest/account/signed-out scopes and their fences durable. Android's local envelope may have platform-specific metadata, but synced payload semantics remain identical.

Build a sanitized shared fixture corpus from existing Swift tests and isolated server responses. Verify both directions through the actual codecs and server adapter: Swift encode → Kotlin decode/re-encode → Swift decode, and Kotlin encode → server response → both clients decode. Do not equate semantic compatibility with byte-identical platform serialization.

Specific traps to cover include:

- Cloud wire schema/economy version 1, nested Farm schema 3/4, and the separate local transaction schema. Never compare only the outer wire version.
- Numeric Foundation dates versus ISO date strings in server responses, including Foundation's 2001 reference epoch. Use field-specific conversions and fractional precision; do not interpret all numeric dates as Unix seconds.
- Optional omission versus explicit null, synthesized Swift enum shapes, UUID representation, integer bounds, unknown catalog IDs, new wardrobe fields and optional Fetch progression.
- Strict rejection of unknown destructive schema/fields, malformed amounts, missing required ledgers and invalid dates. A permissive decoder must not erase a newer save on re-upload.
- Durable operation identity, expected base revision and retry content. Persist the original pending request representation so a new codec/version cannot change an ambiguous retry's fingerprint.
- Session pinning: validate the owner and bind each request to that checked token. The existing [FarmBackupService](../../PhoneInTheOtherRoomApp/Services/FarmBackupService.swift) deliberately avoids a client adapter that can replace the Authorization header with a newer account session.

Audit credential storage for the selected client; use platform-backed key protection without custom cryptography. Exclude tokens, device identifiers, NFC state and the full local transaction/journal from unintended cloud backup or device transfer. Configure the applicable backup rules and test reinstall/transfer; `allowBackup` alone is not the complete acceptance criterion. Android documents [backup exclusions and transfer rules](https://developer.android.com/identity/data/autobackup). This is a proposed privacy-preserving default; any broader transfer needs an explicit contract.

### Accounts and existing Apple users

Implement handle/email plus password, registration, verification, recovery, expiry and explicit switching against the existing identity service. An Android install is a new local device scope, not a reason to create a new account or guest-overwrite a saved Farm.

The proposed Apple-account route is browser-based Apple OAuth through Supabase, with verified redirects and identity linkage preserving the existing UUID. Apple configuration and client-secret maintenance are separate work; Supabase documents a six-month secret rotation requirement for its Apple OAuth configuration. See [Supabase Apple sign-in](https://supabase.com/docs/guides/auth/social-login/auth-apple).

Test a native-iOS-created Apple account through the Android browser flow and prove the same UUID and Farm. Do not assume native and web Apple identifiers map correctly under the current configuration. A verified linked-password route is an alternative decision if browser Apple cannot meet the release gate. Never match or merge Farms merely by email, including private relay addresses. Google sign-in is optional future provider work, not a requirement for Google Play distribution in this plan.

### NFC compatibility

Use Android's native NFC/NDEF APIs after hardware and permission checks. Make NFC hardware optional for installation and keep App Protection available on phones without NFC. [Android NFC documentation](https://developer.android.com/develop/connectivity/nfc/nfc) describes the platform's NDEF handling.

Match the current [PhoneBedNFCService](../../PhoneInTheOtherRoomApp/Services/PhoneBedNFCService.swift) format: one Counting Sheep external-type record containing a lowercase UUID credential, with only its SHA-256 digest and local metadata persisted. Port tag purposes, primary/backup slots, retired-credential rejection, explicit overwrite/reset confirmation and read-after-write verification. Do not persist/upload raw credentials, write private names to tags or erase occupied unrelated tags.

Test the same physical tags on both platforms. Cloud Farm sync does not carry pairing authority: a new phone must explicitly establish its own pairing/recovery. Do not rewrite an existing credential silently, and do not describe a matching scan as proof the phone remained away overnight.

### Social delivery and links

Reuse the existing shared ritual APIs and agreement versions. Fetch capabilities before exposing unsupported actions. Android knowledge of package names does not authorize new exact-app sharing; Singapore/SEA assumptions remain unproven. Missing metrics remain unknown, never misconduct.

For push, add an explicitly approved platform discriminator, FCM token validation/storage and delivery adapter to the existing dispatcher. Preserve current APNs requests and delivery. Reuse event identities, receipt ordering, quiet hours, suppression, bounded retry and unregister revisions. Never send an FCM token through the present APNs-only validator. Credentials for delivery stay server-side. [Firebase's Android setup](https://firebase.google.com/docs/cloud-messaging/android/get-started) provides the client integration requirements.

Push is an optional signal to refresh the account Inbox, not the source of truth for invitations, cheers or session settlement. Handle token refresh, permission denial, sign-out, account switching, withdrawal and invalid tokens. Lock-screen content needs an explicit privacy review.

Add verified Android App Links for existing invitations and auth routes, preserving the website fallback and explicit review/join flow. Serve `/.well-known/assetlinks.json` with the release package and Play App Signing certificate fingerprints; debug and QA associations stay separate. Preserve current Apple association behavior. Test warm/cold/signed-out flows and pending-link recovery without automatic joining. See [Android App Link verification](https://developer.android.com/training/app-links/verify-applinks).

### Visual and accessibility implementation

Translate Theme and PixelComponents into one Android design system. Reuse approved assets and identifiers; adapt catalog packaging, density and format where needed. Port [ShepherdStudyCanvas](../../PhoneInTheOtherRoomApp/Views/ShepherdArtStudy/ShepherdStudyCanvas.swift), palette, garment geometry and current character layering to native Compose drawing. Do not revive retired raster art or attach Shop thumbnails as equipped overlays.

Build representative previews for loading, failed protection, empty selection, expired login, pending sync, incompatible save and large text. Support TalkBack, font scaling, at least 48dp interactive targets, readable contrast, keyboard navigation, safe insets, gesture navigation, predictable Back behavior and reduced-motion preferences. Keep bedtime scenes comfortable in a dark room. Routine release strings must pass the existing [copy review skill](../../skills/product-copy-review/SKILL.md).

## 6 Ordered implementation phases

Effort ranges below are initial planning estimates, not measurements or a launch commitment. Acceptance gates control progression. Each phase closes with inspected changes, applicable checks and a short evidence record identifying the exact source/configuration and unavailable checks.

### Phase 0 Kickoff and baseline

Bounded prototype gate complete locally: authorization, source/backend/asset inventories, toolchain, offline isolation and debug build recorded. Full launch parity/device acceptance remains later.

**Owner:** Founder plus Android lead. **Depends on:** implementation authorization. **Effort:** 0.5–1 engineer-week.

- Confirm project location, app identity, minimum OS, dependency allowlist, launch parity and available test phones.
- Pin the current iOS/backend baseline and record outstanding device/backend limitations separately.
- Approve foundation dependencies and prototype permission scope before installing or enabling them. Keep debug/QA incapable of accidental founder-account production mutations.
- Establish local toolchain versions, Gradle wrapper, environment separation and a reproducible build. Choose representative target apps and non-sensitive QA accounts.
- Create the feature checklist and assign one accountable owner per work package. No new feature discovery is hidden inside a port ticket.

**Deliverables:** kickoff decision record, source/asset manifest, dependency list, build instructions and device inventory.

**Exit gate:** approved bounded implementation scope, clean Android debug build, and verified isolation for all mutating tests.

### Phase 1 Protection and timing feasibility

Prototype implementation and local experiments complete; physical exit gate remains open. Accessibility overlay interception, Brief Access, emergency exit, live-process delayed start/expiry and native file recovery have isolated API-36 instrumentation evidence. OEM overnight/battery/launch-route acceptance and Play declaration/video are pending.

**Owner:** Android platform lead, with founder device review. **Depends on:** Phase 0. **Effort:** 1–2 engineer-weeks.

- Implement only the necessary selection, consent, blocker, persisted protection interval, bounded Brief Access and emergency exit prototype.
- Test automatic boundary feasibility, access expiry and reconnection without building the full Farm interface.
- Exercise the launch routes, window modes, OS lifecycle and package-visibility limitations in section 5.
- Measure battery use against an idle baseline under the same conditions. Review actual permissions and collected events; remove unnecessary ones.
- Prepare the disclosure/declaration draft and a demonstration recording. Document policy fit and unsupported capabilities; final Play review remains later.

**Deliverables:** runnable prototype, Android/iOS capability comparison, timing design, permission inventory and physical-device evidence.

**Exit gate:** selected-app blocking and safe expiry/exit work on the agreed devices, or the founder explicitly chooses a different product contract. A screenshot or enabled-service check is insufficient.

### Phase 2 Domain contracts and durable foundation

AND-006 codec proof and AND-007 local guest domain/persistence are complete locally. AND-007 extends the existing coordinator/store with anchored Wind Down, Phone Away, independent Morning, cumulative credit/bonus/growth, deterministic searches and atomic terminal replay. It adds no account/sync or full Farm interface. [Evidence](../evidence/android-port/2026-09-30-and-007/README.md) reconciles current Swift contracts against the historical prototype; physical acceptance remains pending.

**Owner:** Android domain/data lead; iOS maintainer owns Swift fixture export. **Depends on:** Phase 0 and the locally implemented AND-005/006 baseline. Physical Phase 1 acceptance does not block independently testable domain/persistence work; it still gates protection claims and release readiness. **Effort:** 2–4 engineer-weeks.

- Port the session reducer, anchored plan/scheduling rules, independent morning, exit authorization and Brief Access ledger into UI-free Kotlin.
- Port cumulative credit, bonus policy, search/reward identities and minimal Farm state required for a real settlement.
- Create the sanitized fixture corpus and run semantic parity checks against current Swift outputs. Keep fixture generation deterministic and isolated from personal data.
- Implement atomic JSON storage, checksums, recovery, schema fences, account scope boundaries and terminal replay.
- Establish one coordinator and one transaction authority. Platform services send bounded intents; Compose consumes state.

**Deliverables:** tested domain rules, bidirectional codec suite, local store/recovery harness and integration interfaces required by the actual services.

**Exit gate:** clock/access/reward cases match the source contract, interrupted settlement replays once, corrupt/newer documents stay recoverable, and ownership cannot cross scopes.

### Phase 3 Complete solo journey

**Bounded AND-008 slice complete locally:** usual-plan editing saves without starting; four tabs consume real guest state; protected-start admission, live/early-wake controls and separate durable receipts use the existing coordinator. Farm shows genuine search, bonus, wool and inventory progress. The authorized follow-up adds a local guest introduction, one-time Mabel starter/welcome (existing Farms skip the grant), and real shearing with credit-based regrowth. The optional questionnaire, practice/Pippin reward, Shepherd wearable gift, tasks/goals, reflection, automatic routines, NFC and full Farm/Shop presentation remain later scope. No physical acceptance or full Phase 3 completion is claimed. [Guest journey evidence](../evidence/android-port/2026-09-30-and-008/README.md), [starter/welcome/shearing evidence](../evidence/android-port/2026-09-30-guest-welcome-shearing/README.md).

**Owner:** Android feature/UI lead with design and copy review. **Depends on:** Phases 1 and 2. **Effort:** 2–4 engineer-weeks.

- Build Home/Nights/Farm/Settings, onboarding and plan editing with real guest state.
- Integrate Wind Down, Phone Away and Screen-Free Morning, relevant tasks/checklists, early wake, deferred/skipped morning and terminal receipts.
- Add Android protection setup/repair, quiet session status, reminders and automatic starts only to the proven extent.
- Implement NFC pairing/start/end if included in launch scope, plus device capability fallbacks.
- Port Nights presentation and private reflection ownership. Test midnight, daylight-saving transitions, travel and relaunch.

**Deliverables:** first usable guest build with a full start-to-Farm-progress journey.

**Exit gate:** repeated physical evening/overnight/morning runs preserve protection truth and settled progress; all four tabs remain reachable; affected flows pass large-text and TalkBack checks.

### Phase 4 Identity and private Farm synchronization

**Owner:** Android data lead; backend/identity maintainer owns provider configuration. **Depends on:** Phase 2, with Phase 3 for end-to-end review. **Effort:** 2–3 engineer-weeks.

- Implement registration, handle/email login, verification, recovery, Apple-account access, expiry and explicit account transitions.
- Port activation, automatic sync, owner/token pinning, conditional revisions, persisted retries and account-default behavior.
- Load only a validated account Farm; distinguish missing head, failed lookup, incompatible payload, offline cache and saved generation.
- Implement prior declined-consent handling and safe guest association without credential/Farm merging.
- Port local reset and account-deletion fences; ensure active/unsettled work cannot be lost through an ownership transition.
- Run iOS → Android → iOS write/read scenarios, divergent offline edits, ambiguous responses, stale callbacks and schema-version fixtures using isolated accounts.

**Deliverables:** account build and cross-platform compatibility report.

**Exit gate:** existing account identity and inventory survive both directions, no duplicate rewards or silent replacement occurs, sign-out removes active access, and confirmed-save wording matches the actual generation.

### Phase 5 Farm and visual feature parity

**Owner:** Android feature lead with design review. **Depends on:** Phases 2 and 3; final restored-state checks need Phase 4. **Effort:** 2–4 engineer-weeks.

- Finish Farm/Barn lifecycle, shearing/regrowth, capacity, Shop, wardrobe/equipment, discoveries, Search Journal and approved Farm interactions.
- Port native Shepherd drawing, Ollie animations, fitted accessories, scenery depth, placement and Fetch behavior.
- Keep stable catalog IDs, valid restored legacy items and unknown-ID fallbacks. Verify optional newer fields round-trip without forcing destructive normalization.
- Compare representative production screens and restored real-contract fixtures. Use current assets rather than quarantined MVP screens or retired art.
- Profile low-memory and midrange devices. Bound animation/rendering work; do not rebuild an entire scene for every timer tick.

**Deliverables:** approved visual/state parity checklist and complete personal Farm build.

**Exit gate:** earned/spent wool and ownership survive restart/sync; visual customization preserves item identities; scenes remain usable with accessibility settings and on the agreed device range.

### Phase 6 Shared ritual and Android delivery adapters

**Owner:** Android social lead; backend maintainer exclusively owns schema/dispatcher changes; website owner handles association files. **Depends on:** Phase 4; use Phase 5 appearances where shared. **Effort:** 2–4 engineer-weeks.

- Port parties, accepted agreements, invitation review/join/decline/revoke, shared Farm/meadow and current supported sharing summaries.
- Port Campfire visibility, explicit presence, buddies, exact handle search, contextual cheers and account Inbox. Preserve unknown-data and pre-join boundaries.
- Port durable outboxes, bounded requests, capability gates, suppression and receipt ordering. Guest/account switching cannot leak another account's social state.
- Add the approved FCM adapter and backward-compatible platform registration contract; test existing APNs behavior alongside Android.
- Add Android website association and auth/invitation redirects. Links preserve explicit membership decisions through interrupted onboarding.

**Deliverables:** mixed iOS/Android shared ritual build, additive adapter changes and signed-link evidence.

**Exit gate:** two isolated accounts complete the shared loop across platforms, stale/withdrawn content does not reappear, push-denied users retain Inbox functionality, and no new private fields enter server payloads.

### Phase 7 Hardening and Google Play release

**Owner:** Android lead, QA/device reviewer and founder release owner. **Depends on:** all launch features and accepted omissions. **Effort:** 2–3 engineer-weeks, plus external testing/review time.

- Complete the matrix in section 7 on the signed candidate and repair release blockers.
- Audit actual manifest/dependencies, backup behavior, privacy declarations, provider configuration, production capabilities and association endpoints.
- Prepare a signed App Bundle, reviewer access, store screenshots, support/deletion pages and accessibility declaration evidence.
- Run authorized internal/closed tracks, collect actual feedback and complete any account-specific production-access requirement.
- Freeze the release parity matrix. Submit/publish only with explicit authorization, then use an approved limited rollout and repair plan.

**Deliverables:** release candidate, acceptance evidence, completed Play submission package and rollback/support procedure.

**Exit gate:** all technical, physical, configuration and applicable Play review gates pass. Uploaded, approved, published and physically accepted remain separate recorded states.

## 7 Validation plan

### Automated checks

Reuse the intent of current tests instead of translating test counts mechanically. Shared-domain behavior needs meaningful Kotlin tests, including migration/replay and malformed input at trust boundaries. Keep visual checks focused on representative states and journeys.

| Area | Required cases | Existing starting points |
| --- | --- | --- |
| Timing and routing | Midnight/DST, early/late start, frozen anchors, planned versus actual end, standalone morning, stale callbacks, app/process restart | [NightWatchTests](../../Tests/NightWatchTests.swift), [WindDownSchedulingTests](../../Tests/WindDownSchedulingTests.swift), [IndependentMorningSettlementTests](../../Tests/IndependentMorningSettlementTests.swift), [HomeReceiptRoutingTests](../../Tests/HomeReceiptRoutingTests.swift). |
| Access and protection | Empty selection, denied/revoked readiness, clipped five-minute access, overlapping access, replaced occurrence, runtime apply/clear failure, emergency exit | [ShieldingReadinessTests](../../Tests/ShieldingReadinessTests.swift), [QuietTimeBriefAccessTests](../../Tests/QuietTimeBriefAccessTests.swift), [PersonalShieldTests](../../Tests/PersonalShieldTests.swift), [EmergencyExitChallengeTests](../../Tests/EmergencyExitChallengeTests.swift). |
| Farm economy | Early end, fractional carry, overnight/morning exclusion, overlap union, bonus qualification/no retroactive grants, threshold crossing, independent searches | [CumulativeFarmCreditTests](../../Tests/CumulativeFarmCreditTests.swift), [BedtimeSearchBonusTests](../../Tests/BedtimeSearchBonusTests.swift), [SheepSearchTests](../../Tests/SheepSearchTests.swift), [FarmEconomySimulationTests](../../Tests/FarmEconomySimulationTests.swift). |
| Durable storage | Failed writes, interrupted rename/commit, corrupt latest/recovery copy, unsupported schemas, settlement replay, disk full, deletion pending | [FarmSaveDocumentTests](../../Tests/FarmSaveDocumentTests.swift), [FarmSaveStoreTests](../../Tests/FarmSaveStoreTests.swift), [local harness](../../scripts/validate-farm-save.py). |
| Identity and sync | Wrong owner, changed token, late callback after switch, lookup failure, declined consent, divergent branches, lost response, old/new payload codecs | [AccountFarmOwnershipTests](../../Tests/AccountFarmOwnershipTests.swift), [AccountFarmStoreTests](../../Tests/AccountFarmStoreTests.swift), [FarmBackupViewModelTests](../../Tests/FarmBackupViewModelTests.swift). |
| Social and links | Repeated commands, join/leave, pre-join exclusions, agreement versions, mixed platforms, cold links, withdrawn source, account-bound Inbox | [NightFlockV4Tests](../../Tests/NightFlockV4Tests.swift), [NightFlockInviteRecoveryTests](../../Tests/NightFlockInviteRecoveryTests.swift), [SocialInboxTests](../../Tests/SocialInboxTests.swift), relevant existing Edge tests. |
| Visual and content | Empty/loading/error/restored states, unknown equipment, large text, semantic actions, low-motion scene behavior | Current previews, production renderers and named parity scenarios. |

The implemented Android local gate is:

```bash
cd android
./gradlew :app:assembleDebug :app:testDebugUnitTest :app:lintDebug
./gradlew :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.isolatedPrototype=true
```

Use the connected test command only after selecting isolated emulator/device fixtures. Release checks additionally assemble and test the Release configuration and create the authorized signed bundle. Finalize exact tasks in the generated build instructions. Build, unit tests and lint now pass locally; isolated native instrumentation requires `ANDROID_SERIAL` plus `-Pandroid.testInstrumentationRunnerArguments.isolatedPrototype=true` and only accepts a disposable `sdk_gphone` emulator. See `android/README.md` and the evidence for exact results and commands. Physical checks remain pending.

The Android reference exporter runs the applicable current Swift domain/persistence tests and native Swift codecs in an isolated host package. Production Swift/shared iOS changes still require the applicable native iOS tests and full app merge gate; this Android-only milestone does not modify Swift production source or claim iOS release validation. Documentation-only roadmap edits need reference/consistency/whitespace checks, not XcodeGen or an app build. Backend changes need their existing Deno/SQL tests plus mixed-client contract checks; production fixtures require verified isolation and authorization.

### Physical device matrix

All current offline physical checks are **pending** in the [single consolidated checklist](android-port-physical-acceptance-checklist-2026-09-30.md). The broader launch matrix below remains a roadmap for separately authorized features.

Record manufacturer/model, OS/security patch, source revision, build variant/signing, service grants, alarm grant, notification grant and optimization settings. Keep recordings and sanitized local diagnostics with the evidence; do not use the founder's Farm as a disposable fixture.

Minimum proposed coverage is a Pixel, a Samsung, and an additional manufacturer relevant to Singapore/SEA, plus the chosen minimum OS and current stable OS. Emulators cover API boundaries where hardware is unavailable; those results do not replace OEM enforcement or NFC tests.

| Scenario | Required observation |
| --- | --- |
| Fresh install and denied setup | Plan editing works; protected start stays gated; refusal is understandable and reversible. |
| Manual and opt-in automatic start | Correct owner/occurrence; selected-app behavior observed; missing/delayed start is not called successful. |
| Repeated full nights | At least three overnight cycles per core OEM class, including locked/idle and power-saving conditions; correct morning handoff and bounded end. |
| Launch routes and window modes | Launcher, notifications, recent apps, deep links, already-open app, split screen and picture-in-picture; document coverage and exceptions. |
| Brief Access near each boundary | Saved interval, shortened access near end, restored block before next selected interaction, no old grant reuse. |
| Process death and recent-app dismissal | Actual behavior separately recorded; recovered UI and protection agree with durable state. |
| Force-stop and service disabling | No false continuity claim; safe behavior; next supported entry repairs/reconciles without losing settled progress. |
| Reboot, first unlock and clock changes | No stale overlay or duplicate settlement; privacy before unlock; timezone/civil-date behavior matches the contract. |
| Emergency exit and permission repair | Essential controls remain reachable; block clears safely; reason/typed text obey retention rules. |
| NFC provision/read/replacement | Same physical record format, occupied-tag refusal, explicit reset, read-after-write, retired tag rejection and unavailable hardware. |
| Offline, interrupted save and update | Current owner preserved; durable pending writes; unknown/newer schemas stay intact; failed storage does not become an empty Farm. |
| iOS and Android account use | Same UUID/Farm; owned items and all ledgers survive both directions; divergent branches archived; no duplicate reward or stale owner callback. |
| Mixed-platform shared ritual | Invite/join/leave, cheers/withdrawal, Global/private visibility, quiet-hour push suppression and Inbox recovery. |
| Signed links and push denial | Play-signing association, warm/cold/signed-out routing; no auto-join; in-app Inbox remains usable. |
| Accessibility and dark-room use | TalkBack, large fonts, keyboard/autofill, gesture Back, contrast, target size, reduce motion and night scene comfort. |
| Performance | Compare idle and overnight battery use, event frequency, memory, frame pacing and startup on the same devices/settings; freeze acceptable budgets after Phase 1 baseline. |

## 8 Google Play preparation and rollout

Prepare the account and operational prerequisites early, but treat any account creation, paid service, external configuration, upload or publication as its own authorized action.

- Resolve Play Console ownership, account type, identity verification, contact details and any requirements shown in that account. Assign an owner for signing material, provider secrets and release access.
- Build a signed Android App Bundle and use Play App Signing. Keep upload-key custody/recovery documented; App Links need the app-signing fingerprint used on installed Play builds. See [App Bundle guidance](https://developer.android.com/guide/app-bundle) and [Android signing guidance](https://developer.android.com/studio/publish/app-signing).
- Recheck target API requirements immediately before submission. As researched on 30 September 2026, new phone apps need Android 16/API 36 or higher. Minimum OS remains the separately accepted compatibility choice.
- Complete listing copy, current screenshots, icon, category, audience/content rating, support and privacy policy. Describe the selected-app scope and Android enforcement limitations accurately; preserve no-medical-claim boundaries.
- Complete Data safety from the actual shipped client, SDKs, private Farm sync and consented social payloads. Do not copy the iOS privacy declaration mechanically. Google requires disclosure of SDK handling too. See [Data safety requirements](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en).
- Supply in-app account deletion and a functional web resource through which someone can request deletion without reinstalling. Reuse the account-deletion contract, verification and retained-data explanation. See [Play account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en).
- Complete the accessibility declaration, prominent disclosure, consent/refusal demonstration and listing description. Submit package-visibility, exact-alarm or foreground-service declarations only if the final approved implementation actually requires them.
- Request notification permission contextually on applicable OS versions. Denial must not remove basic session/Farm or Inbox access. See [Android notification permission](https://developer.android.com/develop/ui/compose/notifications/notification-permission).
- Provide isolated reviewer accounts and instructions that reach account/social features without using founder data. Ensure verification and recovery flows are usable by reviewers.
- Progress through authorized internal and closed testing. Personal accounts created after 13 November 2023 currently require at least 12 testers continuously opted in for 14 days before applying for production access. This requirement is conditional on account type/date, and completing it is not production approval. See [Play testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en).
- Record candidate identity, backend capabilities, signed-link results and all outstanding limitations. Obtain publication authorization only after the concrete submission package is ready.

For the first launch, propose a limited country/tester rollout aligned with the agreed device matrix. Make compatible backend additions before allowing new client features; do not remove old APNs or Farm capability support. If a release is bad, halt expansion and ship a higher-version repair while preserving local journals and cloud data. Do not assume that downgrading the APK or reversing a schema migration is a safe rollback.

At launch, review actual Play vitals and consented support reports. No new analytics or crash-upload SDK is implicit. Troubleshooting diagnostics must exclude secrets, package selections, typed confirmations and private routine/reflection content. A future monitoring automation requires its own request; this document does not schedule one.

## 9 First implementation queue

AND-001–008 were authorized by the founder on 30 September 2026. Independent local implementation and verification proceed without waiting for the later consolidated physical pass. Status below separates the bounded guest slice from full launch and physical acceptance; AND-009–010 remain pending. IDs are local planning references; no external tracker tickets have been created.

| Ticket | Work and accountable owner | Dependency | Completion evidence |
| --- | --- | --- | --- |
| AND-001 | Kickoff choices, Android workspace and dependency scope — founder/Android lead | Implementation authorization | Approved decision record and exact source/backend baseline. |
| AND-002 | Reproducible debug/QA build and isolation — Android lead | AND-001 | Wrapper/build/lint pass; QA environment cannot mutate founder data. |
| AND-003 | Minimal package selection and protection consent — platform lead | AND-002 | Scoped queries and consent/refusal on agreed phones; no unnecessary sensitive data. |
| AND-004 | Blocking surface and reachable emergency exit — platform lead | AND-003 | Observed selected-app behavior across agreed launch/window routes. |
| AND-005 | Durable session bounds, Brief Access and automatic-start spike — platform lead | AND-004 | Boundary/restart/overnight evidence and alarm/service-type decision. |
| AND-006 | Swift/Kotlin payload fixture proof — data lead/iOS maintainer | AND-002 | Synthetic representative Farm decoded and re-encoded in both directions; bad/new versions rejected. |
| AND-007 | Single Kotlin coordinator and local guest transaction/replay foundation — domain/data lead | AND-005 local implementation/evidence, AND-006; physical acceptance is independent | Current Swift timing, credit/bonus/access/search semantics, migration and interrupted-settlement cases pass. |
| AND-008 | Bounded real guest plan/start/live/receipt journey — feature lead | AND-007 local evidence; physical acceptance is independent | Plan saves without starting; protected-start gates, early wake, separate overnight/Morning receipts, introduction/starter/welcome and real shearing pass local UI/storage tests. |
| AND-009 | Existing-account identity and private sync — data/backend lead | AND-006, AND-007 | iOS-created account reaches the same UUID/Farm on Android; owner switch and ambiguous upload tests pass. |
| AND-010 | Freeze full launch backlog and estimates — founder/Android lead | Phase 1 gate and AND-006 | Accepted parity matrix, actual capability limits, assigned owners and revised effort ranges. |

Current ticket status ([evidence](../evidence/android-port/2026-09-30/README.md)):

| Ticket | Implemented/tested | Remaining gate |
| --- | --- | --- |
| AND-001 | Approved defaults; source/uncommitted/toolchain/dependency/backend/asset baseline recorded. | Public identity, full launch scope and physical device range remain later decisions. |
| AND-002 | Official checksummed wrapper, one offline debug module; build/unit/lint pass. | No distribution; physical minimum-OS acceptance pending. |
| AND-003 | Scoped launcher selection, system/default-control exclusions, prominent consent/refusal/withdrawal; local admission checks. | Physical disclosure/TalkBack and OEM visibility matrix pending. |
| AND-004 | Accessibility overlay intercepts synthetic target interaction; Brief Access and actual emergency-exit tap open it on API-36 emulator. | Launcher/notification/recents/deep-link/window-mode/physical matrix remains a gate, not a continuous protection claim. |
| AND-005 | Single checksummed session/access authority; clipped five-minute access, stale callbacks, restart/clock/failure tests; live delayed-start/expiry experiment. | Doze/OEM/overnight/battery acceptance; exact-alarm/service permission decisions require separate evidence/authorization. |
| AND-006 | 8 actual Swift fixtures; both encode/decode directions; 23 shared malformed/newer cases rejected, no destructive normalization/upload path. | Auth/owner-token binding/live sync are AND-009, outside this proof. |
| AND-007 | Integrated single coordinator/v2 transaction; real local guest credit, growth, separate Morning fills, deterministic searches, v1 migration, recovery fences and interrupted replay. Build/unit/lint, 142 current Swift rule tests, semantic fixtures and native emulator checks pass. | Physical acceptance remains in the consolidated checklist; no protection/release acceptance or verified account-owned Farm is inferred. |
| AND-008 | Saved usual plan, Home/Nights/Farm/Settings guest shell, bounded manual starts, live access/early endings/early-wake choices, separate durable overnight/Morning receipts, minimal Farm presentation plus local guest introduction/starter/welcome and real shearing; v4/Farm-v2 migration and fresh phase/occurrence confirmations. Build/unit/lint, 195 current Swift tests, extended starter/yield/regrowth parity and isolated emulator UI/storage checks pass. | Physical protection, TalkBack/OEM/overnight acceptance remains pending. Optional questionnaire, practice/Pippin and wearable gifts, routines, goals/tasks, reflection, NFC and full Farm/Shop are later scope; no full solo-launch parity claim. |
| AND-009–010 | Pending. | Account/service/release work needs its own authorization; physical capability results inform the launch freeze. |

The current slice has a usable local guest plan-to-receipt journey, with internal short scenarios retained under Settings. The physical Phase 1 gate stays open. Full Shop/social/account interfaces and full guest onboarding/Farm parity were not scaffolded.

## 10 Effort ownership and risks

With one experienced Android engineer, the phase allowances total approximately **14–25 engineer-weeks**, before external review delays and any additional policy redesign. This is an initial planning assumption based on the scope above, not a measured estimate. Founder/design review, backend maintenance and device QA availability also affect elapsed time. Replace it after the protection proof and a representative persistence/scene port; do not promise a launch date from these ranges.

The local sequence is kickoff → protection prototype → durable domain/coordinator → authorized guest journey. The independent physical sequence is the consolidated protection/overnight/battery acceptance pass → supported protection claims and launch readiness. Physical timing does not suspend local domain/persistence implementation. Serialization fixtures can start during the protection spike. Identity/sync follows the data foundation; visual feature completion can overlap account work; social depends on stable identity. More engineers can shorten independent work, but cannot remove overnight observation or external review time.

Assign responsibilities even if one person fills several roles:

- Founder: scope, platform tradeoffs, dependencies/services, product exceptions and publication.
- Android lead: architecture, client delivery, platform capabilities and local verification.
- iOS/domain maintainer: authoritative behavior, fixture export and compatibility review.
- Backend maintainer: additive contracts, provider configuration, FCM registration/delivery and old-client compatibility.
- Design/copy reviewer: native art parity, usability, accessibility and release wording.
- Device/release reviewer: isolated real-device acceptance, signed candidate and Play submission evidence.

| Risk | Early evidence or mitigation | Decision boundary |
| --- | --- | --- |
| Blocker coverage or Play policy mismatch | Narrow Phase 1 prototype and disclosure/permission review | Founder accepts proven limits or changes scope; no hidden timer-only fallback. |
| OEM kills/delays background execution | Repeated nights under normal and restricted conditions | Narrow supported promise/device range or revise design before launch. |
| Lossy Farm serialization | Actual mixed-codec fixtures including new optional fields and dates | Cloud writes stay gated until safe compatibility is proven. |
| Account identity split | Native Apple → Android OAuth UUID proof and relay-email cases | No launch migration that requires duplicate accounts or merging by email. |
| Divergent offline Farm edits | Preserve current account-default/archive behavior and conditional revisions | A new merge algorithm is a separate product/data decision. |
| Android push breaks iOS | Additive platform-aware validation, separate transport and APNs regressions | Backend activation has explicit authorization and compatibility evidence. |
| Visual drift and asset bloat | Current native Shepherd reference and approved asset manifest | Port existing art; review new platform assets centrally. |
| Accidental data transfer or new sharing | Backup exclusions, permission/data audit and payload allowlist tests | New device/cloud/social fields need explicit acceptance. |
| Scope expansion | Freeze the parity matrix, record explicit launch omissions | New Health, Wear OS, sign-in providers, billing and Friends work remain separate. |

## 11 Decisions needed to start

The 30 September founder request approved the bounded kickoff/project/protection/codec choices. The evidence is the decision record and dependency/permission inventory. Unresolved later choices below still need their own authorization; do not reopen approved routine setup. Resolve actual alternatives once; do not ask for repeated permission for ordinary edits/checks inside the approved slice.

| Decision | Proposed answer |
| --- | --- |
| Approve implementation slice | Approved AND-001–007; locally implemented/tested, physical gates pending for the consolidated pass; later expansion needs authorization. |
| Repository and identity | `android/`, native Kotlin/Compose, proposed existing brand package ID with separate QA/debug IDs. |
| Minimum OS and first device set | Android 10+ authorized/configured; API-36 emulator tested. Physical Pixel, Samsung, SEA OEM and API-29 acceptance pending. |
| New dependencies | Approved/installed narrow pinned Kotlin/Compose/AndroidX/coroutines/serialization/test foundation. Supabase/Firebase remain outside this slice. |
| Protection scope | Selected app packages through the approved consumer mechanism; explicit capability limits, no implied website/category parity. |
| Initial public parity | Core solo rituals, personal Farm and current invite-only shared ritual; accept individual omissions explicitly. |
| Existing Apple account route | Browser Apple OAuth with verified same-UUID linkage; confirm provider setup and maintenance owner. |
| NFC, Health and wearable scope | NFC proposed for first release after proof; Health and Wear OS proposed later. |
| External services and release ownership | Confirm Play account owner and signing custodian; authorize provider/Firebase/backend/website changes when the concrete work is ready. |

## 12 Completion and handoff

Before declaring the Android port release-ready, record all of the following:

- [ ] Accepted launch parity matrix, supported OS/device range and product exceptions.
- [ ] Repeatable Kotlin domain, codec, persistence/replay, UI and lint checks.
- [ ] Actual protection/access/exit behavior on the signed candidate across the accepted device matrix.
- [ ] iOS/Android Farm round-trips and two-account isolation with no duplicate rewards, missing inventory or destructive schema normalization.
- [ ] Supported Apple/password account access, consent migration, recovery and deletion.
- [ ] Current personal Farm, art and shared ritual parity, or explicit accepted release omissions.
- [ ] Approved additive backend/push configuration and verified release App Links, including existing iOS regression evidence.
- [ ] Actual privacy/permission/dependency/backup inventory and matching Play disclosures.
- [ ] Required closed-test and production-access evidence for the actual Play account.
- [ ] Authorized signed bundle/upload/submission; Play approval and publication recorded separately.
- [ ] Support/repair ownership, retained diagnostic boundaries and a rollout-halt procedure.

At each phase, place an evidence record under a dated `docs/evidence/android-port/` directory once that evidence exists. Record the source revision, toolchain, exact commands/results, fixture isolation, devices/configuration, recordings where useful and concrete remaining limitations. Link unresolved work from [the backlog](../FUTURE_AGENT_TASKS.md). Preserve local/cloud data during repair and do not commit, push or deploy without the relevant authorization.

The bounded AND-008 usual-plan/guest start/live/receipt journey is now locally implemented. The authorized follow-up now implements guest introduction/starter/welcome and a real durable wool/shearing action. Recommended next bounded AND-008 slice: optional protected onboarding practice with its separate once-only Pippin reward, retaining this authority and separate receipts; full Shop/social/account work remains separately authorized. The founder's consolidated physical protection/overnight/battery pass remains independent and pending; it gates supported protection claims and release readiness. Later account/service phases and all release acceptance remain pending.
