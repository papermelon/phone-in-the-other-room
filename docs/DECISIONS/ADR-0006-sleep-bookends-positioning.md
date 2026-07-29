# ADR-0006: Protect the Edges of Sleep with One Night Watch

- Status: Accepted
- Date: 2026-07-18
- Decider: Founder
- Supersedes in part: ADR-0001's bedtime-only boundary
- Related: ADR-0003, ADR-0004, `docs/PROJECT_BRIEF.md`, `docs/PRODUCT_PRINCIPLES.md`

## Context

The bedtime-only product already had a strong physical-separation ritual, but its primary
surface still looked like a configurable focus timer. The founder chose to make sleep and
screen time more explicit and to protect both the last part of the evening and the first part
of the morning. Broad screen-time apps already offer arbitrary schedules, app groups, strict
modes, and productivity sessions; copying that breadth would erase Counting Sheep's niche.

The morning addition also creates a scope risk. If implemented as a separate timer, routine
builder, or productivity mode, it would contradict the restraint established in ADR-0001.

## Decision

**Counting Sheep protects the edges of sleep with one phase-aware Night Watch.**

1. The user configures an intended bedtime and wake time, a wind-down bookend, and a
   morning-quiet bookend. The default is 30 minutes on each side, with modest alternatives.
2. At the requested wind-down time, the user physically puts the phone in another room and
   begins Night Watch. QR, Watch placement, and honor-based starts remain interchangeable
   session guards.
3. Night Watch has three phases: wind-down, overnight, and morning quiet. The morning is the
   continuation of the same night, never an independent focus mode.
4. The user may choose one offline evening cue and one morning cue. These are suggestions,
   never verified tasks or conditions for ending the session.
5. Completion and economy credit only actual quiet minutes in the two bookends. Overnight
   hours must never inflate focus minutes, stars, rewards, or other progress.
6. Customer-facing language uses “Night Watch,” “protected night,” and “quiet bookend
   minutes.” `FocusRun` remains an internal persisted type for backwards compatibility.
7. Screen Time reports and consensual app shielding should eventually use one selected set
   of distracting apps across both bookend windows. That work remains gated by ADR-0004 and
   the Family Controls distribution entitlement.
8. HealthKit remains optional context. Counting Sheep does not score sleep, diagnose a
   condition, or claim that a Night Watch caused better sleep.

## Consequences

- The one-sentence pitch becomes: “Put your phone to bed. Wake up before it does.”
- The existing phone-authoritative timer, restore path, session guards, Watch companion,
  notifications, and Live Activity remain useful.
- The setup UI changes from duration selection to a saved schedule and two quiet bookends.
- A requested wind-down reminder is appropriate; generic re-engagement notifications are not.
- Product analytics should prioritize completed protected nights and screen time in the two
  windows rather than daily opens, total session length, or all-day focus minutes.
- Independent morning timers, habit checklists, productivity templates, and broad daily app
  blocking remain out of scope.

## Revisit criteria

Revisit only if TestFlight evidence shows that users understand the bedtime ritual but find
the morning continuation confusing or routinely end it for essential access. In that case,
shorten or make the morning bookend optional before broadening into another product category.
