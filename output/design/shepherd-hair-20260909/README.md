# Long-hair repair — 9 September 2026

The founder's boxy-head screenshot showed two rounded hair strips starting on the cheeks.
Removed those foreground strips. Long hair now uses a continuous scalp-to-shoulder silhouette
behind the face and clothing, sized to the selected head. The side view keeps the long hair
behind the head rather than behind the nose. Back hair follows the same lift/rotation as the
head, so the study's motion does not separate the hair from the scalp. Skin is masked out
of the scalp region for long hair, eliminating the skin-colored antialiasing seam seen in
the first corrected render. Existing saved hair,
head and equipment choices are unchanged.

`bash output/design/shepherd-hair-20260909/export.sh` renders the actual shared production
Canvas without DEBUG. The four clothing sheets exercise long hair on every head, skin tone,
outfit and headwear family; `long-hair-views.png` adds all five viewing directions. These are
host SwiftUI renders, not screenshots of a deployed phone build.

Validation: full app unit run passed, 930 tests, zero failures; result bundle
`/tmp/shepherd-hair-final-tests.xcresult`, log `/tmp/shepherd-hair-final-tests.log`. Final test run rebuilt the app after the seam correction. The preceding generic app build
also passed; log:
`/tmp/shepherd-hair-build.log`. No new domain tests were added for a drawing-only correction.
Whitespace checked with `git diff --check`. No archive/upload or physical-device validation.

Commands:
```sh
xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=1887D62C-09DF-48D7-8A04-0D32D1640BA2' -derivedDataPath /tmp/counting-sheep-shepherd-native -resultBundlePath /tmp/shepherd-hair-final-tests.xcresult
xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/counting-sheep-shepherd-native
```
