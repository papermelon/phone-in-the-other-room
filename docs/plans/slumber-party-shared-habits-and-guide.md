# Slumber Party shared habits and a shorter ideas library

Date: 2026-08-28. Status: **independent connection, guide and social-presentation implementation authorized; verified app-data sharing and sensitive-history rollout remain gated. No deployment or new sensitive collection is authorized.**

## 1. Outcome and scope

Make Slumber Party useful for adults—friends, couples and families—who support one another's Wind Down habits. A person should recognize their group, understand a recent shared habit update, and encourage someone without scrolling through repeated Farm portraits. Keep Ollie and customization in the product; stop making a cosmetic snapshot the main information on every member card.

Also replace the long “About these ideas and sources” page with a short, browsable local guide. This is a separate, independently deliverable UI slice.

The founder reports handling the remaining TestFlight setup personally. This planning pass does not independently confirm tester availability or the installed build, and does not resume distribution. Screenshots reviewed: `IMG_7287.PNG` and `IMG_7288.PNG` in the founder's Downloads folder.

Preserve the approved minimalist Home hero, its Ollie motion, compact Wind Down timing, Phone Away start flow, four tabs and local Farm economy. Social-avatar selection does **not** change the Home hero. No avatar art redesign, shared Farm, chat, public discovery, remote shielding control or new reward mechanic is included. New health/app information is a requested direction to design, not consent to start uploading it.

Singapore and the wider SEA audience are the primary customer context for this plan. An automatic, verified presentation of the exact selected app identities and then meaningful category buckets is essential to the requested experience. A manual label, self-described category, unauthorized extraction from the Screen Time report sandbox, OCR, App Group relay, logs, hidden UI, or private API is not a substitute and must never be represented as one. A future permitted export API remains subject to the Singapore customer-route gate below.

## 2. What the current code actually does

Audit baseline: saved checkout `codex/night-flock-mvp`, HEAD `cce766d1840a850a23d5c47e4a542203c26a728b`, plus inherited uncommitted changes. Do not start implementation from HEAD alone or from an assumed clean checkout.

| Finding | Evidence | Implication |
| --- | --- | --- |
| Every member card always renders the curated Farm snapshot below status. | `SlumberPartyV4MemberCard.swift:58,180,195` | Appearance takes space even when identical or no useful update exists. |
| “Featured Mabel” is automatic: first favourite active sheep, otherwise first active sheep. | `Services/PersistenceService.swift:461`, `Shared/WelcomeReward.swift:117`, `Shared/CountingSheepUserProfile.swift:14` | There is no explicit social-avatar choice. A favourite must not silently become the selected social sheep. |
| V4 social records carry mode, completed/partly-completed status, rounded quiet minutes and occurrence time, plus expiring live statuses and cheers. | `Shared/NightFlockV4Models.swift:175,252`, `NightFlockViewModel+V4.swift:417` | Sleep, verified app identity, usage, protection evidence and adherence need a new contract; legacy V3 sharing is not V4 implementation. |
| The waiting message is the old-server capability branch. | `SlumberPartyV4PartyDetailView.swift:94`, `Shared/NightFlockPresentation.swift:414,425` | A screenshot is consistent with an older capability response, not proof of a live server version. |
| Ordinary members' settings contain only Leave; hosts also get rename/delete. | `SlumberPartyV4PartyDetailView.swift:526` | The empty-looking settings disclosure is real, not hidden useful functionality. |
| Realtime invalidation refetches canonical state after a 350 ms debounce; selection, foreground and local publications also refresh. No periodic polling. | `NightFlockService.swift:111`, `NightFlockViewModel+V4.swift:891` | A lost connection needs recovery, not a permanently prominent refresh button or app-switch workaround. |
| The guide renders ten full idea cards with repeated source text, grouped into Evening/Morning/Phone Away. | `Views/Components/WindDownGuideCard.swift:454` | Root density comes from hierarchy, not lack of content structure. Six topics and seven registered sources already exist. |

### Why the previous work did not deliver the intended social experience

