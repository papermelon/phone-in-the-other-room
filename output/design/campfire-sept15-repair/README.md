# Campfire device-feedback repair — 15 September 2026

## Finding and scope

Founder supplied light/large-text and dark/default screenshots from two different accounts on TestFlight build 51. Both showed the Wind Down participant; the second phone was running Phone Away. Founder confirmed Slumber Party was enabled and was unaware of the separate Campfire agreement.

Current renderer, publication path and SQL support both Wind Down and Phone Away. The start UI previously rendered Campfire controls only when an agreement was already enabled, hiding the means to discover setup. Missing Campfire consent is therefore the leading explanation; no historical device consent receipt or failed server request was inspected. Do not label a server defect or physical-device recovery as proven.

Local changes:

- Start choices now expose disclosure/setup for supported parties before either ritual. Party state refreshes when the start choices appear; unsupported old servers do not advertise Campfire.
- Party detail explains separate sharing, sessions that began before consent, sessions excluded from the captured audience, and sessions not yet visible. Pending consent changes continue using existing delivery feedback. No consent is automatically accepted and no in-progress session acquires a new audience.
- Large-text Live sessions/Shared meadow selection uses stacked controls with selected accessibility state. People/Sheep/Lantern stack at large sizes and fall back vertically when the horizontal labels cannot fit.
- The running-session return bar stacks title and timer at large sizes and retains one accessible return action, with a minimum 44-point target.
- Mixed Wind Down/Phone Away regression coverage verifies both participants, input-order independence and one participant ending without removing the other. Phone Away validity uses its own planned end.

Existing uncommitted Campfire, Buddies, Farm, Fetch, backend and project work was preserved. No project regeneration, new dependency/entitlement, production mutation, commit, push or distribution was performed for this repair.

## Validation

- Final generic iOS Simulator app build: **passed**. Log: `/tmp/campfire-sept15-final-build.log`.
- Final full unit suite: **1,040 tests, zero failures** on disposable `Counting Sheep Pasture Unit QA` (`A0DB65B8-F3FC-4961-8B0C-9689F51C9EA1`). Log: `/tmp/campfire-sept15-final-tests.log`; result: `/tmp/campfire-sept15-final-tests.xcresult`.
- `git diff --check`: passed; local references in the new plan/evidence and owning-document additions checked.
- No backend changes were made by this repair; no hosted or local SQL test was represented as new evidence.

Commands:

```sh
xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator'
xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=A0DB65B8-F3FC-4961-8B0C-9689F51C9EA1' -resultBundlePath /tmp/campfire-sept15-final-tests.xcresult
git diff --check
```

## Native visual inspection

Disposable iPhone SE Simulator (`60935BFC-7044-4BE8-9712-7D1B6C568A16`), DEBUG `--campfire-buddies-qa`, isolated defaults and inert fixture actions. Fixtures supply two participants; these are rendering evidence, not cross-account transport evidence.

| State | Evidence | Result |
| --- | --- | --- |
| Default dark, both modes | [Dark live scene](dark-live.png) | Two distinct Shepherd seats; Wind Down and Phone Away cards |
| Light, accessibility3 | [Live scene](light-large-live.png) | Readable stacked view selector and both Shepherds |
| Light, accessibility3, scrolled | [Controls](light-large-controls.png) | People, Sheep and Lantern each fit in a full-width row |
| Light, accessibility5 | [Selector](light-max-selector.png) | Shared meadow wraps between words without clipping; selected state exposed in AX |
| Phone Away, accessibility5 | [Return bar](light-max-returnbar.png) | Title and timer stack; arrow stays visible, with a single return accessibility label |
| Setup entry | [Opened disclosure](setup-sheet.png) | The new start-flow review action opens the existing Campfire sharing sheet. The inspected AX tree includes the separate-choice explanation and enable action; acceptance was not performed |

Visual QA used native screenshots and accessibility-tree inspection. This does not establish physical VoiceOver reading order, actual push delivery, real app shielding or the state of the two reported phones. Earlier captures remain valid for unchanged layout code; the default dark scene, setup route and return-bar capture use the final build.

## Remaining acceptance and proposal

On the affected Phone Away account, inspect Campfire → Sharing. If disabled, enable it explicitly before a new session; a session already underway remains under its captured audience. On the updated device build, use two accounts with prior Campfire consent, start one Wind Down and one Phone Away, and verify both phones show both participants. Exercise expiry, offline early end/reconnect, withdrawal and account isolation with disposable accounts. Keep their Farms intact.

The [global Campfire implementation proposal](../../../docs/plans/global-campfire-2026-09-15.md) covers independent worldwide discovery, explicit public sharing, activity gatherings and mutual connections. It is a draft, not a deployed change to Slumber Party's audience.
