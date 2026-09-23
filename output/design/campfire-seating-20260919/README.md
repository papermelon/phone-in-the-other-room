# Campfire seating/navigation — local evidence, 19 September 2026

Implements the [approved refinement](../../../docs/plans/campfire-seating-navigation-2026-09-19.md)
on top of the existing uncommitted bedtime changes. No hosted deployment/activation,
signing changes, distribution, commit or push occurred.

## Validation

- Full app build passed: `xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator'`.
  [Build log](build.log) reflects final UI refinements.
- Full Swift unit suite passed: **1,078 tests, zero failures**.
  `xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=A0DB65B8-F3FC-4961-8B0C-9689F51C9EA1' -resultBundlePath /private/tmp/campfire-seating-tests-20260919.xcresult`.
  [Test log](tests.log). New checks cover seating stability across membership changes,
  occupied-seat swaps, bounds/invalid coordinates, missing service versus authentication/
  connection failures, and buddy request/paired cues. Subsequent changes were view-only
  layout/copy and task ownership; the full build was rerun after them.
- XcodeGen regenerated membership for the extracted scene. Project.yml, signing,
  entitlements, dependencies and tab structure are unchanged.
- `git diff --check` passed. Existing SDK/AppIntents/deprecation warnings remain.
  The prior bedtime SQL/Edge checks remain applicable; this refinement changes no backend
  migration or Edge contract.

## Visual inspection

[Capture script](capture-native.py) uses the existing isolated DEBUG fixture, with no
account/network events, on the iPhone SE Simulator. Screenshots cover eight/mixed seats,
private buddy cues and intentions, largest text, unavailable Global, connection failure
and a successfully empty Global gathering. Inspection found and repaired narrow-column
word wrapping and an oversized decorative buddy icon at accessibility text sizes.

- [Eight seats](eight-dark.png)
- [Mixed awake/sleeping](mixed-light.png)
- [Party scene](buddy-party.png) and [participant actions/intentions](buddy-actions.png)
- [Largest text](buddy-large-text.png)
- [Global unavailable](global-unavailable.png), [connection failure](global-connection.png),
  [empty gathering](global-empty.png)

Seats snap around the fire and exchange occupied positions locally. They last while
that scene is open, are isolated by audience/account, and never publish movement.

## Review and remaining gates

Local code review: **approve with device-validation follow-ups**, risk **M** (shared
rendering/gesture component, navigation and availability presentation). Existing Farm
hit targets keep their default accessible movement step; Campfire opts into the larger
step. Session eligibility, admissions, outboxes, ownership guards and rewards are preserved.

Native computer-use could not reliably target the review Simulator window, so no successful
touch-drag or spoken VoiceOver interaction is claimed. The shared gesture implementation
and pure seat transitions were inspected/tested. Physical tap-versus-drag/scroll, VoiceOver,
Reduce Motion and navigation-return checks remain in the linked contract/backlog. Global
still requires its separately authorized deployment and activation. Themed cause/interest
gatherings and mutual connections remain later slices, not implemented features.