Three layers were treated too similarly: a finished local client, a deployed server contract, and an accepted experience on real accounts. The membership-sharing source can pass fixtures while a phone still receives round-only behavior. Previous member-card work also improved a cosmetic contract without supplying the verified habit information now requested. A build/test pass cannot establish that a screen is useful, a second account sees updates, or a new server capability is live.

The correction is to make those gates explicit. Do not merely shrink portraits, add panels, or remove truthful fallback text while automatic verified app identity is unavailable to the Singapore customer route.

## 3. Proposed Slumber Party layout

### Party overview

1. **One compact header:** party name, member count, small selected social-identity previews and an overflow button for Group details. Use pull-to-refresh and a small last-updated/stale indication.
2. **People first:** each compact row/card has one member-selected social avatar, name/role, current factual status if fresh, and one short latest habit summary. The avatar is exactly one of the person's existing **Shepherd**, **Ollie**, or an explicitly selected unlocked/discovered sheep. Existing Shepherd and Ollie cosmetics remain intact; do not imply that sheep have cosmetics they do not have. Selecting a sheep requires a dedicated picker and an affirmative choice; neither the first active sheep nor a favourite is an implicit selection. The selected canonical identity applies across that member's parties by default. Remove the Ollie/sheep/pasture triptych from this default surface.
3. **Last night / 7 nights / 30 nights:** a shared selector changes the habit summary independently of the fixed seven-night reward round. “Last night” uses the contributor-local date when relative wording would be ambiguous. The 7- and 30-night views show coverage and arithmetic means over eligible available nights only; they never zero-fill unavailable or ineligible nights. Tapping a summary opens its dated, coverage-aware drill-down.
4. **One recent group highlight**, followed by “See shared activity.” Examples: a completed Wind Down, factual Phone Away completion, received cheer, or an agreed competition result once its rules are defined. Do not infer that everyone improved from incomplete data.
5. **Seven-night round:** compact progress/reward section below the people. Before/between rounds, explain that sharing continues and expose the leader's round action. A round is not the entry ticket to sharing.

Illustrative member card, with invented values for layout only:

```text
[Selected avatar] Papa · Group leader                 Cheer
Wind Down finished · updated this morning
Last night: 30 min Wind Down
7 nights: 4 eligible nights · 28 min mean             Details ›
```

Member details may add sleep duration and app-protection evidence only after the shared contract and relevant platform gate are met. Keep one or two summary metrics on the overview. A compact nightly strip may show recorded completion/partial/unknown states with accessible text. No red failure mark for an absent upload.

### Member detail

Show the selected period's Wind Down history, separately labeled Phone Away activity, protection evidence and sleep summary. Put method, coverage, provenance and freshness beside every metric. Own detail includes **Preview what this party sees** and **Leave party**; it has no field-level sharing switches. Another person's detail never reveals private settings or why information is absent.

Keep full Farm customization in Farm. The chosen social avatar changes only from that explicit selection route. Because a sheep is eligible once unlocked/discovered, later shearing, trading or release does not erase the selected social identity. A decoded legacy profile with no selection defaults to Shepherd and asks for an explicit choice at a safe next visit. Neither behavior changes an already-rendered Home hero.

### Empty, private and stale states

- Newly joined: show the group's existing consented history and “You're in. Your next shared Wind Down or Phone Away will appear here.” No host-start dependency on a capable backend. Joining does not upload the newcomer's private pre-join history.
- Missing activity: “No recent shared update.” Not “missed last night.”
- Data unavailable: adults may join without Health sleep data or readable access. Show “No data available” to peers; offer contextual connection/help to the owner. Do not infer permission denial from an empty query or expose private reasons to peers. Missing data is never evidence of cheating.
- Former member: retain permitted past contributions with a “Former member” label; exclude the person from current member counts, live status, active targets and new competition eligibility. History is a dated record, not a continuing profile or permission to collect new data.
- Offline: retain dated cached content with a stale label; never present a stale active session as live after expiry.
- Legacy backend: retain truthful compatibility behavior, but mark immediate-sharing rollout incomplete in release acceptance.

