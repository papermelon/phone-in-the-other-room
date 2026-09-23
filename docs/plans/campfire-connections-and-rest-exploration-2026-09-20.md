# Campfire themes, connections and overnight re-entry

20 September 2026. Founder requested exploration alongside Global activation and the Ollie play repair. These are recommendations, not implemented features. [Global deployment](../evidence/global-campfire-deploy-20260920/deployment.md) and the play repair have separate evidence.

## What already exists

`CampfirePanel` already filters Global by Everyone, Wind Down and `CampfireActivity` (Phone Away, Reading, Studying, Making, Chores, Resting). These are views of actual shared sessions, not memberships. Browsing a filter never joins or publishes. The service returns eight-person pages, coarse counts/time bands and fixed encouragement; `CampfireVisibilityStore` already provides account-owned durable commands.

Private Campfire Buddies already supports separately authored intentions, asking for a buddy, one volunteer buddy, encouragement and later self-reported outcomes/reflections. Its seven-day session record is not a permanent connection graph. Private Slumber Parties already provide ongoing membership, invitations, history and a shared meadow. Use these rather than building another group system.

## Recommended next slice: themes people deliberately choose

First expose the existing activity gatherings more clearly. Reading together, an evening making something, or taking a phone break can create common ground without a new backend. Keep a single prominent start/return action and the fire near the top; the screen should help someone settle, then leave.

A second slice can add a small curated **shared purpose** independent of session activity: examples to prototype are “Make room for reading”, “More time together” and “Make something offline”. Treat these as proposed labels to evaluate, not an approved taxonomy. A cause/theme must be deliberately selected; never infer it from private routines, goals, Health, location or blocked apps. A session can belong to at most one theme initially. No user-created rooms, free-text causes or persistent theme memberships are needed for this slice.

Suggested minimal contract:

- Optional `themeID` on the new-session public publication, bound to that owner/source/agreement. Read filters use `themeID` separately from `activity`; selecting a filter is never a write.
- A short server allowlist with display titles in the app. Preserve nil for old clients and omit the field to old servers. An additive `supportsThemes` state capability gates writes. Unknown incoming theme IDs display the base session instead of breaking the entire state.
- Choose a theme in the existing sharing/start review. If a theme is chosen from browsing, carry it as an unconfirmed suggestion into that review. Show what will be public in the existing disclosure/card preview; do not add a schema-version consent modal.
- Freeze it for the admitted publication. Do not retag past private activity or silently alter a current session by changing browse filters. Defer mid-session retagging until there is a concrete need.
- A chosen theme does not occupy a seat. Only a current explicitly shared session does. Keep existing expiry, terminal precedence, idempotency, blocking, account fencing and stale-state rules.

Likely files: `Shared/CampfireVisibility.swift`, `CampfireVisibilityView.swift`, `CampfirePanel.swift`, `NightFlockViewModel+GlobalCampfire.swift`, `NightFlockViewModel+CampfireVisibility.swift`, `NightFlockService.swift`, `_shared/global-campfire.ts`, a new additive SQL migration and existing Global test suites. Do not edit an already-deployed migration to introduce themes.

Tests: old payloads/servers; unknown tags; invalid/private fields rejected at both trust boundaries; selected browse filter does not publish; owner swap during queued admission; duplicate/terminal-before-start; expiry; Off; block; paging constrained to the chosen theme. Preview empty/one/eight people, unavailable, stale and large text.

## Then: mutual connections, without chat

A helpful interaction can lead to “Connect”, ideally on a return visit rather than a new bedtime demand. Acceptance gives each person a saved way to find the other and explicitly invite them to an existing Slumber Party. It grants no private history, exact schedule, current private-session visibility or automatic group membership. Public aliases can repeat; use the existing opaque public profile ID as the request target, with account IDs resolved only on the server.

Keep one relationship row per canonical unordered account pair, with requester, pending/accepted/declined state and timestamps. A new request after a decline must have a new request identity, so a delayed accept cannot revive an old invitation. Use idempotent commands, account ownership headers, transaction locking and an explicit connection capability. Default proposal: five new requests per account/day, one pending per pair, seven-day expiry, thirty-day decline cooldown. Those numbers are tunable product defaults to evaluate, not claims about the deployed implementation.

Actions: Request, Cancel, Accept, Decline, Remove, Block. A reciprocal request must not silently accept the first request; show the existing pending request. Block immediately excludes both directions from discovery/requests/connections and uses the existing cross-surface block boundary. Deletion cascades; removing a connection does not undo separately accepted group membership. Keep rejected/removed-request tombstones long enough to fence offline replay, with explicit retention tests.

No connection push in the first implementation; show a bounded inbox on deliberate visits. Later notification opt-in must reuse existing quiet-time rules. Do not reuse private `CampfireBuddySession` or its notifications as a stranger-connection service. If a private-party invitation is offered, use the existing invitation and disclosure path and only reveal group information as that path permits.

