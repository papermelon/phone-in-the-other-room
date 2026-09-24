# Moss Bandana motion repair — 20 September 2026

## Scope

Reference garment repair, before expanding the collection. Existing inventory IDs, purchase
state, prices and unlocks are unchanged. The other five garments retain their previous fitting
until separately migrated. No generated artwork, new dependency or animation runtime.

## Root cause and repair

The old fitting table assigned the same translation, rotation and width to all six Home
frames, although frame 5 substantially tilts the head. Clothing also covered the entire
flattened dog sprite without a foreground chin/ruff layer.

`OllieBandanaPose` supplies independent neck-left, neck-right and chest-tip coordinates for
all 23 production sprites. `OllieDressedSprite` deforms the native paper bandana between
those points and redraws the original textured chin/ruff over its tucked upper edge. Curled
poses expose a small side fold and hide the front motif/knot. Base, cloth and fur use one
uniform 512-point canvas transform, including non-square layout proposals and parent mirroring.

Home, Farm, active-session chase, Fetch, search progress and Shop already share this renderer.
Shop previews now play the production head-tilt and settle/rest/rise sequences; Reduce Motion
keeps each selected pose still. The debug capture now includes all six Home frames rather
than only neutral.

## Reproduce

Build the `PhoneInTheOtherRoom` scheme for an iPhone Simulator. Launch the app with:

```text
--shop-wardrobe-qa --shop-mode=motion --shop-capture-art --shop-capture-bandana
```

This uses the existing isolated QA Farm storage and disables external services. Captures are
written to the Simulator app's `Documents/shop-art-review/`. Other screen fixtures use
`--shop-mode=home`, `pasture`, `journey` or `detail`.

## Validation

- Final full app/extension Simulator build passed:
  `xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/counting-sheep-wardrobe-build -jobs 2 ARCHS=arm64`.
- Full unit suite passed: **1,104 tests, zero failures**. Command:
  `xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=1887D62C-09DF-48D7-8A04-0D32D1640BA2' -derivedDataPath /tmp/counting-sheep-wardrobe-build -jobs 2 ARCHS=arm64 -parallel-testing-enabled NO -resultBundlePath /tmp/counting-sheep-wardrobe-tests.xcresult`.
- New wardrobe tests check all production poses for valid cloth orientation/area, verify
  independent neckline/chest movement during the tilt, and keep resting details out of the
  foreground paws. Existing purchase/equipment save/restore tests remain passing.
- Inspected all 23 native rendered poses, 210-point Home and 72-point Farm/chase sizes,
  both running directions, light/dark backgrounds, non-square proposals and unknown-item
  fallback. Also operated Sitting/Running/Resting controls and inspected their updated
  accessibility labels. Captured Shop detail at accessibility3 with readable wrapped copy.
- The first visual pass found a small cloth tip outside the right neck during frame 5.
  Added an alpha silhouette clip for the tucked fabric, separate from the loose knot.
  `check-neck-silhouette.swift` detected **16 stray green pixels before the correction and
  zero afterward**. Reproduce the final assertion from the repository root:

  ```sh
  swift -module-cache-path /tmp/ollie-module-cache output/design/ollie-bandana-20260920/check-neck-silhouette.swift Assets.xcassets/dog/dog_classic_home_idle_frame_05.imageset/dog_classic_home_idle_frame_05.png output/design/ollie-bandana-20260920/head-tilt.png --assert-clean
  ```

The initial generic build also passed before that final silhouette correction. One rebuild
was interrupted to restrict work to the available Apple Silicon Simulator. The final full
build and suite above ran against the corrected source. A stalled Simulator capture request
was retried; the saved images are from the final build. `source-hashes.txt` identifies the
checked implementation files.

## Visual evidence

- `all-poses.png`: native ImageRenderer contact sheet of every registered sprite.
- `head-tilt.png`: deepest tilt against black, used by the pixel regression check.
- `home-farm-chase-sizes.png`: actual display sizes, mirrored chase, dark/light backgrounds.
- `layout-and-fallback.png`: wide/tall proposals and unknown equipment fallback.
- `shop-large-type.png`: native Shop detail at accessibility3.
- `moss-bandana-motion.gif`: 10.8-second motion contact sheet assembled from the native
  frame captures, using production action frame durations; neutral holds and repeated run
  cycles align the three panels. It is a fitting comparison, not a live screen recording.

## Next collection work

Use the fitting contract in `docs/ASSET_NAMING.md#ollie-neckwear-fitting`. Colour and motif
variants can share the accepted bandana silhouette. Collars, scarves and capes need an
explicit silhouette/overlap review; do not blindly reuse the bandana triangle. Expand the
same native capture whenever a new animation pose or garment shape is introduced.

Physical-device/TestFlight appearance, system Reduce Motion and spoken VoiceOver remain
separate acceptance checks. The existing Reduce Motion branch returns a stable selected pose
and pauses the preview timeline; this pass inspected that code path rather than toggling the
device's accessibility settings. No archive, upload, commit or push was performed.
