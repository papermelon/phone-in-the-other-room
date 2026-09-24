# Wardrobe expansion study and current combination checks

22 September 2026. [Full expansion study](../../../docs/plans/wardrobe-expansion-2026-09-22.md).

## Deliverables

- `concept-board.png`: exploratory breed/coat, Shepherd layering and Farm/keepsake board.
  Generated with the built-in image tool. Exact prompt: [image-prompt.txt](image-prompt.txt).
  References: `../shepherd-body-20260912/revised-wardrobe.png`,
  `../ollie-garment-integration-20260920/ollie_moss_bandana.png` and
  `../shop-ollie-20260913/shop-art-review/farm.png`.
  Visual review: coherent painted palette and broad silhouettes; simplify tiny seams,
  checks and prop details for runtime. No generated images were added to the asset catalogue.
- `shepherd-combinations.png`: actual production renderer, all 3 hats × 4 outfits, long hair.
  Both selections are visible together; this is separate from the generated concept art.
- `wardrobe-se-hat-and-coat.png`: actual iPhone SE simulator after changing Moss Work Coat to
  Moonlit Coat while retaining Wool Field Hat.
- `wardrobe-se-accessibility.png`: same screen at accessibility3, with stacked rows and full
  item/action labels. Pinned preview retains both equipment choices.

## Implemented scope

The existing independent headwear/outfit state was correct. The owned wardrobe now visibly
groups Headwear and Clothing, Shop detail explains which selection changes, and VoiceOver
labels identify the exact Wear/Take off item plus the preview's current equipment. Rows stack
at accessibility sizes. No new garment slots, breeds, coat choices or catalogue items ship
in this exploration.

## Validation

Build: **BUILD SUCCEEDED**. Full suite: **TEST SUCCEEDED**, 1,124 tests, zero failures.

```sh
xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/counting-sheep-coat-build -jobs 2 ARCHS=arm64
xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=1887D62C-09DF-48D7-8A04-0D32D1640BA2' -derivedDataPath /tmp/counting-sheep-coat-build -jobs 2 ARCHS=arm64
```

Full logs: `build.log`, `tests.log`. Test build includes final UI/fixture changes.
Touched code fingerprints: `source-sha256.txt`. `git diff --check` passed.

The combination regression covers each hat/outfit pair in both purchase orders, same-position
replacement, removing either item, re-equipping, Farm JSON round-trip and the existing public
appearance decode/render path. Private backup coverage now includes both a coat and hat.

Manual simulator checks used `--shop-wardrobe-qa --shop-mode=wardrobe`, a random disposable
Farm directory/defaults suite with external services disabled. Removed and restored the hat
without losing the coat, then changed coat without losing the hat. The accessibility tree
confirmed both equipment names. Large text checked with `--shop-large-type`. Contact sheet:
`--shop-capture-art --shop-capture-shepherd`.

This is simulator/AX inspection, not physical-device VoiceOver or multi-account delivery
validation. The build emitted existing AppIntents metadata and Watch debug-fixture warnings.
No deployment, distribution, commit or push was performed.
