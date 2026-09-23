# Coat and clothing layers — 23 September 2026

Founder authorized the first fuller Border Collie coat pack and an independently selected
Shepherd shirt beneath an open coat. This is a local native implementation; no backend,
TestFlight, commit or push is included.

## Behavior

- Ollie has Classic and Fuller coat choices in Shop and his detail wardrobe. Changing coat
  costs no wool and preserves garments, ownership and progression. The 23 transparent painted
  frames cover sit/blink/tilt, run, ear/tongue gestures, settle/rest/rise and Farm idle.
- The shared dressed renderer resolves the whole pack before using it. If any required image
  is missing, it uses Classic throughout. Per-frame ground offsets preserve the existing
  ground anchors, with independent fuller-coat neck/chest registration and fur occlusion.
- Berry Field Shirt costs 6 wool; Open Meadow Coat costs 10. Both are immediate cosmetic
  purchases. Headwear, shirt and outerwear are independently selected. Closed coats hide the
  saved shirt, open coats reveal it, and overalls show its sleeves. Removing any one retains
  the others. The cream shirt is the baseline when no purchased shirt is selected.
- Optional `ShepherdProfile.shirtItemID` and `FarmEquipment.ollieCoatID` preserve absent legacy
  fields and unknown future identifiers on round-trip. Both travel only inside the existing
  private Farm equipment/profile payload. No new public fields are sent.
- Remote avatars never inherit the viewing person's coat. Exact new-layer sharing was
  activated in the [23 September backend rollout](../evidence/campfire-wardrobe-deploy-20260923/deployment.md);
  older clients and servers use the closed moss coat, baseline cream shirt and classic Ollie coat.

## Art and verification

The artwork uses the original app sprites as pose references, with the fuller sitting master
as the coat reference. Each frame was generated individually using built-in ImageGen, then
mechanically downsampled to 512×512 with `sips`, preserving alpha. No procedural fur overlay
or new art dependency is used. Original base art is unchanged. Shepherd clothing uses the
existing textured Canvas paths and palette; the same renderer supplies inventory previews.

Evidence: [review folder](../../output/design/wardrobe-layers-20260923/README.md).
The integrated Simulator build, all 1,128 Xcode tests and 83 persistence tests passed.
All six garments were inspected across 23 poses, with native coat toggling, independent
Shepherd clothing removal and Accessibility 3 checks. Detailed results and remaining
physical-device/social-sharing checks are recorded in the evidence folder.
