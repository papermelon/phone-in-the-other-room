# Campfire Buddies — research and proposed next iteration

13 September 2026. Historical research and design proposal. The founder subsequently approved implementation; see the [current Buddies source contract and differences](campfire-buddies-implementation-2026-09-13.md). The [Buddies backend and push configuration](../evidence/campfire-buddies-deploy-20260913/deployment.md) were subsequently deployed; device distribution and physical notification receipt remain pending. The proposal below records the research-stage direction. The founder requested party-wide start notifications, clearer goals/tasks, and peer accountability, with X research and Friend Controls as a comparator.

## Recommended product loop

**State an intention → let the party know → join or offer support → spend time away → share how it went.**

Campfire should make three things immediately legible: who has a current shared session, what they intend to do, and how a friend can help. The social interaction belongs chiefly at the beginning and after returning. Viewing the party never requires starting a session; starting a session never depends on somebody responding.

Keep Slumber Party as the private group, Campfire as its current shared sessions, and Shared meadow as its persistent place and collection. Introduce “buddy” as a support relationship attached to an intention. Membership, cheering, and being a buddy must never put an inactive character at the fire.

## What the comparators offer

| Comparator | Verified mechanism | Proposed adaptation |
| --- | --- | --- |
| [Friend Controls: Screen Time](https://apps.apple.com/us/app/friend-controls-screen-time/id6651826679) | People set app limits and ask friends to approve or deny additional time. | Give a friend an explicit role: “I’ll check in afterwards.” Preserve Counting Sheep’s independent emergency exit and protection rules. |
| [Focusmate](https://www.focusmate.com/how-it-works/) | Partners state goals before working and check in afterwards; its sessions use video. | Use the opening intention and closing reflection around existing Phone Away/Wind Down sessions. A person can join with a different task and duration. |
| [Finch Accountability Buddies](https://help.finchcare.com/hc/en-us/articles/37943772406413-Accountability-Buddies) | A person shares a goal with selected friends, who can follow progress, encourage, mute, or unfollow. | Make the shared goal and audience explicit; separate support from doing the same activity. |
| [Finch Good Vibes](https://help.finchcare.com/hc/en-us/articles/37780369483533-Sending-Good-Vibes) | Preset encouragement produces an in-app message and a character visit. | Offer one-tap encouragement attached to a particular session. Show it as a note or brief gesture, so it cannot be mistaken for active presence. |
| [HabitShare](https://habitshareapp.com/) | Custom habits, reminders, and per-friend visibility; habits start private. | Let users deliberately share a session’s intention without exposing their full private routine or task list. |

These are product mechanisms, not evidence that copying them will improve sleep or adherence. Detailed comparator layouts have not been audited in installed apps.

## X research worth retaining

Searches included Friend Controls/app/screen-time variants, Focusmate goals/accountability, SwiftUI Vortex, and Moving Parts Pow. Public web indexing was weak; direct X browser searches produced the following useful original posts. Results are a curated sample, not an exhaustive survey or a measure of demand.

- [Paul Hudson introducing Vortex, 18 January 2024](https://x.com/twostraws/status/1747928407672008876): original SwiftUI particle-library announcement, linked to its repository. [Video introduction post, 31 January 2024](https://x.com/twostraws/status/1752659543622905920). Useful for exploring subtle fire/ember motion.
- [Moving Parts open-sourcing Pow, 30 November 2023](https://x.com/movingpartsio/status/1729894249183727714): source ownership moved forward with Emerge Tools. [Change Effects demonstration post, 27 September 2022](https://x.com/movingpartsio/status/1574439463350067200) provides an interaction reference; use the current license rather than its earlier paid-product announcements.
- [Focusmate discussing community coworking, 21 October 2021](https://x.com/focusmate/status/1451116467206819845): useful direction for bringing an existing group into a shared ritual. The operational flow is corroborated by its current help pages above.
- [Focusmate morning-routine testimonial, 12 August 2021](https://x.com/focusmate/status/1425736910991933441): inspiration for a later morning ritual; this is a company-posted testimonial, not clinical evidence.

Friend Controls phrase searches returned mostly unrelated uses of the words. No useful original X post about that app was verified in this pass; its official site and App Store listing are the basis for that comparison. No messages, follows, likes, or reposts were sent.

## Concrete session flow

### 1. Before starting

Keep the existing duration and protection setup. Add a compact “At the campfire” section:

- Intention category, followed by an optional short public intention: “Read one chapter,” “Finish the essay outline,” or “Shower, then read.” Proposed limit: 80 characters.
- Sharing audience: selected Slumber Parties, with a preview of exactly what members will see. A private start remains available.
- An optional “Ask for a check-in” choice. Choose one party member to invite as a buddy, or allow one volunteer from the party. The request takes effect only when accepted; a pending request is labelled as such.
- “Let my party know when I start” preference, separate from publishing presence. Show this alongside the recipient preview. Remember the choice while keeping it accessible at each start.

Do not copy private task titles into a public field automatically. Existing category-only agreement remains valid for category-only sharing. New public text, support requests, and reflections need a new explicitly accepted sharing capability.

### 2. On admitted start

The local coordinator admits the session and applies its existing protection workflow. When the server accepts the shared start, add the person to Campfire and enqueue one start announcement for each eligible party recipient.

Example default notification: **“Tommy started Phone Away. Join the campfire when you’re ready.”**

Optional category preview: **“Tommy is starting a reading session for 30 minutes.”** Free-text intentions stay out of push payloads by default. Inside the app, the card can show the complete explicitly shared intention.

Opening the notification refreshes the current party before presenting the session. “Join” opens the recipient’s own session setup; it never silently starts a timer or applies protection. Joining is allowed with a different activity or duration. “Send encouragement” creates a scoped support note and does not create presence.

### 3. While sessions are active

Keep the wide shared meadow artwork. Use a compact scene above a readable list of active intentions, so the scenery does not push the accountability information below the fold.

Example card:

> Tommy · Phone Away  
> Read one chapter  
> Planned until 9:30 PM  
> Papa will check in afterwards  
> Join with my own goal · Send encouragement

Each active Shepherd has a distinct seat and a small activity symbol. Selecting a character selects the matching card. Essential text remains outside the art for Dynamic Type and VoiceOver. Static presentation supports Reduce Motion; backgrounded scenes stop animating. Empty state: **“No shared sessions right now. Start one when you’re ready.”** Failed/stale refresh: **“Live sessions couldn’t be refreshed.”** These must be different states.

Presence remains app-reported session status. Do not call a participant verified offline or asleep. Wind Down may span overnight, so use “Wind Down · planned until 7:00 AM,” without implying that a bedtime task continues all night. Ending, expiration, withdrawal, or membership loss removes the active seat. Offline early endings remain uncertain until synchronized or expired; do not fabricate an immediate departure.

### 4. On return

For Phone Away, offer an optional check-in on the return/receipt screen: **“How did your plan go?”** Choices: **Did it / Made progress / Changed plans**, with an optional brief shared note. Session completion and task completion remain separate facts. A person may skip; the party sees “No check-in shared,” without treating it as failure.

For Wind Down, put this invitation after the morning quiet period or when the person next returns. Do not send a bedtime notification asking them to report whether they slept.

The accepted buddy sees the shared result in a bounded session card and can respond with encouragement. One gentle “How did it go?” request is available after the agreed check-in time, subject to the recipient’s preferences. While a person is still in their quiet period, hold it for their return. No repeated automated chasing or general-purpose chat is needed for this first iteration.

## Notification policy — proposed defaults

All eligible opted-in party members should receive the start invitation; the named buddy does not replace the party audience. A record of the start can be available in the agreed party view even when push alerts are muted.

| Event | Audience and timing | Handling |
| --- | --- | --- |
| Newly accepted shared start | Other current, consenting party members with start alerts enabled | Once per source session and recipient; deduplicate overlapping party membership. Never notify the sender. |
| More people join shortly afterwards | Same eligible recipients | Coalesce near-simultaneous starts; proposed two-minute grouping window and ten-minute per-party push cooldown. Preserve each session in the in-app list. |
| Recipient is winding down, in Phone Away, or within chosen quiet hours | In-app record only | Suppress the immediate invitation; do not replay an obsolete invitation when quiet hours end. Respect OS notification preferences. |
| Buddy invitation accepted | Session owner | In-app acknowledgment; avoid interrupting their active session with an alert. |
| Encouragement arrives | Target participant | Save to the session for return; no active-session sound or repeated push. |
| Shared result / agreed buddy check-in | Opted-in buddy, after their quiet period | At most one relevant notification; refresh before showing actions. |
| Early end, cancellation, unavailable update | Current party presentation | No accusatory party-wide alert. Update known state; uncertainty remains explicit. |

Start alerts should expire quickly: proposed expiry is the earlier of five minutes after the start or planned end. Recheck membership, block state, consent and session validity before dispatch. Drop queued alerts on known end/withdrawal. A notification already accepted by APNs cannot be guaranteed retractable, so opening it must handle an ended or unavailable session gracefully. Delivery is best effort; server acceptance never means a person saw it. [Apple APNs registration](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns) and [request documentation](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns).

The timing numbers above are starting hypotheses for testing, not approved product requirements. Personal notification preferences and party sharing permissions are separate controls.

## Shop, Ollie, and the lantern

The core gathering and buddy actions stay free. The existing lantern keeps its earned shared-meadow role and current contribution rules; it does not determine whether a session exists. Explain it in the meadow rather than giving Lantern equal prominence with joining a live session.

First cosmetic opportunities: a personal seat blanket, a small intention-card frame, and a keepsake displayed beside that person's active seat. They can make purchases socially visible without making appearance an activity indicator. An equipped decoration should appear only at the owner's active seat, and disappear with that seat. Personal ownership and shared visibility are separate; placement never duplicates ownership.

Preserve the current distinction between Shepherd identity and personal Ollie. Adding everyone's Ollie to a busy campfire would need a separate density and motion design. Continue sharing the same equipped Ollie appearance across existing personal screens. An eventual campfire Ollie cameo would use that same appearance model, not a second social wardrobe.

## Repositories and reusable assets

| Resource | Verified license/platform | Appropriate use |
| --- | --- | --- |
| [Vortex](https://github.com/twostraws/Vortex) | [MIT](https://github.com/twostraws/Vortex/blob/main/LICENSE); [manifest](https://github.com/twostraws/Vortex/blob/main/Package.swift) declares Swift tools 5.9 and iOS 15+, with no external package dependencies | Quiet embers/fireflies around an active fire. Benchmark on a small iPhone and respect Reduce Motion. Manifest compatibility is not a tested integration. |
| [Pow](https://github.com/EmergeTools/Pow) | [MIT](https://github.com/EmergeTools/Pow/blob/main/LICENSE); [manifest](https://github.com/EmergeTools/Pow/blob/main/Package.swift) declares iOS 15+. It also declares SnapshotPreviews-iOS, despite its preview target dependency being disabled by default. | Small acknowledgment and arrival transitions. Review a pinned version and its resolved dependencies before adoption. |
| [Kenney Particle Pack](https://kenney.nl/assets/particle-pack) | Pack page specifies CC0, 80 two-dimensional particle assets | Possible source masks for sparks and glow; inspect and adapt selected files to the paper palette. No final asset selection or visual fit has been validated. |
| Existing native SwiftUI components and paper renderers | Already in this app | Recommended first implementation: intention cards, sheets, stable seats and subtle transitions can use existing components without a new UI framework. |

MIT notices must accompany reused code. Other apps' characters, screenshots, commercial art, and arbitrary X snippets are inspiration only unless reuse rights are established. Do not bring pixel-art or 3D furniture packs into the current collection simply because they are free. No package or external asset was installed in this research pass.

## Implementation sequence and acceptance

1. **Intentions and truthful live presentation.** Add explicit public task text under a new consent/capability version, audience preview, the compact scene plus cards, and join-with-own-session routing. Keep current stale-state and terminal-precedence protections.
2. **Party start notifications.** Add authenticated ordinary APNs device registration, account-bound token lifecycle, recipient settings, and an idempotent server outbox/dispatcher. Existing `PhoneNotificationService` schedules local reminders; `_shared/apns.ts` sends Live Activity updates. Neither is presently the complete party alert path. Production capability/signing configuration must be checked before implementation and distribution.
3. **Buddy commitments and follow-through.** Add revisioned invitations/acceptance, bounded encouragement, optional return check-ins, and quiet-time delivery rules. Proposed retention: remove free-text session intentions/reflections after seven days or earlier withdrawal, with no historical visibility for later joiners. Resolve exact retention and consent copy before exposing the capability.
4. **Cosmetic refinement.** Only after the interaction works across accounts: evaluate selected effects, personal seat décor and quieter paper-texture motion. Preserve existing reward calculations.

Acceptance must exercise two isolated accounts/devices: denied notifications, duplicate/retried starts, two parties with the same recipients, quiet hours and overnight spans, early end before dispatch, late APNs delivery, expired deep links, leave/block/rejoin, account switch/token reassignment, older clients, offline end/reconnect, and buddy invitations ending before acceptance. Revalidate eligibility for all session actions; notification payloads are not authorization.

Measure whether invitations lead to a voluntarily started session, whether intentions receive useful support, and whether people find return check-ins helpful. Track mute/disable rates as an interruption signal. Session overlap is an app-timer metric; do not report it as measured sleep, physical phone placement, or completed work.

Validation for this pass: direct X browser searches, primary app/help/repository/license review, and read-only inspection of current Campfire and notification code. This document and its backlog link are the only new local changes from the research pass. No app build, push notification delivery, dependency integration, backend deployment or physical-device validation was performed for the proposed additions.
