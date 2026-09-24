# Campfire: readable plans and a natural gathering

20 September 2026. Research and implementation planning requested by the founder after
reviewing the Campfire polish screenshots. The founder subsequently authorized both native slices. **Local source implemented;
build and 1,106-test suite passed; native checks recorded below.** Deployment and physical-device acceptance remain separate.

[Implementation evidence](../../output/design/campfire-readable-20260920/README.md).

## Selected direction

Readable shared-plan bubbles and irregular, stable seating are implemented together. The pass also simplifies
the existing person sheets so the shared plan and useful actions precede the longer profile.
Keep the current scenery, customized Shepherds, eight-person channel capacity, local seat
moves, consent boundaries and loading continuity.

The visual goal is a loosely gathered campsite where I can understand a person's shared
plan at a glance and open its complete wording in one tap. Spatial proximity is decorative;
it must not imply friendship, a paired buddy, or a shared task.

## Research actually examined

Mobbin searches covered illustrated character dialogue, shared-focus participants, task-based
encouragement, person sheets and a friend-encouragement flow. Screens were inspected visually;
these are composition references, not evidence of animation timing or product effectiveness.
No competitor artwork is needed in the app. Canonical links below remain the reference record;
no expiring image URLs are embedded.

| Reference | Visible evidence | Adaptation for Counting Sheep | Limit |
| --- | --- | --- | --- |
| [Finch: character dialogue](https://mobbin.com/screens/6bcfac13-2500-4f7e-a76b-e1e7919613c4) | A full-width multiline bubble sits apart from the character, above response choices. | Separate readable text layout from sprite dimensions; give a selected person's full plan room. | This is one character. It does not establish that eight full messages fit at once. |
| [Finch: named character message](https://mobbin.com/screens/786e6c7f-409e-4ca7-989b-df1d4829eda9) | A speaker label is attached to a multiline message; one main action sits below the illustration. | Clear association between person and plan; one primary action after reading. | Do not copy its modal interruption into routine Campfire browsing. |
| [Numo: stated commitments](https://mobbin.com/screens/3b5dbd53-7071-4539-9f78-5c9570680636) | A named person and explicit tasks appear next to a like affordance. The screenshot is onboarding and shows checked tasks. | Lead with what the person chose to share, followed by encouragement. | No inferred task completion or popularity counters; the image is not evidence of a live community flow. |
| [Finch: sending back Good Vibes](https://mobbin.com/flows/fb1e4bd1-b9f9-4eca-ba02-3f6e65987658) | Inspected previews 1, 3 and 5: friend tree, named recipient/message/action choice, return to the tree with sent feedback. | Preserve place context; acknowledge an encouragement concisely after sending. | Intermediate screens were not inspected. Keep Counting Sheep's existing actions; do not add a gift catalogue. |
| [Duolingo: friends quest action](https://mobbin.com/screens/db515e34-0a3a-4369-93ba-d2224676d4cf) and [acknowledged action](https://mobbin.com/screens/30e202bf-259b-4d41-83de-4adebaaa892a) | A shared goal has adjacent actions; a later screen visibly says the friend was high-fived. | Put the action beside its human context and show its resulting state. | These are separate screenshots, not proof of a transition. Do not adopt competition, countdown pressure or paid boosts. |

Other returned screens were weaker fits: the Forest result was a solo timer with room entry;
the TIDE result showed aggregate company rather than individual plans; generic profile menus
did not address readable activity. They do not justify this design. No inspected reference
solved eight readable bubbles in an organic scene; the spatial recommendation below is our
own design proposal and requires native validation.

## Confirmed implementation constraints

- `CampfireSceneView.swift` puts the bubble, sprite and name in a 100-point-wide stack.
  The bubble has `lineLimit(1)` and caps scene typography at Large. The truncation in the
  screenshot is therefore expected from the current code, not a transient rendering issue.
- `CampfireSeating.point(for:)` calculates eight equally spaced angles on an ellipse.
  `reconcile` already preserves assigned slots across membership changes. Dragging snaps
  to a seat, swaps occupants, and stays local to the open view.
- Awake people all use the same seated three-quarter art. `ShepherdStudyCanvas` already
  supports facing left; a local presentation override can reuse it without changing the
  saved Shepherd. Bedtime pose remains derived from the existing frozen session boundary.
- Private bubbles use an accepted buddy intention, otherwise the session title. Global
  bubbles consume `participant.thought`. The local profiles SQL projects the first task,
  otherwise the first routine; `CampfireProfileSnapshot.thought` mirrors that choice.
  Neither field means the person is doing that task at this instant.
- Global participant rows currently omit `thought`, and the public person sheet does not
  lead with it. A profile fetch can eventually reveal the full tasks, but that is a weaker
  path than showing the already received plan immediately.
- The public sheet places the full profile, including Farm content, before its start and
  encouragement actions. Private sheets already lead with the Buddy card; preserve that
  useful structure and avoid adding another duplicate card.
- Profile display strings can be long (up to 2,048 characters under the current contract).
  A scene cannot promise to show every full message simultaneously. Preserve source text;
  use deliberate disclosure rather than arbitrary clipping or generated summaries.

## Two feasible directions

| Direction | Treatment | Tradeoff |
| --- | --- | --- |
| **A — readable cues around a loose campsite (recommended)** | Every person retains a short bubble; readable full short plans wrap, long plans use activity plus “View plan”. One tap opens the existing sheet with the complete shared wording first. | Preserves the founder's visible-bubble direction and direct profile navigation. Requires dense-layout checks. |
| B — names/activity cues in the scene, one selected plan panel | Selecting a person shows a larger full plan panel below the scene; a further action opens their profile. | Gives long text more room but adds a step and hides most intentions until selection. Reserve it only if native density checks invalidate A. |

A was selected for the authorized implementation. Do not add a second selection/navigation state
machine just to fit more text.

## Slice 1: bubbles, placement and full-text access

### Bubble contract

1. Reuse the currently authorized text. Trim empty/whitespace-only values for display and
   fall back to the known session/activity title. Do not pull extra private task data.
2. Decouple bubble width from the 58-point Shepherd and the name label. Use the available
   scene width and safe gutters to choose a bounded width; keep type legible instead of
   shrinking it to fit. Prototype two-to-three-line bubbles at the smallest supported width.
3. If the complete text fits that allocation, show it verbatim (apart from display whitespace).
   If it does not, show the known short activity plus **View plan**. No clipped fragments such
   as “Read before b…”, no automatic paraphrasing and no fabricated present-tense activity.
4. Tap either the bubble or Shepherd to open the existing person sheet. Put the complete
   available shared text near the top under **Shared plan**, before asynchronous profile
   content. The disclosure label describes intent, not live observation or task completion.
5. Include the same full text in **People here** for Global as well as private participants.
   Combine name, shared plan and action into a coherent VoiceOver element; avoid announcing
   the decorative duplicate bubble separately. Keep actions at least 44 points.
6. For accessibility text sizes, make the full-text list easy to reach and expand it by
   default on entry. The scene remains optional spatial context; complete plan text in the
   sheet/list must scale normally. Do not solve accessibility by shrinking or clipping text.

### Seating and orientation contract

- Replace the ellipse formula with eight deliberately composed, asymmetric seat anchors.
  Vary radius and depth with open space near the fire. Use stable slot-to-facing choices,
  primarily inward three-quarter faces with some variation. Keep names and bubbles upright.
- Reuse `CampfireSeating` slot ownership, reconciliation, nearest-seat swap and Reset seats.
  No per-refresh random numbers, physics, wandering, database coordinates or new dependency.
  Closing the view may reset positions, as today; persistence is a separate feature.
- Keep pose authority unchanged: awake stays awake; the supported bedtime boundary controls
  the sleeping bag. Do not invent a reading/working pose from a general profile task.
- Bubble anchors may use a small ordered set of above/side placements. Reserve measured
  space for the status notice, sprites, names, fire and hit targets. Prefer safe anchors
  over a general collision engine. Validate in points at each supported width, not only
  normalized distances.
- At eight people on a narrow phone, allow more scene height before reducing readability.
  Reserve that capacity consistently across loading/refresh/empty for the same width and
  text category; membership changes must not shuffle incumbents or repeatedly resize the page.
  If a plan still cannot fit, use the explicit View plan fallback. Pixel coordinates and
  final height are native-prototype outputs, not invented constants frozen by this plan.
- During dragging, avoid animating other people's text into new places. A drop resolves to
  a safe seat and its bubble anchor; accessible seat moves use the same rules.

### Immediate full-text and state behavior

| State | Scene | Person sheet / accessible list |
| --- | --- | --- |
| Current short plan | Full wrapped plan associated with its Shepherd | Same complete wording; existing actions |
| Current long plan | Known activity + View plan | Full wording, scrollable, before extended profile |
| Missing/blank thought | Session/activity title | No fabricated plan; ordinary session information |
| Current snapshot refreshing | Preserve people, anchors and text while still authorized/fresh | Preserve existing freshness checks |
| Expired, withdrawn, blocked or account-invalid | Remove the person using existing authority rules | No retained plan through a new cache or selection object |
| Profile fetch pending/failed | Existing activity/plan remains sufficient to identify the person | Local profile loading/retry below the plan, not a replacement for the whole sheet |

### Implementation map

| File / area | Change |
| --- | --- |
| `Shared/Campfire.swift` | Replace ellipse with composed anchors; retain the existing seat model. Add only the small pure presentation rules actually needed. |
| `CampfireSceneView.swift` | Independent text sizing/placement, readable fallback, hit-target association and stable depth ordering. Keep the existing scenery and fire. |
| `CampfireShepherdView.swift` | Optional local facing for Campfire, default unchanged for other callers. Reuse existing Canvas capabilities. |
| `CampfirePanel.swift` | Supply full existing plan to Global rows; accessibility-size disclosure behavior. No new audience or routing. |
| `CampfirePersonViews.swift` | Show existing Global thought at the top; avoid duplicating the private Buddy intention. Preserve join, block and report paths. |
| `Design/Theme.swift` | Centralize only the final scene/bubble dimensions validated by the prototype. |
| `CampfireBuddiesNativeFixture.swift`, existing previews | Add density, text and state fixtures using isolated defaults and no real network. |
| `Tests/CampfireTests.swift` | Update geometry expectations; retain stability/swap/invalid-coordinate tests. Add bounded text/fallback checks only where pure rules are introduced. |

Search every `CampfireSeating.point`, `CampfireShepherdView` and scene caller before editing.
The current seat test asserts a distance greater than 0.3 from the centre; that encodes the
old ring. Replace that assumption with useful invariants: safe bounds, distinct anchors,
reserved fire space and stable identity. Native screenshot inspection must cover actual
bubble rectangles; a normalized point-distance test cannot establish readable layout.

No SQL/Edge, sharing agreement, persistence schema or deployment change is needed for this
slice. The local full-profile revision has separate rollout evidence: verify current status
before release. Legacy/unsupported profiles must still render useful activity fallbacks.

## Slice 2: person sheets and Slumber Party actions

After Slice 1's scene is readable, reorder rather than rebuild the detail flow:

1. Person/name and permitted audience; shared plan/current session information.
2. Existing useful actions: start my own session when eligible, encouragement, and private
   buddy/check-in actions only where already supported. Hide duplicate headings and empty
   decorative sections; keep a clear path back to the running session.
3. Extended tasks/routines, history and Farm remain available through deliberate disclosures.
   Preserve the full-profile product direction rather than deleting these approved features.
4. Keep block/report discoverable in the public sheet. Use pending, sent and retry wording
   backed by the existing command/receipt state. Sent never becomes Seen; offline never
   silently becomes success. Inspect the actual action state before editing those labels.
5. Apply the same hierarchy to private member cards and old shared updates after tracing
   their separate permissions and receipts. A past update must not look like current presence.

This slice requires a focused follow-up trace of member/update/cheer views and outbox state;
those paths were not fully audited in this research. Do not treat the broader historical
redesign prompt as authorization to add themes, connections, chat or notification flows.

## Sequence and acceptance gates

| Order | Work | Exit evidence |
| --- | --- | --- |
| 1 | Native layout prototype using existing fixture and real Shepherd art | 1, 2, 4 and 8 people; short/long plans; narrow phone; compare composed positions and bubble readability before finalizing geometry |
| 2 | Implement Slice 1 as one coherent change | Full app build/unit suite; state/freshness tests; native snapshots and tap/seat actions; no cut-off ordinary plans |
| 3 | Live-network and two-device acceptance for Campfire | Slow read, retry, expiry, background return, gathering/channel/account switches, block/withdrawal; correct people and text disappear together |
| 4 | Implement Slice 2 against the actual action/receipt state | Intention and useful action visible before Farm/history; pending/sent/retry, private/public and active/ended verified |
| 5 | Resume wider visual work | Home primary action and first-start continuity, Nights recent-night hierarchy, then Farm control density; give each a separate brief |

These are ordered work packages, not calendar promises. Do not start broad Home/Farm changes
or new social backend features in the bubble/seating slice. Physical checks can proceed
alongside detail design, but remain a release gate rather than a reason to claim completion.

Native fixture acceptance includes: short “Read a chapter”; two-part “Shower, then read before
bed”; a very long plan; whitespace-only/missing text; long names; emoji/combining characters;
CJK and right-to-left text; 0/1/2/4/8 occupants; light/dark; ordinary and maximum Dynamic Type;
Reduce Motion; fresh/refreshing/stale/failed; own/other participants; awake/bedtime; scrolling,
bubble tap, profile tap, hold/drag, seat swap and reset. At eight occupants there must be no
bubble/name/hit-target collision, cropped text or obstruction of the refresh notice/fire.
VoiceOver must expose complete permitted text and the same profile/seat actions.

Run the repository's build and full unit gate after source work; add a regression check for
any changed pure rule. Planning-only work needs link/consistency/whitespace checks, not an app
build. Use disposable fixtures/accounts for validation and record physical evidence separately.

## Related records

- [Completed continuity/motion pass](campfire-polish-2026-09-20.md)
- [Current character/profile contract](campfire-profiles-2026-09-20.md)
- [Current seat/navigation behavior](campfire-seating-navigation-2026-09-19.md)
- [Broader social exploration](campfire-connections-and-rest-exploration-2026-09-20.md)
- [Current native polish evidence](../../output/design/campfire-polish-20260920/README.md)


## Implementation notes

The native scene uses eight composed anchors, an 800-point base canvas, and extra header
clearance that scales with Dynamic Type. The fire sits in the upper part of the clearing,
with seats staggered above and below it. This deliberately uses more vertical space than the
previous 520-point ring to preserve readable bubbles and separate tap targets. Bubble shapes
hug their text inside a reserved layout area; native `ViewThatFits` chooses the complete text
or the activity plus View plan fallback. The list and existing sheet expose the full text.

Local facing uses the existing Shepherd Canvas `faceLeft` support and never changes saved
appearance. Seat reconciliation, swaps and reset remain the existing implementation.

Public sheets now show the available shared plan before start/encouragement actions. Private
sheets keep their Buddy card, omit its duplicated person name and label the shared plan.
Both put an explicit Profile & Farm disclosure after the actions; profile loading starts
when expanded. Extended Farm and history sections have their own disclosures. Public safety
actions remain available under Safety options, with their existing confirmation dialogs.
Queued encouragement uses Waiting to send and an existing retry path; only the server-backed
participant state displays Encouragement sent. No new delivery or sharing mechanism exists.

The broader Slumber Party member/update timeline and theme/connection exploration are not part
of this two-slice implementation. Backend profile capability and device rollout remain governed
by the separate profile contract. Read the linked evidence for actual validation results.