Likely code: a small pure connection model in `Shared/`, independent connection commands/state through `NightFlockService` and a focused ViewModel extension, a connection section in the existing Campfire people sheet, and one additive SQL migration. Reuse the durable account-scoped command pattern, but do not let `Off` for live presence silently delete a separately accepted relationship. Define relationship retention and deletion explicitly before implementation.

Security/behavior checks: concurrent crossed requests, decline/retry, old accept after new request, two-device conflicts, offline cancel, blocked/suspended/deleted targets, shared alias collisions, no private group data in public payloads and no rate-limit bypass through idempotency-key changes.

## Social redesign direction

The screenshot puts transport explanations above human meaning. Preserve the underlying acknowledgement evidence, but make the default interaction “Send a quiet cheer” → a visible selected cheer with a compact saved state. A server acknowledgement can support “Sent”; it cannot support “Seen”. Pending/offline should remain “Waiting to send”; failed sends offer retry. Put optional technical delivery details in a secondary detail view, not an explanatory paragraph repeated on every activity card. Avoid showing zero counters on every unsent cheer.

One person sheet should answer: who this is within the permitted audience; what they chose to share; what I can do now. For a live private session, lead with the intention and relevant Join/Buddy/Encourage action. For an old update, lead with when and what happened and one small cheer control. Keep sleep averages and history secondary. Public profiles receive only the allowed public projection.

Mechanics to test: shared purpose; a visible willing buddy; one quiet encouragement; an optional morning reflection; a familiar mutual connection. These are hypotheses about motivation, not proven outcomes. Do not add wool or leaderboard rewards for social actions. Use existing session/cheer receipts for debugging; do not introduce new behavioral analytics without a defined question and data decision.

[Copyable redesign prompt](campfire-social-redesign-prompt.md).

## Overnight re-entry: one phase-aware surface

The report is explained by `PersonalShieldSession`: `isSleepTime(at:)` already changes the headline at bedtime, but `visibleSteps(at:)` continues returning the evening checklist and `listButton(at:)` still says “My routine”. `PersonalShieldChecklist` consequently shows both “Time for sleep” and unfinished pre-bed tasks at 5:30 AM.

Recommendation: keep the same shield route and session; change the content by the frozen plan phase.

| Phase | Primary button/destination | Content |
| --- | --- | --- |
| Before intended bedtime | My routine | Existing optional evening checklist |
| At/after bedtime, before morning | Back to rest | Quiet, short return surface; “Your Wind Down is still running.” / “Put your phone away when you’re ready.”; primary “Done”; secondary “Evening routine” disclosure |
| Screen-Free Morning | My morning | Existing morning checklist |
| Phone Away | My tasks | Existing tasks |

Do not attempt to detect that someone woke up. Do not say “You woke up”, start another timer, reset checked steps or infer sleep. Keep 5-min access, emergency exit and all protection behavior in the existing coordinator. A completed evening checklist before bedtime can still show the existing gentle sleep headline without being interpreted as an overnight wake-up.

For implementation, add a pure phase predicate based on `bedtime` and `mode(at:)`; use it consistently for the shield button, in-app button and sheet. Do not reuse `isSleepTime` unmodified for the new overnight route because it also becomes true when all checklist steps are checked before bedtime. Use existing presentation boundaries/foreground reevaluation for an already-open sheet; preserve older-OS shield handoff and cached-shield limitations. Test immediately before/at bedtime, late admission, frozen settings/time-zone change, morning boundary, no bedtime in old data and additionalQuiet. Physically verify warm/cold shield routing and actual blocked-app behavior. No separate “back to sleep routine” editor or medical guidance is needed.

## Staged handoff

1. Prototype two social layouts against real private/public/empty/pending/stale states using the linked prompt; choose one before rewriting the UI.
2. Implement the phase-aware overnight presentation as an isolated native change, preserving shield routing and coordinator behavior.
3. Improve discoverability of existing activity gatherings and private buddy/cheer actions. Validate navigation, Dynamic Type, VoiceOver and quiet-time behavior.
4. Add the optional curated theme contract only after selecting the initial taxonomy. Deploy additive schema/Edge capability before exposing publishing UI; older clients remain valid.
5. Add mutual connection state/actions and its bounded inbox; test hostile/concurrent/offline paths before enabling. Group invitations remain explicit and separate.
6. Evaluate connection notifications and recurring gatherings after the above works on two devices. Chat, user-created causes and automatic matching need their own designs and moderation implementation.

Unresolved decisions: initial theme labels (broad interests versus specific causes), whether connections should be discoverable while someone is not globally sharing (default: accepted contacts only, no live presence), and the operational owner/support contact and age policy for broader public connections. The repository cannot establish those human operating decisions. No implementation of themes, connections or the overnight redesign is claimed here.