## 4. Shared habit information and evidence boundaries

| Information | Proposed presentation | Evidence / honesty requirement |
| --- | --- | --- |
| Wind Down participation | Last-night factual quiet minutes and completed/ended-early record; 7- and 30-night recorded/eligible coverage. | Complete period queries must deduplicate round and membership streams. Archive history is paginated; the latest-100 list is never a complete archive. |
| Wind Down adherence | Later: “Met your planned Wind Down on 4 of 5 eligible planned nights,” with an explanation. | Requires expected occurrences, the plan version for that night and a defined tolerance. Keep started, completed, met plan, early-ended and unknown distinct. The 420-minute reward rule is not adherence. |
| App protection | “App protection recorded: 30 min before bed”; a full-session duration only if supported by evidence. | Derive from apply/clear/failure evidence, never planned timer alone. It is app-recorded evidence, not independently verified continuous enforcement or proof of physical separation. |
| Exact selected app identities, then category buckets — founder requirement | Automatically show verified exact identities and their category buckets, with clear period/scope. | This remains **blocked** until a sanctioned Singapore customer route is demonstrated. Do not replace it with manual categories or pretend private Screen Time artefacts establish identity. |
| Screen Time usage | OS-reported per-app minutes, with category totals and a clearly named reporting window; distinguish selected-app usage from all-device usage. | Requires its own supported Singapore export evidence. Identity access alone does not establish usage access. Prevent overlapping category totals from double-counting and never substitute protection minutes for usage minutes. |
| Sleep | Last-night duration, plus 7- and 30-night arithmetic means and coverage. | Use eligible available nights only, no zero-fill. Reuse local processing only after reviewing night boundaries, overlapping sources, partial nights and late samples. Send a derived summary, never raw samples, source IDs, stages, or exact bed/wake times in the first slice. |
| Competition | A later, explicitly named agreed challenge/scorecard. | Competition is desired direction, not prohibited. Define participation, evidence, eligibility, comparison period, ties, absences, rewards and fairness first. Never rank people by longer sleep by default. |

Never multiply protection duration by number of apps. Do not combine overnight protection, Wind Down quiet credit and Screen-Free Morning reward minutes into a flattering total. Phone Away stays separate from the nightly ritual and its reward accounting.

### Platform feasibility and release gates

The platform assessment is a required engineering gate, not a promise of a solution or a legal conclusion. See the companion [Singapore app-data feasibility plan](slumber-party-singapore-app-data-feasibility.md) for the verified SDK/API details and acceptance evidence.

