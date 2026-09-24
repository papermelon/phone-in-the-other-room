# Future Agent Tasks — Prioritised Backlog

## Slumber Party recurring loading failure and request volume (22 September 2026)

- [Investigation and local repair](plans/slumber-party-loading-investigation-2026-09-22.md): confirmed **`PGRST303: JWT issued at future`** on PostgREST 14.5, strongly matching Supabase's stale-time-cache incident. The founder authorized one project restart around 22:02 SGT; afterward the same secret-key HTTP checks passed twice and the Slumber Party list RPC returned HTTP 200 (387 ms from the Mac). Production remains on 14.5, so this is recovery evidence, not a proven permanent fix. Verify physical Farm/Apple/party recovery and confirm the patched service upgrade if failure recurs; the offered Postgres 17.6.1.166 upgrade has not been proven to contain that fix.
- Campfire also has a confirmed compatibility defect: build 58 sends default-channel and withdrawal-consent fields rejected by production version 1. Local repair omits the default channel, repairs rejected withdrawal commands only after confirmed legacy capability, and retains profile-sharing gates. Validation is recorded in the linked report.
- The affected account has 282 server revisions, latest September 12. The founder signed out; preserve the phone installation and verify the local account archive before any reset/restore that could lose newer changes. New 22:06 screenshots show Apple/Face ID completing; Farm RPCs returned HTTP 200. A separate confirmed client defect rejects the saved ISO date strings as numeric dates. The shared remote decoder and response normalization are repaired locally with synthetic regression coverage; distribute and physically verify recovery of the correct account and its newer local pending progress. Earlier no-sheet reports remain unverified separately.
- Earlier request coalescing/backoff/Auth/diagnostic changes remain locally implemented. Production Edge functions have not received them. Obtain separate deployment/distribution authorization, then verify current Farm sync, Campfire audience changes, and two-account/privacy boundaries on a physical build. Never deploy the unrelated pending feature migrations as a blanket repair.

## Home intent, goal picker, routine ideas, and receipts (22 September 2026)

- [Implemented direction](plans/routine-home-receipt-2026-09-22.md): atomic goal-sheet presentation, contextual draft-based ideas, Farm progress copy, compact receipts, and Ollie/intent Home composition with grouped sections.
- Home follow-up: compact start controls, Offline Together, feature info sheets, and the 30-minute manual Wind Down overlap rule are implemented. Verify the live transition, early-start confirmation, and both info sheets on the next physical build. Automatic start times remain unchanged.
- After distribution, repeat first goal tap/save/reopen, cancel and save ideas, daytime/bedtime action transitions, full-card planning, Reduce Motion, narrow-screen wrapping, and spoken VoiceOver on physical devices. Planned minutes must remain clearly distinct from measured sleep or readiness. [Local evidence](../output/design/routine-home-receipt-20260922/README.md).

## Home routine and Farm navigation clarity (21 September 2026)

- [Implemented presentation](plans/home-farm-clarity-2026-09-21.md): whole evening routine with full-card editing, clearly named Wind Down/Phone Away start actions and purpose cues, grouped Farm destinations with contextual search help. Existing start eligibility, rewards and guidance dismissal state are preserved.
- Distribute separately and repeat full-card taps, routine edits, smaller-version toggle, action-mode transitions, Farm guide targets and spoken VoiceOver on physical devices. Repeat narrow-device and complete large-text visual checks: local Simulator launch/capture was limited by low disk space and native automation errors. [Local validation](../output/design/home-farm-clarity-20260921/README.md).

## Profile authentication and search collapse (21 September 2026)

- [Source repair](plans/account-and-search-repair-2026-09-21.md): separate verified sign-in feedback from Farm activation, retry connection without repeating Apple, restore saved status after credential refresh, expose unique handles on Profile, and make the search summary/trail plus a bottom Show less control toggle reliably.
- Distribute the app, then verify Apple success → Farm connection failure → retry on the affected physical account with support diagnostics. The screenshot establishes the failure stage, not its hosted cause. Verify handle claim collision with disposable accounts and spoken VoiceOver; preserve the founder's Farm.
- Recheck expand/collapse in the full Farm screen on physical iPhone 16 Pro and other supported sizes. Local simulator checks are recorded in [evidence](../output/design/account-search-repair-20260921/README.md).

## Automatic start and loading follow-through (21 September 2026)

- [Source repair](plans/wind-down-loading-repair-2026-09-21.md): preserve due automatic occurrences during ordinary account sync, move the toggle to Edit Wind Down, bound Campfire reads, handle missing party detail, and reuse Bramble's running art for loading.
- Distribute the updated app, then verify the reported 10 PM case with automatic start enabled beforehand and an account refresh across the boundary. Repeat background/terminated/open starts, actual selected-app access and the next unattended night. Simulator scheduling probes do not establish physical enforcement.
- On the affected account/device, check Campfire timing, offline timeout/retry, party/Global switching, reduced motion and spoken VoiceOver. Source fixes do not identify the screenshot's specific hosted latency without request evidence. [Local checks](../output/design/wind-down-loading-20260921/README.md).

## Slumber Party consent and addressed invitations (21 September 2026)

