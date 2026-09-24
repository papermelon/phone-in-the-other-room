# Readable Campfire plans and person sheets — 20 September 2026

Local implementation completed and validated in Simulator. Scope follows the
[research and plan](../../../docs/plans/campfire-readable-plans-and-organic-seating-2026-09-20.md).

## Reproduce

Use the existing isolated Debug fixture:
`--campfire-buddies-qa --buddy-view=<mode>`.

- `unified-plans`: eight shared participants with short, two-part, long, blank, CJK, Arabic,
  emoji and missing plans. `--buddy-count=1`, `2` or `4` limits the displayed participants.
- `unified-refreshing`, `unified-stale`, `unified-empty`: existing presence-state coverage.
- `public-card`, `public-card-long`, `public-card-pending`, `public-card-sent`: public person sheets.
- `private-card`: private person sheet with its existing buddy actions.
- `profile`: permitted extended profile content without a backend request.
- `--buddy-light`, `--buddy-large-text`, `--buddy-max-text`, `--buddy-bottom` retain their existing meanings.

These fixtures use disposable local defaults and no configured network service. A rendered
pending/sent fixture is evidence of UI presentation only, not live delivery. Global fixture
presence ages out under the existing 45-second freshness rule; relaunch for a fresh capture.

## Checks

- Full Simulator app build passed: `/tmp/counting-sheep-readable-build.log`.
- Final full test run rebuilt the refinements and passed **1,106 tests, zero failures**:
  `/tmp/counting-sheep-readable-final-tests.log`, result bundle
  `/tmp/counting-sheep-readable-final-tests.xcresult`.
- The earlier layout test caught a one-point bottom-seat overflow (801 into an 800-point
  canvas). The anchor was corrected before the passing final run.
- Added checks cover complete Unicode plan preservation, blank fallback inputs, safe seat/
  bubble rectangles on a 288-point content width, fire clearance, and existing stable
  identity/swap assumptions. Native inspection covers measured text rendering.
- iPhone SE native inspection: short and two-part plans wrap; an oversized plan uses
  View plan and opens its complete text in the existing person sheet. Profile fetch failure
  stays below the plan/actions. Chinese, Arabic, emoji, blank and absent plan fallbacks render.
- One-, two-, four- and eight-person fixtures were inspected. At accessibility text sizes,
  the People here list starts expanded with the full plans. The large-text refresh notice
  remains above the top bubbles. Freshness expiry was observed removing people and plans
  while leaving the campsite in place.
- Public pending/sent fixtures show Waiting to send with retry versus Encouragement sent;
  Safety options exposes the existing Block/Report actions. These fixtures do not send anything.
- The private sheet leads with its full shared plan and Start/Buddy/Encourage actions; the
  duplicate member-name heading is gone. Extended profile, Farm preview and history disclosures
  were opened successfully. Maximum Dynamic Type was inspected on the public person sheet,
  including wrapped start/sent/profile controls and the unavailable-profile message.
- An accessible Move right action exchanged Morgan and Jo's seats, preserving their plans
  and changing the artwork facing with the seat. Spoken VoiceOver and physical gestures are
  not inferred from this accessibility action.

Build/test commands:

```sh
xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=60935BFC-7044-4BE8-9712-7D1B6C568A16' -derivedDataPath /tmp/counting-sheep-first-start-build
xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=60935BFC-7044-4BE8-9712-7D1B6C568A16' -derivedDataPath /tmp/counting-sheep-first-start-build -resultBundlePath /tmp/counting-sheep-readable-final-tests.xcresult -parallel-testing-enabled NO
```

Captures:
- [Plans and fire](plans-light-top.png)
- [Multilingual plans and accessible seat swap](plans-dark-seat-swap.png)
- [Actions before profile and its unavailable state](person-actions-profile-unavailable.png)
- [Pending encouragement](person-pending.png)
- [Acknowledged encouragement at maximum text size](person-sent-ax5.png)
- [Private plan and buddy actions](private-plan-actions.png)
- [Expanded Farm](profile-farm-expanded.png)
- [One-person campsite](one-person-light.png)
- [Expired presence removed](stale-people-removed.png)

## External acceptance

Two-device live-network checks, spoken VoiceOver and physical hold/drag-versus-scroll remain
separate. No backend deployment, signing or distribution change is included in this pass.
