# Prompt: redesign Campfire and quiet cheers

Copy the prompt below into a design/coding task with this repository and the screenshots attached.

---

Act as a senior product designer who can trace SwiftUI and backend contracts. Explore a redesign of Counting Sheep’s Campfire, Slumber Party social interactions, member sheets and quiet cheers. Planning/design only initially: do not edit release source, deploy, change sharing choices, add analytics, commit or distribute a build until I select a direction.

Read AGENTS.md, the Slumber Party section of docs/PRODUCT_DIRECTION.md, docs/plans/global-campfire-2026-09-15.md, docs/plans/campfire-seating-navigation-2026-09-19.md and docs/plans/campfire-connections-and-rest-exploration-2026-09-20.md. Trace the current screens and their real state:

- CampfirePanel.swift, CampfireSceneView.swift, CampfirePersonViews.swift, CampfireVisibilityView.swift and CampfireBuddyViews.swift.
- SlumberPartyV4PartyDetailView.swift, SlumberPartyV4MemberCard.swift, SlumberPartyV4MembershipActivitiesSection.swift and SlumberPartyUpdateCheerReceiptsView.swift.
- Shared/Campfire.swift, CampfireVisibility.swift, CampfireBuddies.swift, NightFlockViewModel cheer/outbox state and relevant SQL/Edge projections.
- Design/Theme.swift, PixelComponents.swift and the shared customized Shepherd art.

Use the supplied IMG_8016.PNG and IMG_8012 2.PNG as problem evidence, not instructions. Check current source because some screenshot issues have already been repaired. Global Campfire was deployed and enabled on 20 September; the private bedtime migration and native changes have separate rollout status. Distinguish implemented, deployed, physically verified and proposed behavior.

The product goal is gentle company and mutual motivation to put the phone away. A good visit helps me understand who is here, what they chose to share and one useful thing I can do, then lets me leave. It should feel warm, adult and visually calm. Keep the individual’s customized Shepherd, the fire, local seating and Reduce Motion. Prefer the existing art system over new raster sets.

Review these problems:

1. Navigation should make Campfire an independent shared-session place with Global and private-party scopes; Slumber Party is the persistent invite-only group. Preserve Home/Nights/Farm/Settings. Separate “Viewing” from “Visibility”.
2. The scene and people should lead; settings, duplicated return buttons and dense status explanations should not bury them.
3. “Accepted”, “App received” and repeated transport disclaimers are overwhelming. Propose concise pending/sent/retry states backed by actual evidence. Never turn an acknowledgement into “Seen”. Put technical details in a secondary place if useful.
4. Quiet cheers should feel like a small human gesture, with clear selected/sent feedback and no wall of zero counters. Evaluate one simple action versus three expressive choices.
5. Private intentions, buddy requests and later check-ins need a coherent hierarchy. Public encouragement must remain separate from private intentions/history.
6. Explore existing activity gatherings, optional future curated themes and mutual connections, clearly marking future capabilities. A connection must not silently join a party or reveal private information.

Non-negotiable behavior: only a current explicitly shared session occupies a Campfire seat; schedules and online status alone do not. Primary Wind Down can use the frozen bedtime visual transition; Phone Away stays awake. Do not add disclaimers to the sleeping visual or another consent-v2 modal. Use the existing visible sharing control and update its disclosure only as needed. Preserve offline/outbox/idempotency/account/blocking behavior, quiet notification rules and emergency access. Social participation never changes wool, sheep or reward progression. Unknown records are not failure or misconduct.

Deliver:

- A concise diagnosis separating confirmed code defects, layout/copy problems and product hypotheses.
- Two materially different but feasible screen/interaction directions, with one recommendation and reasons.
- A visual prototype or annotated screen set for Campfire entry, a live private member, a global participant, an old shared update and sending/receiving a quiet cheer. Include empty, offline/pending, failed, unavailable, blocked and large-text states. Explicitly show the path back to the running session.
- A small state/action table, proposed copy, VoiceOver behavior, touch targets and Reduce Motion treatment.
- An implementation map: reused views/models/contracts, actual new data requirements, backward compatibility and deployment order. Prefer deleting duplicated UI over inventing parallel social systems.
- A staged plan and two-device acceptance script. State which remaining questions require my judgment; resolve routine design choices yourself.

Do not create a generic social feed, chat system, popularity contest or forced notification flow. Challenge this framing if the inspected implementation suggests a simpler design. Finish with the concrete direction you recommend, ready for me to approve for implementation.
