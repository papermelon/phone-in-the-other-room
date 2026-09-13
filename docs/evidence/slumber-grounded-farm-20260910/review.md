# Grounded shared Farm and stable member updates — 10 September 2026

Source implementation authorized after the founder reported member-sheet flashing and floating
characters. Scope: native refresh presentation and shared Farm composition; no backend, membership,
reward, consent, or four-tab changes. Unrelated working-tree edits preserved.

The member sheet formerly interpreted every observation state except `current` as stale. A normal
`current → refreshing → current` cycle inserted and removed the connection warning and retry button.
The observation enum now lives in Shared and exposes a warning only for an actual stale state;
explicit refresh failures still show recovery. A small indicator overlays the existing portrait
region, leaving the card layout unchanged. Reduce Motion uses a static refresh icon.

The shared Farm uses a generated paper-textured dusk meadow, fixed ground line and dark contact
shadows. Original production character renderers preserve chosen identities, heads and outfits.
Shepherds are larger than seated companions. Names appear on paper below the scene, with a separate
“You” line and a subtle ground selection ring. Stable membership ordering is unchanged. Each meadow
holds at most two people, or one at accessibility text sizes; the accessible list remains available.

Artwork: built-in image-generation tool, 1536×1024 original copied into
`Assets.xcassets/farm/farm_shared_meadow_dusk.imageset`. The exposed tool did not offer a model-version
selector; no claim is made that a particular requested model version was selected. The original
Farm background remains available to other screens. No generated characters or names are baked in.

Visual inspection uses the production views through the existing isolated native fixture entry,
with Clover (outfitted Shepherd) and Moss (bandana-wearing Ollie), never the founder’s Farm.
Initial inspection caught and repaired an adaptive light shadow and an empty toolbar decoration.

## Final validation

- Generic iOS Simulator app build passed; full suite **940 tests, zero failures**.
  [Validation summary](validation.txt). Logs and `tests-final.xcresult` are under
  `/tmp/slumber-grounded-20260910`.
- Regression exercises repeated current/refreshing cycles, initial loading and real stale states.
- Final current/refreshing captures are pixel-identical below y=750 (portrait ends above this),
  including the headline, update card and receipts: [comparison](layout-comparison.txt).
- Inspected light/dark layouts, SE-size screen, eight members at accessibility3, named button
  traits/hints, list expansion and selection. Moss opened Moss’s update; River opened River’s
  no-update state. No private account, network publication or founder Farm used.
- Reduce Motion is read from the real system environment: the meadow has no animation and the
  progress overlay switches to a static icon. Physical VoiceOver speech and Reduce Motion device
  confirmation remain in the backlog; Simulator AX inspection is not that physical evidence.
- No backend change or release upload in this batch. These production views need a new installed
  build before the founder’s phone can show the native repair.

Commands:

```sh
xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator'
xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=60935BFC-7044-4BE8-9712-7D1B6C568A16'
```

## Actual native captures

[Farm — dark](farm-dark.png) · [light](farm-light.png) · [small screen](farm-small-final.png) ·
[eight-member accessibility view](farm-accessibility.png)

[Member current](member-current-final.png) · [refreshing](member-refreshing-final.png) ·
[failed refresh](member-stale.png)

