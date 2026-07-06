# Implementation Notes

## Source Documents

The MVP skeleton was implemented from:

- `phone_in_the_other_room_product_blueprint.md`
- `phone_in_the_other_room_screen_production_spec.md`
- `phone_in_the_other_room_asset_inventory.md`

The screen production spec file is a reviewed prompt/spec scaffold rather than a completed screen-by-screen deliverable, so the implemented MVP screen list follows its listed MVP candidates plus the product blueprint's final recommended IA.

## Navigation

The iPhone app now uses the blueprint tab order:

```text
Home
Farm
Missions
Friends
Stats
```

Dog is not a bottom tab because the product blueprint explicitly recommends Doghouse as a global destination. Doghouse is reachable from Home. Settings and onboarding placeholders are also reachable from Home/top bar.

## Reusable Placeholders

Reusable components live in:

```text
PhoneInTheOtherRoomApp/Views/Components/AssetPlaceholderComponents.swift
```

Key components:

- `DogSpriteView`
- `SheepSpriteView`
- `MissionCard`
- `RewardCard`
- `ProgressRing`
- `ProgressBar`
- `FarmTileView`
- `StatsCard`
- `FocusSessionCard`
- `AssetPlaceholderView`

These are deliberately SwiftUI shape/icon placeholders. Final artwork should be integrated by replacing component internals with `Image(assetName)` calls or by creating image-backed variants while keeping call sites stable.

## Theme

Design tokens live in:

```text
PhoneInTheOtherRoomApp/Design/Theme.swift
```

The theme defines:

- `AppColors`
- `AppSpacing`
- `AppRadius`
- `AppTypography`
- `AppShadows`
- `AssetSlot`

`AssetSlot` is the central place to keep predictable asset names in code.

## Mock Data

Mock data lives in:

```text
PhoneInTheOtherRoomApp/MockData/MVPMockData.swift
```

It covers:

- focus sessions
- sheep collection
- Ollie dog state
- missions
- rewards
- screen-time/statistics fallback
- farm unlocks/decorations
- simple friend feed

The mock layer is app-only and does not affect the deferred Watch source, shared proximity models, or deferred Screen Time report source.

## Existing Integration Safety

The existing Focus Run, Watch proximity, Screen Time authorization, FamilyControls selection, DeviceActivity report, and Health sleep scaffolding were left in place. The new Stats surface adds populated mock cards as a fallback while keeping the existing Screen Time setup and report rows in `FocusStatsView`.

## Temporary Local Build Mode

The default `PhoneInTheOtherRoom` app target is currently configured for no-sign local build testing:

- The generated Xcode project currently includes only the iPhone app target and test target.
- The Watch app target source remains on disk, but the target is omitted from `project.yml`.
- The Screen Time report extension source remains on disk, but the target is omitted from `project.yml`.
- The app target does not use the Family Controls entitlement.
- FamilyControls and DeviceActivity code is behind the explicit `SCREEN_TIME_REPORTS` compilation flag.
- `CODE_SIGNING_ALLOWED` is set to `NO` for the app target.

This is intentional until a paid Apple developer account and the required Family Controls capability are available. To re-enable the full production surface later, add the Watch app and Screen Time report extension targets back to `project.yml`, restore the Family Controls entitlement, add `SCREEN_TIME_REPORTS` to the relevant Swift active compilation conditions, set a real development team, and run `xcodegen generate`.

Known entitlement/signing risk for the deferred targets:

- FamilyControls and DeviceActivity require Apple entitlements and a properly signed iOS target.
- The project currently has `DEVELOPMENT_TEAM` blank in `project.yml`, so device builds will need local signing configuration when no-sign mode is removed.

## Replacing Placeholders Later

Recommended replacement flow:

1. Add final assets to the matching `Assets.xcassets` namespace group.
2. Add or confirm the asset name in `AssetSlot`.
3. Replace the relevant SwiftUI shape inside `DogSpriteView`, `SheepSpriteView`, `FarmTileView`, or `AssetPlaceholderView`.
4. Keep screen call sites unchanged unless the asset needs new state-specific behavior.