- [Implementation and current direction](plans/slumber-party-repair-2026-09-21.md): consolidated terms, creation acknowledgement, scoped invitation feedback, exact handle/ID search, recipient inbox, shared loading sheep and button padding. [Evidence](../output/design/slumber-party-repair-20260921/README.md) separates local checks from hosted/device proof.
- Backend deployed with founder authorization on 21 September: `20260921120000_slumber_party_invitations.sql`; `directInvitationsVersion = 1`, account username claim/search and invitation tests passed against production with rolled-back fixtures. [Deployment evidence](evidence/slumber-invitation-deploy-20260921/deployment.md). No Edge function or invite-key rotation was needed.
- Pending distribution and physical two-account checks: create/join agreement confirmation, send/accept/decline/revoke, offline retry, account switch, blocked/expired invitation, large text, spoken VoiceOver and Reduce Motion. Diagnose the original screenshot request `ccf30050-1ad5-4960-bcce-a189142ab23a` against hosted logs if retained; the local source fix does not prove the original server incident's cause.
- Persisting the entire create request across process death remains separate from the existing durable agreement receipt; after an uncertain relaunch reconcile the party list before retrying creation.

## Campfire profiles and channels rollout (20 September 2026)

- Deploy the [profile contract](plans/campfire-profiles-2026-09-20.md) only with explicit deployment authorization: additive profile migration and matching `campfire-global` Edge revision. Existing public version-1 receipts must not expose broader details until Save Global accepts version 2.
- Distribute the updated native build separately; verify Global/party thought-bubble taps, exact times, own-account history, inventory/appearance, account switching, withdrawal, expiry and blocking on two physical accounts. Verify channel moves, full-channel races and the eight-person cap. Confirm large-text and VoiceOver behavior. Final channel/spacing and read-only Farm screenshot QA needs repeating after CoreSimulator launch/boot failures; see the [local evidence](../output/design/campfire-profiles-20260920/README.md). Local Farm positions remain local.
- Future GTM: “claim your handle” reserves the same account character identity; do not introduce a separate public alias or Campfire name.

## Ollie's next search card and bedtime bonus (20 September 2026)

- [Scoped implementation](plans/ollies-next-search-2026-09-20.md) and [validation/native captures](../output/design/search-progress-20260920/README.md): shared card replaced in place, with a separately accounted 20-point bedtime bonus and 15-minute start tolerance for new runs. Source implemented; existing Farm layout and active-session visibility retained. Live Farm and Ollie’s Search disclosure/collapse and normal/large-text rule scrolling now verified in Simulator. TestFlight 1.0 (53) is processed and assigned to Internal QA. Pending: spoken VoiceOver on the founder’s iPhone (agreed handoff; automation could not establish speech/focus evidence), and signed-device overnight/account-switch validation. Heavy Phone Away still dominates the 30-day simulation; its cap, grouped arrival provenance and recoverable wandering remain separate follow-ups.

## Repeated Brief Access and early-wake protection acceptance (20 September 2026)

- [Source repair and acceptance matrix](plans/shield-access-and-early-wake-repair-2026-09-20.md): serialized restore warnings, per-grant callback identities, explicit terminal-parent replacement and stable independent-Morning access reconciliation. The App Shielding Start now handoff uses a dedicated button; NFC remains tag-authorized. Verify six back-to-back grants without foreground recovery and early wake during an active grant on a signed physical build. Source tests do not establish background Screen Time delivery.

## Overnight re-entry and social exploration (20 September 2026)

- [Exploration and staged plan](plans/campfire-connections-and-rest-exploration-2026-09-20.md): use a phase-aware “Back to rest” surface after frozen bedtime, preserving the evening checklist as secondary content. This is a recommendation, not yet implemented. Retain Brief Access/emergency exit and test real shield warm/cold routes.
- [Social redesign prompt](plans/campfire-social-redesign-prompt.md) covers private/public people sheets, quiet cheers, buddy actions, activity gatherings and future themes/connections. Choose a design and initial theme taxonomy before new backend implementation.
- Ollie play now explains the existing active-session restriction at the shared controller; menu and profile requests converge there. [1,079-test/build and native alert evidence](../output/design/campfire-global-20260920/README.md). Verify both entry paths on the next physical build, including VoiceOver. App distribution remains pending.

## Personal shield device acceptance (19 September 2026)

- Interactive review resumed: both modes, completion/check states, phrase gates, Ollie/
  receipt routing, early-wake handoff, light/dark, keyboard and accessibility-size wrapping
  were inspected. Touch targets and disabled-button appearance were refined. The final
  app build, 1,065 unit tests, and isolated integration probe passed; see
  [Simulator evidence and captures](../output/design/personal-shield-20260919/README.md).
  Finish small-screen inspection (the disposable iPhone SE had boot/app-launch failures),
  touch scrolling with large text, spoken VoiceOver and dictation. Accessibility
  labels, Checked/Unchecked values and lower-action activation were inspected locally.
