# Asset Naming

This project keeps the reusable SwiftUI fallback components, while importing final artwork in
small, reviewable batches. A generated sheep batch should only be added to
`Assets.xcassets/sheep` after its style has been approved against the Farm references.

## Format

Use lower snake case:

```text
category_subject_variant_state
```

Recommended categories:

- `dog`
- `sheep`
- `farm`
- `home`
- `mission`
- `stats`
- `ui`
- `icon`
- `reward`
- `shop`
- `badge`
- `sfx`

Examples:

- `dog_idle`
- `dog_sleeping`
- `dog_focused`
- `sheep_common`
- `sheep_common_white`
- `sheep_golden`
- `farm_fence`
- `farm_barn`
- `home_bed`
- `mission_daily_icon`
- `ui_progress_ring`

## Asset Catalog Groups

The iOS asset catalog now has namespace groups for:

```text
Assets.xcassets/dog
Assets.xcassets/sheep
Assets.xcassets/farm
Assets.xcassets/home
Assets.xcassets/missions
Assets.xcassets/stats
Assets.xcassets/ui
Assets.xcassets/icons
Assets.xcassets/shop
```

Use the closest group for final PNG/SVG/PDF assets. If Xcode namespace lookup is used later, keep code references centralized in `AssetSlot` inside `PhoneInTheOtherRoomApp/Design/Theme.swift`.

## Image Expectations

Current Farm environment direction: paper-textured illustration for the personal and shared
Farm, barns, meadows and related scenery. Preserve existing character renderers and fitted
cosmetics. Pixel-art guidance below applies to assets intentionally retained in that style;
it does not require new Farm scenery to remain pixel art. See the
[scenery migration and retirement register](plans/farm-art-retirement-2026-09-12.md).

- Use PNG for pixel art, textured illustrations, and sprite sheets.
- Use single-scale vector PDF or SVG only for simple icons that must scale cleanly.
- Keep transparent backgrounds for characters, sheep, props, icons, rewards, badges, and overlays.
- Keep environment backgrounds opaque unless they are foreground/depth layers.
- Export pixel art at exact integer scale. Avoid fractional scaling in source art.

## Asset lifecycle

Only approved runtime artwork belongs in the asset catalog. Put generation working files in
ignored `tmp/imagegen/`; keep necessary masters/provenance outside runtime resources. Record
superseded artwork as a retirement candidate, migrate consumers, check dynamic IDs/fallbacks and
all affected targets, then remove the unused files once recovery is established. Do not retain
every old version in the catalog or delete uncommitted work on the assumption Git has a copy.
The [retirement register](plans/farm-art-retirement-2026-09-12.md) owns candidates and checks.

## Shop thumbnails and equipped render art

Keep Shop inventory artwork separate from production character rendering:

- Inventory thumbnails use the `shop/` namespace, explicit `shop_` names, and the 384×384
  transparent illustration canvas. These are displayed in catalogue cards and may also be used
  as standalone Farm decoration or keepsake art when the item is not attached to a character.
- Equipped Ollie accessories use the `dog/` namespace with an explicit
  `farm_..._equipped_overlay` suffix. The neutral Ollie base and every accessory overlay share
  the exact same transparent full-body canvas and alignment origin.
- Shepherd bodies, hair and clothing use the native `ShepherdStudyCanvas` renderer through
  `ShepherdAvatarView`. Use current production renders as visual references; the old
  large-eyed `farm_shepherd_*` raster family is retired and must not be regenerated,
  reimported or used as a style reference. See the [retirement record](evidence/legacy-shepherd-retirement-20260923/README.md).
- Character render code must choose the equipped render asset from the persisted item ID and
  must never resize or position a 384×384 Shop thumbnail over a character. Missing render art
  should leave the owner/equipment state intact and show the base character or a code-native
  fallback.

### Ollie neckwear fitting

The six current Ollie garments use code-native paper artwork in `OllieDressedSprite`, with
per-frame neck-left, neck-right and bib-tip landmarks in `OllieNeckwearPose`. The neckline
follows the neck while the bib stays against the chest; a registered cut restores the original
sprite's chin/ruff over the tucked-in cloth. The same canvas transform must place the base,
cloth and occluding fur. Do not replace this with a single position/rotation shared by every
Home frame, or stretch a separate clothing canvas to a non-square view.

