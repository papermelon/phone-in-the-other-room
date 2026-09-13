# Shepherd movement prototype — 8 September 2026

Status: interactive design experiment, not app integration or final animation artwork.

Open `shepherd-motion.html` as the inline study; `preview.html` is its standalone local validation wrapper. `turnaround-study.png` is a generated concept reference (built-in imagegen; exact prompt in `prompt-turnaround.txt`).

## What is implemented

- Both accepted head-shape directions, B and C.
- Independent short/long hair, five skin tones, three outfit silhouettes, and removable wool hat. Shirt and trousers, a berry dress, and a moss coat support masculine, feminine, and neutral presentation without gender locks; any combination is selectable.
- Front, three-quarter, side, back three-quarter, and back drawings, with left/right mirroring.
- User-started idle sway/blink, walk-in-place limb movement, stopping, turning, and manual walk-frame stepping. Motion does not start automatically. Reduced Motion suppresses continuous movement and retains manual pose stepping.
- Large 220-pixel canvas and 72-pixel Farm-size canvas. These sizes describe the complete canvas, including padding.
- A layered vector rig with a procedural paper-grain approximation, suitable for testing joints and overlap. It is not a replacement for the accepted generated/painted artwork and does not prove export, native performance, or physical-device quality.

## Decisions for the next production slice

1. Keep oversized heads, tiny bodies, mitten hands, oval eyes, and economical face lines. B and C remain separate head choices. Avoid realistically modeled cheeks, hair strands, or clothing folds.
2. Use one shared joint arrangement initially. Clothing defines different silhouettes; appearance choices do not carry gender restrictions. New head shapes should be tested with identical hair/eyes before expanding the matrix.
3. Start with outfit, headwear, and neckwear concepts as separate visual slots. Existing app persistence still has its current slots; neckwear stacking and head-shape persistence require explicit compatible implementation before shipping.
4. Use layered motion plus angle-specific drawings. Do not generate the full Cartesian product as unrelated whole-character pictures. Shared body coordinates and controlled head/hair/hat fitting should keep identity stable.
5. Keep painted paper texture anchored to each part. The prototype filter approximates the surface; final texture strength and grain size must be matched to approved Ollie/sheep art at actual display size.
6. Use five view directions for review. Side/back silhouettes need dedicated drawing; mirrors are suitable only for symmetric garments. Future asymmetric insignia, pockets, hair, or carried objects need explicit left/right art.

## Layer and alignment contract

The experiment uses a 240×280 logical canvas, feet near y=266, shoulders around y=174, hips around y=218, and head attachment near (123,157). These are provisional rig coordinates, not an approved asset-catalogue size. Native masters must be normalized to one chosen production canvas and baseline before exports.

Layer ordering: rear hair, neck, far leg/near leg, far arm, garment torso, near arm, head, facial features, front hair, hat. In the back view, the hair mass moves over the head and upper garment; eyes and front pockets/buttons disappear. The current walk is a simple rotation experiment; production should adjust far/near limb order with the view, plant feet convincingly, and tune short hair/long hair follow-through.

Headwear must cover the hair crown while keeping the correct exposed hair. Hat removal restores the exact prior head and hair; outfit changes must preserve skin, head, hair, hat, and ownership. Purchases are not simulated and no account or catalogue data is changed.

## Actual validation

`node output/design/shepherd-motion-20260908/check-prototype.cjs` passed. The local harness exercised 600 combinations of head, hair, clothing, skin, viewing direction, and mirroring. Each toggled the hat on/off and verified exact restoration, valid rendering strings, and absent facial features from rear views. It also checked walk changes, stopping, turning, stepping, idle controls, and Reduced Motion behavior. This is logic evidence, not exhaustive visual inspection.

Browser inspection: controls changed appearance; walking and stopping worked; a C/long-hair/dress/hat combination was inspected in three-quarter and back views. Layout inspected at 360 and 736 pixels wide, with 220- and 72-pixel character canvases. Initial browser inspection found a head/body gap; a neck attachment was added and the updated preview inspected. Idle was checked after its addition. No browser-based reduced-motion emulation, dark-mode screenshot, native build, or physical-device check is claimed.

## Limitations before scale

- The SVG rig is a motion study, not exact final art. Side/rear geometry is approximate; frame-to-frame foot planting and body weight need polish. Walking is in place, not Farm navigation/pathfinding.
- The generated turnaround has small identity drift, including B's front-view nose. It is not a production master; the accepted B/C reference remains authoritative for identity.
- The prototype covers two hair choices and three outfit silhouettes. The full hairstyle/headwear/garment matrix is not produced, and no native persistence was changed.
- Idle blinking uses a simple closed-eye scale approximation. Final eyelid drawings and facial expressions need dedicated art.
- Paper filtering at 72 pixels cannot establish the final bitmap texture or native rendering cost.

Next bounded production step: refine one B and one C angle set against the accepted reference, replace the most approximate side/back parts, tune a short planted-foot walk cycle, and then fit one shirt, one dress, one coat, and one hat to those locked masters. Review that result before expanding the wardrobe.