- `DeviceActivityReport` and Shield Configuration have privacy/sandbox boundaries. Their values cannot be relayed to a server through App Group writes, OCR, hidden labels, logs or another side channel. [DeviceActivityReport](https://developer.apple.com/documentation/deviceactivity/deviceactivityreport), [ShieldConfigurationDataSource](https://developer.apple.com/documentation/managedsettingsui/shieldconfigurationdatasource).
- The local iPhoneOS 26.5 SDK marks `FamilyActivityData` / `approvedWithDataAccess` and `DeviceActivityData.activityData(filteredBy:using:)` iOS 26.4+. Apple documents the usage-data entitlement route as customer-gated to EU device location and EU Apple Account region. Development availability does not prove customer availability. [activity-data API](https://developer.apple.com/documentation/deviceactivity/deviceactivitydata/activitydata(filteredby:using:)), [FamilyActivityData](https://developer.apple.com/documentation/familycontrols/familyactivitydata), [usage entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.family-controls.app-and-website-usage).
- Singapore feasibility is the **first acceptance gate**. An EU-only path cannot be deferred as a region adapter or presented as delivery for the primary SEA audience. Keep automatic verified identity sharing blocked until a sanctioned Singapore customer route has been demonstrated on an appropriate customer configuration.
- Keep these evidence claims separate in model, copy and tests: (1) verified app identity, (2) actual usage, (3) shielding applied, (4) continuous enforcement, and (5) server trust in a client report. Evidence for one does not prove another.
- HealthKit read authorization cannot be inferred from an empty query. Adults may join without Health data, with “No data available” shown. The party contract does not grant iOS permission; unavailable data is never a cheating signal. Health connection status must distinguish an authorization request from observed data and refresh consistently across screens. [HealthKit authorization](https://developer.apple.com/documentation/healthkit/hkhealthstore/authorizationstatus(for:)), [App Review 5.1](https://developer.apple.com/app-store/review/guidelines/#privacy).
- A Slumber Party family is not automatically Apple Family Sharing or parental-control authorization. A group leader receives no additional right to inspect or change another adult's protection or health data beyond the same consented group projection available to other members. [Family Controls authorization](https://developer.apple.com/documentation/familycontrols/authorizationcenter/requestauthorization(for:)).

## 5. One party-sharing contract and adult group controls

Joining a party presents one informed, recipient-aware sharing contract. **Accept and join** starts the contract; no new shared field uploads before that action. Sharing is on while the person remains a member. There is no active per-field, per-party toggle matrix: stopping new party sharing means leaving that party, not deleting an account or the app. Existing members must accept the revised agreement before new fields or a broader recipient audience are enabled for their contributions. Historical optional-toggle proposals are superseded.

The join flow must state the shared fields, current and future members as recipients, availability limitations and what leaving means. Adults without Health samples or readable access can accept and join. OS connection controls are separate from party consent and must appear where relevant, without routing through the app's Settings hub. See [contextual connections and Health status repair](contextual-connections-health-status.md). No missing-data reason becomes a cheating signal.

Consent revision and membership epoch remain per party. Check both before queueing, sending and accepting a record. A leave immediately stops local uploads—even offline—removes pending sends and hides/purges the leaver's group cache; revoke server membership/read access and clear live status when remote completion succeeds. Require no host approval. An ordinary leave does **not** automatically delete previously shared group history under the requested new contract. Distinguish pending outbox cancellation, reader access revocation, published-history retention and a privacy deletion request.

**Founder-selected history audience:** every current member, including someone who joined later, can see all of the group's retained, lawfully shared history, including permitted former-member contributions. This includes history from before the viewer joined and before/between rounds. It does not import anybody's private pre-membership history, another party's history, or deleted records. A new reader's consent cannot retroactively enlarge an earlier contributor's agreement: re-consent or a separately justified migration basis is required before widening that audience. Keep unsupported legacy history under its original restrictions.

**Past contributions after leaving:** ordinary leaving should retain earlier shared records rather than redact them, with former-member attribution. This is the founder's product preference, not a claim of irrevocable consent. Continued display is continued disclosure; accessible withdrawal/deletion requests and account deletion must remain meaningful. Apple requires withdrawal and deletion handling; Singapore's PDPC requires collection/use/disclosure to stop after consent withdrawal unless another applicable basis permits it. Obtain privacy review before implementing the retained health/app-data archive; disclosure text alone does not settle this. [Apple privacy rules](https://developer.apple.com/app-store/review/guidelines/#privacy), [account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app), [PDPC obligations](https://www.pdpc.gov.sg/overview-of-pdpa/the-legislation/personal-data-protection-act/data-protection-obligations).

Draft concise joining copy, **subject to that review and final field/retention scope**:

> Share your habit updates with this group's current and future members. Leaving stops new updates; shared history stays while the group exists. You can request deletion in Privacy & data.

Show the actual data categories visibly above this copy, including that sleep appears only when available. A short “How sharing works” detail covers retained periods, withdrawal/deletion, recipient changes and account deletion. No “permanent” or “cannot be deleted” promise. The privacy route must work after leaving without rejoining; it is not a per-field sharing toggle.

Adults are first. The group leader is a coordinator with parent-like responsibilities, never a label that turns adult peers into children. The proposed first leader powers are invite management, round management, and proposing an agreed bedtime target. Every affected adult must explicitly accept a target change; no leader may silently alter another adult's schedule, permissions, device protection, app selection, Health access, sharing or local session. Exact leader powers beyond those proposals remain a clarification, not blanket authorization.

### Group details screen

| For everyone | Group leader, with real server authorization |
| --- | --- |
| Party agreement and recipient preview | Rename party |
| People and existing report/block controls | Create/replace/revoke invite |
| Invite using the current active invite | Start the next seven-night round |
| Proposed agreed bedtime target; accept/reject own change | Propose agreed bedtime target |
| Leave party, separated at the bottom | Transfer leadership, or dissolve-and-leave, so a leader can withdraw without host approval |

If the first UI slice has no new controls, remove the empty “Party settings” disclosure for ordinary members and expose Leave through overflow/Group details. Do not invent filler settings. Notification preferences are out of scope unless their delivery path supports them.

## 6. Ideas and sources: progressive disclosure

Use the short destination title **Ideas & sources**, retaining existing entry-point wording where useful.

1. **Root:** one short introduction, six compact topic rows, and **Browse all sources**. The existing topics are Screens and boundaries, Light and timing, Gentle sleep cues, A clear morning, Letting the mind settle, and A calmer room. Ten ideas do not yet justify a large search/filter interface.
2. **Topic:** short title rows and optional one-line descriptions. Open a single idea; do not repeat every source or full rationale here.
3. **Idea:** suggestion first; one concise rationale and practical example. Use “More context” for longer background, a compact relevant-sources disclosure, and the existing optional add-to-routine action only for genuine routine items. Important caveats remain beside the claim, not buried in an accordion.
4. **All sources:** seven registry entries, grouped as external references and Counting Sheep design notes. Each opens its title, organization, relevance/editorial note and external link where available. Include the unreferenced AASM background record, clearly marked background context; do not imply that every source supports every idea. Internal product rationale is not scientific evidence or a dead external link.

Preserve stable item/source IDs and array order, the three phase groups used by contextual guidance, optional routine limits (three evening/two morning), replacement choice and the onboarding draft binding. No new health claims or clinical-review badge. Home remains occasional/contextual/dismissible. Active Wind Down remains a short phase cue, not a browsable library.

Unify Home, routine editor, onboarding and Settings routes. The legacy `NightFlockIdeasView` also lists all ideas and raw source IDs: route any still-reachable entry through the same library without re-enabling the legacy dashboard or changing persisted shared idea IDs. Split the library out of the already oversized `WindDownGuideCard.swift`; do not add another large mixed-purpose file.

## 7. Sequencing and agents

Sol High owns orchestration: founder decisions, architecture, approved screen hierarchy, complete worker packets, scope control, independent checks and final acceptance. Luna High and Terra High are bounded subagents, not new user-owned tasks. Exact model availability/routing must be checked at execution; never silently substitute.

| Phase | Owner and exact responsibility | Acceptance before moving on |
| --- | --- | --- |
| 0. Establish the actual candidate and capability | Sol: record installed build, source/worktree fingerprint and read-only server capability/deployment evidence. | Know whether the screenshot is on the expected binary and server; no assumption that TestFlight activated membership sharing. |
| 1. Settle contract, adult roles and feasibility | Sol: record the founder decisions and reconcile canonical documents. Terra High: bounded Apple API/evidence/aggregation feasibility assessment. Luna High: compact mockups for empty, unavailable, populated and stale states. | The founder approves composition and leader powers. A sanctioned Singapore customer route proves automatic verified app identity/category capability, or that portion stays blocked. No new sensitive upload during assessment. |
| 2A. Deploy existing membership contract | Terra High: separately authorized Edge/database rollout and retention operations using `slumber-party-membership-sharing.md`; Sol verifies. | Two real accounts share before/between rounds. Compatible validators precede advertising the capability. Privacy operations and rollback are explicit gates. |
| 2B. Short guide | Luna High: guide root/topic/source/detail views and entry-point wiring. Terra High: only required pure query helpers and Shared tests. | All ten ideas/seven sources reachable, concise root, draft/routine behavior intact, Dynamic Type and VoiceOver checked. This can ship independently. |
| 2C. Contextual system connections | Terra High: Health/Screen Time connection state, service/presentation models and tests. Luna High: native inline connection/picker actions in Nights and relevant join/own-member surfaces; retain the optional Connections overview. | Health request markers are not treated as read authorization; stale/no-data state is not denial; no fake OS switch and no protection disconnect. See [contextual connections and Health status repair](contextual-connections-health-status.md). This can ship independently of new social-data transport. |
| 3A. Night-summary contract prerequisite | Sol: apply the settled audience rule and define the remaining archive/migration treatment. Terra High: minimum contributor-night-key schema, capability, complete period queries, deduplication and consent/publication enforcement; Luna High: required agreement/re-agreement flow. | Accepted wire examples and backward decoding; creator/joiner/existing-member consent and publication fences work before new night fields upload. Coverage denominators include only authorized, eligible periods. No precise schedule upload. |
| 3B. Social summary foundation | Terra High: consume the accepted 3A contract for eligibility/coverage/freshness and reconnect reconciliation. Luna High: compact member cards, 7/30 drill-down and Group details controls. | Useful existing activity presentation; selected avatar; no cosmetic triptych; no adherence claim from incomplete history; old-server fallback tested. Real night summaries require 3A. Before then, an independently approved UI slice may show dated existing activity and avatar/layout changes only. |
| 4. Shared-habits contract | Terra High: revised-contract schema, derived summaries, account/outbox fences, server projection, ordinary-leave access revocation and separately reviewed deletion. Luna High: join agreement, recipient preview, absence states and details. | Ordinary leave survives retries/recovery while retaining approved history; deletion is a separate reviewed flow; no data precedes acceptance; SG-gated automatic identity is absent until sanctioned; no fabricated evidence. |
| 5. Independent acceptance and release | Sol reruns validation, inspects accumulated diff and native screens, commissions a fresh review, then coordinates separately authorized beta rollout. | `ship`, `fix-first` or `rethink` with device/three-account evidence and recorded remaining gaps. |

### Worker ownership and dependency boundaries

- **Terra High, social/data lane:** new pure summary/contract models and tests in `Shared/`/`Tests/`; `Shared/CountingSheepUserProfile.swift`, `Services/PersistenceService.swift` and the curated projection; relevant public-profile API allowlists/migration; `NightFlockV4Models/API/Outbox/PublicationPolicy`, `NightFlockViewModel+V4`, `NightFlockService` and relevant account/outbox services; additive SQL migration, Edge validators and tests. This lane also owns the Phase 2C service/state/presentation tests. Agree wire examples before splitting app/backend work. Do not edit rewards/coordinator except an explicitly reviewed evidence/publication integration requirement.
- **Terra High, guide helper lane:** bounded changes to `WindDownGuidance.swift`, `WindDownGuidanceSources.swift`, and `WindDownGuidanceTests.swift`. No new recommendations or silent content rewriting.
- **Luna High, guide lane:** focused library/topic/source views in `Views/Components/`, extraction of `WindDownGuideView`, bounded `WindDownGuidanceDetailView` changes, and entry points. No social backend or Health logic.
- **Luna High, social UI lane:** `SlumberPartyV4MemberCard`, `SlumberPartyV4PartyDetailView`, focused member-detail/group-details/join-agreement views, the explicit social-avatar picker using existing Shepherd/Ollie cosmetics and sheep presentation, and Phase 2C contextual connection/picker views. Consume accepted presentation models. No API-derived business rules in Views, new art, global theme overhaul or Home-hero change.
- **Sol:** requirements/ADR/plan documents, candidate identity and acceptance. Screenbook fixture changes are assigned to one UI worker at a time. Every packet says preserve inherited changes and do not revert others' work.
- No worker changes `project.yml`, entitlements, signing or tabs without founder approval. No commit sweep, push, deployment or upload is inferred from approving this plan.

## 8. Technical and acceptance requirements

### Data and transport

- Add an explicit shared-habits capability/version. Do not revive legacy V3 consent or send new fields to strict legacy validators. Older V4 responses still decode.
- Derived models separately represent period, value, eligible-night coverage, availability, provenance, verification level and revision. Unknown/private/unavailable/partial are not zero. Do not collapse verified app identity, actual usage, shielding applied, continuous enforcement and server trust.
- **Night attribution, implemented and accepted in Phase 3A before Phase 3B aggregates:** derive a stable contributor-local night key from the saved plan's intended-bedtime calendar date and timezone at occurrence creation. Preserve the anchor across later plan/timezone changes. A viewer must not silently shift it; use an explicit date when “Last night” is ambiguous. Phone Away has a separate contributor-local activity-day key. Never upload precise schedules just to label a night. Phase 3A includes the minimum schema/capability/agreement/publication changes for these fields; Phase 4 is the later sensitive-data extension, not their prerequisite deferred until after UI delivery.
- Existing V4 rows with only terminal `occurredAt` cannot be reliably reclassified into nights. Reconcile only from retained authoritative local identity under the current agreement/capability; otherwise retain dated activity, mark night assignment unknown and exclude it from night/adherence aggregates with coverage explanation. Approve wire examples/tests before period UI.
- 7- and 30-night means use arithmetic mean of eligible available nights only within their fixed contributor-local 7- or 30-calendar-night windows. Those are summary windows, not an archive-retention limit. Retained group history must be paginated rather than capped at the latest 100 records. Archive duration, migration treatment, deletion/withdrawal semantics and disclosure require privacy/operations review; do not infer perpetual retention or silently cap the founder's “all retained history” direction. Already expired legacy records cannot be reconstructed. Clearly show partial coverage.
- Sleep corrections are revisioned; replayed/out-of-order records cannot double-count. No perpetual background polling promise on iOS.
- Client session/protection data remains client report. Server validation/receipt does not independently attest continuous shielding or sleep.
- Fetch canonical summaries after realtime invalidation; reconcile on reconnect/foreground. If realtime is unavailable, use bounded visible-social-view foreground fallback with cancellation/backoff. Never poll Active Wind Down.
- Under test conditions, an acknowledged change must appear to its sender without navigation and reach an online second device within five seconds of server acceptance. If it cannot, show a clear pending/stale state and record measured latency. Health updates depend on HealthKit availability and an allowed sync opportunity; do not promise live publication.
- Reader membership epoch and author publication epoch are distinct. A former member retains only a bounded historical name/avatar snapshot beside already published records; it is not ongoing profile tracking. Leaving blocks later Health/app-data updates, clears live status and starts a new membership epoch if the person rejoins. It must neither duplicate records nor replay rewards.
- Shared contract checks occur when queueing, sending and server-accepting. Ordinary leave immediately blocks uploads locally, even offline; it cancels pending sends, purges the leaver's group cache and revokes server read/write/live-status access on reconnect, while retaining approved published history. Explicit privacy withdrawal/deletion and account deletion use separate reviewed flows. Neither ordinary leave nor deletion may permit reward replay.

### Required tests

1. Membership-capable and old/unknown server; no round, active round, between rounds, multiple parties, late join, leave/rejoin and out-of-order terminal/live updates.
2. Aggregate completeness for 7 and 30 nights: over 100 activity rows, duplicate round/stream records, partial completion, missing dates, plan edits, travel/DST and practice exclusion. Means use only eligible available nights; unknown is never non-adherence.
3. Protection apply/clear/failure, authorization loss, restoration, overlapping statuses, brief access and missing evidence. Test the five evidence levels separately; never backfill fabricated overnight totals.
4. Sleep empty/partial/overlapping sources/late corrections, coverage and unavailable permission states. Reject raw Health samples, opaque tokens, private purposes and routines in payloads. Exact selected app identities and usage may travel only through a demonstrated sanctioned Singapore customer route and explicit party agreement; reject them otherwise.
5. Creator and joiner agreement acceptance before any new-field queueing; legacy-member re-agreement; leave before queued send; privacy withdrawal/deletion separately from ordinary leave; Apple recovery/account switch; leave/rejoin; unauthorized reader; pending-send cancellation and leaver-cache purge. Verify server enforcement, not UI hiding only.
6. Singapore customer-route evidence for automatic verified exact app identity/category buckets before that UI or transport path is enabled. EU-only results, manual category labels and sandbox bypass attempts fail the gate.
7. Real three-account test: a member contributes, leaves, and a later joiner reads that permitted retained history; the leaver can neither read it nor publish again. Test explicit privacy deletion separately from ordinary leave. Also test the leader's transfer-or-dissolve-and-leave path without waiting for a successor or host approval. Use appropriately consented test accounts. Confirm local rewards and emergency exit are unaffected.
8. UI fixtures for 1/2/8 members, long names, Shepherd/Ollie/selected unlocked sheep identity, sheep later sheared/traded/released, decoded legacy profile, no eligible data, stale state, small iPhone and accessibility text. Include native Health/Screen Time connect/picker states: request marker, available data, stale/no data and revoked/changed status—never a fake OS toggle or a protection-disconnect route. Test actual taps, scrolls, VoiceOver order, 44-point targets and period drill-down.
9. Guide: ten ideas/seven sources; valid reference IDs/links; root/topic/source navigation and Back; offline bundled text; internal/external source distinction; optional routine addition/replacement; onboarding draft remains draft; dismissal cadence and active-phase cues unchanged.

After code changes, run the repository’s required XcodeGen, iOS build, full unit suite, Slumber Party QA, Deno, local SQL/RLS and relevant Screenbook checks for affected lanes. Record exact commands, candidate hashes and outputs. Local SQL/fixtures do not prove hosted auth/realtime, Singapore Screen Time availability or physical-device evidence.

Before distribution, reconcile public privacy policy, App Store privacy answers, Health purpose text, retention/moderation operations and the exact shipping capability matrix. Deployment and beta upload require explicit authorization and a verified compatible client/server pair. A capability rollback may hide unsupported shared-habits data without interrupting local sessions or deleting reward authority.

## 9. Remaining gates and decisions

The founder has answered the prior join question: adults may accept and join without Health data, and peers see “No data available.” The founder has also answered the prior reader-history question: later members see the party's retained, consented group history, including permitted former-member records, subject to the contributor-audience rule in section 5. Do not re-open either as a product-choice question.

1. **Singapore API/customer route:** automatic verified app identity and usage remain blocked until the sanctioned Singapore customer route is demonstrated.
2. **Archive, deletion and migration:** the founder selected history for the lifetime of the party, subject to legitimate deletion requests. Privacy/operations review must validate that duration, dissolution cleanup, disclosure, withdrawal/deletion, account deletion and migration treatment before archive rollout.
3. **Leader powers:** confirm any authority beyond invite/round management and proposing an agreed bedtime target. Adult acceptance and the ban on remote enforcement remain fixed.

The prior per-field/per-party-choice proposal and manual-category alternative are superseded by the one joining contract and automatic verified-identity requirement. The plan remains deliberately blocked where these gates are unresolved.

## 10. Evidence and work performed in this planning pass

Parent inspected screenshots, current native views, private protection/sleep processing, data models, delivery/membership handoffs and Apple primary documentation. No app/backend implementation, build/test validation or remote deployment was performed. The companion feasibility assessment is maintained separately; existing verification does not prove the proposed features.

An earlier Sol review found that night aggregates depended on contract work placed after their UI; Phase 3A now supplies that prerequisite. A fresh Sol High review of the latest history/connection revision found no material defects and returned proceed for the plan only. The review was behaviorally read-only on an unrestricted host; parent hashes of 1,104 files showed no changed or added files during review. Documentation whitespace/link checks passed; comparison with the Build 35 source manifest found only documentation differences. No app build, tests, phone update or release acceptance is claimed.
