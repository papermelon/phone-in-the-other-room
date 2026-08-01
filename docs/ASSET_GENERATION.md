# Generated Asset Notes

The checked-in asset catalog is the source of truth for the current sheep art. Character
sprites should be generated as a separate art-import pass, then chroma-keyed to transparent
PNGs before they are referenced by the catalogue. SwiftUI keeps a placeholder fallback so an
incomplete art batch never blocks a build.

## Workspace Assets

- `OllieKeyArt`: in-app focus pasture/key-art backdrop.
- `OllieAppIcon`: app icon source image.
- `OllieMascot`: shared iPhone/Watch mascot image.
- `RewardLetter`, `RewardTennisBall`, `RewardRibbon`, `RewardSheepBadge`, `RewardFieldMap`, `RewardPostcard`, `RewardTrophy`, `RewardMuddyPaw`, `RewardStick`, `RewardOllieMail`: cropped reward collectibles from the generated reward sheet.

## Prompt Notes

The sheep batch uses one reference-conditioned illustration language, but not one silhouette:
compact storybook sheep, limited palette, simple ink-like outline, subtle paper texture, and
readable breed traits. The current breed pass covers smooth common/cream wool, long fluffy
locks, spotted fleece, tight Merino curls with horns, slate night wool, and a broad Guardian
ram. Accessories remain a separate identity layer (names, ribbons, glasses, bells, and so on)
so two sheep can share a breed without becoming duplicates. Generated source files and
chroma-key helper outputs belong in the local `tmp/imagegen/` working area; only the approved
transparent PNGs are imported into `Assets.xcassets`.
