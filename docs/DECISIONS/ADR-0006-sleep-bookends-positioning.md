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

**Historical framing:** Counting Sheep once described one phase-aware Night Watch. ADR-0019
supersedes that release-facing framing with Wind Down plus a linked, independently settled
Screen-Free Morning; older `NightWatch*`/guard values remain compatibility internals.

1. The user configures an intended bedtime and wake time, a wind-down bookend, and a
   morning-quiet bookend. The default is 30 minutes on each side, with modest alternatives.
2. At the requested wind-down time, the user physically puts the phone in another room and
   begins Wind Down with required selected-app protection. ADR-0019 supersedes this ADR's
   interchangeable-guard clause: current release flows offer the shielding timer or optional
   NFC + app shielding; QR, Watch-placement, and raw honor-timer values are decode compatibility only.
3. Night Watch still has wind-down and overnight timing phases. ADR-0019 supersedes this ADR's
   "never independent" Morning clause: Screen-Free Morning is a linked but independently
   settled occurrence with its own factual minutes and Sunrise Trail ledger.
4. The user may choose one offline evening cue and one morning cue. These are suggestions,
   never verified tasks or conditions for ending the session.
5. Historical credit language in this ADR is superseded by ADR-0019: Wind Down compatibility
   reward/progress and shared Wind Down metrics use the factual wind-down bookend only.
   Screen-Free Morning actual minutes settle independently through Sunrise Trail. Overnight
   hours never inflate focus minutes, stars, rewards, or other progress.
6. This ADR's customer-facing “Night Watch” / “protected night” nomenclature is superseded by
   Wind Down, Screen-Free Morning, and Ollie's wording in ADR-0019. `FocusRun` remains an
   internal persisted type for backwards compatibility.
7. This ADR's future/gated shielding clause is superseded by ADR-0012 and ADR-0019: current
   release starts require Family Controls authorization and one opaque selected app/category
   set for app protection. Runtime failures fail open to repair after a valid start.
8. HealthKit remains optional context. Counting Sheep does not score sleep, diagnose a
   condition, or claim that a Night Watch caused better sleep.

## Consequences

- The one-sentence pitch becomes: “Put your phone to bed. Wake up before it does.”
- The existing phone-authoritative timer, restore path, session guards, Watch companion,
  notifications, and Live Activity remain useful. Any implication here that an independent
  Morning is out of scope or that a "protected night" is current release language is superseded
  by ADR-0019's Wind Down plus Screen-Free Morning model.
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
