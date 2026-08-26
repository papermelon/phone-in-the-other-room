# UI Visual Revamp Asset Guide

This pass treats the mockups as composition references, not literal screenshots. Home and Farm now use a small asset-backed design system so the product reads as a cozy pixel farm game while preserving responsive SwiftUI layout.

## File Map

- Design tokens and asset names: `PhoneInTheOtherRoomApp/Design/Theme.swift`
- Reusable pixel components: `PhoneInTheOtherRoomApp/Design/PixelComponents.swift`
- Home screen composition: `PhoneInTheOtherRoomApp/Views/PixelHomeDashboard.swift`
- Farm screen composition: `PhoneInTheOtherRoomApp/Views/MVP/AssetReadyScreens.swift`
- Generated source art: `Assets.xcassets/generated_sources/`
- Runtime asset catalog groups: `Assets.xcassets/dog`, `home`, `farm`, `sheep`, `missions`, `stats`

Always reference assets through `AssetSlot` rather than hard-coded strings in screens.

## Generated Source Assets

The source images from the GPT image generation pass are kept for traceability:

- `Assets.xcassets/generated_sources/counting-sheep-sprite-sheet-gpt-image-2.png`
- `Assets.xcassets/generated_sources/farm-background-day-gpt-image-2.png`

The sprite sheet was generated on a flat `#ff00ff` chroma-key background, cropped into individual sprites, converted to PNG alpha, and stored as `.imageset` entries.

## Asset Catalog Contract

| AssetSlot | Asset catalog name | Current size | Replacement guidance |
| --- | --- | ---: | --- |
| `AssetSlot.Dog.idle` | `dog/dog_idle` | 260 x 307 | Transparent PNG. Keep full seated dog visible, centered, 5-10% padding. Target 512 px tall for final art. |
| `AssetSlot.Home.door` | `home/home_door` | 212 x 292 | Transparent PNG. Door plus mat, front view. Keep aspect near 0.72. |
| `AssetSlot.Home.plant` | `home/home_plant` | 190 x 270 | Transparent PNG. Should fit narrow room-side composition. |
| `AssetSlot.Home.window` | `home/home_window` | 222 x 202 | Transparent PNG. Square-ish framed wall picture. |
| `AssetSlot.Home.bedtimeMoon` | `home/bedtime_moon` | 235 x 221 | Transparent PNG. Used as row icon, should read at 48-72 pt. |
| `AssetSlot.Farm.backgroundDay` | `farm/farm_background_day` | 1784 x 882 | Opaque PNG/JPG-style. Wide hero background, about 2:1. Keep center-left clear for sheep overlay. |
| `AssetSlot.Farm.barn` | `farm/farm_barn` | 277 x 262 | Transparent PNG. Used as compact upgrade icon. |
| `AssetSlot.Farm.fence` | `farm/farm_fence` | 275 x 181 | Transparent PNG. Used as compact upgrade icon. |
| `AssetSlot.Sheep.common` | `sheep/sheep_common` | 272 x 251 | Transparent PNG. White sheep with black face. Must read at 34-168 pt. |
| `AssetSlot.Sheep.cream` | `sheep/sheep_cream` | 271 x 251 | Transparent PNG. Cream sheep variant. |
| `AssetSlot.Sheep.black` | `sheep/sheep_black` | 278 x 253 | Transparent PNG. Dark sheep variant with visible outline. |
| `AssetSlot.Sheep.golden` | `sheep/sheep_golden` | 277 x 250 | Transparent PNG. Merino/ram variant with horns. |
| `AssetSlot.Missions.awayIcon` | `missions/mission_away_icon` | 214 x 245 | Transparent PNG. Stopwatch icon, should fit square green tile. |
| `AssetSlot.Missions.dailyIcon` | `missions/mission_daily_icon` | 219 x 216 | Transparent PNG. Calendar icon. |
| `AssetSlot.Missions.achievementIcon` | `missions/mission_achievement_icon` | 190 x 224 | Transparent PNG. Medal/badge icon. |
| `AssetSlot.Stats.phone` | `stats/stats_phone` | 153 x 233 | Transparent PNG. Purple phone, should read at 38-52 pt. |
| `AssetSlot.Stats.watch` | `stats/stats_watch` | 184 x 238 | Transparent PNG. Watch with green check. |

## Replacement Specs

- Use PNG with transparency for sprites and icons.
- Keep pixel art crisp: no blur, no vector-style gradients, no photographic rendering.
- Use transparent padding rather than cropping to the exact outline; most components rely on `.aspectRatio(.fit)`.
- Avoid text inside art. All labels should remain SwiftUI text for localization and dynamic layout.
- Use black or very dark outlines so assets stay legible on cream cards and green panels.
- Keep `farm_background_day` opaque and wide. If replacing it, preserve a clear center-left character zone and barn/right-side composition.
- For new sheep variants, add the `.imageset`, then add a constant to `AssetSlot.Sheep` and map it in `FarmSheepFigure`.

## Design System Rules

- `PixelAssetImage` is the common image renderer. It uses `.interpolation(.none)` and `.antialiased(false)` to preserve pixel edges.
- Home should remain lower-density than the old prototype: focus progress, room hero, primary CTA, three status cards, weekly comparison, and a short action stack.
- Farm should use the wide hero background and larger sheep sprites; mission rows should not force manual line breaks.
- Typography should stay monospaced/black only for headers, counters, and game labels. Body copy should be shorter and allowed to wrap naturally.
- Cards use restrained rounded corners and light strokes. Avoid nested card-on-card layouts unless the nested element is a repeated item or an intentional overlay.

## Original Image Prompt

Built-in GPT image generation was used. The asset-sheet prompt requested a cozy mobile-game pixel art sprite sheet on `#ff00ff` chroma key with Ollie, room props, sheep variants, farm icons, mission icons, and stats icons. The farm background prompt requested a wide pixel-art pasture card with hills, fence, barn on the right, and open center-left space for a sheep overlay.
