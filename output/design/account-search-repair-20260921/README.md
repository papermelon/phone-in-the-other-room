# Account and search repair validation — 21 September 2026

Source: [implementation note](../../../docs/plans/account-and-search-repair-2026-09-21.md). This is local source/simulator evidence, not a distributed app or physical-device sign-in result.

## Automated checks

- `xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/slumber-repair-derived` — BUILD SUCCEEDED (`/tmp/account-search-build.log`).
- `xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=71CF8F3E-9E9A-449D-93A8-B73F64869A5E' -derivedDataPath /tmp/slumber-repair-derived -resultBundlePath /tmp/account-search-tests.xcresult` — TEST SUCCEEDED, 1,112 tests, zero failures (`/tmp/account-search-tests.log`).
- `python3 scripts/validate-farm-save.py` — 81 tests, zero failures; final rerun includes sign-out cleanup assertions (`/tmp/account-search-farm-tests-final.log`). Regressions cover authenticated-but-unconnected state after Apple/Farm lookup failure, retry preserving atomic ownership and completion callbacks, metadata refresh retaining confirmed Farm presentation, and sign-out clearing authenticated identity.
- `git diff --check` — passed.

## Read-only production check

Queried only `pg_constraint` definitions for `private.account_usernames` on the linked production project `sxjlkcccsentmhowgoqe`. [Recorded constraints](handle-constraints.json) confirm normalized-name CHECK, user-id primary key and UNIQUE(username). No account rows were read and no production data changed. Existing SQL tests also cover normalized and duplicate claims.

## Native simulator inspection

Installed the final test-built app on task-owned iPhone 17 and iPhone 16 Pro simulators, iOS 26.5. Account fixtures inject presentation state and do not authenticate or claim a real handle.

- iPhone 17 Profile: pending authenticated account shows Sign-in complete, Farm not connected, preserved local Farm explanation, Retry Farm connection, Support details and Sign out. Apple sign-in controls are absent. [Capture](profile-connection-pending.png).
- Profile with no handle shows Choose a handle directly. Navigation opens the handle field with unique-username, separate-Shepherd-name and immutable-claim explanation. [Capture](choose-handle.png). Connected Profile also displays the existing @handle and Copy handle control.
- iPhone 16 Pro shared search card: tapped the trail artwork to expand, bottom Show less to collapse, then reopened and tapped the artwork to collapse. Accessibility value switched Expanded/Collapsed correctly. [Expanded capture](search-16pro-expanded.png).
- iPhone 16 Pro **full Farm screen**: both the header toggle and bottom collapse action returned the card to Collapsed. Existing Farm/tab navigation remained present.
- iPhone 17 at accessibility3 text: expanded card, activated bottom collapse, reopened, and collapsed from the header; both returned the accessible state to Collapsed. Text wraps vertically and details scroll. [Collapsed large-text capture](search-large-collapsed.png).

## Remaining physical checks

Distribute the updated app separately. Repeat the reported Apple connection failure/retry on the affected physical account with support diagnostics; screenshot alone does not identify its hosted cause. Verify actual Apple sheet, real account ownership/switching, handle collision, spoken VoiceOver, and physical iPhone 16 Pro/other-size touch behavior. Simulator AX activation does not prove spoken VoiceOver or all physical devices.
