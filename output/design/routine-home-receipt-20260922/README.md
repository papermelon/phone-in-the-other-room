# Routine, Home, and receipt validation — 22 September 2026

## Commands

- `xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/slumber-repair-derived -disableAutomaticPackageResolution`: passed during initial goal/receipt implementation; `/tmp/routine-receipt-build.log`.
- `xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=71CF8F3E-9E9A-449D-93A8-B73F64869A5E' -derivedDataPath /tmp/slumber-repair-derived -disableAutomaticPackageResolution`: builds the full app and targets, then runs the unit suite. Initial Home/ideas revision: 1,112 tests, zero failures (`/tmp/routine-receipt-tests.log`). Final-source result is recorded in validation.txt.
- `git diff --check`: passed.

## Native checks

Used the isolated Counting Sheep Account Search iPhone 16 Pro QA Simulator (iOS 26.5), fixture data and native Simulator controls; no production account mutation.

- Goal picker: first tap shows complete sheet; Not now dismisses; reopening shows complete sheet; select Wind Down → Making room to unwind → Save goal. My routine displays the goal and Review my activity. See goal-saved.png.
- Home: final native screenshot home-intent.png shows Ollie, 30 min before bed / Your planned Wind Down, and the whole-routine Start Wind Down action. Your evening / Your day / Together and separate before-bed/morning plan values are present in the accessibility tree. Tapping the Phone Away card opens Phone Away schedule, with Start now and one-time/repeating planning controls.
- Contextual ideas: Home routine card → Explore evening ideas → Make the room feel ready → Add to this draft. A full routine presents replacement choices. Replacing the third item confirms it is still a draft. Back → Save ideas → Save plan returns to Home; the third saved item appears in both the routine and primary action. This did not start a session.
- Receipt: compact default shows timer, Farm progress, two collapsed detail groups, View farm, and Done for now. Expanding timer details shows eligible progress and before-bed time; Health/protection expands to the factual disconnected/not-requested fixture states. See receipt-compact.png.
- Accessibility-size Home uses a vertically wrapping start action and stacked timing values. home-large-type.png records that layout before the final hero metric wording; the below-fold content requires scrolling.

## Limits

No TestFlight upload or physical-device acceptance. Spoken VoiceOver, tactile feel on a real phone, all narrow-device layouts, Reduce Motion on device, and the automatic/session-protection paths remain release checks. Simulator UI automation intermittently omitted navigation-toolbar elements and returned noWindowsAvailable; visible controls were operated from fresh screenshots when needed. No claim is made that every iPhone layout has been physically tested.