- Local source implementation is recorded in the [personal shielding note](plans/personal-shield-design-2026-09-17.md).
  On a signed iOS 26.5+ device, verify warm/cold shield buttons open the correct sheet
  over Ollie, normal reopens do not replay it, checked steps appear on the next shield
  presentation, and cached shields refresh without clearing protection. Verify older-OS
  manual handoff, an unattended automatic start, NFC-authenticated exit, cancelled and
  fresh phrase gates, near-end Brief Access, restore after suspension, VoiceOver/dictation,
  and account/occurrence changes. Simulator evidence does not establish these platform
  behaviours. No deployment or physical-device acceptance is implied.

## Wind Down automatic-start and late-reopen acceptance (17 September 2026)

- Source repair and validation: [repair note](plans/wind-down-automatic-recovery-2026-09-17.md).
  Verify actual selected-app blocking on both affected signed devices with the app
  closed overnight, two consecutive unattended starts, receipt dismissal, and late
  reopening. Verify non-daily routines and multi-night history recovery: the legacy
  automatic shield repeats daily while app persistence retains one occurrence.

## Private Campfire bedtime rollout and device acceptance (19 September 2026)

- Local implementation follows the [bedtime contract](plans/campfire-bedtime-2026-09-19.md). See [validation evidence](../output/design/campfire-bedtime-20260919/README.md). Deploy only with separate authorization: additive `night-flock-command` validator first, then `20260919130000_campfire_bedtime.sql`, verifying the actual hosted wrapper chain and privileges. Keep this private-bedtime rollout separate from the already activated Global slice.
- Updated distribution and the contract's physical two-account matrix remain outstanding: open-screen bedtime/wake, late start/sharing, frozen settings, offline terminal/reconnect, receiver resume, withdrawal/block/party/account isolation, old/new clients, VoiceOver and Reduce Motion. Preserve founder data; presence never grants progression or proves sleep/online status.

## Campfire readable plans and organic seating (20 September 2026)

- [Mobbin research and implementation plan](plans/campfire-readable-plans-and-organic-seating-2026-09-20.md) records the implemented readable multiline plan cues, explicit full-text disclosure and stable asymmetric seats with local facing variation. [Validation evidence](../output/design/campfire-readable-20260920/README.md) tracks the local build, tests and native checks.
- Bubbles/seating and person-sheet hierarchy are implemented locally, with full shared text in the existing sheet/list and profile/Farm disclosures after actions. Live-network, spoken VoiceOver and two-device acceptance remain release gates; no distribution or backend deployment is included.

## Campfire polish acceptance (20 September 2026)

- The common Campfire panel now keeps its campsite through loading, empty, populated,
  refreshing and failed states, with native fire motion, a participant disclosure and a
  seating menu. Valid presence survives routine refresh; unavailable presence is removed.
  Duplicate entry command draining and overlapping periodic reads were reduced. See the
  [implementation record](plans/campfire-polish-2026-09-20.md) and
  [local evidence](../output/design/campfire-polish-20260920/README.md).
- Remaining physical checks: slow/flaky network, account/gathering changes, foreground return,
  spoken VoiceOver and seat actions, Reduce Motion, and hold/drag versus scrolling. No backend
  deployment or app distribution is included in this visual pass.

## Campfire seating and navigation device acceptance (19 September 2026)

- Local [seating/navigation changes](plans/campfire-seating-navigation-2026-09-19.md) require physical tap/hold/drag versus scrolling, VoiceOver seat actions, Reduce Motion and party-to-Campfire return checks. Seats are local view state. Global was deployed and activated on 20 September; themed gatherings and mutual connections are [exploration only](plans/campfire-connections-and-rest-exploration-2026-09-20.md).

## Unified Campfire activation and device acceptance (16 September 2026)

- Founder-authorized source implements one Campfire with Off / My Slumber Party / Global. Home/Farm and private-group entry share the same panel; browsing never changes audience. The visible agreement flow, typed joins, both session modes, accessible lists and larger-text layouts (with the 20 September persistent campsite replacing compact empty cards) replace the earlier proposed “Together now” direction. See [implementation contract](plans/global-campfire-2026-09-15.md) and [local validation](../output/design/unified-campfire-20260916/README.md).
- Explicitly authorized [Global deployment/activation completed on 20 September](evidence/global-campfire-deploy-20260920/deployment.md): exact migration, Edge v1, enabled switch, hosted rolled-back SQL suite, service-only access and invalid-auth probes verified. Daily pg_cron is configured; observe its first scheduled execution. Authenticated two-device HTTP/UI acceptance, operational moderation owner/support contact, public-connections age/disclosure decisions, backup/restore and production load evidence remain unverified. No native app distribution occurred.
- Repeat the original build 51 scenario on disposable physical accounts after updated app distribution: one Wind Down and one Phone Away, both private seats on both phones; then zero-party Global, mixed private/global, active widening/narrowing, offline early end/Off, kill/relaunch, two-device receipt conflicts and account switch. Verify shielding, morning check-in timing and VoiceOver separately. Preserve the founder’s Farms. Simulator sessions and app-reported presence do not prove physical placement.
- General mutual connections, public free text/chat, worldwide realtime/scale and the broader Wind Down/Screen-Free Morning redesign remain later slices. The [Fable study](plans/cursor-fable-social-ux-handoff-2026-09-15.md) is design evidence; its public proposal buttons do not imply these features shipped.
- Trace the screenshot’s “completed Wind Down · 0 quiet min” using before-bed versus overnight records. A factual zero is distinct from absent sharing or no record. This metrics investigation is separate from the unified Campfire visibility implementation.

