# Asset Naming

This project is asset-ready but intentionally does not include final artwork yet. SwiftUI placeholders should be replaced later by adding image assets with the names below and swapping the drawing internals of the reusable placeholder components.

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
```

Use the closest group for final PNG/SVG/PDF assets. If Xcode namespace lookup is used later, keep code references centralized in `AssetSlot` inside `PhoneInTheOtherRoomApp/Design/Theme.swift`.

## Image Expectations

- Use PNG for pixel art, textured illustrations, and sprite sheets.
- Use single-scale vector PDF or SVG only for simple icons that must scale cleanly.
- Keep transparent backgrounds for characters, sheep, props, icons, rewards, badges, and overlays.
- Keep environment backgrounds opaque unless they are foreground/depth layers.
- Export pixel art at exact integer scale. Avoid fractional scaling in source art.

## Recommended Sizes

Initial target sizes:

- Dog full-body state: `512x512`
- Dog head/bust: `256x256`
- Sheep variant: `256x256`
- Farm prop: `256x256` to `512x512`
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