New colours/motifs can reuse a validated garment silhouette. Different silhouettes need
their own fit and overlap review, including all Home/blink/tilt, run, settle/rest/rise and
Farm-neutral frames. Keep texture attached to cloth coordinates. Use the production motion
timings in previews; inspect at Home and small Farm/chase sizes, in both directions, against
light and dark backgrounds. Reduce Motion must provide a stable fitted pose. Metadata
coverage tests do not establish visual fit. Add a garment by choosing one of the existing
fitted patterns (kerchief, collar, scarf or cape), rather than placing a Shop thumbnail over
Ollie's sprite.

### Expansion: coat packs and independent clothing

The [22 September expansion study](plans/wardrobe-expansion-2026-09-22.md) defines candidate
collections and their worn/placed destinations. A breed or longer coat changes Ollie's base
silhouette across the complete production motion pack, with its own garment registration and
ground contact. A generic neck overlay is not a coat-length asset. Review sit, run and rest
masters before authoring the remaining frames; only complete, visually validated packs become
selectable. The current Border Collie remains the fallback.

Shepherd headwear and clothing already render independently. Extend this rule to new positions:
tops, outerwear, bottoms, footwear, neckwear and carry items replace only their occupied slots.
Coverage by another garment must not erase a selection. Author overlap for hair/hat, shirt/coat,
collar/scarf and bag/arm combinations. Keep existing whole-outfit IDs compatible when introducing
separate layers, and show a combined try-on using the current appearance before purchase.

## Recommended Sizes

Initial target sizes:

- Dog full-body state: `512x512`
- Dog head/bust: `256x256`
- Sheep variant: `256x256` minimum; generated full-body sprites may be larger and are scaled
  by the image set at runtime.
- Farm prop: `256x256` to `512x512`
- Farm Shop inventory object: `384x384` with a transparent background
- Home prop: `256x256` to `512x512`
- Full background: `1290x2796` for iPhone portrait source, with safe-area bleed
- Mission/reward/stat icon: `96x96` or vector PDF
- Reward card art: `512x384`
- Watch icon/mini character: `128x128` to `256x256`

## P0 Names To Reserve

Dog:

```text
dog_idle
dog_happy
dog_sleeping
dog_waiting
dog_focused
dog_proud
dog_concerned
dog_sad_gentle
dog_surprised
dog_collar_default
dog_collar_blue
dog_bandana_focus_blue
dog_hat_straw
dog_badge_sheep_finder
```

Sheep:

```text
sheep_common_white
sheep_cream
sheep_fluffy
sheep_black
sheep_spotted
sheep_curly_wool
sheep_golden
sheep_barbary
sheep_corriedale
sheep_merino
sheep_night
sheep_streak
sheep_guardian
```

Farm and home:

```text
farm_background_day
farm_background_empty
farm_barn
farm_fence
farm_sheep_pen
farm_windmill
farm_hay_bale
farm_signboard
home_room_day
home_room_evening
home_bed
home_window
home_rug
home_plant
home_phone_away
```

Missions, UI, and icons:

```text
mission_daily_icon
mission_weekly_icon
mission_achievement_icon
mission_event_icon
ui_card_mission_default
ui_card_reward_default
ui_progress_ring
ui_progress_bar
ui_empty_farm
ui_error_watch_disconnected
icon_tab_home
icon_tab_farm
icon_tab_missions
icon_tab_friends
icon_tab_stats
icon_device_watch_connected
icon_device_phone_away
```


23 September first coat pack: `dog/dog_fuller_classic_home_idle_frame_01…06`,
`dog/dog_fuller_classic_run_frame_01…06`, `dog/dog_fuller_ollie_motion_pose_02…11`,
and `dog/dog_fuller_classic_farm_idle`. These are complete painted bases, not fur overlays.
All exports are transparent 512×512. `OllieFullerCoatRegistration` records ground offsets and
neck landmarks against those exports. A missing member disables the whole fuller pack.
See [implementation and evidence](plans/wardrobe-layers-2026-09-23.md).
