# Shepherd native study — first implementation batch

## Scope

A Debug-only native Canvas experiment in the existing iOS app target. No new target, package,
entitlement, backend, catalogue item, or persisted appearance field was added. Production
avatars and purchases continue to use the existing renderer and profile. Screenbook is not
used or expanded.

Launch the existing Debug app with `--shepherd-art-study`. Add `--shepherd-art-export` to
export PNG master sheets into the isolated app's `Documents/ShepherdArtStudy` directory.
Ordinary SwiftUI `#Preview` states are also provided in `ShepherdArtStudyView.swift`.

The harness branches before constructing production services. The normal runtime's model
factory is evaluated lazily by StateObject, keeping the normal view lifecycle from repeatedly
constructing coordinator/notification dependencies.

## Art and motion

- B/pear and C/round are starting head shapes. Boxy and triangular are explicitly labeled
  explorations, not final art approvals. All four use a common rig.
- Head shape, calm/open eyes, short/long hair, five skin tones, shirt/trousers, Moss Coat,
  berry dress, and wool hat are independent local choices without gender restrictions.
- Front, three-quarter, side, back three-quarter and back views plus left/right mirroring.
  Dedicated profile paths replace the web study's horizontal side-view compression.
- Pear/triangular use a small wedge nose; round/boxy use a loop nose. Exporting masters from
  the renderer removes the earlier generated sheet's accidental B-to-C nose substitution.
- 30 Hz, user-started idle/blink and walk-in-place. A 0.9-second step cycle holds each foot
  on the ground for 60% of its cycle; only the recovery foot lifts. Still stops movement.
- Reduce Motion, inactive scenes and invisible views pause continuous scheduling. Manual
  frame stepping remains available. Large accessibility text stacks the comparison canvases.
- One fixed-seed cached grayscale grain image is clipped into native paths. This is an
  approximation of the accepted paper material, not a claim of final painted texture.

## Geometry contract

Master paths live in `ShepherdStudyMasterPaths.swift`; the exporter uses the same drawing
code as the on-screen study. Canvas: 240×280 logical units; head attachment near (123,157),
shoulders near y=174, hips near y=213, standing sole near y=263. The live comparison includes
a 72×72-point canvas, matching the current Farm slot rather than assuming 72 points of opaque
character height. Palette is centralized in `Design/ShepherdStudyPalette.swift`.

The path masters and PNG exports are an editable native art experiment. They are not yet
installed into the production asset catalogue or declared final character artwork.

## Validation

The full generic iOS Simulator build succeeded. After visual repairs, the full iOS build/test
run passed all 925 tests (seven new study tests), with zero failures. Commands:

```sh
xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/counting-sheep-shepherd-native
xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=1887D62C-09DF-48D7-8A04-0D32D1640BA2' -derivedDataPath /tmp/counting-sheep-shepherd-native -resultBundlePath /tmp/shepherd-native-final-tests.xcresult
```

The new tests cover independent appearance choices, hat removal, turn cycling, hidden rear
faces, Reduce Motion/inactive behavior, a grounded supporting foot, loop continuity, invalid
time and brief idle blinking.

Native drawing inspection was completed using macOS SwiftUI ImageRenderer with the same
Canvas/path/palette/motion sources. This found and repaired the missing second front ear,
the far hand being hidden by the coat, and an overly angular mouth. The final exported PNGs
were visually inspected. This establishes drawing output, not iOS screen layout or performance.
Reproduce these exports with `bash output/design/shepherd-native-20260908/export-host-masters.sh`.
The small host driver supplies only the existing skin-tone vocabulary and the sheet layout;
all character drawing comes from the app sources. Files: `bc-native-masters.png` and
`head-shape-explorations.png` (2008×1292 each).

**Blocked iOS UI check:** app install completed, but `simctl launch` stalled before the process
started on two fresh isolated devices (iOS 26.5 and 26.4), including after restarting the first
device. SpringBoard showed incompletely loaded default icons. Boot status completed and unit
tests ran successfully; native study screen interaction, iOS master export, Dynamic Type and
VoiceOver UI checks could not be confirmed. Existing test devices/Farms were not reset or
reused. Retrying after Simulator service recovery is a required follow-up.

## Remaining gates

Physical iPhone appearance, memory/frame pacing, thermal cost, final paper material, and
founder art acceptance are not established by Simulator output. Side-view sleeve overlap,
rear-view depth ordering, hair follow-through and a walk tied to actual Farm displacement
remain art/motion polish before scale. The study does not implement locomotion/pathfinding,
head-shape persistence, Slumber Party appearance transport, neckwear slots, or replacement
of existing paid cosmetics. Those belong to subsequent stages in the integration plan.
