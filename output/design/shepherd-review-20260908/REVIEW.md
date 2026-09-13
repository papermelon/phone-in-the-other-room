# Shepherd design review — 8 September 2026

Status: founder accepted third-study B and C as head-shape customization directions. A has generation defects and is not accepted. Wardrobe exploration follows; no integrated production artwork.

The founder is satisfied with Ollie and the sheep and requested that the human Shepherd adopt their art style. Those animals are the references for this revision.

## Findings

- The existing Shepherd has a large head and eyes and a flat frontal torso. The latest founder correction explicitly favors its cartoon simplicity and proportions; these are useful references, not defects to replace with realistic anatomy.
- The Moss Work Coat Shop thumbnail is pixelated and shows a structured coat with collar, cuffs, buttons, and pockets; the equipped appearance does not deliver that garment.
- `Shared/FarmShopCatalog.swift` declares fitted overlays for all four Shepherd outfits, but none of those four imagesets exists in the current catalogue.
- `ShepherdAvatarView` in `PhoneInTheOtherRoomApp/Views/Components/FarmSharedComponents.swift` falls back to a solid template-color outfit mask when the equipped asset is absent. This explains the green recoloring; it does not establish that skin pixels are being recolored.

## Revised design

Use soft paper texture as the shared app illustration standard. Return to the original Shepherd's oversized head, tiny body, simple mitten hands, and broad shapes. Take facial inspiration from the supplied Moomin cartoons: oval eyes with small pupils, spare nose and mouth lines, and slight irregularity. Avoid realistic anatomy, modeled facial shading, hair strands, fingers, or detailed garment folds. Preserve gender-neutral personalization and all existing skin-tone and hairstyle choices.

The second board is superseded: the founder found all three studies too complicated and realistic. The third board uses the original Shepherd and supplied Moomin examples directly. Its B and C head shapes are accepted for customization; they are not personality classes. Head-shape selection is an authorized product direction, with implementation and backward-compatible persistence still outstanding.

## Wardrobe exploration

See `wardrobe-study.png` for everyday clothes, a proposed striped shirt, Moss Work Coat, and Field Overalls on both B and C. See `headwear-study.png` for hat-off, Wool Field Hat, Moon Beanie, Clover Headscarf, Moonlit Coat, and a proposed neckerchief combination. Striped shirts and a separate neckerchief are exploratory additions, not currently purchasable catalogue items. No new prices are proposed.

The intended visual behavior is stable identity: equipping an item changes only that garment or accessory, and removing it restores the underlying art. Hats fit each head shape and hide the appropriate hair; removing a hat restores that hair while preserving clothing. Separate neckwear layering is a concept, not evidence that the existing single accessory slot supports stacking. Purchase preview should depict the same fitted item as the equipped avatar; purchase ownership and worn state remain separate.

Show the same person in everyday clothing and the Moss Work Coat. The coat needs a distinct hem, sleeves, cream collar and cuffs, large pockets, and brass buttons. Face, hands, hair, trousers, and boots retain their identity and colors. The concept board is a style study; its companion animals are reference depictions, not replacements for approved assets.

## Production work remaining

1. Create aligned transparent masters for accepted B and C head shapes across the five hairstyles, preserving five skin-tone choices and subtle paper texture. Add backward-compatible head-shape selection without changing existing ownership. Settle wardrobe concepts before producing their complete fitted asset matrix.
2. Produce fitted garment artwork for Moss Work Coat, Moonlit Coat, Field Overalls, and Star-Keeper Cloak. Share garment coordinates only where the body geometry actually matches. Separate back hair, clothing, hands, and front hair where overlap requires it.
3. Refit headwear for all hairstyles. Redraw Shop thumbnails in the same style as their equipped garments.
4. Replace the color-only missing-garment fallback with a truthful base-avatar presentation while retaining owned/equipped IDs. Verify missing-art behavior and unchanged account/purchase persistence.
5. Inspect all hairstyle/skin/outfit/headwear combinations and check real displays at 58, 72, 84, 180, and 210 points, on light and dark backgrounds. Check alpha edges and clothing occlusion; run the app build and unit merge gates after integration.

No production sprites, runtime code, ownership, prices, or purchases were changed in this review. No app build or physical-device validation is claimed.

Generation: built-in imagegen. First study retained as `shepherd-concept.png` with `prompt.txt`; second uses `shepherd-faces-v2.png` with `prompt-v2.txt`; third uses `shepherd-cartoon-v3.png` with `prompt-v3.txt`.