## Mobbin first-night follow-up (updated 20 September 2026)

- The state-aware first-start sheet is implemented with a full-height presentation, fixed
  bottom action, separate permission/selection/start steps, existing repair intents, and
  preserved consent/NFC behavior. See the [research and implementation brief](plans/mobbin-first-night-2026-09-14.md)
  and [local validation evidence](../output/design/first-start-20260920/README.md).
- Remaining acceptance: physical-device authorization denial/restoration, picker dismissal,
  foreground return, runtime protection failure, NFC cancellation/mismatch/success, spoken
  VoiceOver, and a first-use observation. Preview readiness is simulated and cannot prove
  those platform behaviors.
- The consolidated plan-review experiment remains proposed and was not implemented in this
  task. The private three-flow collection is available in the brief. OAuth succeeded during
  research; that research used the authenticated browser, not a verified MCP search.

## Shop/Ollie and campfire follow-up (13 September 2026)

- Campfire Buddies source is implemented: explicit intentions, volunteer buddy support, return
  check-ins and opt-in ordinary APNs party/buddy notifications. Preserve the existing paper art.
  [Current contract and activation checklist](plans/campfire-buddies-implementation-2026-09-13.md);
  [validation evidence](../output/design/campfire-buddies-20260913/README.md). Still pending: authorized
  app distribution and two-device notification/quiet-time/account-switch acceptance. The two new
  migrations, matching Edge bundle, APNs topic and Vault/pg_net scheduler were
  [deployed and verified](evidence/campfire-buddies-deploy-20260913/deployment.md); scheduled workers
  returned HTTP 200 with zero queued events. Physical push receipt is not yet proven. Validate
  foreground token rotation, offline logout limits, duplicate receipt recovery, physical VoiceOver,
  notification-denied state and expired deep links. Named buddy invitations and new social collectibles
  remain later refinements; current support is one volunteer buddy per session/party.
- Local shop pass replaces floating cutouts with fitted paper garments for all six Ollie items,
  and adds native paper art for all eight decorations, six keepsakes and four pasture upgrades.
  Home, Farm, Shop previews and chase share the equipped look. See [review and campfire direction](plans/shop-ollie-and-campfire-2026-09-13.md)
  and [native visual/build evidence](../output/design/shop-ollie-20260913/README.md).
