# Compact Home actions and Offline Together — 22 September 2026

## Implemented

PrimaryGreenCTA now places the icon beside all existing copy instead of stacking it above. Accessibility text retains a wrapping vertical layout. Ollie, the primary action’s press feedback, and planned-minute hero remain.

Home’s section is Offline Together. Each social entry has its own labelled 44-point info button, separate from the navigation action. Slumber Party explains private invite-only groups; Campfire leads with the Global community and explains the separation between viewing and sharing.

HomeStartRoutingPolicy resolves the current Wind Down or the next one when a default 30-minute Phone Away would cross its start. Exactly touching the start is not overlap. The same policy is used during manual preflight and confirmation, with source-ID matching. Home refreshes its clock-dependent presentation every 30 seconds while displayed. Automatic schedule eligibility and start time remain unchanged.

## Validation

`xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=71CF8F3E-9E9A-449D-93A8-B73F64869A5E' -derivedDataPath /tmp/slumber-repair-derived -disableAutomaticPackageResolution`

Full app/target build and 1,114 tests passed, zero failures. New tests cover either side of the 30-minute boundary, the exact boundary, active Wind Down, midnight crossing, disabled/missing primary plans, unrelated Phone Away, stable source identity, and the intended bedtime anchor. Existing automatic eligibility is checked to remain closed during the manual lead-in. Log: `/tmp/home-compact-social-tests.log`; summary: validation.txt. `git diff --check` passed.

Native isolated iPhone 16 Pro QA Simulator checks:
- Fixed 22:10 fixture, scheduled start 22:30: compact Start Wind Down appears and opens the WIND DOWN confirmation. Dismissed without starting; physical shielding was not tested.
- Daytime Phone Away fixture: compact Start Phone Away retains the scheduled title and end time. See phone-away-compact.png.
- Both info sheets open independently and dismiss; Campfire visibility remains Off. See slumber-party-info.png and campfire-info.png.
- Accessibility-size Home retains wrapping action text and labelled info controls. Native VoiceOver speech, narrow physical-device layouts, tactile interaction, and actual early session admission/shielding remain physical release checks.

No new archive, upload, backend deployment, or production-data operation was performed.
