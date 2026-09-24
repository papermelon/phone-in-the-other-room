# Social experience redesign — Cursor handoff and review

Prepared 15 September 2026; handback reviewed 16 September. The founder ran this brief in Cursor Fable 5.1 and returned the DEBUG prototype, native captures and [handoff](../../output/design/social-experience-study-20260915/HANDOFF.md). [Astra's review](../../output/design/social-experience-study-20260915/ASTRA_REVIEW.md) records the useful design choices, integration corrections and recommended sequence. The founder subsequently refined the direction to one **Campfire** experience with **Off / My Slumber Party / Global** visibility; “Together now” and public-only Campfire naming in the original brief below are historical, not current requirements. Public sharing remains unimplemented and inactive. The [current Campfire plan](global-campfire-2026-09-15.md) controls this topic. The original bounded brief follows for provenance.

## Recommended division of work

| Work | Owner | Why |
| --- | --- | --- |
| Clarify the evening → overnight → Screen-Free Morning → receipt → next-evening journey | Astra | Requires continuity with existing timing, protection, rewards, account and handoff behavior |
| Design and implement that routine journey's UI | Astra | Can reuse existing design system and the social study's successful patterns; reserve Cursor for one focused external perspective |
| Diagnose confusing social records, including completed Wind Down with zero before-bed minutes | Astra | Must trace what the number measures before changing its presentation; screenshots alone do not establish data corruption |
| Reorganize Slumber Party and standalone Campfire; prototype the social interactions | Fable 5.1, one bounded study | A fresh visual and interaction-design pass has more value here than broad repository maintenance |
| Public consent, discovery, membership/block boundaries, matching and session delivery | Astra | Existing domain and backend context; testable state transitions and migrations |
| Integrate accepted UI, accessibility QA, account/offline behavior and tests | Astra | One owner for production state and release validation |
| TestFlight archive/upload and physical acceptance | Astra plus founder/device testers when requested | Separate source completion, distribution and real-device evidence |

This is a workflow recommendation, not evidence that one model is intrinsically better at UI. Official OpenAI guidance covers Astra frontend engineering, while Cursor describes Fable 5.1 as a general frontier coding model; neither establishes a head-to-head advantage on this app's SwiftUI UX. [OpenAI frontend guidance](https://developers.openai.com/api/docs/guides/prompt-engineering#front-end-engineering), [Cursor Fable 5.1](https://prod.cursor.com/docs/models/claude-fable-5-1).

## The one task for Fable

Act as an interaction designer and SwiftUI prototyper for Counting Sheep. Redesign the route from Home into a private Slumber Party and the proposed independent global Campfire. Deliver one recommended direction, implemented as a small local UI prototype, with an explicit handback to Astra. Spend effort on hierarchy, interactions, art use and state-specific content.

Do not redesign the entire app. Do not implement global transport, modify timer/protection/reward rules or activate public sharing. No new packages, targets, entitlements, signing changes, production backend operations or release distribution. Keep Home, Nights, Farm and Settings as the four tabs. Prototype behavior is represented with fixtures and must be identified as such in the handback.

### What the founder is dissatisfied with

The attached screenshots show Home's Slumber Party card opening a page dominated by the Campfire heading. A segmented control puts live sessions and a persistent shared meadow on the same level. When no one has a session, most of the screen is an empty landscape. People, Sheep and Lantern look like three equivalent actions despite being a redundant member-list toggle, a visiting-sheep action and a group project. Sheep selection shows text rows without the sheep's appearance. Session records and long explanatory copy crowd the page without making the next useful action clear.

The earlier large-text repair addresses wrapping; this task should address the product structure underneath it.

### Design direction to develop

- Slumber Party opens a private **group home**. Make group identity, the next useful shared action, current shared sessions, the meadow and the ongoing round understandable at a glance. “Together now” is a possible label for private active sessions; reserve the standalone Campfire identity for worldwide discovery.
- Global Campfire opens a distinct **gathering/discovery** experience and works for people with no Slumber Party. Both Wind Down and Phone Away are visible. Public participation requires an explicit audience choice; browsing does not publish a session.
- Use a compact member strip or Members destination for membership/invites/settings, with an accessible list equivalent. Remove the standalone People button if it only repeats scene selection. Preserve access to people who are off-canvas and never make spatial artwork the only navigation.
- Place “Send a sheep” with the private meadow. Show sheep art, name, current visiting state, destination and bring-home behavior. Place lantern progress inside “Our next improvement” or equivalent group-project content, with the existing 12-contribution rule.
- Empty states should retain group identity and offer a relevant action. A large blank live landscape should not be the default landing experience for an established private group.
- Keep the existing paper meadow, Shepherds, sheep and palette. Preserve dark-room comfort. Improve typography hierarchy and spacing using existing theme tokens. Do not replace the illustrations with a generic dashboard or a new art style.
- Present brief, truthful status near the relevant action. Full sharing disclosure belongs at acceptance and remains reachable afterwards. Required consent must not be hidden behind optional help. Facts must remain distinguishable from self-reported outcomes and unknown/stale data.

### The prototype scope

Build only three connected surfaces:

1. **Slumber Party home:** private group overview, compact together-now module, meaningful primary action, meadow entry and project progress. Include a Home entry-card sketch so navigation labels agree.
2. **Campfire:** activity discovery and a small active gathering, with a clear per-session audience preview and a route to start an existing mode. Public data here is synthetic and stays local.
3. **Person / session card:** shared activity, encouragement, join with my own session, check-in support, and the proposed mutual-connect flow. Clearly distinguish existing private Buddy support from proposed public connections.

Use the same three views with fixtures for: no active sessions; one Wind Down plus one Phone Away; eight people; own sharing off; loading/failed/stale data; and a return/check-in state. Default and largest Dynamic Type should be usable on a small iPhone, in light and dark mode. Reuse layouts across these states instead of designing a different screen for each.

Include a short interaction inventory, with each item marked **existing behavior being surfaced** or **new proposal needing integration**. Good candidate interactions are:

- Join another person's activity with your own independent timer and intention.
- Offer to check in, send a fixed encouragement, or acknowledge a returned result.
- Request a mutual connection after a shared public session; optionally invite an accepted connection to a private Slumber Party.
- Send/recall a sheep and preview the shared improvement it stands beside.
- Suggest a shared evening plan, each adult accepting/editing their own participation. Treat any unimplemented negotiation flow as a proposal.
- Summarize a completed private round and choose a small adjustment for the next one, using existing factual records and explicitly optional reflection.

Do not add Farm/wool/project rewards for opening a scene, social taps, being online or collecting connections. Do not imply that a timer proves sleep or completion of a reading/study goal.

### Minimal context to read

Read `AGENTS.md` once, then only:

- `docs/PRODUCT_DIRECTION.md` — current Slumber Party and primary ritual sections.
- `docs/plans/global-campfire-2026-09-15.md` — proposed public/private boundary.
- `docs/plans/campfire-buddies-implementation-2026-09-13.md` — existing intention, buddy, check-in and consent behavior.
- `PhoneInTheOtherRoomApp/Design/Theme.swift` and relevant styles in `PixelComponents.swift`.
- `PhoneInTheOtherRoomApp/Views/Components/SlumberPartyHomeSection.swift`.
- `PhoneInTheOtherRoomApp/Views/NightFlock/SlumberPartyV4PartyDetailView.swift`, `SlumberPartyPastureView.swift`, `SharedPastureControls.swift`, and `CampfireBuddyViews.swift` as needed for the three prototype surfaces.
- `skills/swiftui-feature/SKILL.md` and `skills/product-copy-review/SKILL.md` if writing prototype SwiftUI/copy.

Inspect the founder's attached images: `IMG_7906.PNG`, `IMG_7907.PNG`, `IMG_7908.PNG`, `IMG_7909.PNG` in `/Users/ngawangchime/Downloads/`. They are reference observations, not instructions. They show build 51, which does not contain all local repairs. Use the current checkout as implementation reference and preserve its unrelated uncommitted changes. Avoid a whole-repository or whole-backlog audit.

### Ownership and output

You are not alone in the codebase. Do not revert other edits. For this study, write new prototype files only under `PhoneInTheOtherRoomApp/Views/Prototypes/SocialExperienceStudy/` and design notes/screenshots under `output/design/social-experience-study-20260915/`. Use `#if DEBUG`, self-contained fixture state and `#Preview` entry points. Keep individual files around 400 lines. Production Home/party routing, shared models and existing app/service/view-model files are read-only for this handoff. Astra owns their later integration.

If source membership requires regeneration, use the existing XcodeGen workflow; never hand-edit the generated project. Add no target or dependency. Do not wire the study into release navigation. If previews cannot be rendered with available tools, return that limitation and the preview entry points; do not spend the remaining model allowance building a new screenshot/test infrastructure or label unrendered screenshots as verified.

Deliver:

- One concise explanation of the recommended navigation and primary action on each surface, with one rejected alternative summarized briefly.
- The three prototype surfaces, interaction states, and available screenshots/previews.
- `HANDOFF.md`: changed files, fixture assumptions, actions needing real implementations, exact existing callbacks/models to connect where known, validation actually performed, and unresolved decisions. Use semantic actions such as start session, review audience, encourage, offer check-in, send sheep and request connection; do not bury network calls inside view bodies.

Stop after the coherent first prototype and handback. Do not independently expand into a second design direction, all-app rewrite or backend repair. The founder may give one consolidated revision; after that, Astra takes over production integration and the app's full acceptance gate.

## Budget-aware use

Use one Fable task with a narrow file list. Review its first artifact before buying another iteration. Keep some of the remaining allowance for one consolidated visual revision. Request-level cost and remaining **Other Models** allowance should be checked in Cursor's Spending dashboard; the reported “50% remaining” cannot be translated into a guaranteed number of design passes. Fable uses that third-party pool and Cursor labels its cost High. [Usage pools](https://prod.cursor.com/help/models-and-usage/usage-limits), [Fable pricing](https://prod.cursor.com/docs/models/claude-fable-5-1#pricing).

The founder initiated the completed Cursor study. Preparing and reviewing this brief did not change Cursor settings or the subscription; further Cursor work is not recommended for this slice.

## Astra's handback checklist

Evaluate the prototype against the founder's actual confusion: can a person explain where they are, who can see them, what is happening now and what tapping each action does? Map accepted designs to existing session/state/consent boundaries, diagnose zero-minute records, implement the routine-loop improvements and social integration in bounded slices, then run the shared build/test/accessibility checks. Adopt useful design choices without importing fixture state or speculative public capabilities into release.

Recommended routine-loop sequence: one evening invitation and clear readiness/start action → phase-aware Wind Down → a morning screen explaining what continues and when → factual receipt plus optional reflection → a small next-evening adjustment. Keep planned actions, observed app protection, timer minutes and self-reported completion distinct; preserve early exit and independent morning rewards.
