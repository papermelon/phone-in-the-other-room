# ADR-0004: Watch-Independent Bedtime Sessions (Foqos-Inspired NFC/QR)

- Status: Accepted (direction); implementation gated
- Date: 2026-07-07
- Deciders: Founder
- Related: ADR-0001 (positioning), ADR-0003 (which this outranks), `docs/PROJECT_BRIEF.md`

## Context

The core loop verifies phone separation with Apple Watch + Nearby Interaction, which
requires a UWB iPhone (11+) *and* a UWB-capable Watch, worn during the run. That is a
narrow funnel — most workshop and roadshow attendees won't qualify, and the founder plans
in-person and virtual onboarding sessions where broad participation matters.

[Foqos](https://github.com/awaseem/foqos) (MIT license, ~578 stars, shipping on the App
Store) demonstrates the alternative pattern: app-blocking sessions started/stopped by
tapping an NFC tag or scanning a QR code, built on `FamilyControls` + `ManagedSettings`
(shields) + Core NFC, with strategies (manual / NFC / QR / timer, optional
physical-unblock) organized behind a `StrategyManager`.

This repo already has half the required scaffolding: `ScreenTimeAuthorizationService`
(FamilyControls auth) and `ScreenTimeSelectionService` (persists a **bedtime**
`FamilyActivitySelection`).

## Decision

**Adopt the concept — not the codebase — as Counting Sheep's top post-build-1 product
bet:** a watch-independent bedtime session where a tag or QR code placed in another room
becomes the phone's "bed".

- At bedtime, the user carries the phone to the tag/code and taps/scans it: the walk *is*
  the ritual, preserving physical separation as the product (ADR-0001) rather than
  becoming pure software blocking.
- The tap starts the session and applies a `ManagedSettingsStore` shield to the user's
  bedtime app selection; morning tap-out (or gentle timer expiry) clears it.
- **QR first, NFC second.** QR works on every iPhone with a camera and costs nothing
  (printable); NFC tags (<$1) become the branded workshop takeaway ("tuck your phone in").

### Gates (all must pass before implementation)

1. **Family Controls distribution entitlement approved by Apple.** (Request submitted
   early — it gates TestFlight distribution of any blocking feature. Long lead time.)
2. **TestFlight build 1 shipped and stable** (same Gate 0 as ADR-0003).
3. Design passes the anti-addiction review: consensual block list, gentle shield copy,
   always-available emergency exit, no shame on early unlock.

### Architecture direction

Generalize the existing verification seam rather than bolting on a parallel system.
`DistanceProvider` already abstracts "how do we know the phone is away"; evolve it into
session-guard strategies consumed by `ProximitySessionCoordinator`:

- `.watchProximity` — today's Watch/UWB loop (unchanged)
- `.nfcTag` / `.qrCode` — tap/scan-to-start, shield via ManagedSettings, tap/scan-to-end
- `.honorTimer` — no-hardware fallback (extends the existing `NoDistanceFallbackProvider` path)

Reuse `ScreenTimeAuthorizationService` and the bedtime scope in
`ScreenTimeSelectionService`. New capability needs: Core NFC (standard, no special
approval) and the Family Controls entitlement (approval required). An App Group becomes
necessary when the Screen Time report extension ships alongside.

### Attribution

If any Foqos code is adapted (vs. concept-only reimplementation), credit it in a NOTICE
file per its MIT license. Prefer studying `Foqos/Models/Strategies/` +
`Utils/StrategyManager.swift` as reference and writing our own.

## Consequences and tradeoffs

- **Audience unlock:** anyone with an iPhone can adopt the ritual; roadshows/workshops can
  onboard whole rooms (QR posters, NFC swag), with staff absorbing the Screen Time
  permission friction in person.
- **Priority displacement:** this outranks Farm/Shop reintroduction (ADR-0003) — it grows
  who can use the app rather than deepening engagement for existing users.
- **Review risk:** blocking features draw App Review scrutiny and depend on Apple's
  entitlement approval timeline — hence hard-gated, and never in build 1.
- **Principle tension:** shields are coercion-adjacent. The anti-addiction constraints
  (consent, gentle copy, emergency exit) are part of this decision, not optional polish.
- **Scope discipline:** this is the sanctioned answer to "the Watch requirement is too
  narrow" — agents should cite this ADR instead of inventing other verification schemes.
