# Personalisation validation — 13 September 2026

Local implementation only. No commit, deployment, distribution, AI requests or API spend.
The [delivery record](../../plans/meaningful-personalisation-implementation-2026-09-13.md)
describes the behavior; the [AI pilot](../../plans/personalisation-ai-pilot-2026-09-13.md)
is proposed only.

## Actual checks

| Check | Result |
| --- | --- |
| `xcodegen generate` after new source membership | Passed; generated project, no hand edits |
| `xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator'` | Passed, including app, Watch and extension dependencies |
| `xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,name=iPhone 17e'` | **1,002 tests, zero failures**, final shortened UI source; completed 10:11:47 +08 |
| `python3 scripts/validate-farm-save.py` | **79 tests, zero failures**, including five new real temporary-store personalisation tests; completed 09:59:36 +08; subsequent changes were UI/copy only |
| `python3 -m unittest discover -s scripts/personalisation-eval -p 'test_*.py'` | **8 tests passed**, offline validator; final repeat 10:17 +08 |
| `python3 scripts/personalisation-eval/evaluate.py` | 25/25 contract passes, 20/25 seed mapping matches; **no model quality measured** |
| In-app isolated habit probe | **4/4 cases passed** on final build at 02:15:57 UTC; [machine-readable result](habit-probe.json) |
| `git diff --check` | Passed |

The app unit suite includes 15 new pure personalisation tests. The separate storage
suite checks guest/account A/account B isolation, stale write fences, exact sibling
values, corrupt/future schema preservation, atomic commits and reload. The in-app
probe checks reviewed activity projection, pending-write recovery without duplicate
revisions, old feedback associations and unchanged timing/protection/Farm/settlement.
Its shielding and remote delivery are simulated or disabled, as declared in its report.

Raw build/test logs remain at `/tmp/personalisation-build-final.log`,
`/tmp/personalisation-tests-final.log`, `/tmp/personalisation-storage-tests-final.log`.
A compact [result extract](validation-results.txt) is retained here. The iOS test
result bundle is `~/Library/Developer/Xcode/DerivedData/PhoneInTheOtherRoom-cbapevrcjnbvryejcvolmjxokfkc/Logs/Test/Test-PhoneInTheOtherRoom-2026.09.13_10-10-28-+0800.xcresult`.

## Representative UI inspection

Used a newly created disposable **Counting Sheep Personalisation QA** Simulator,
iPhone SE (3rd generation), iOS 26.5. Existing user/account data was not reset.
Screenbook synthetic fixtures disable remote services. These are actual Simulator
captures of the final shortened screens, not design mockups:

| Flow | Capture / observed result |
| --- | --- |
| Personal goal, compact light | [Goal](goal-compact.png): one question, editable personal wording, next-step cue and visible Save goal / Not now |
| Save unavailable | [Error](goal-save-unavailable.png): clicking Save goal in the failure fixture leaves the draft and shows the save error |
| Review custom activity, compact light | [Plan review](review-compact.png): contextual details collapsed; activity, optional cue and Save change fit the viewport; save is disabled until an activity exists |
| Large Dynamic Type, dark | [Review top](review-large-dark-top.png): accessibility3 text wraps; navigation and contextual disclosure remain legible; more content requires scrolling |
| Uncertain morning feedback / needed phone | [Reflection](reflection-compact.png): optional context collapsed; Not sure, save, delete and explicit protection review available |

Accessibility trees exposed the actual question, picker values, edit fields, buttons,
and disabled Save change state. Clicking Save goal verified the error route. This
is not a spoken VoiceOver walkthrough. Simulator scroll/drag attempts did not
reliably move the large-text fixture, so keyboard/scroll reachability is **not
claimed as passed**. Physical VoiceOver order, large-text editing with the keyboard,
account changes with a sheet open, and linked/independent morning protection and
receipt flows remain in the [release follow-ups](../../FUTURE_AGENT_TASKS.md).

No result establishes real shielding/NFC/Watch delivery, sleep, phone placement,
activity completion, habit effectiveness, production sync, or release readiness.
The redesigned countdown, completion views, coordinator and settlement implementation
were not edited for this feature. Preexisting unrelated working-tree edits remain.
