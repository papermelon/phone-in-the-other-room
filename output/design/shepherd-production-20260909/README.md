# Shepherd production integration — 9 September 2026

## Implemented

The normal `ShepherdAvatarView` now uses the same paper-textured native Canvas renderer as
the art study. The renderer and appearance mapping compile without DEBUG. The study screen,
its disposable production-controls preview, and its export buttons remain Debug-only.

- Saved pear, round, boxy and triangular heads in Farm customization and onboarding.
- Five existing skin tones and five distinct hairstyles; no gender restrictions.
- Fitted Moss Work Coat, Moonlit Coat, Field Overalls, Star-Keeper Cloak, Wool Field Hat,
  Clover Headscarf and Moon Beanie. Existing ownership/equipment IDs remain unchanged.
- Shared rendering for Farm, customization, onboarding, shop item previews/thumbnails and
  social avatar callers. No legacy whole-character tint fallback.
- Private `ShepherdProfile.headShapeID` survives local JSON and private backup/restore.
  Missing legacy values remain absent when encoded, keeping existing cloud fingerprints
  stable. Unknown future values are retained while the renderer uses pear.
- Public Slumber Party appearance fields are unchanged. Remote head shapes default to pear
  until a supported, consented public-contract extension is implemented.

## Open the Debug study

In Xcode select the PhoneInTheOtherRoom scheme. Product → Scheme → Edit Scheme → Run →
Arguments → Arguments Passed On Launch: add `--shepherd-art-study`. Use Debug configuration.
Run, then open **Preview production customization** to try the actual production controls
with disposable state. No account, Farm save, purchase, notification or run services start.
Add `--shepherd-production-preview` alongside the study argument to open that preview directly.
Remove/disable the arguments to use the normal app. TestFlight/Release cannot open this harness;
they now get the new static avatar through their normal screens.

## Visual evidence

`bash output/design/shepherd-production-20260909/export.sh` compiles the actual drawing and
profile mapping without DEBUG and exports the four contact sheets here. The script extracts
the actual pure profile declarations from FarmModels for the standalone host renderer.
These are macOS SwiftUI ImageRenderer exports, not screenshots of iOS. Inspected 100 large
combinations plus 20 Farm-size examples across four head shapes, all skin tones, all five
hairstyles, all four outfits, and all three hats. Shapes, fitted garment details, transparent
backgrounds and the dark-room round-head sheet were inspected.

## Validation

- `xcodegen generate`: succeeded for new source membership; no new target/dependency.
- Full generic iOS Simulator Debug app build: succeeded.
- Full unit suite: **930 tests, zero failures**, including five new integration tests and
  seven existing rig tests. Log `/tmp/shepherd-production-final-tests.log`, result bundle
  `/tmp/shepherd-production-final-tests.xcresult` (rerun after the layout fix).
- Full Release configuration build (arm64 + x86_64): succeeded. Log
  `/tmp/shepherd-production-release.log`. Final arm64 Release build after the accessibility
  and shared-palette fixes also succeeded: `/tmp/shepherd-production-verified-release.log`.
  Final Debug UI build succeeded: `/tmp/shepherd-production-final-debug.log`.
- iOS 26.5 isolated preview launched successfully. Verified head selection, actual production
  avatar/accessibility state, Moss Coat and field-hat equipment, and restoring selected long
  hair when taking off the hat. `ios-customization.png` records the resulting appearance. The final shared-palette build
  was installed and inspected again; `ios-customization-final-dark.png` is the final preview.
- Largest Dynamic Type in dark mode exposed overly narrow head-choice columns. Fixed the
  appearance grids to use one column for accessibility sizes; verified the repaired iOS
  screen and full labels at the largest text size. See `ios-accessibility-dark.png`.
- `git diff --check`: clean.

New release copy is limited to “HEAD SHAPE”, the four shape names and concise VoiceOver
appearance/equipment labels. Reviewed with the product copy skill: descriptive, no new
outcome, sharing or enforcement claims. Selection has an explicit selected accessibility
trait and a minimum 64-point button content area.

## Remaining

Farm displacement/turning/walking is not enabled. The rig remains available in the study;
side/back garment coverage needs refinement before movement ships. Eye-expression controls,
new wardrobe collections and neckwear are later stages. Physical iPhone visual/performance,
VoiceOver and update/cloud-restore acceptance remain unclaimed. No signed archive, upload or
physical-device deployment was performed. Existing Ollie/sheep art remains unchanged.

## Reproduce the build checks

```sh
xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/shepherd-production-build
xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=1887D62C-09DF-48D7-8A04-0D32D1640BA2' -derivedDataPath /tmp/counting-sheep-shepherd-native -resultBundlePath /tmp/shepherd-production-final-tests.xcresult
xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/shepherd-production-build ARCHS=arm64 ONLY_ACTIVE_ARCH=YES
```

The initial sandbox could not access Xcode caches/Simulator services. Running the same
validation with the approved Xcode/Simulator access succeeded. The test runner shut down its
own simulator after its first run; booting the dedicated device allowed the UI preview to
install and launch. No founder account/Farm was used as a test fixture.

Final review: no blocking findings in the touched source. Risk is moderate because the new
optional appearance field crosses private-save restoration; legacy/future-ID and strict cloud
fingerprint coverage passed. Actual remote multi-device restore and signed physical-device
update remain separate acceptance checks. No public appearance fields were added.
