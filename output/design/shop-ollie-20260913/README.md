# Shop and Ollie — local implementation evidence

13 September 2026. This is local source and Simulator evidence; no archive, TestFlight upload,
backend deployment or new sharing activation was performed.

## Delivered

- All six existing Ollie purchases use fitted paper garments rather than inventory cutouts.
- The same composition is used in Home idle, Farm, Shop and all six active chase frames, including
  the independent morning journey. Pose registration covers the entire existing motion manifest.
- The 18 non-character objects (eight decorations, six keepsakes, four capacity upgrades) use
  native paper illustration in inventory and their existing placed/shelf appearances. The seven
  existing fitted Shepherd items continue using the same paper renderer.
- Detail sheets offer sitting/running/resting wardrobe previews and actual owned-item actions.
  Purchase behavior is explained before spending wool. Locked art stays visible; insufficient-wool
  button labels fit narrow cards. Keepsakes wrap into rows on narrow/large-type screens.
- IDs, costs, unlocks, storage schema, purchase transactions and equipment slots are unchanged.
  The preexisting build-number change to 49 is preserved; this work did not change project.yml.
- [Collection-by-collection review and campfire proposal](../../../docs/plans/shop-ollie-and-campfire-2026-09-13.md).

## Visual inspection

The DEBUG-only `--shop-wardrobe-qa` route creates a unique disposable defaults suite and Farm
storage directory with external services disabled. It never reads or resets the founder's Farm.

- [Small-phone preview](detail-dark-se.png): fitted Moss Bandana, pose controls and purchase explanation.
- [Large-text preview](detail-large-type-se.png): accessibility3, narrow iPhone SE. Content wraps and scrolls.
- [Home](home-dark-se.png), [Farm](pasture-dark-se.png), [active journey](journey-dark-se.png): production
  components inside the isolated fixture, including the same equipped bandana. The fixture is
  intentionally surrounded by empty space; it is not a redesigned app shell.
- [Moss Bandana](shop-art-review/ollie_moss_bandana.png), [Moon Kerchief](shop-art-review/ollie_moon_kerchief.png),
  [Brass Farm Bell](shop-art-review/ollie_brass_bell.png), [Clover Collar](shop-art-review/ollie_clover_collar.png),
  [Sunrise Scarf](shop-art-review/ollie_sunrise_scarf.png), [Star-Keeper Cape](shop-art-review/ollie_star_keeper_cape.png):
  six native ImageRenderer proof sheets, each with 17 representative registered poses.
- [Farm objects](shop-art-review/farm.png), [keepsakes](shop-art-review/collectibles.png),
  [pasture upgrades](shop-art-review/barn.png): native inventory proofs. No image-generation mock
  is substituted for the actual SwiftUI renderer.

[Native UI interactions](native-interactions.txt) checked: Take off → success alert → Wear; Wear → named success alert →
Take off; Sitting → Running changes the rendered pose and accessibility description; Resting
shows the cape folded over Ollie's back. A 4-wool Brass Farm Bell purchase reduced the fixture balance from 5 to 1, equipped the bell,
and retained Moss Bandana as owned. Accessible labels describe the item and preview pose.
Physical VoiceOver speech/gestures and system Reduce Motion remain device acceptance work.
The active journey fixture explicitly uses its Reduce Motion path; no actual shield was requested.

Visual repair loop: removed the hollow neck rim; fitted chase/curled poses; retained folded cape
fabric at rest; corrected the Moon Gate crescent and banner flower contrast; registered each
placed object's ground edge; wrapped the keepsake shelf. Initial preview compilation rejected
an attempted override of a read-only environment value; it was removed before successful builds.

## Validation

```sh
xcodegen generate
xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/counting-sheep-shop-build
xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=A0DB65B8-F3FC-4961-8B0C-9689F51C9EA1' -derivedDataPath /private/tmp/counting-sheep-shop-build -resultBundlePath /private/tmp/counting-sheep-shop-tests-final.xcresult
git diff --check
```

- [Final app build](build-final.log): **BUILD SUCCEEDED**, affected app and dependent targets.
- [Final full unit suite](tests-final.log): **1,006 tests, zero failures**. Includes four new
  wardrobe tests for complete item/pose coverage, rest/run registration differences, unknown-item
  rejection, purchase/re-equip ownership, and save/restore. Existing economy, migration and
  animation tests remain passing.
- Existing unrelated Supabase initializer deprecation warnings remain.
- Source membership was regenerated from project.yml. The starting unrelated project changes are
  saved in [preexisting-project.patch](preexisting-project.patch); they were preserved.
- The campfire interaction study was checked in the in-app browser: Phone Away → intention →
  shared-session appearance and Wind Down → appearance, both before the lantern is earned.
  This is local simulated UI only. A scene-height overlap was fixed and rechecked.

## Review and remaining gates

Local review: no known blocking implementation issue remains in the authorized Shop/Ollie pass.
Risk is medium: shared visual components changed, without new persistence, session transitions,
permissions or social transport. Native artwork retains per-object pixel/asset fallbacks for
future unsupported items; legacy PNGs have not been deleted or claimed as bundle savings.

Campfire presence, temporary seating, activity labels and versioned consent/capability were subsequently
implemented and validated in the [campfire pass](../campfire-20260913/README.md). The shared lantern retains
its 12-contribution behavior. Hosted deployment remains pending.
Physical device acceptance and any authorized release/rollout remain in the project backlog.