- **20 September fitting correction:** the earlier placement-only renderer reused one neck
  transform for every Home frame and had no chin/ruff occlusion. All six current garments now
  use independent neckline/chest landmarks and the original textured fur over the fabric. New
  silhouettes need their own overlap review; colour/motif variants can reuse an accepted shape.
  The Shop preview now
  includes head tilt and settle/rest/rise, and native art capture includes every Home frame.
  See [fitting contract](ASSET_NAMING.md#ollie-neckwear-fitting) and
  [repair evidence](../output/design/ollie-bandana-20260920/README.md).
- Confirm fitted motion, small Farm scale, large text, physical VoiceOver and Reduce Motion on
  the next device build. Source/Simulator checks do not constitute installed TestFlight acceptance.
- Campfire source is implemented: free gathering place, separate version 1 sharing consent,
  bounded Phone Away intentions, overnight validity, terminal precedence and temporary seating.
  See [contract](plans/campfire-implementation-2026-09-13.md) and
  [local evidence](../output/design/campfire-20260913/README.md). Production migrations and matching
  Edge version 5 were [deployed and verified on 13 September](evidence/campfire-deploy-20260913/deployment.md).
  Device feedback exposed an always-lit fire and inactive-member/active-seat overlap; the live-only
  scene, distinct seating, separate saved meadow and visible-screen refresh fallback are repaired
  locally. Verify zero/one/eight active participants and recovery after stale updates in the next
  app build; [repair evidence](../output/design/campfire-live-repair-20260913/README.md).
  Recheck any service-unavailable error while opening/refreshing with the preserved outgoing
  request ID; the screenshot’s exact network/gateway cause could not be established from logs.
  Verify two-device consent/start/expiry/early-end retry, killed
  app/relaunch, leave/block/account switching, and real shielding. Mac lock prevented native tap
  and VoiceOver automation during this pass; complete physical interaction/accessibility checks.
- A future separate small charm slot for selected keepsakes needs fitted art and backward-compatible
  storage/public appearance rules. Current keepsakes remain on their four-slot shelf.
- Legacy Shop/overlay PNGs are bypassed by the new native renderers but retain catalog compatibility
  references. Retire only after all-target/static/dynamic reference and recovery checks; do not
  claim resource savings from this rendering change.

## Personal Farm fetch — device acceptance (updated 20 September 2026)

- Current source uses ball-origin swipe/flick throws, all four grass corners, continuous dressed
  Ollie retrieval, pickup/carry/handoff, one ball at a time, and bounded sheep avoidance. Large-text
  controls wrap/stack and the Shepherd nameplate stays inside the card. Validate
  gesture feel on a physical iPhone, including flick strength versus parent-scroll gestures,
  repeated throws, resting-to-rise transitions, pasture changes, backgrounding, Reduce Motion and VoiceOver direction-menu
  throws. Native Simulator captures and domain/lifecycle tests are recorded in
  [original fetch evidence](../output/design/fetch-20260913/README.md). No new TestFlight upload is implied.
- [20 September validation](../output/design/fetch-swipe-20260920/README.md): full app build
  passed; 1,096 tests passed with the unrelated, uncompilable `CampfireProfileTests.swift`
  excluded (14 fetch tests passed). Restore the unrestricted full-suite gate after that test
  target issue is repaired. Native large-text, swipe/scroll and VoiceOver acceptance remains
  pending: the Mac was locked and capture Simulators stalled launching/migrating. The DEBUG
  fixture supports `--fetch-largest-text` and `--fetch-controls-only` for the next inspection.
- Progression and wool Shop additions are proposals, not shipped features. Start with optional
  short target practice and cosmetic balls; see [fetch progression proposal](plans/fetch-progression-2026-09-20.md).
  Confirm the first progression slice before changing inventory, save contracts or rewards.

## Farm / shared pasture — device and rollout gates (12 September 2026)

Production source now includes the original wide shared meadow with movable Shepherds and
separate owned sheep, recall-based visits, revisioned placements, contextual member sheets,
one group stream, and the 12-contribution lantern. Personal Farm/barn art is refreshed; four
verified unused runtime files are retired. Ollie stays personal, with fetch/gather and a detail
page; Shepherd customization keeps its live model above the scrolling options. See
[implementation evidence](evidence/pasture-redesign-20260912/README.md) and
[current decisions](plans/slumber-party-pasture-redesign-2026-09-12.md).
The earlier prototype/research work is historical; its simulated store remains out of release wiring.

- **Production backend deployed 13 September with founder authorization.** The additive pasture
  and campfire migrations and both Edge functions passed hosted checks; see
  [deployment evidence](evidence/campfire-deploy-20260913/deployment.md).
  Policy starts at migration activation; pre-activation private sessions do not backfill the lantern.
- Run physical disposable-account A/B tests: contribute/recall, remove/trade sheep then sync,
  two-party exclusivity, account A/sign-out/B/A, leave/rejoin, block, party deletion, offline
  placement retry after a concurrent move, and relaunch with ambiguous contribution acknowledgement.
  Isolated SQL and durable native storage tests establish source contracts, not live transport.
- Verify fresh session cues, expiry, reconnect and exact original-update cheer context on two
  devices. Preserve pending/accepted/app-received distinctions; no claim that a person saw a cheer.
- Verify active Wind Down Home → party → live Home on physical devices with actual selected-app
  shielding, emergency exit, background/foreground and independent settlement. Simulator fixtures
  exercise navigation only and deliberately request no shielding.
- Test real tap versus double-tap pet versus 0.35-second hold/drag, camera swipe, collision and
  interruption on SE and larger phones. Simulator accessibility move/select/pan controls are
  inspectable; automation could not reliably reproduce touch hold/drag. Confirm physical VoiceOver
  focus/speech and Reduce Motion. Do not treat screenshot evidence as motion/protection evidence.
- Check pinned Shepherd/Ollie previews with the keyboard, landscape, largest Dynamic Type and
  fitted accessories on physical devices. Keep the four release tabs and return navigation intact.

## Shared Farm and contextual cheers — rollout and device gates (9 September 2026)

Production native source now integrates the shared Farm, member update sheets, contextual
cheers, durable queued update-cheer recovery and named recipient entries. The additive backend
source includes optional public head shape, participant-only app acknowledgements and a bounded
projection retaining each member's latest/cheered update. See [plan and validation](plans/slumber-party-shared-farm-and-cheers.md).

- Backend rollout completed with founder authorization on 10 September: both Edge functions v4
  and migration `20260909090000`, including the shipped Foundation-date compatibility repair.
  See [deployment evidence](evidence/slumber-backend-20260910/deployment.md). Confirm the installed
  TestFlight app clears the publication error after reopen/refresh; no physical retry was observed
  during deployment. Add an explicit native transport date contract and an end-to-end encoded
  request test in the next native maintenance batch; retain the backend adapter for older builds.
- Native flashing/layout repair is integrated in source on 10 September; validate repeated
  background refresh on the next installed TestFlight build for both self and friend sheets.
  Confirm fixed card position, truthful failure recovery, grounded feet, name readability and
  VoiceOver/Reduce Motion on-device. See [native review](evidence/slumber-grounded-farm-20260910/review.md).
- Run physical two-account A/B tests: different characters/outfits/head shapes, exact update
  selection, duplicate taps, ambiguous send + relaunch, acknowledgement + sender reconnect,
  account A/sign-out/B/A, leave/rejoin/block, and loss of consent. Use disposable accounts.
- Verify active Wind Down behavior with background/foreground/overnight transitions against
  the 12 September redesign: deliberate interactive pasture access is allowed; shielding and
  settlement remain intact, no new unsolicited notification policy is assumed, and app receipt
  never claims human attention. Earlier no-social-UI requirements are superseded for this journey.
- Confirm native VoiceOver speech/focus and Reduce Motion on physical iPhones. Simulator
  accessibility-tree/layout inspection is separate evidence from physical assistive technology.
- Operate existing 90-day stream cleanup and verify cascading acknowledgement cleanup;
  legacy round retention continues to require its existing operations review. Receipt metadata
  is participant-only and never a read receipt or a party-lifetime history grant.


## Meaningful personalisation — release checks and optional AI (13 September 2026)

The [local loop](plans/meaningful-personalisation-implementation-2026-09-13.md) is implemented;
see its [validation record](evidence/personalisation-20260913/validation.md). Before distribution,
validate on physical devices: VoiceOver action order, large text with keyboard/long custom
wording, account switch with a sheet open, offline relaunch, and a real independent/linked
morning preserving its countdown, app protection and compact reward receipt. Run a consenting
usefulness study for goal labels, weekly invitation burden, and accepted changes' later
self-reported helpfulness. Simulator tests do not establish habit improvement.

The [AI pilot proposal](plans/personalisation-ai-pilot-2026-09-13.md) and offline synthetic harness
are ready for review. API credit balance/expiry/project access are unverified. No paid evaluation,
server endpoint, AI consent flow, quota ledger, remote retention or deployment exists. Authorise
a bounded evaluation budget separately before any model calls; ship AI only if the held-out
comparison clears the documented quality/privacy/authority gates. Cross-device personalisation
sync and secure removal from OS backups/recovery history require separate storage designs.

## Wind Down habit loop — validation beyond local implementation (8 September 2026)

The [implementation and pilot record](plans/wind-down-habit-loop-2026-09-08.md) describes the
plan-first route, private support/reflections, and unchanged admission/reward boundaries.
Before claiming release readiness, validate on physical iPhones: denied/revoked/empty-selection
repair; actual selected-app shielding and emergency exit; essential communication/transcription
and visual alerts with category selections; automatic-start relaunch and the smaller-choice
snapshot; notification delivery; Watch transport; account A/sign-out/B/A with private drafts.
Simulator probes establish local behavior only. No distribution or production activation was
performed by this task.

Run the independent-use pilot and 40-minute SADeaf activity, with interpretation/access needs
co-designed with participants. Prepare one tested iOS or device-specific Android setup per
person and a visual way to test, undo, and revise it; app use is optional. Record independent
use/revision, appeal, and return after interruption separately from long-term habit/sleep claims.
Do not infer effectiveness from feature completion or add remote analytics by default.

If real corruption of the new private support/reflection values is encountered, add an explicit,
owner-scoped recovery flow that preserves the unreadable bytes before any replacement. Current
saves protect those bytes and show an error; reopening retries loading. Deferred personalization
questionnaire answers are not saved until the person accepts the result; closing it discards
that optional draft without changing existing answers or gift eligibility.

## Shepherd artwork and fitted clothing — 12 September 2026

22 September expansion follow-up: [wardrobe and collection study](plans/wardrobe-expansion-2026-09-22.md).
The [23 September first slice](plans/wardrobe-layers-2026-09-23.md) implements a fuller coat and
independent shirt/outerwear. Capability-gated social appearance support for the shirt, open
coat and Ollie coat IDs, with validators, storage and old-client fallbacks, was [deployed to production
on 23 September](evidence/campfire-wardrobe-deploy-20260923/deployment.md). Verify a two-account
physical Campfire and distribute the matching native app before claiming exact social appearance
is live on devices. Older clients retain the cream shirt, closed moss coat and classic Ollie coat.
Berry, dusk and amber shirts are now in the local Shop.
Then add footwear/neckwear/carry alongside finished art and persistence coverage. Farm collections
require coexisting placement review before sale. The [Corgi sit/run/rest study](../output/design/corgi-breed-study-20260923/README.md)
corrects the earlier Collie-like colour swap. Complete all 23 poses and garment fit, including
an uninterrupted copper forehead, before making it selectable or shareable. Other breeds still
need complete authored packs.
Physical-device motion, VoiceOver and multi-account restore remain separate from Simulator QA.
Production lint after the 23 September rollout reports two JSONB initialization cast warnings
in `public.global_campfire_state_before_wardrobe`; exercised paths passed, but use explicit
JSONB literals if that function is next revised. Two older unused-variable warnings remain.

The founder-approved body correction is implemented in the shared production renderer:
broader curved clothes, angled sleeves, mitten hands, shorter trouser sections, rounded boots
and a broad paper wash. [Before/after proofs and validation](../output/design/shepherd-body-20260912/README.md)
record the current source state. Existing equipment and customization IDs are unchanged.

Long-hair cheek overlap repaired after founder screenshot review; see the
[repair and rendered checks](../output/design/shepherd-hair-20260909/README.md).

The [production integration](plans/shepherd-native-art-integration.md) now connects the shared
paper-textured Canvas renderer to normal avatar surfaces, provides four saved head shapes,
retains five hairstyles/skin tones and fits all seven existing wearables. Shop thumbnails
match the renderer. Legacy saves retain their original absence of a head-shape field; future
IDs remain intact. See [validation and visual evidence](../output/design/shepherd-production-20260909/README.md).

Public head-shape support is now part of the capability-gated
[shared Farm work](plans/slumber-party-shared-farm-and-cheers.md), with legacy pear fallback.
Remaining: connect actual pasture locomotion/turns with grounded feet; complete the continuous
motion and side/back fit review for every garment before enabling motion; add eye-expression
selection, wardrobe collections and neckwear only with saved-state/fit coverage. Physical
update/restore, VoiceOver and low-end iPhone rendering performance remain release acceptance
checks. No archive or distribution is claimed. Screenbook remains shelved; use the dedicated
Debug study or ordinary SwiftUI previews. Historical [batch-1 evidence](../output/design/shepherd-native-20260908/README.md)
and [design review](../output/design/shepherd-review-20260908/REVIEW.md) remain references.

## Agent instruction maintenance — 7 September 2026

Repository cleanup is complete; see [the implementation and validation record](agent-instruction-cleanup-2026-09-07.md).
Provider-managed Figma/Google Docs discovery-description changes remain an upstream or
maintained-plugin-source follow-up. Prepared replacement wording is in the record; do not
edit versioned caches or disable plugins as a substitute. After any future metadata change,
check relevant and unrelated task selection while preserving tool prerequisites and consent.


## Account-backed Farm save — native acceptance remaining (2026-09-05)

The founder authorized production deployment and physical-device testing. The local
transaction store, private Supabase RPCs, account-scoped pending operations,
restore/conflict/revision controls, shared Apple sign-in, onboarding/Settings entry
and in-app disclosures are implemented. Farm-only production migrations were
applied without the unrelated pending social migration. See
`docs/FARM_BACKUP_DEPLOYMENT.md` for evidence and actual remaining gates.

Release-review restore publication and shared account-deletion fencing are fixed
locally, with focused fault-injection tests. The complete final-candidate acceptance
matrix is `docs/PLAYBOOKS/final-build-acceptance.md`; unchecked items remain gates.

Finish physical Apple sign-in, real backup/restore, network interruption and second
account/device acceptance. Update/reinstall testing must use a disposable install;
do not erase the founder's existing Farm. Public policy publication and app
shipping remain separately reported from source edits and Supabase deployment.

## Cumulative Farm credit — physical acceptance remaining (2026-09-05)

Local implementation and migration: ADR-0020. Before distributing, test a real overnight
run, five-minute access while the app is terminated, same-run schedule revision,
permission/restore failure, early NFC/emergency exit, and morning handoff. Confirm access
expiry and actual shield reapplication on supported iOS versions. Simulator arithmetic,
replay and receipt capture do not establish Family Controls enforcement. Local accounting
keeps consumed spans/receipt IDs until reset; no new backend deployment is needed.


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
- **Accept:** run from Wind Down through Screen-Free Morning on a physical iPhone; cover locked
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
  the active run, completion, and More. The initial implementation used a single phase cue; the 7 September device review replaces the unrelated educational pairing with the chosen routine ideas (see `plans/live-activity-and-app-copy-2026-09-07.md`).
- **Mode:** Product + Codex · **Size:** S · **Autonomous:** no
- **Accept:** satisfied by `docs/DECISIONS/ADR-0008-wind-down-guidance.md` and
  `docs/SLEEP_GUIDANCE_SOURCES.md`: short static notes, authoritative source IDs, user goals
  first, no diagnosis or sleep-quality promise, no notifications/feed/novelty loop, and no
  nighttime interaction requirement. Any future expansion still needs product review.

### D4. Slumber Party v4 production follow-through and two-account proof — backend deployed, human gates pending
- **2026-09-07 · Build 40 Profile / Apple return-sign-in review:** local source moves
  Profile to the Farm header, separates identity/sync/destructive controls, and fixes
  Apple callback-slot and cancelled-link cleanup. Before calling the reported native
  failure resolved, verify sign-out → Apple sign-in on a physical device using the new
  stage/code diagnostic. A system-sheet failure is distinct from Supabase/account or
  Farm-load failure. Do not change signing or hosted settings without identifying the
  failing stage and obtaining any required activation authorization.
- **2026-09-07 · Refresh and experience draft:** local changes scope summary/detail read
  failures, correct error support references, name failed v4 actions, and simplify the party
  screen. See [draft and acceptance](plans/slumber-party-refresh-and-experience.md).
  Correlate the device's rejected request with the affected build and hosted logs; a screenshot
  reference may have belonged to an earlier successful command. Prove delayed reads, reconnect,
  successful retry, and two-account updates on devices. The source draft does not establish or
  repair the underlying hosted rejection. Broader command/outbox error ownership and cursor
  recovery remain follow-ups; the draft does not replace every legacy global error path.
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
  entitlement, or backend changes. Screenbook is shelved (founder confirmed 8 September 2026);
  first-run states are covered by ordinary `#Preview`s and applicable native validation.

### D7. Review the expanded Farm economy after four weeks of TestFlight data
- **Gate:** at least four weeks of real TestFlight use with user-initiated economy exports.
- **Mode:** Product decision before code · **Size:** M · **Autonomous:** no
- **Accept:** review first-purchase timing, balances, ownership, shearing, and duplicate trading
  against the checked-in simulations. Prefer repricing only new items if progression is slow. If
  balances accumulate too quickly, consider permanent 30/45/60-wool environment themes before
  changing established wool yields or trade returns.

## E. Later / explicitly postponed (do not start; citable refusals)

- **Historical expanded Shop bitmap drafts** — the old pixel-art selection requirement is
  superseded by the founder's 13 September paper-art revision. The active collection now uses
  fitted native paper garments/objects; old exploration drafts are not awaiting installation.
  See the current Shop follow-up above for physical acceptance and legacy asset retirement.
- **Screenbook — shelved** — founder reconfirmed 8 September 2026. Do not cite it as the
  default review workflow, expand its registry, or pursue its maintenance backlog. Retain
  existing tooling as historical work; restarting it requires explicit founder direction.
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

- Profile sync follow-up (7 September device screenshots): shared header Profile icon and visible consent-operation feedback implemented locally. Physical device validation remains: enable automatic sync on the affected legacy Apple account, confirm success removes the consent card, and capture any remaining server failure. No production account operation was performed during implementation.

- **Production sync endpoint blocker resolved (7 September 2026):** Founder authorized repair. Production catalog confirmed the account migration was absent. Deployed `20260907110000_account_identity_and_farm_sync.sql` and recorded migration history atomically on `sxjlkcccsentmhowgoqe`; new sync/revision/username HTTPS endpoints resolve and reject anonymous access. Transactional randomized production tests passed, including actual authenticated-role save and restore; all fixtures rolled back and zero test users remain. See [deployment evidence](FARM_BACKUP_DEPLOYMENT.md#7-september-2026--account-sync-production-repair). Remaining: physical Profile consent/save and native Apple sign-out/sign-in on the affected build. No founder Farm was modified in testing.

- **7 September device protection / Slumber Party entry:** Local repair routes, monitor-installation result handling, and account-Farm loading recovery are implemented. Confirm automatic scheduling and two-account Slumber Party on the affected device/build; a screenshot does not identify an underlying hosted rejection. See [repair and validation](plans/device-protection-and-slumber-entry-repair.md).

- **13 September morning / completion redesign:** Source now shares the sunrise countdown scene, removes active-session Purpose menus, and makes completion reward-led with linked morning summaries. Verify compact-screen and accessibility layouts, scene/background behavior, NFC/emergency exit, saved reward destinations, and protection repair on the final build; the founder deferred full build/device verification during these visual edits. Focused macOS XCTest execution passed 21 journey/morning/receipt domain tests (the unchanged ActivityKit adapter was excluded from the harness); affected SwiftUI files passed syntax parsing. These checks do not type-check or visually validate the iOS app. Meaningful personalisation is now implemented separately in the [local delivery record](plans/meaningful-personalisation-implementation-2026-09-13.md); a paid AI pilot remains proposed only.
- **7 September Live Activity / copy:** Verify the background bedtime redraw on a locked phone without reopening the app, including offline and app-terminated cases. The local next-boundary freshness projection does not provide repeated background transitions or terminal dismissal. On 12 September the founder approved APNs, Debug/Release client flags were enabled, and existing hosted scheduler/configuration health was verified; signed-device delivery remains unproven. Inspect the three-idea Lock Screen layout, large text and VoiceOver; see [implementation and acceptance](plans/live-activity-and-app-copy-2026-09-07.md). The 13 September icon update uses a crescent moon for Wind Down/overnight and a sun for Screen-Free Morning; include both in the next Lock Screen and Dynamic Island device check.

- **12 September Wind Down completion repair:** On a new signed build, verify Wind Down → overnight → Morning → checkmark/completion copy while locked; then open from both the activity and app icon and confirm the activity disappears. Repeat completion with Farm/Nights/Settings selected, dismiss the receipt, and switch all four tabs. Include active linked Morning, no saved run, relaunch, offline, early end, APNs rotation and retry. Local source and isolated Simulator checks do not establish physical APNs/Lock Screen behavior. Original Wind Down schedules use the enabled existing backend; independent/rescheduled Morning-only push scheduling remains a separate follow-up.

- **NFC start repair, 12 September:** Source now permits a new NFC scan when the coordinator retains a completed/early-ended receipt, gives the pending mode priority over the prior run's tag purpose, and cancels preflight only on actual sheet dismissal rather than temporary disappearance under system UI. Confirm on a physical iPhone: open the start sheet → start the scanner → read a registered tag → one admitted run with the correct mode; repeat Wind Down after Phone Away and the reverse, completed/early-ended receipt retention, scanner cancellation/retry, picker return, mismatched tag, and protection-readiness rejection. A bare tag tap outside the in-app scanner is not currently a start entry point; the reported tap context remains to be confirmed.

- **Old NFC tag recovery, 12 September:** Idle pairing/replacement now routes recognized orphaned credentials through explicit reset confirmation; the lost-tag wizard owns that dialog. Error copy distinguishes unreadable tags from readable unrecognized formats and a different tag scanned at confirmation. Physically retest the reported old tag on an updated build, including ordinary pairing, lost-tag replacement, recovery after local-data reset, cancellation, same-tag confirmation, and preservation of the old pairing after write failure. The screenshot alone cannot identify the tag's NDEF format. Unrecognized legacy/foreign formats remain unsupported; collect the new error category before deciding on a format migration or an explicitly confirmed erase flow. Simulator checks do not prove a physical write or NFC-sheet presentation.
