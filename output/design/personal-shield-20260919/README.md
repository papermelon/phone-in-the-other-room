# Personal shielding — local validation, 19 September 2026

- Final generic iOS Simulator app build: **passed**.
- Full unit suite on disposable iOS 26.5 Simulator: **1,065 tests, zero failures**.
- Isolated production VM/coordinator/persistence probe: **passed**; see `integration-probe.json`.
  Covers save/reload, shared check projection, Home route consumption, no ordinary replay,
  wrong/fresh phrases, failed access, one-use grants/ending, early-wake gating, corrupt-list
  exit fallback, terminal precedence and account separation. Shielding is a spy: this
  does not establish physical blocking, DeviceActivity scheduling, or NFC behaviour.
- `git diff --check`: passed.
- Native UI review resumed after unlock. Checked light/dark appearance, check/uncheck,
  saved checks after reopening, mode-specific labels, Wind Down sleep completion,
  Phone Away completion without ending, exact next-task phrases, wrong/valid input,
  case/punctuation tolerance, fresh end input after access, cancellation back to Ollie,
  successful ending to the receipt, and early-wake choice → phrase → receipt.
- Fixed the issues found: the phrase/task fields now have at least 44-point height,
  and the confirmation button visibly dims until the phrase matches. The debug-only
  dark-appearance flag now applies at the actual app root.
- Checked the system `accessibility-extra-large` text setting. Text wraps and all
  actions remain present in the accessibility tree; the lower End action was activated
  through accessibility. Checked explicit Checked/Unchecked values and hints, disabled
  action state, and standard-size onscreen-keyboard layout. Spoken VoiceOver, dictation,
  and touch scrolling with large text still require device acceptance.
- Small-screen inspection is **unavailable**, not passed: the disposable iPhone SE
  stalled at the Apple boot screen on two boots. A later warm boot reached SpringBoard,
  but app launch failed with NSPOSIXErrorDomain code 3 (no process handle); a retry also
  did not reach the fixture. Only that disposable device was shut down afterward.
  Existing review devices were not changed.
- The initial `checklist-with-system-prompt.png` is historical and not visual acceptance.

Commands:

```sh
xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator'
xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=DCE14575-BF37-4DB8-969E-DFC79B163B58'
```

Final test result: `Test-PhoneInTheOtherRoom-2026.09.19_19-51-21-+0800.xcresult` in the
project's existing Xcode DerivedData Logs/Test folder. Build/test logs are in
`/private/tmp/personal-shield-build.log` and `/private/tmp/personal-shield-tests.log`.

## Captures

- [Wind Down completion](wind-down-complete.png)
- [Early-wake phrase handoff, dark](early-wake-end-dark.png)
- [Phrase and onscreen keyboard, dark](phrase-keyboard-dark.png)
- [Phone Away completion, accessibility text](phone-away-complete-large-text.png)
- [Phone Away end gate, accessibility text](phone-away-end-large-text.png)
- [Exact next-task access phrase, accessibility text](task-phrase-large-text.png)

## Reproduce and remaining acceptance

Disposable device: **Counting Sheep Personal Shield QA**,
`DCE14575-BF37-4DB8-969E-DFC79B163B58`. The final Debug build is installed. Its system
text size is `accessibility-extra-large`; this setting was changed only on the disposable
QA device. Small-screen device: **Counting Sheep Personal Shield Small QA**,
`E8CE43A5-1C9C-4780-A703-FF371DAFB0F3` (shut down after boot/app-launch failures).

Launch the existing Screenbook scenario with:

```sh
xcrun simctl launch DCE14575-BF37-4DB8-969E-DFC79B163B58 com.ngawangchime.countingsheep -screenbook-scenario iphone.home.configured.default -screenbook-run-id personal-shield -screenbook-personal-shield -personal-shield-probe
```

Additional fixture flags: `-personal-shield-tasks`, `-personal-shield-complete`,
`-personal-shield-access`, `-personal-shield-end`, `-personal-shield-home`,
`-personal-shield-dark`, `-personal-shield-overnight`, `-screenbook-habit-accessibility`.
The last flag affects the fixture root but does not propagate into this presented sheet;
use Simulator Features → Increase Preferred Text Size for the sheet inspection.

Remaining UI acceptance: a working small screen, touch scrolling at accessibility text
sizes, spoken VoiceOver and dictation. Text entry/keyboard, both appearances, check states,
cancellation and early-wake handoff were inspected as described above.
Physical-device acceptance remains separate: native shield warm/cold handoff, older-OS
manual route, cached shield refresh, unattended automatic starts, actual grant/restore
(including suspension and near-end requests), and authenticated NFC exits.
No production activation, release upload, or physical validation is claimed.
