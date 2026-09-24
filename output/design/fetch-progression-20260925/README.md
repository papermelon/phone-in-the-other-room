# Fetch progression — 25 September 2026

Implemented first slice: five-throw clover practice, deliberate swipe or adjustable
heading/strength throws, per-landing scoring, voluntary replay/free fetch, personal
best in the account-owned Farm, and two wool Shop balls (Moss 3, Sunset 4).

The same ball renderer is used by Shop previews and flight/pickup/return. Purchase
uses the existing atomic wool/inventory transaction; equipment changes do not alter
physics. Optional fields retain legacy defaults and unknown item IDs. No reward,
search-credit or public social field is added.

Review repaired two lifecycle interactions: the visibility boundary now includes
fetch controls, so scrolling to large-text controls does not cancel practice; a
Reduce Motion scene refresh no longer cancels explicit play when a best is saved.
The existing active-session, background, disappearance and pasture-change gates remain.

## Validation

- `python3 scripts/validate-farm-save.py`: **84 tests passed**, including the new
  account-switch/sign-out/reload case. Disposable local stores; no production account.
- Full Simulator app build: **passed**, including final visual/accessibility cleanup
  (`build-verified.log`). Generated project membership comes from `xcodegen generate`.
- Unrestricted unit suite: **1,137 tests passed**, including **20 fetch tests**
  (`tests-final.log`). The initial run found an old clothing-only assertion for the Ollie
  category; it now checks wearable effects and explicitly rejects balls as garments.
  Subsequent view-only marker/summary/label cleanup passed the final full app build.
- Native iPhone SE / iOS 26.5: inspected production views through offline, disposable
  fixtures using CUA. Verified ball taps do not throw, a swipe does throw, direction and
  strength controls update the aim and can earn 3 points, and a complete five-throw round
  reports 12/15 with a matching personal best and voluntary replay/free fetch.
- Largest accessibility text (AX5): labels wrap, controls remain reachable, and play
  continues when scrolling takes the field offscreen. Shop preview was inspected in
  dark mode at AX3 and light mode at standard text. A 3-wool Moss Ball purchase succeeded,
  equipped the ball, and switching back to the original ball succeeded.
- Visual review moved the target markings below residents and removed disabled aiming
  controls from the completed-round summary. Rechecked a completed 1/15 round and replay:
  aiming controls disappear at completion, replay starts at 0/5, and the best remains 1/15.
  Both ball previews use the same renderer
  as play. Accessibility-tree inspection covered target/status text, slider values,
  throw availability, and purchase/equipment actions; this is not a physical VoiceOver run.
- `git diff --check`: passed. Review risk: M (Farm save additions and local game state).
  Domain tests cover inner/outer/missed landings, one score per landing, no preset scoring,
  handoff completion, cancellation, Reduce Motion refresh, invalid inputs, purchase failures,
  duplicate purchase, legacy defaults, private payload round-trip, unknown IDs and bad bests.
- The dedicated Fetch Unit QA Simulator stalled in CoreLocation migration; it was shut
  down. Tests and inspection used the already-running Review iPhone SE QA Simulator.

Commands (same derived data reused):

```sh
xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/counting-sheep-search-build -jobs 2
xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=60935BFC-7044-4BE8-9712-7D1B6C568A16' -derivedDataPath /private/tmp/counting-sheep-search-build -parallel-testing-enabled NO -jobs 2
python3 scripts/validate-farm-save.py
```

Screens: [clover practice](clover-practice.png), [largest text controls](practice-largest-text.png),
[Sunset Ball preview](sunset-ball-preview.png), [completed practice](practice-complete.png).
Screens show fixture Farms, not the founder’s data.

Logs are adjacent. No archive, TestFlight upload, backend deployment or physical
phone validation was performed. Later toys, target mats, baskets and mastery rewards
remain the phased proposals in the [implementation plan](../../../docs/plans/fetch-progression-2026-09-20.md).
