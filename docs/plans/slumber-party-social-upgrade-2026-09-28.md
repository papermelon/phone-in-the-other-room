# Slumber Party, invitations, inbox, and meaningful cheers

28 September 2026 plan · Implementation updated 29 September 2026

**Status:** The founder authorized implementation, expanded research-informed cheers, Associated Domains, and production backend deployment after validation. The source upgrade and two backend migrations are implemented; the backend is deployed. The native app is not distributed. Website theme 3.4.1 is installed on staging; page checks remain blocked by a saved browser permission, and live website publication is pending. See [validation and rollout evidence](../evidence/social-upgrade-20260929/validation.md).

This consolidates the current conversation about handles, adding people, friends versus groups, missing invitations/cheers, notifications, and sent/received feedback. It carries forward the relevant work from the [21 September invitation repair](slumber-party-repair-2026-09-21.md), [Shared Farm and contextual cheers](slumber-party-shared-farm-and-cheers.md), and [20 September social exploration](campfire-connections-and-rest-exploration-2026-09-20.md). It is the implementation brief for these topics. Other exploratory themes, causes, and general connections remain separate.

## 1. Recommended product direction

Make the entire loop understandable: **find someone → invite them into a specific party → review and join → exchange meaningful encouragement → find it again.**

- **Slumber Party** is an ongoing private group. Two people are a valid party. Seven-night rounds organize shared progress inside the group; the relationship does not expire with a round.
- **Campfire** shows current shared sessions, with private-party and Global scopes. Browsing, group membership, and sending encouragement do not create presence.
- **Buddy** means a voluntary commitment to a particular session's check-in. A supportive message does not make its sender a buddy.
- **Inbox** is one account-owned destination for incoming invitations and encouragement. It is reachable from Home and relevant party screens, within the existing four tabs.
- **Cheers** becomes the familiar umbrella for short, explicit messages of support. Actual buttons say what will be sent. Retire the three decorative labels from new sends on the upgraded service.

A separate Friends layer is deferred. It becomes useful when a person needs to keep a connection after meeting someone at Global Campfire without joining the same party. If introduced, friendship and party membership must remain separate mutual decisions; neither silently grants private history or session visibility. Calling today's party invitation an “Add friend” action would misrepresent its effect.

Keep the existing Home, Nights, Farm, Settings structure; shared meadow, Farm ownership, wool and search rules; session coordinator; visibility choices; privacy agreements; and emergency exit. These upgrades do not add social rewards, chat, an unrestricted people directory, or a new mandatory step before Wind Down.

## 2. What the research actually supports

Research performed on 28 September: inspected Mobbin screen/flow previews for Finch, Strava, Duolingo, X, Discord, Retro, and Lapse; consulted first-party product documentation and two primary research papers. Mobbin captures establish patterns visible in those captures, not the latest behavior of every installed app. Observational research from Facebook is useful context, not evidence that any particular phrase will improve sleep or retention in Counting Sheep.

