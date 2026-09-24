# Legacy Shepherd raster retirement — 23 September 2026

Founder identified the large-eyed raster Shepherd family as outdated during launch-film
art review. It must not be used as runtime artwork or as a generation/style reference.

## Removed family and recovery

20 image sets (five character bases, ten skin/outfit masks and five hairstyle-specific
Wool Field Hat overlays) were copied, verified with SHA-256 and removed from
`Assets.xcassets/farm`. The archive also preserves the incidental Finder metadata.
The original catalog sources total 1,365,234 bytes (not an installed-app size claim).

Recovery: `/Users/ngawangchime/Desktop/Counting Sheep Retired Assets/legacy-shepherd-20260923`.
[manifest.json](manifest.json) records original paths, checksums, sizes and the baseline Git
commit. The external archive also contains the rejected AI-generated derivative, clearly
labelled. Its original Codex generation-cache file remains outside the repository.
No Git history rewrite, commit, push, purchase or saved appearance migration was performed.

## Current source of truth

`ShepherdAvatarView` in `Views/Components/FarmSharedComponents.swift` renders
`ShepherdStudyCanvas(appearance: ShepherdStudyAppearance(profile: profile))`.
The native Canvas/path/palette and clothing layers are current production artwork despite
“Study” in their compatibility names. Farm, Shop previews, customization, onboarding and
social avatars use this renderer. Use its current rendered exports as visual references.

`output/design/shepherd-body-20260912/revised-companions.png` is a useful visual comparison;
`output/design/wardrobe-layers-20260923/shepherd-shirts-with-coat-and-hat.png` records the
newer independent clothing composition. Historical screenshots remain evidence, not art masters.

## Consumer audit and source cleanup

- Removed 20 unused `AssetSlot.Farm` constants. Repository source searches found no callers.
- Removed the unused Shepherd equipped-bitmap catalog descriptors and their helper/types.
  Shop displays these items through native `ShepherdAvatarView`, including try-on.
- Preserved inventory item IDs, thumbnail metadata, prices, ownership, saved profiles,
  public appearance fields and all native drawing code. Ollie descriptors are unchanged.
- Replaced the obsolete test expecting a hat PNG path with verification that the persisted
  hat item maps to native headwear. Existing purchase/restore/appearance tests remain.
- The common catalog is shared by phone, Watch and Live Activity. No source membership,
  entitlement, target or signing edits were needed; no XcodeGen regeneration was performed.
- Corrected the stale retirement-register instruction to retain the obsolete PNG family,
  and updated asset guidance and launch-film references to identify the actual native source.

## Validation

External archive: every file checksum matched before source removal. Source lookup audit
found no remaining legacy-family names in Swift runtime/test source after cleanup.
`git diff --check` passed. Full Simulator app build succeeded, and the full unit suite
passed: 1,131 tests, zero failures. No physical-device validation is claimed.

Commands (23 September 2026):

```sh
xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/counting-sheep-coat-build -jobs 2
xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=1887D62C-09DF-48D7-8A04-0D32D1640BA2' -derivedDataPath /tmp/counting-sheep-coat-build -jobs 2
```

Logs: `output/counting-sheep-intro-20260923/.tesseract-work/quarantine/build.log`
and `tests.log`. Archive hashes were rechecked after validation; all 41 files match. `assetutil --info`
on the built phone `Assets.car` found no retired `farm_shepherd_` entries.
