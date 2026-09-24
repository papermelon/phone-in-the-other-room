# Wardrobe implementation evidence

Implemented and locally verified on 23 September 2026. No backend deployment or TestFlight
distribution was performed.

- `shepherd-combinations.png`: actual production renderer, all three hats with all five
  outerwear choices, wearing the Berry Field Shirt under each.
- `shirt-with-hat.png`: Simulator after taking off the open coat; shirt and hat remain.
- `coat-source-paths.json`: original generated source paths for all 23 fuller coat frames.
- `coat-alpha-bounds.txt`, `classic-alpha-bounds.txt`: alpha > 0.5 bounds measured with AppKit;
  ground differences populate the new pack's registration. Asset exports use transparent
  512×512 PNGs, scaled with sips without crop or background replacement.
- `build.log`: initial shirt/coat Simulator build passed before Ollie pack integration.
- `build-fuller.log`: integrated generic iOS Simulator build passed.
- `tests-final.log`: full Xcode unit suite passed, 1,128 tests, zero failures. The earlier
  `tests.log` recorded six failures in one new restore test because its expected owned-ID
  array was unsorted; the fixture was corrected to match the existing canonical sorting.
- `farm-save-tests.log`: Foundation persistence suite passed, 83 tests, zero failures.
- `full-coat-review/`: inspected all six garments across all 23 fuller-coat poses, including
  head tilt, run, rest and rise. Neckwear follows each registered pose and stays behind fur.
- `coat-picker.png`: switched Classic → Fuller in the native UI; selected state updates,
  Moss Bandana remains worn, wool balance stays at 5.
- `fuller-home.png`, `fuller-farm.png`, `fuller-journey.png`: inspected production scene
  components with the same fuller coat and Moss Bandana. Journey capture uses Reduce Motion.
- `fuller-motion.mp4`: recorded running and settling/rising preview; sampled live poses
  inspected through the Simulator. This is Simulator evidence, not physical-device validation.
- `wardrobe-large-type.png`: Accessibility 3 layout on iPhone SE. Native controls verified
  that removing the coat retains shirt and hat; removing the shirt retains coat and hat.

Commands: `xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom
-destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/counting-sheep-coat-build
-jobs 2 ARCHS=arm64`; `xcodebuild test` with the same project/scheme/derived data and destination
`platform=iOS Simulator,id=1887D62C-09DF-48D7-8A04-0D32D1640BA2`;
`python3 scripts/validate-farm-save.py`; `git diff --check`.

The existing social contract still projects cream shirt, closed moss coat and Classic Ollie.
Exact new appearance sharing, other breeds, physical-device motion and spoken VoiceOver checks
remain in the backlog. Accessibility labels/selected traits were inspected through native AX.

The review runs `--shop-wardrobe-qa` with random disposable defaults/Farm storage and external
services disabled. No founder Farm is used. `--shop-mode=wardrobe` shows the actual wardrobe;
`--shop-fuller-coat --shop-capture-art` captures the new coat with every garment.
`--shop-capture-shepherd` captures Shepherd combinations; `--shop-large-type` checks large text.

Follow-up on 23 September: `shepherd-shirts-with-coat-and-hat.png` is a fresh native
renderer capture of Berry, Dusk and Sunrise shirts under the same open moss coat and
field hat. The shirt colours remain distinct and the independent layers fit. The
source now has capability-gated private and Global Campfire wardrobe IDs, with a
PostgreSQL migration and bounded Edge validation; backend activation and physical
two-account verification remain separate. The follow-up generic Simulator build,
1,131 Xcode tests, 83 Farm persistence tests and 9 Global validator tests passed.
The migration's wrapper logic passed a disposable local PostgreSQL stub check;
`supabase/tests/campfire_wardrobe_test.sql` still needs a full migrated backend run.
