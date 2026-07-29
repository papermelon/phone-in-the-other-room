# ADR-0004: Watch-Independent Bedtime Sessions (Foqos-Inspired NFC/QR)

- Status: Accepted; QR shipped, NFC/shielding development preview implemented, Release still gated
- Date: 2026-07-07
- Deciders: Founder
- Related: ADR-0001, ADR-0003 (which this outranks), ADR-0006 (sleep bookends), `docs/PROJECT_BRIEF.md`

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

This repo already has part of the required scaffolding: `ScreenTimeAuthorizationService`
(FamilyControls auth) and `ScreenTimeSelectionService` (persists scoped
`FamilyActivitySelection` values). ADR-0006 has since made the two quiet bookends—not an
all-night shield—the intended Screen Time boundary.

## Decision

**Adopt the concept — not the codebase — as Counting Sheep's top post-build-1 product
bet:** a watch-independent bedtime session where a tag or QR code placed in another room
becomes the phone's "bed".

- At bedtime, the user carries the phone to the tag/code and taps/scans it: the walk *is*
  the ritual, preserving physical separation as the product (ADR-0001) rather than
  becoming pure software blocking.
- The tap starts Night Watch. A future `ManagedSettingsStore` shield may use the user's
  consented selection during wind-down, clear overnight, and optionally return during the
  morning-quiet bookend. The saved morning end time clears it automatically.
- **QR first, NFC second.** QR works on every iPhone with a camera and costs nothing
  (printable); NFC tags (<$1) become the branded workshop takeaway ("tuck your phone in").

### Gates for blocking (all must pass before implementation)

1. **Family Controls distribution entitlement approved by Apple.** Completed for the
   containing app and Screen Time report extension on 2026-07-25.
2. **TestFlight build 1 shipped and stable** (same Gate 0 as ADR-0003).
3. Design passes the anti-addiction review: consensual block list, gentle shield copy,
   always-available emergency exit, no shame on early unlock.

### Implemented first increment (2026-07-11)

Build 1 includes a non-blocking `.qrCode` session guard: the user can scan a QR code at
their phone's resting place, with a manual-code fallback for camera-unavailable devices.
The first successful scan registers that phone bed locally; future runs confirm it. It
does not shield apps, prevent an early end, or make any sleep claim. This increment is
deliberately usable without Family Controls approval because it is only a gentle ritual
signal.

The default `.honorTimer` is now phone-authoritative and the Watch/UWB path is a brief,
optional `.watchPlacement` check. Once a run starts, neither app needs to remain open.

### Implemented reporting foundation (2026-07-25)

The DeviceActivity report extension is embedded in the containing app, both targets carry
the approved Family Controls and App Group entitlements, and scoped selections are shared
through `group.com.ngawangchime.countingsheep`. Existing standard-default selections
migrate forward without replacing a selection already saved in the App Group.

This increment is read-only reporting infrastructure. It does not authorize or implement
ManagedSettings shielding, NFC, or an all-night block. Those remain subject to gates 2–3
and must apply only to the two quiet bookends with an emergency exit.

### Implemented development preview (2026-07-27)

Debug builds can register and confirm an NDEF phone-bed tag and can opt into shielding the
existing consented bedtime selection. The policy shields only wind-down and morning quiet,
clears settings overnight, and clears on completion, early end, reset, and replacement.
The NFC and shielding controls remain absent from Release until gate 2 is met.

This foreground coordinator integration is intentionally not described as reliable
background scheduling. Shipping phase-accurate shielding while the app is suspended or
terminated requires a `DeviceActivityMonitor` extension, its own explicit App ID and
Family Controls distribution assignment, and physical-device validation.

### Architecture direction

Generalize the existing verification seam rather than bolting on a parallel system.
`DistanceProvider` already abstracts "how do we know the phone is away"; evolve it into
session-guard strategies consumed by `FocusSessionCoordinator`:

- `.watchPlacement` — one initial Watch/UWB placement check, then it stops
- `.nfcTag` / `.qrCode` — QR now confirms placement; later shield via ManagedSettings,
  with tap/scan-to-end
- `.honorTimer` — no-hardware, phone-authoritative timer

Reuse `ScreenTimeAuthorizationService` and the bedtime scope in
`ScreenTimeSelectionService`. New capability needs: Core NFC (standard, no special
approval) and the Family Controls entitlement (approval required). An App Group becomes
necessary when the Screen Time report extension ships alongside.

Night Watch remains one phone-authoritative run across all three phases. Shield scheduling
must derive from its `NightWatchPlan`; it must not create separate bedtime and morning
timers, shield overnight by default, or count the overnight interval as progress.

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
