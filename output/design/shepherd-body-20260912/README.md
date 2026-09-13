# Shepherd body revision proof

These sheets render the actual production SwiftUI `ShepherdStudyCanvas`, compiled without `DEBUG`. They are evidence of the app drawing code, not new generated concept art. The canvas and appearance mapping are shared with `ShepherdAvatarView` in the production app.

The design reference is [the approved turnaround](../shepherd-motion-20260908/turnaround-study.png). The comparison holds the existing head and face drawings fixed while reviewing the torso, sleeves, hands, trousers, boots, garment details, and texture.

## Reproduce

From the repository root:

```sh
output/design/shepherd-body-20260912/export.sh
```

This writes `revised-*.png` plus the source checksums. It uses system SwiftUI/AppKit and ImageRenderer, with no package dependency or application data access. It includes `ShepherdStudyBodyPaths.swift` automatically when present.

The original renderer was captured before the revision in `/tmp/shepherd-body-before` and rendered with:

```sh
output/design/shepherd-body-20260912/export.sh before /tmp/shepherd-body-before
```

The saved before sheets and checksums preserve that evidence; the temporary source snapshot is local and may be removed by the operating system.

## Sheets

- `before-fit-{dark,paper}.png` and `revised-fit-{dark,paper}.png`: the same Moss Coat, everyday shirt, and Berry Dress in front and three-quarter views, each at the 180 pt customization frame and 72 pt Farm frame. Export scale is 1.5 pixels per point.
- `revised-wardrobe.png`: all six drawing outfits, four heads, and short/long hair. The Berry Dress remains a study drawing option, not a newly purchasable production item.
- `revised-motion.png`: all five drawing directions for Moss Coat and Field Overalls, using actual contact, stance, and recovery poses from `ShepherdStudyMotionRules`. These are compatibility samples; they do not claim shepherd walking has been activated in the production Farm.
- `revised-companions.png`: revised avatars alongside the existing `dog_classic_farm_idle` and `sheep_bramble_wool_ready` raster assets at 180 pt and 72 pt frames. Those companion assets are loaded directly and unchanged.

Production build, unit tests, Simulator UI checks, and any remaining physical-device verification are recorded in the implementation report and owning plan. These host exports alone do not prove device rendering or deployment.

## Visual review

The revised exports were regenerated and inspected after the final arm texture and pocket layer corrections. The fit sheets show sloping shoulders and sleeves, hands below the cuffs, broader garment hems, short trouser sections, and rounded boot toes at both production frame sizes. The wardrobe matrix showed no newly detached limbs or clothing/hair collisions. The sampled contact, stance, and recovery poses showed continuous waist coverage and attached cuffs; they are a finite compatibility sample, not a complete animation audit.

The first revision exposed a texture-space error: arms were drawn in local coordinates outside the paper texture rectangle, making the cream shirt sleeves look flatter than the torso. The final exported source applies the arm shapes in the common paper coordinates, and the corrected proof was re-inspected.

The final layer review found that pockets could paint over thumbs during inward arm swing. Garment details now render before the arms, with collars separately layered above the sleeves. The regenerated motion sheet was checked at the 0.225 s stance sample: front and three-quarter coat hands remain skin-colored and sit in front of the pockets. Fit and wardrobe sheets were re-inspected after this change.

Final source verification: `shasum -a 256 -c output/design/shepherd-body-20260912/revised-source-sha256.txt` passed for all seven recorded production drawing and appearance sources.

The silhouette is closer to the approved turnaround. The native renderer still has a flatter graphic finish than the generated reference and animal raster shading; these exports intentionally show that actual implementation instead of claiming an exact reproduction.

## Native validation — 12 September 2026

- Full app Simulator build passed (`generic/platform=iOS Simulator`, both architectures).
- Full unit suite passed: **946 tests, zero failures**. The test invocation rebuilt the final
  renderer after the pocket/hand layer correction.
- Exact commands:

```sh
xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/counting-sheep-shepherd-native
xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=1887D62C-09DF-48D7-8A04-0D32D1640BA2' -derivedDataPath /tmp/counting-sheep-shepherd-native -resultBundlePath /tmp/shepherd-body-tests.xcresult
```

Build/test logs are `/tmp/shepherd-body-build.log` and `/tmp/shepherd-body-tests.log`;
structured test results are `/tmp/shepherd-body-tests.xcresult`. Existing warnings in unrelated
account/social code remain; the three drawing files produced no reported compiler warnings.
No new source membership, project regeneration, signing, dependency or saved-data change was needed.

The local production preview uses the real `ShepherdAvatarView` and appearance controls with
disposable view state; it branches before account/Farm services initialize. Physical iPhone
appearance/performance and a distributed build remain separate release checks. No archive,
upload or deployment was performed in this batch.

### Native preview inspection

Installed the freshly built app on the isolated **Counting Sheep Shepherd Art Study** iPhone 17
Simulator (iOS 26.5), then launched with `--shepherd-art-study --shepherd-production-preview`.
The preview is a test harness around the same production drawing and controls, not a second
art implementation. Checked:

- Default shirt: longer curved hem, continuous waist, angled sleeves and rounded boots
  ([screenshot](ios-default-shirt.png)).
- Pear / cropped hair / warm skin / Moss Work Coat: coat silhouette, cuffs, mittens, collar,
  pockets and short trouser sections ([screenshot](ios-moss-coat.png)).
- Boxy / long hair / deep skin / Field Overalls / Moon Beanie: fitted layering without cheek
  hair intrusion or garment clipping ([screenshot](ios-long-hair-overalls.png)).
- Taking off overalls and beanie restores the shirt and full long-hair silhouette while
  retaining the selected boxy head and deep skin. Accessibility values update with equipment.
- Largest accessibility text size: full avatar remains visible; head choices use readable,
  full-width cards ([screenshot](ios-accessibility-size.png)). Restored normal text size after.

Accessibility labels/selection state were inspected through the native accessibility tree;
this is not a physical VoiceOver speech/navigation pass. Farm-size readability comes from
the exact-renderer 72pt exports; no founder Farm/account was used as a test fixture.