| Reference inspected | Observation | Application here |
| --- | --- | --- |
| [Finch gesture picker](https://mobbin.com/screens/a9e089a3-94dc-4fcb-bfc9-d6a871044ab3) and [received message](https://mobbin.com/screens/3831e0f3-a0d5-47ec-977e-2b4e82775609) | Recognizable social gestures have labels; the receiving screen identifies the sender and presents a message. | Give each choice an intelligible meaning and make the received result feel addressed to a person. Avoid copying its large catalog or mandatory full-screen celebration. |
| [Finch's Good Vibes documentation](https://help.finchcare.com/hc/en-us/articles/37780369483533-Sending-Good-Vibes) | Preset gestures can be sent to an existing friend and arrive in-app with a character visit. | A small prescribed vocabulary can convey support without adding free-text chat. Counting Sheep must keep any gesture distinct from live Campfire presence. |
| [Strava activity recognition](https://mobbin.com/screens/106bee68-c61f-48f0-b7fd-5b4625874ec0), [activity detail](https://mobbin.com/screens/5e952589-967e-47e3-9f2e-fda0727a6728), and [official Kudos explanation](https://support.strava.com/en-us/articles/15402054-what-is-kudos) | Recognition stays attached to a specific activity; selected state and participants are inspectable. | Preserve the original session/update, show a stable sent state, and let recipients inspect permitted senders. Avoid making large popularity counts the focal point. |
| [Duolingo message preview](https://mobbin.com/screens/fc7db71d-d814-476e-9997-bd704c81c773), [milestone acknowledgement](https://mobbin.com/screens/5933bbc6-72c6-45b3-8be7-ecb6ea680f41), and [Friends Quests explanation](https://blog.duolingo.com/friends-quests/) | Support can be contextual, with the intended message visible before an explicit send. | Match wording to what was actually shared. Preserve sender authorship; do not secretly select or send a different message, or introduce automatic chasing. |
| [X invitation flow](https://mobbin.com/flows/a79a44c8-deb6-4b58-a77f-62ff6d01b26d) | Group entry and a search-result row put name, handle, and invitation action close together. | Keep the destination party visible and invite from the matching row. |
| [Discord username entry](https://mobbin.com/screens/18d103f8-a927-4838-ae1f-4c8f2752f928) | The screen explains the requested identifier and also shows the user's own username. | Make the account handle easy to find and share; use party-specific action wording rather than copying its friend-request semantics. |
| [Retro activity inbox](https://mobbin.com/screens/bab2c258-9b2d-446a-bb82-b9a28703a759) and [Lapse activity inbox](https://mobbin.com/screens/d8f55727-0ec6-444a-aa3f-60210f9e3302) | Relationship events and reactions share a chronological destination with actor and object context. | One Inbox with Invitations and Cheers filters, clear response actions, and exact destinations. Keep unrelated suggestions and promotional content out. |
| [Scissors, Burke, Wengrovitz, CSCW 2016](https://thoughtcrumbs.com/publications/scissors_burke_wengrovitz_whats_in_a_like.pdf) | Their Facebook study found respondents generally cared more about who provided lightweight feedback than its volume; interpretations varied. | Lead private receipt rows with the sender and meaning. Treat exact wording and perceived warmth as hypotheses to test. |
| [Burke and Kraut, JCMC 2016](https://onlinelibrary.wiley.com/doi/10.1111/jcc4.12162) | Targeted composed communication from strong ties was associated with improved well-being; one-click interactions were not associated with those changes in their analysis. | Do not promise that a preset button substitutes for meaningful conversation or produces a health benefit. Evaluate clarity and felt support directly. |
| [Apple notification permission guidance](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications) and [notification design guidance](https://developer.apple.com/design/human-interface-guidelines/notifications/) | Permission is best requested in context; previews should communicate purpose without exposing excessive detail. | Offer explicit social notification choices when their use is clear. Keep previews generic and the inbox usable with permission denied. |

**Synthesis:** familiar meaning, a known sender, specific context, and dependable receipt matter more than inventing three branded objects. The strongest approach for this product combines a small vocabulary with context-sensitive defaults, rather than a universal Like or a large sticker picker.

## 3. Confirmed current gaps

| Area | Inspected behavior | Consequence |
| --- | --- | --- |
| Lookup | Exact account handle or UUID, scoped to an existing party member; no general friendship graph. | It should be presented as an invitation to a named party, with handles foregrounded. |
| Entry | Invite people lives in Group details. The incoming inbox follows party cards/acquisition controls. | Senders and first-time recipients can miss the central action. |
| Request feedback | Search, refresh, and invitation writes share `partyConnectionsBusy` and one error. | Unrelated operations interfere; generic failures can obscure the remedy. |
| Notifications | Addressed membership invitations have no APNs event path. Existing Campfire alerts require party membership/session context. | A nonmember cannot receive a membership invitation through that event contract. |
| Update cheers | Three labels become Pending / Accepted / Try again; receipts foreground transport explanations. | The selected gesture loses its identity and Accepted sounds interpersonal. |
| Receiving | Party update receipts, private Campfire encouragement, Global counts, and transient live feedback are separate presentations. | There is no dependable place to revisit all incoming support. |
| Freshness | Home uses the original update's `occurredAt`, with a 48-hour window. Received update order also follows update time. | A newly received cheer on an older update may be invisible on Home or buried. |
| Global history | The public state response exposes an encouragement count for the recipient's latest session. | Earlier received encouragement is not a browsable recipient history. |
| Compatibility | Swift's `NightFlockV4Cheer` and existing SQL checks enumerate `warmWave`, `moonGlow`, `pawPrint`. | Blindly adding raw values can break older clients; relabelling old values would rewrite past meaning. |
| Routing | AppRootView's inspected URL handler handles Quiet Note; notification routing currently stores a party target. | Exact invitation/update/session links require routing work. Universal links are not established by the inspected configuration. |

Source anchors: [invitations UI](../../PhoneInTheOtherRoomApp/Views/NightFlock/SlumberPartyInvitationsView.swift), [request state](../../PhoneInTheOtherRoomApp/ViewModels/NightFlockViewModel+Invitations.swift), [invitation SQL](../../supabase/migrations/20260921120000_slumber_party_invitations.sql), [cheer controls](../../PhoneInTheOtherRoomApp/Views/NightFlock/SlumberPartyV4MembershipActivitiesSection.swift), [named receipts](../../PhoneInTheOtherRoomApp/Views/NightFlock/SlumberPartyUpdateCheerReceiptsView.swift), [Home selection](../../Shared/SlumberPartyHomePresentation.swift), [Campfire alerts](../../supabase/migrations/20260913150000_campfire_alert_delivery.sql), [Global projection](../../supabase/migrations/20260920120000_campfire_profiles.sql), and [current reaction enum](../../Shared/NightFlockV4Models.swift).

Deployment records previously established portions of invitations and Campfire push infrastructure. This planning pass did not inspect current hosted migrations, send real messages, or prove physical delivery. Current source and historical rollout records are not interchangeable.

## 4. Replace decorative cheers with explicit messages

The founder requested a broader range than the original three suggestions. The implemented vocabulary keeps three clear intentions and offers only phrases suited to the current shared source:

| Meaning | Available phrases | Appropriate context |
| --- | --- | --- |
| Encouragement | **Rooting for you**, **You’ve got this**, **Cheering you on** | Active Phone Away and non-celebratory updates. Encouragement stays available alongside recognition and bedtime wishes. |
| Recognition | **Nice work**, **High five**, **Lovely progress** | App-recorded completion or explicitly shared Did it / Made progress check-in. |
| Bedtime wish | **Rest well**, **Good night**, **Wishing you a peaceful evening** | Currently shared Wind Down; wishes do not claim sleep. |

Use a familiar small symbol as a secondary cue, with readable text always present. Keep the existing art style and customized Shepherd identity. A fist-bump or open-hand support mark, small applause mark, and moon can work; the text carries meaning so users never have to decode an illustration. Exact artwork is part of the prototype, not a new asset commission in this plan.

Show one primary message according to context and a “Choose a cheer” picker with three to five permitted choices. An active Wind Down offers the three bedtime wishes plus Rooting for you and Cheering you on; a completed update offers three recognition phrases plus those two encouragements. This supersedes the initial one-alternative recommendation. Never show a message without a permitted shared source just to fill three buttons. Early ending is not automatically an achievement, failure, or a request for consolation. Unknown/missing data yields no invented story.

The primary button itself displays the message, so a tap can send directly. If the user opens the alternative picker, it previews the exact text and target before Send. Do not add a mandatory picker for every interaction. Do not auto-send when opening a card or changing a selection.

These phrases are product hypotheses, not experimentally proven winners. [Finch’s Good Vibes guidance](https://help.finchcare.com/hc/en-us/articles/37780369483533-Sending-Good-Vibes) supports familiar, explicitly named caring gestures. [Reeve and Jang’s autonomy-support study](https://selfdeterminationtheory.org/SDT/documents/2006_ReeveJang_JEP.pdf) supports avoiding controlling pressure; applying that educational evidence to a sleep-adjacent social app is a design inference, not direct validation. The earlier Mobbin and social-feedback studies below inform source context, readable labels, and sender identity. Test comprehension, warmth and fit with actual users, including regional English speakers:


| Candidate comparison | Recommendation and reason to test |
| --- | --- |
| Rooting for you / You've got this | Start with Rooting for you: communicates the sender's support without asserting an outcome. Check that users understand the phrase naturally, including regional English speakers. |
| Nice work / High five | Start with Nice work: explicit recognition. Test whether High five feels warmer and equally clear without becoming too playful for the audience. |
| Rest well / Good night | Start with Rest well: directly expresses a wish. Test whether Good night feels more natural between partners and friends. |

Do not lead with “I'm with you”: it can imply an active shared session or a buddy commitment. “Proud of you” may fit close relationships but assumes intimacy for Global participants. “Keep going” is a poor default for bedtime. “Thanks” can be evaluated later as a response, but this release does not need a recursive reply/notification loop.

### Sender and recipient behavior

| State | Visible presentation | Evidence requirement |
| --- | --- | --- |
| Available | `Rooting for you` | Server-advertised message and eligible source |
| In flight | `Rooting for you · Sending…` | Send started; no success claim |
| Durably queued | `Rooting for you · Waiting to send` | Account-bound intent persisted for retry |
| Confirmed | `Rooting for you · Sent ✓` | Server acknowledgement or matching canonical server record |
| Unconfirmed failure | `Couldn’t confirm your cheer · Retry` | Preserve original command identity on retry |
| Source no longer eligible | `This shared session is no longer available` | Stop replay; do not move the message to another session |

Keep message identity visible in the selected state. Eliminate empty counters and repeating transport paragraphs. Do not expose a new Seen label. Existing recipient-app acknowledgements may remain as internal/recovery evidence; they do not show that a person read a message.

Private received row: sender identity, exact phrase, original activity context, party name, and time the cheer arrived. Example:

```text
[Moss's Shepherd]  Moss: “Nice work.”                 New
                  Your Wind Down yesterday · Night Owls
                  8 minutes ago                  View update
```

Global received row: retain aggregate sender presentation initially, using permitted message categories: `3 people are rooting for you` plus the exact public-session context. Do not infer permission to expose senders' private account identities. Legacy generic encouragement remains generically worded.

One active new-message choice per sender, recipient, and scoped source is the proposed starting rule. Duplicate taps/retries reuse it. Choosing a second phrase after sending does not create another notification. Provide an explicit Remove action in the message detail if someone sent by mistake; preserve a tombstone to fence replay and do not send a “removed” alert. A message or OS notification may already have been received. Replacement/resend within the same source is outside the first slice. Legacy records with multiple gesture types remain readable.

## 5. Handles, creation, and invitation journeys

**Profile and own identity.** Put `@handle`, Copy, and Share alongside the account identity already in Profile. Reuse the existing username claim flow when missing. A handle identifies an account; requests bind to the immutable verified UUID so later renaming cannot retarget them. Keep raw UUID lookup in an advanced compatibility path.

**Party entry.** Home's Slumber Party card opens the existing party destination. Put an Invite button beside the party name and member count. For an empty account, show incoming invitations first, then Start a party. Explain once: `A private group for you and people you know. Your party stays together between rounds.` Do not lead with database-like capacity and lifecycle wording; show limits when relevant.

**Create.** Name party → inspect compact sharing summary with expandable full terms → Create & agree → confirmed membership → Invite to [party]. Creation success and receipt-backed sharing confirmation remain distinct. An uncertain create response reconciles by its durable command identity before retry; it must not create a second party after process death.

**Invite sheet.** Show destination party throughout. Use exact handle search with an explicit keyboard Search action, clear control, and deliberate paste support. Normalize surrounding whitespace, case, and optional @ through the existing validator. Explain invalid input locally. Do not issue partial-directory queries or perform unsolicited clipboard reads. A broad prefix/name directory is a separate discoverability proposal, not a search polish task.

Matched row contains name and @handle, with Invite / Invited / In party states. Use a neutral identity mark unless the lookup contract explicitly permits a public appearance; do not expose private Farm/outfit/history merely because an account was found. Keep the confirmed result visible after send. Pending invitations list names, expiry, and Cancel where authorized.

**Recipient.** Inbox → invitation preview with inviter and handle where permitted, party name, current member count/capacity, and the actual capability-aware sharing summary → Join & agree or Decline. A membership list of other people is not exposed before joining unless its existing contract already permits it. Verify current invitation state on open and again when accepting.

After joining, navigate to the exact party. If membership succeeds but the agreement confirmation or refresh fails, show the truthful existing recovery state; never report either success as proof of the other. Sender sees Joined after server-confirmed membership. Decline/cancel/expiry receive quiet terminal UI; never send rejection pressure to the recipient.

Handle search needs distinct states: invalid input, no match, searching, found, already invited, already member, offline, rate-limited with retry timing when known, expired session requiring account repair, and unavailable service. Blocked/deleted/unknown accounts must not produce distinctions that expose private relationship state. A rate limit is not a connection failure.

### Shareable invitations

Keep code exchange working throughout. Add a native share sheet containing a revocable invitation link once the link route is ready. The link should reuse the existing invite credential lifecycle rather than embed an account UUID as a bearer credential.

- Addressed invitation notifications open the specific recipient-bound invitation. Forwarding that route does not grant another account acceptance rights.
- Shareable party links are intentionally bearer invitations. Preserve host revocation, expiry, capacity, block checks, preview, and affirmative agreement.
- Opening a link never accepts, enables sharing, or starts a session automatically.
- Signed-out recipients can sign in and resume a pending route. Resolve the route with the current account; never carry a previous account's private preview across a switch.
- Logged-out web fallback gives safe app/open/install instructions without disclosing private party details. After installation, reopening the link or entering its code must work; do not promise automatic deferred deep linking through the App Store.
- Universal links require a controlled HTTPS domain, AASA hosting and an Associated Domains entitlement. These are a separate capability/configuration and deployment step requiring founder authorization under AGENTS.md. [Apple's associated-domain requirements](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.associated-domains)

## 6. One dependable Inbox

Home exposes a labeled Inbox button with the count of new items. The Slumber Party card can also show `2 invitations` or a compact recent cheer entry that opens the same destination. No fifth tab is required.

The Inbox has All / Invitations / Cheers filters. Pending invitations requiring a decision stay in their own leading section; received support is chronological underneath. Within each party, show a compact For you section filtered from the same server-authorized results. Empty state remains accessible, explaining that invitations and received cheers appear here.

Inbox invariants:

- Order cheers by server acceptance/arrival time, never the original update time. Preserve original context time as a separate label.
- Pending invitation count and new/unseen item count are distinct. Reading an invitation can clear New while leaving its Join/Decline action pending.
- Mark only items actually presented, or explicitly opened via a notification, as no longer new. Do not clear the whole account's inbox on launching the app. Dismissing an OS notification is not an inbox read.
- Persist account-owned read state across devices with idempotent writes. It remains private and does not become a sender-visible read receipt.
- A later cheer on a previously opened update creates new recipient information without making all old cheers new again.
- Group multiple cheers for one source without losing their distinct phrases or permitted senders. A mixed group must not say every sender chose the first message. Count unique people accurately when one person appears in legacy records more than once.
- The original source opens directly. If it expired or access was withdrawn, show a neutral unavailable destination and reconcile the count. Do not silently substitute the latest update.
- Preserve the current audience of every source. An inbox is a view over authorized data, not permission to retain revoked private content.
- Retention proposal: recipient projections for up to 30 days, bounded by the underlying source's shorter retention. Current Global records are pruned sooner; initially respect that window rather than secretly retaining public-session content for 30 days. Invitations keep their existing seven-day validity and existing cleanup rules until an explicit retention migration is approved.
- A contextual Sent detail is available on the original source. A full outbound message feed is unnecessary for the first release.

Refresh on account activation/foreground, entry, explicit pull-to-refresh, and relevant authorized realtime invalidations. Coalesce overlapping reads, retain loaded content and scroll position, and back off failures. Respect the 25 September removal of Campfire polling; do not restore a per-screen timer loop. Home needs a small summary, not a fan-out fetch of every party's complete history.

## 7. Notification policy

Introduce explicit account-level Invitations and Cheers preferences. Existing permission for routine reminders or per-party starts does not silently opt a person into these new categories. Keep existing per-party session/buddy preferences. In-app receipts remain available when push is off or denied.

| Event | In-app result | Optional push policy |
| --- | --- | --- |
| Membership invitation received | Pending invitation immediately | One alert per new invitation; defer through known quiet periods until eligible or expired |
| Invitation accepted | Member list and inviter acknowledgement | Initial default is in-app only; an optional inviter confirmation can be evaluated later |
| Declined, revoked, expired | Quiet state reconciliation | No push |
| Private cheer received | Original-context receipt in Inbox | Batch nearby events; defer while quiet; notification opens the relevant entry/group |
| Global encouragement received | Aggregate receipt for the correct public session | Separate optional Global inclusion, off initially; batch as a digest when enabled |
| Campfire start | Existing current-session behavior | Preserve short expiry and drop stale starts rather than replaying them in the morning |
| Buddy request/result | Existing consented follow-through | Preserve its own eligibility, deferral, and expiry rules |

Proposed first-rollout tuning: two-minute batching for cheers, at most one cheer push per recipient per hour and three per local day; after a quiet window, coalesce waiting cheers into one alert. Expire undelivered cheer alerts after 24 hours while eligible inbox records remain. These are explicit starting defaults to evaluate, not requirements derived from the research. Membership invitations remain distinct from cheer quotas and are additionally protected by recipient abuse limits.

Lock Screen copy stays generic: `You have a Slumber Party invitation` or `You received encouragement`. Names, group names, intentions and activity details appear only after authenticated access. Do not label any of these Time Sensitive or Critical. No badge inflation for automatic system encouragement.

Reuse the existing scheduled quiet hours and synchronized active-session quiet interval, including morning quiet, with current time zone/DST handling. If several devices have active quiet state, honor the relevant existing account-wide suppression. Newly changed offline state cannot instantly reach the server; OS Focus, background delivery, and sync delays remain practical limitations. Do not claim guaranteed interruption prevention or delivery from a queued/APNs-accepted event. [APNs delivery behavior](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns)

Ask permission when someone deliberately selects Notify me about invitations/cheers. If iOS already granted permission, save only the explicitly chosen category. If denied, retain the Inbox and offer a Settings route; avoid repeated prompts. Source implementation is not evidence that a signed TestFlight build receives pushes.

## 8. Backend and compatibility design

**Reuse:** verified immutable account IDs, existing party/membership/agreement tables, invitation RPC security, current durable outboxes, block rules, device registration, APNs sender, leasing/retry patterns, and existing realtime invalidations. Keep session starts/settlement independent of social networking.

**Add only the missing contracts:**

| Contract | Minimum responsibility |
| --- | --- |
| Invitation state extension | Bounded/paginated incoming and authorized outgoing state, accurate counts and terminal outcomes, independent read/write request feedback |
| Versioned support messages | Stable semantic ID (`rootingForYou`, `niceWork`, `restWell`), catalog version, sender, derived recipient, scope and original source, accepted time, command identity and withdrawal state |
| Social inbox projection | Merge authorized invitation events, legacy receipts, new support messages, and eligible Campfire encouragement; return stable event IDs, target routes, timestamps, counts, cursor and capabilities |
| Private inbox read state | Recipient-only markers for specific delivered items/groups, separate from existing app receipt evidence |
| Social notification events | Recipient/event/source references, category, due/expiry, dedup key, retry/lease state and delivery diagnostics |
| Account social preferences | Explicit notification categories, relevant Global inclusion, and reuse of device/time-zone/quiet state |

Avoid copying Farm documents or shared history into a second social feed. Prefer a bounded server projection over current records. If an inbox event index is needed for efficient ordering/read state, retain opaque source references and minimal metadata; render identity/context through current authorization. Retention and revocation apply to projections, caches and notification events as well as the source.

### Trust and transactional behavior

- Derive caller identity from authentication; never accept client-supplied authoritative sender/recipient/permission flags. Resolve target to its owner and current permissible scope server-side.
- Keep exact lookup indexed and rate-limited. Preserve per-sender limits and decline cooldown; add recipient aggregate and sender-recipient limits so rotating party IDs cannot spam one account. Return bounded pages. Do not expose raw private tables to clients.
- Acceptance rechecks addressed recipient, invitation status/expiry, inviter's current membership, blocks, party existence, member capacity and recipient's party cap inside the transaction. Retain duplicate-accept success for the same resulting membership.
- Persist send/accept/create command identity through ambiguous responses and process death using existing account-scoped storage patterns. Cancellation/revocation and stale retries must resolve to canonical state, never a newly targeted request.
- Validate message/source compatibility server-side, using shared data rather than private routines or inferred sleep. Freeze the chosen phrase and context at accepted send; do not later change it when a timer finishes. Expired queued live sends fail honestly rather than attaching to a new live session.
- Write the message/invitation and notification event atomically. Retries must not enqueue another event. A notification cannot exist without its underlying successful action.
- A recipient-bound invitation is eligible before membership; do not reuse Campfire's requirement that both parties already have membership epochs. Reuse transport helpers, with event-specific eligibility and expiry.
- Before dispatch, revalidate preferences, source existence, block/membership/consent conditions and quiet state. Invalidate queued events after revoke/withdraw/delete. Existing OS-delivered previews cannot be retroactively guaranteed erased.
- Server-sourced IDs fence duplicate projections of the same legacy round/membership update. Do not deduplicate by rounded minutes or similar text. Keep different parties' consent scopes distinct; batching can reduce alerts without merging their private data.
- Preserve device-owner/revision fences during token rotation, sign-out and account switching. A delayed old-account response cannot populate the new account's inbox or navigate into its private party.

### Meaningful-message migration

Do not reinterpret historical Warm wave as Rooting for you, Moon glow as Rest well, or Paw print as Nice work. Those messages were not what people chose. Existing records keep their legacy identity; the new inbox may use a generic `sent you a cheer` headline with the original gesture in detail.

Introduce an additive advertised support-message capability and a separate optional message projection/command contract. New semantic values must not be inserted into a legacy reaction array decoded by the closed Swift enum. Use a focused new record lane if the old schema's checks make in-place evolution unsafe; this is preferable to replacing the full existing social system.

The upgraded client must tolerate unknown future semantic IDs and show a generic message rather than reject the entire party/inbox. Older clients keep their legacy projections. An old server must not make the new client promise a phrase it cannot store: retain the accurately labelled legacy fallback or show that expressive messages require the updated service. Deploy support before promoting the new composer.

Update both sides of Watch messages safely: preserve the current legacy feedback field and use an optional additive versioned message value for new support. Test older Watch/phone combinations. New messages must not be translated into a different legacy gesture merely to get a transient display. Absence of compatible transient feedback does not remove the durable inbox receipt.

New notifications deep-link by opaque event/target identifiers. Persist deferred navigation bound to the verified account. Freshly authorize the target before revealing details. Opening a cheer or invitation never changes Global visibility, joins a party, starts a run, or ends protection.

## 9. Implementation map and ordered delivery

Keep focused files near current owners, split large view bodies instead of growing the existing oversized party detail. Use Theme.swift/PixelComponents tokens and the current Sheep loading/error patterns. New pure rules belong in Shared and new side effects in Services. No new dependency is needed.

| Slice | Main existing surfaces/contracts | Deliverable and gate |
| --- | --- | --- |
| **0. Native prototype and copy validation** | Theme, current invitation/member/receipt views; existing fixture approach | Approved group/inbox hierarchy, three message defaults, sent/received states, large-text variants; no live social writes |
| **1. Visible invitation loop** | SlumberPartyHomeSection, SlumberPartyV4ListView, GroupDetailsView, SlumberPartyInvitationsView, +Invitations, NightFlockService, SlumberPartyInvitations | Home invitation entry, Invite on party, own-handle access, accurate matching/error states, scoped request state and durable ambiguous-action recovery |
| **2. Inbox and receipt foundations** | Existing invitation/receipt SQL; SlumberPartySharedFarm, SlumberPartyHomePresentation, ReceivedCheersSection, +UpdateCheers, CampfirePanel | Bounded authorized inbox/summary, original-source routing, arrival ordering, read state and usable offline/empty states |
| **3. Meaningful support messages** | Versioned shared models; membership activities/member cards; CampfirePersonViews/BuddyViews; outboxes; SQL/Edge validation; WatchMessage and Watch consumers | Context-aware explicit messages on private and Global surfaces, stable send feedback, retention/withdrawal rules, legacy and mixed-client compatibility |
| **4. Social push delivery** | CampfireNotificationService, +CampfireNotifications, PhoneNotificationService, APNs helper and leased dispatcher | Account opt-ins, invitation/cheer event handlers, batching/quiet rules, typed routing; signed two-device receipt evidence |
| **5. Shareable link acquisition** | Existing encrypted/recoverable invitations, AppRootView/Home routing, project.yml/entitlements only after approval, controlled link domain | Universal links, safe fallback, resume after sign-in, revocation/expiry and install/reopen proof |
| **Later, evidence-triggered** | Existing public person sheet and separate relationship model if needed | Mutual Friends only after users demonstrate a need to retain connections outside parties; new moderation/privacy contract before launch |

Slices 1–3 form the first cohesive product upgrade: visible invitations and a dependable place to receive clearly worded support. Slice 4 completes notification discovery. Slice 5 removes typing friction for people outside the app. Do not describe the whole upgrade as complete after only changing labels.

For each backend-bearing slice: additive migration and server validators first, compatibility tests, capability advertisement only when usable, client build, then explicitly authorized hosted activation/distribution and physical acceptance. Preserve unrelated migrations. Capability rollback disables new writes while keeping accepted messages and the old app readable; never roll back by deleting user records.

Before implementation, translate selected defaults into their owning product/capability decision documents. The exact domain/entitlement and production deployment need their normal explicit authorization. Routine source edits and local verification, once implementation is requested, do not need repeated approval.

## 10. Design review and acceptance

Prototype with five representative participants: at least one existing pair, someone who has not used Slumber Party, and a large-text user. This small study is for comprehension problems, not statistically proven behavior change. Include partner/friend and Global-stranger contexts so overly intimate wording is detected.

Tasks: find/share your handle; invite a known person; locate an invitation without coaching; explain what joining shares; send support to a live session and a completed update; identify exactly what was sent; find a newly received cheer on an older update; explain Sent versus Seen; disable push while retaining inbox access.

Proposed success criteria: at least four of five find the invitation and received cheer unprompted within 15 seconds from Home; at least four of five correctly paraphrase every proposed message; no participant believes a cheer proves sleep, live presence or a buddy commitment; no participant interprets Sent as read. Revise and retest failures. Compare against the existing UI when feasible; record qualitative objections, not just speed.

Representative native states: no handle, no parties, pending invitations, invalid/no-match search, multiple parties, full party, five-party cap, declined/revoked/expired invitation, partial join confirmation, denied push permission, queued/failed send, mixed message types, Global anonymous aggregate, old server, old Watch, inaccessible/expired source, offline relaunch, large Dynamic Type, VoiceOver and Reduce Motion. Keep touch targets at least 44 points, reading order deliberate, status expressed in text, and animation decorative and optional.

### Engineering acceptance matrix

| Area | Required checks |
| --- | --- |
| Identity/search | @/case/space normalization, claim collisions, rename after lookup, invalid IDs, no email/name enumeration, verified-account requirement, blocked/unknown indistinguishability, sender and recipient limits |
| Invitations | Duplicate send/accept, accept-versus-revoke race, sender leaves, party deleted, expiry, final-seat concurrency, five-party cap, decline cooldown, recipient mismatch, join response lost, restart recovery and agreement retry |
| Message meaning | Server rejects incompatible phrase/source; exact selected phrase survives transitions, retry and relaunch; no early-end completion inference; no shifted target; withdrawal fences old replay |
| Compatibility | New client/old server, old client/new server, unknown future IDs, legacy history unchanged, round/membership aliases, old Watch/new phone and inverse |
| Inbox | New cheer on a >48-hour-old visible update, fresh cheer after an earlier read, mixed phrases grouped correctly, unique-person counts, pagination ties, realtime duplicate, no historic unread flood, denied push, account A/sign-out/B/A, removed source and privacy withdrawal |
| Delivery | Atomic action/event creation, duplicate retry, APNs acceptance then worker crash, expired lease, revoked token, two devices, offline logout, expired deep link, source blocked/deleted before dispatch, generic preview |
| Quiet periods | Midnight crossing, time-zone/DST change, active overnight plus morning quiet, stale/offline quiet sync, several quiet devices, delayed invite versus stale start, batched morning release and quotas |
| Core ritual | Social read/write/notification failure never blocks session admission or ending, alters protection, creates Campfire presence, grants wool or imports another account's data |

Use isolated test accounts and devices. Never reset the founder's Farm. TestFlight requires production APNs. Record actual receipt on both physical devices, then open from terminated/background/foreground states. A green simulator suite and a healthy dispatcher do not prove these outcomes.

Follow AGENTS.md validation once per relevant source state: meaningful unit tests for pure rules and migrations/replay, isolated SQL/Edge tests, affected-target builds, full local app build/unit gate, and native UI inspection. Regenerate through XcodeGen only for source membership or project.yml changes. Documentation-only work needs link/consistency/whitespace checks, not an app build.

## 11. Evaluation and scope control

Primary outcomes are whether people find requests, understand the relationship they accepted, know what they sent, and can recover received support. Record protocol health using existing operational diagnostics: bounded request latency, rejection classes, queue age, retries, token rejection, and confirmed canonical outcomes. Do not log handles, invitation credentials, private intentions, or raw notification tokens in general diagnostics.

A later product measurement decision may authorize aggregate invitation acceptance, time to first party interaction, inbox discovery and optional cheer usage. Do not add a new behavioral tracking system as a side effect of this plan. More pushes, longer bedtime app sessions, or higher cheer counts are not success measures by themselves.

Recommended boundaries for the first implementation: three meaningful messages with contextual defaults; one Inbox; exact lookup and shareable invitations; existing small private groups; optional respectful push. Defer free-text messages, arbitrary emoji, paid stickers, reply chains, activity leaderboards, contact uploads, a public account directory, and general Friends until a concrete need warrants their additional contracts.

## 12. Decision and work record

- Recommended: group-first model; Home Inbox; contextual Rooting for you / Nice work / Rest well; exact message retained through send/receive; no sender-visible read receipt; account opt-in notifications with quiet-time batching.
- Validate with the prototype: final wording, the alternative-message affordance, and proposed notification quotas. Research does not settle those product choices.
- Separately authorize at the appropriate stage: implementation; any new associated-domain capability/domain hosting; production migration/Edge activation; distribution. No such action occurred during this research.
- Completed in this planning pass: source/contract inspection, primary-source and Mobbin research, concrete implementation/compatibility/rollout plan, backlog handoff, documentation validation. No app tests or device delivery checks are claimed.
