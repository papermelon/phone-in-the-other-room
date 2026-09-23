# Campfire seating, navigation and interaction discoverability

Founder authorized local implementation following the screenshot review on 19 September.
This extends the [bedtime implementation](campfire-bedtime-2026-09-19.md).

## Implemented contract

- Home/Farm open an independent Campfire sheet. The private group links to that same
  destination with its party selected; browsing Global no longer sits under a private
  party title. The existing four tabs remain. The group retains its persistent meadow,
  membership and check-ins. The Campfire sheet has one running-session return control;
  the group uses the existing shell return bar.
- The original scene placed eight seats around a central fire. Its ellipse layout is superseded by the [20 September readable-plan and organic-seating refinement](campfire-readable-plans-and-organic-seating-2026-09-20.md). Awake Shepherds use a reusable seated
  pose in the shared Canvas art, retaining customized head, hair, skin and clothing.
  Bedtime still derives from the frozen session boundary and uses the sleeping bag.
- Hold and drag rearranges seats locally, snapping to the closest seat and exchanging
  occupants when occupied. People retain seats as others arrive/depart or change pose.
  Reset seats restores the initial arrangement. The existing Farm gesture/accessibility
  component is reused with a larger accessible movement step. Reduce Motion remains
  respected. Positions live only in the open view, scoped by audience/account; closing
  the view resets them. No publication, persistence schema or heartbeat was added.
- Existing private Buddies metadata now supplies a small scene indicator and explicit
  “Buddy welcome” / “Buddy paired” row cues; shared intentions appear in the rows.
  Tapping still opens the existing card's join, encourage and check-in actions. No
  private text is added to Global, and no rewards change.
- The missing Global endpoint, disabled capability, network failure, authentication
  failure and unsupported response have distinct presentation paths. Missing/disabled
  Global is labelled unavailable and cannot be newly selected for publication. Explicit
  availability checks remain; automatic state retries stop for unavailable/auth/version
  failures. A successful empty gathering remains a distinct, valid state. Existing
  durable command replay semantics are unchanged.

## Release observation and remaining gates

A read-only GET to the configured release `campfire-global` endpoint returned HTTP 404,
`NOT_FOUND`, “Requested function was not found” during the preceding review. Private
party APIs are separate. The seating change itself did not deploy Global. Subsequent explicit
founder authorization led to [production deployment and activation on 20 September](../evidence/global-campfire-deploy-20260920/deployment.md).

Themed interest/cause gatherings, mutual connections and recurring circles remain later
product slices. No new consent layer, public profile fields or connection backend was
introduced here. Existing public disclosure and selected private agreements still apply.

[Local validation and screenshots](../../output/design/campfire-seating-20260919/README.md)
record actual checks. Physical-device follow-up: tap versus hold/drag while scrolling,
accessible seat moves with VoiceOver, Reduce Motion, all eight seats on the smallest
phone, party → Campfire → Global → Done/return routing, account switches, and offline
visibility changes. Prior bedtime/offline/two-account acceptance gates still apply.
