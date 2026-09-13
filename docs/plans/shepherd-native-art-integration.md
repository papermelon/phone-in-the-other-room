# Shepherd native art integration

## Current founder decisions

- Preserve approved Ollie/sheep art. Standardize soft paper texture across app illustration.
- Keep simple cartoon anatomy: large heads, small bodies, oval eyes, spare face lines, broad hair/clothing shapes.
- B (pear) and C (round) are starting head options. The set is extensible, including boxy and triangular explorations. Shape is independent of hair, eye expression, clothing, and gender presentation.
- Support masculine, feminine, and neutral looks without gender-locked cosmetics.
- Cosmetics need fitted artwork with stable identity, not whole-character color changes.
- Screenbook is shelved. Use ordinary SwiftUI previews and a local native Debug harness for this batch. Existing Screenbook code is retained, not expanded or activated.

## Body fidelity revision — 12 September 2026

The founder approved correcting the production body's mismatch with the turnaround. The
turnaround controls the broad garment silhouette, sloping sleeves, little mitten hands,
short trouser sections and rounded boot toes. Preserve the existing head/face choices and
long-hair repair while fitting each garment to that anatomy.

Implementation sequence:

1. Capture the existing renderer, then redraw the Moss Coat and everyday shirt. Extend the
   shirt hem and overlap the waist with both legs so movement cannot reveal a waist gap.
2. Fit Moon Coat, Field Overalls, Star Keeper Cloak and the study-only dress to the same
   shoulder/foot anchors. Keep cuffs, hands and boot contours as separate moving parts.
3. Add a restrained broad pigment wash to the cached fine paper grain. Keep the texture
   deterministic and attached to the drawing, including during motion.
4. Inspect exports from production code at 180-point customization and 72-point Farm sizes,
   all heads/outfits, five directions and walking poses; compare beside approved animals.
5. Build the app, run the unit suite and inspect the isolated native production preview.
   Record actual evidence before treating this source batch as complete.

The same production renderer supplies Farm, customization, Shop and social callers. This
batch changes drawing geometry only: it adds no equipment IDs, persistence fields, purchase
rules, Farm locomotion or new deployment. The [body proof record](../../output/design/shepherd-body-20260912/README.md)
contains reproducible before/after exports and validation status.

Validation complete locally: full app Simulator build and 946 unit tests passed. Native
preview checks covered default shirt, Moss Coat, long hair with overalls/beanie, equipment
removal and largest accessibility text size. The code is integrated; distribution and physical
iPhone acceptance remain release steps.

## Production integration — 9 September 2026

The founder authorized carrying the avatars into the production build. The shared Canvas
renderer now replaces the legacy masked PNG renderer in `ShepherdAvatarView`, including
Farm, customization, onboarding, Shop previews and social avatar callers. The drawing code
compiles in Release; only the study UI and export tools remain Debug-only.

Saved customization offers pear, round, boxy and triangular heads independently of the five
existing hairstyles and skin tones. An optional `headShapeID` lives in `ShepherdProfile` and
therefore in the private Farm payload. Absent legacy IDs remain absent on encoding (rendering
pear), preserving old cloud fingerprints. Unknown future IDs are retained and render pear.
Existing ownership, equipment IDs, welcome rewards and account storage paths are unchanged.
Older clients cannot display new shape choices; use this version when restoring these saves.

All four existing outfits and all three existing headwear items have fitted drawings. Shop
thumbnails use the same avatar renderer. Taking off an item restores the chosen hair and
underlying default clothes; no whole-character tint or missing PNG overlay is required.
Unknown item IDs remain saved and use the unequipped visual fallback until supported.

The later [shared Farm work](slumber-party-shared-farm-and-cheers.md) adds capability-gated
public head-shape support and maps it into this renderer. Legacy or unsupported shapes keep
the pear fallback. The body revision does not change that consented appearance transport.

The standing renderer is integrated; Farm locomotion, free eye-expression selection, extra
wardrobe collections and independent neckwear remain later work. The dress remains an art
study option and is not added as an unowned saleable item.

Validation and rendered evidence: [production integration record](../../output/design/shepherd-production-20260909/README.md).
No archive or TestFlight upload is performed by this source integration.

## Stage 1 — corrected masters and native experiment (implemented)

Implement a local study vocabulary and renderer using the existing app target. Launch with
`--shepherd-art-study`; the route must branch before production dependencies are initialized.
Use no account, notification, Farm, or purchase services and no saved profile state.

Provide B/C, exploratory boxy/triangular shapes, independent eyes, short/long hair, five skin
tones, shirt/trousers, dress, Moss Coat, and one removable hat. Render five viewing angles,
left/right direction, idle/blink, walk, stop, and manual stepping. Pause animation for Reduce
Motion, inactive scenes, and invisible views. Inspect a 72-point canvas alongside the larger
master drawing. Export deterministic native master sheets from the exact renderer, eliminating
identity drift between unrelated generated frames.

The renderer is native Canvas with authored paths and cached paper grain. It is a testable
art/rig experiment, not a declaration that this medium replaces final painted assets. Native
Simulator validation and physical iPhone performance/visual validation are separate evidence.

## Stage 2 — saved customization (private Farm implemented)

Add head-shape selection to persisted appearance with a deliberate default, compatible
decoding, unknown-value handling, and migration tests. Preserve all existing item IDs, skin
tones, hairstyles, ownership, and equipment. Carry appearance through private Farm sync;
update public Slumber Party presentation only through its supported, consented versioned
contract. Keep visual motion state transient. No stage-2 persistence changes belong in batch 1.

## Stage 3 — complete static replacement (implemented and locally validated)

Produce the supported standing matrix for all existing hairstyles and paid items before
replacing `ShepherdAvatarView`. Use one shared renderer across Farm, customization, onboarding,
Shop and social avatars. Update Shop thumbnails to match fitted clothing. A missing image
retains ownership/equipment and shows a truthful fallback, not a flat garment recolor.

## Stage 4 — Farm motion

Connect pose and direction to the existing pasture controller, which retains ownership of
position, dragging and interaction. Start with idle, then turning and walking tied to real
displacement. Match step timing to distance and keep feet planted. Respect visibility,
application lifecycle, Reduce Motion, Wind Down restrictions, nameplates and touch targets.
The batch-1 walk is in place and does not implement Farm navigation.

## Stage 5 — expansion

Add small complete wardrobe collections, new hair, neckwear stacking, and further head shapes.
Keep headwear, outfit and neckwear visual slots distinct. A new neckwear persistence slot and
independent shirt/bottom/outerwear combinations come only with compatible implementation and
complete fit coverage. Existing owned cosmetics take priority over new saleable items.

## Gates

Each code batch requires applicable tests, full app build/unit gates and visual inspection.
Persistence adds replay/migration and account isolation checks. Release candidates require
physical-device evidence, a signed archive and the release workflow; deployment/distribution
are separate authorized actions. Art acceptance does not prove native performance or a saved
Farm migration.

Batch-1 evidence and limitations are recorded in
[the native study record](../../output/design/shepherd-native-20260908/README.md).
