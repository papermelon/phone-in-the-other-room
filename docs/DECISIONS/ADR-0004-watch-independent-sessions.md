# ADR-0004: Watch-Independent Bedtime Sessions (Foqos-Inspired NFC/QR)

- Status: Accepted; NFC and optional sleep-bookend shielding implemented for App Store 1.0, distribution/physical QA pending
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

**Adopt the concept — not the codebase — for Counting Sheep 1.0:** a watch-independent
bedtime session where a tag or QR code placed in another room becomes the phone's "bed".

- At bedtime, the user carries the phone to the tag/code and taps/scans it: the walk *is*
  the ritual, preserving physical separation as the product (ADR-0001) rather than
  becoming pure software blocking.
- The tap starts the user-facing Wind Down ritual. In NFC mode, ending normally requires
  tapping the same registered tag again. A deliberately multi-step emergency exit remains
  available if the tag is lost or unreachable. The optional `ManagedSettingsStore` shield uses the user's
  consented selection during wind-down, clears overnight, and returns during the
  morning-quiet bookend. The saved morning end time clears it automatically.
- QR works on every iPhone with a camera and costs nothing; generic writable NDEF tags add
  the most tactile version of the same ritual.

### Gates for App Store distribution

1. **Family Controls distribution entitlement available for every target.** The 2026-07-30
   App Store export produced Apple Distribution profiles carrying Family Controls for the
   containing app, report, monitor, configuration, and action targets. App Store server
   validation and physical runtime proof remain pending.
2. **TestFlight build 1 uploaded.** Build 1 was uploaded and was still waiting for external
   beta review on 2026-07-30. It has not yet produced external-tester evidence.
3. **Anti-addiction review.** Implemented: consensual selection, bookends only, gentle
   shield copy, Counting Sheep remains unshielded, and a visible emergency exit always
   clears settings.
4. **Physical-device proof.** Pending: provision/replace/read generic NDEF tags; background
   and terminated-app window transitions; early end; schedule replacement; timezone/DST.

### Implemented first increment (2026-07-11)

Build 1 includes a non-blocking `.qrCode` session guard: the user can scan a QR code at
their phone's resting place, with a manual-code fallback for camera-unavailable devices.
The first successful scan registers that phone bed locally; future runs confirm it. It
does not shield apps, prevent an early end, or make any sleep claim. This increment is
deliberately usable without Family Controls approval because it is only a gentle ritual
signal.

The honor-timer fallback is phone-authoritative and the Watch/UWB path is a brief,
optional `.watchPlacement` check. Once a run starts, neither app needs to remain open.

### Implemented reporting foundation (2026-07-25)

The DeviceActivity report extension is embedded in the containing app, both targets carry
the approved Family Controls and App Group entitlements, and scoped selections are shared
through `group.com.ngawangchime.countingsheep`. Existing standard-default selections
migrate forward without replacing a selection already saved in the App Group.

This increment is read-only reporting infrastructure. It does not authorize or implement
ManagedSettings shielding, NFC, or an all-night block. Those remain subject to gates 2–3
and must apply only to the two quiet bookends with an emergency exit.

### Implemented App Store 1.0 increment (2026-07-30)

Release builds can provision and confirm a generic writable NDEF phone-bed tag. Only a
SHA-256 digest of the generated registration token is stored locally; legacy tag
fingerprints remain readable for migration. Scanning never silently enrols an unknown tag.
The same registered tag authenticates the normal early-end path; a mismatch or cancelled
scan leaves Wind Down running. The Watch cannot bypass this requirement.

Optional shielding reuses the consented bedtime selection. A `DeviceActivityMonitor`
derives both windows from the authoritative `NightWatchPlan`, a shield-configuration
extension supplies gentle copy, and a shield-action extension closes the shielded app.
The main app and extension append bounded apply/clear status evidence through the App Group,
allowing protected shield minutes to be distinguished from merely scheduled minutes.

### Architecture direction

Generalize the existing verification seam rather than bolting on a parallel system.
`DistanceProvider` already abstracts "how do we know the phone is away"; evolve it into
session-guard strategies consumed by `FocusSessionCoordinator`:

- `.watchPlacement` — one initial Watch/UWB placement check, then it stops
- `.nfcTag` / `.qrCode` — QR now confirms placement; later shield via ManagedSettings,
  with tap/scan-to-end
- `.nfcTag` — default registered phone-bed tag, required for the normal end action
- `.honorTimer` — explicit no-hardware, phone-authoritative timer fallback

Reuse `ScreenTimeAuthorizationService` and the bedtime scope in
`ScreenTimeSelectionService`. New capability needs: Core NFC (standard, no special
approval) and the Family Controls entitlement (approval required). An App Group becomes
necessary when the Screen Time report extension ships alongside.

The internal `NightWatch*` model remains one phone-authoritative run across all three phases. Shield scheduling
must derive from its `NightWatchPlan`; it must not create separate bedtime and morning
timers, shield overnight by default, or count the overnight interval as progress.

### Attribution

The 1.0 implementation was independently written against Apple framework contracts and the
existing Counting Sheep session coordinator. No literal or substantial Foqos source was
adapted, so its MIT notice is not required in the app bundle. This ADR keeps the conceptual
reference. If source is copied later, add Foqos's copyright and MIT text to `NOTICE`.

## Consequences and tradeoffs

- **Audience unlock:** anyone with an iPhone can adopt the ritual; roadshows/workshops can
  onboard whole rooms (QR posters, NFC swag), with staff absorbing the Screen Time
  permission friction in person.
- **Priority displacement:** this outranks Farm/Shop reintroduction (ADR-0003) — it grows
  who can use the app rather than deepening engagement for existing users.
- **Review risk:** blocking features draw App Review scrutiny and depend on Apple's
  entitlement approval and server validation — hence the explicit release gates.
- **Principle tension:** shields are coercion-adjacent. The anti-addiction constraints
  (consent, gentle copy, emergency exit) are part of this decision, not optional polish.
- **Scope discipline:** this is the sanctioned answer to "the Watch requirement is too
  narrow" — agents should cite this ADR instead of inventing other verification schemes.
