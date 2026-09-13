# Character Asset Production

The production checklist for the rounded cut-paper character family. The 8 September 2026
founder direction preserves approved Ollie and sheep art and revises the human Shepherd to
match them. This file tracks artwork contracts; the
runtime and persistence decisions remain in `AGENTS.md`, `docs/ARCHITECTURE.md`, and ADR-0015.

## Approved style anchors

- Rendering authorities: `dog/dog_classic_farm_idle` and `sheep/sheep_mabel_wool_ready`.
- `farm/farm_shepherd_default_idle` is the existing human implementation, not the style
  authority for its revision. See [Shepherd review](../output/design/shepherd-review-20260908/REVIEW.md)
  for the concept and outstanding production work; the concept is not yet integrated.
- Classic Ollie identity: `dog/dog_classic_idle`
- Common-sheep direction: the approved broad cloud-body concept; canonical named sheep still
  require individual production assets.
- Shapes: broad overlapping geometry, no exterior keyline, no pixel edges, no individual fur or
  fleece strands.
- Animal faces: preserve approved white circular eyes with solid plum pupils, no iris or highlight.
- Shepherd: the founder rejected the first revised face as generic and the second study as
  too complicated and realistic. Return to the original Shepherd's oversized head, tiny body,
  and broad simple shapes. Use Moomin-inspired oval eyes, small pupils, and spare cartoon
  nose/mouth lines. Avoid anatomical facial modeling, detailed hair, fingers, and fabric folds.
  Keep paper grain subtle. Selective fine facial lines are compatible with the soft paper body;
  the animal eye formula is not a requirement for the human. The founder accepted B and C
  in `shepherd-cartoon-v3.png` as head-shape customization directions; A has generation defects
  and is not accepted. Both shapes must support fitted clothing and headwear. This is design
  acceptance. Saved head choices and static native rendering were integrated on 9 September;
  see the native integration plan for current validation and remaining motion work.
  B/C are starting options, not a closed set. The founder explicitly welcomes future boxy,
  triangular, and other silhouettes; keep head geometry independent of hair, eyes, and clothing.
- Surface: soft paper texture is the founder's shared standard across app illustration,
  including characters, clothing, props, and environments. Use restrained grain and soft
  internal shading; no glossy 3D finish. This direction does not claim all legacy art has
  already been converted.
- Output: sRGB RGBA PNG with transparent corners and no matte fringe.

## Shepherd static production renderer

As of 9 September, normal avatar surfaces use the shared native Canvas drawing with cached
paper grain, fitted garments and headwear. Legacy PNG masks are retained as historical assets;
they no longer tint the production shepherd. The [integration record](../output/design/shepherd-production-20260909/README.md)
separates source/build evidence from deployment and physical validation.

The 12 September body revision follows the approved turnaround more closely: curved, broader
garment silhouettes; tapered angled sleeves and separate mitten hands; a longer default shirt
over an overlapping trouser waist; short trouser sections and rounded boot toes. Fine grain
and a cached broad pigment wash share the resting garment coordinates. Pockets stay beneath
moving hands. [Native before/after proofs](../output/design/shepherd-body-20260912/README.md)
cover matching garments, Farm size, all head shapes and sampled motion. This remains authored
native artwork, rather than a pixel-identical extraction of the generated concept.

## Shepherd movement study

The founder authorized the recommended small movement prototype before bulk generation.
The native first batch uses a dedicated Debug-only harness and ordinary SwiftUI previews;
Screenbook is shelved. See the [native integration plan](plans/shepherd-native-art-integration.md).
The [interactive study and production contract](../output/design/shepherd-motion-20260908/README.md)
cover B/C, short/long hair, unrestricted clothing presentation, five viewing angles, removable
headwear, and a layered idle/walk experiment. Its vector rig and generated turnaround are
concept evidence, not production-ready replacements. Preserve accepted B/C identity when
refining the angle drawings; finalize fit, foot placement, and texture before generating at scale.

## Canvas contracts

| Family | Canvas | Alignment |
|---|---:|---|
| Ollie static and Farm | 512×512 | centered; paws share a stable baseline |
| Ollie run cycle | 512×512 | faces right; consistent apparent scale |
| Ollie equipped overlay | 512×512 | exact Farm-base coordinates |
| Ollie Shop thumbnail | 384×384 | standalone centered object |
| Sheep canonical/lifecycle | 512×512 | consistent baseline and three-quarter view |
| Shield pair | 360×300 | centered compact pair |

## Classic Ollie — integrated

- [x] `dog_classic_idle`
- [x] `dog_classic_focused`
- [x] `dog_classic_sleeping`
- [x] `dog_classic_happy`
- [x] `dog_classic_proud`
- [x] `dog_classic_concerned`
- [x] `dog_classic_run_frame_01` through `dog_classic_run_frame_06`
- [x] `dog_classic_home_idle_frame_01` through `dog_classic_home_idle_frame_06`
- [x] `dog_classic_farm_idle`
- [x] `sheep_bramble_chase_run_frame_01` through `sheep_bramble_chase_run_frame_06` (decorative journey companion)
- [x] Three fitted Farm equipment overlays
- [x] Three separate 384×384 Shop inventory assets
- [x] `ollie_sheep_storybook_shield`
- [ ] App and Watch icon refresh after in-app character QA

Equipment stays modular. Farm overlays are required for every selectable Ollie look. Static
ritual and run-cycle equipment are later, separately reviewed packs because their size is
`looks × poses × items`.

## Named sheep backlog

Each definition needs `wool_ready`, `shorn`, and `regrowing` assets. The wool-ready asset is the
canonical reveal/catalogue image; the lifecycle variants must preserve the same identity and
non-removable story accessory.

| ID | Base | Identity accessory | Ready | Shorn | Regrowing |
|---|---|---|:---:|:---:|:---:|
| mabel | common white | blue ribbon | ☑ | ☑ | ☑ |
| pippin | spotted | round glasses | ☑ | ☑ | ☑ |
| bramble | fluffy | green neckerchief | ☑ | ☑ | ☑ |
| clementine | cream | sunflower pin | ☑ | ☑ | ☑ |
| oat | merino | book satchel | ☑ | ☑ | ☑ |
| midnight | black | silver bell | ☑ | ☑ | ☑ |
| juniper | cream | amber spectacles | ☑ | ☑ | ☑ |
| hazel | spotted | yellow hat | ☑ | ☑ | ☑ |
| ramsey | guardian | red wool scarf | ☑ | ☑ | ☑ |
| luna | merino | crescent necklace | ☑ | ☑ | ☑ |
| marigold | fluffy | flower crown | ☑ | ☑ | ☑ |
| wisp | night | starry cape | ☑ | ☑ | ☑ |

Duplicate encounters use the canonical image until a later deterministic marking-variation
pack is complete. Never randomize appearance on view load.

## Selectable Ollie looks

The first Shop set is Classic, Grown, Swift, and Meadow. Each look is incomplete until it has
all six static ritual states, all six run frames, one Farm base, fitted overlays for every
shipping Ollie item, a Shop thumbnail, and a Shield rendering.

Concept masters have been generated for Grown (larger adult rough-coat border collie), Swift
(lean smooth-coat border collie), and Meadow (sable-and-white Shetland sheepdog). They are not
yet purchasable: concept approval comes before the full matrix so a selected look never falls
back to mismatched Classic art.

Additional candidates are Highland, Moonfield, Dusk, Hearth, and Cloud. They remain storybook
looks for the same Ollie unless a later product decision introduces separate named companions.

## Generation and review sequence

1. Generate one character per request using the approved animal style anchors plus the relevant identity master.
2. Generate a chroma-key source; remove the key locally with soft matte and despill.
3. Normalize canvas, baseline, and padding mechanically rather than trusting generated placement.
4. Derive new poses from the approved identity. Never generate unrelated poses without the
   identity master as an input.
5. For animation, use the legacy frame only as a limb-phase reference. Reject changes in head,
   muzzle, markings, torso length, tail length, or scale.
6. Composite every equipped overlay over its real base and inspect it at 72, 84, and 176 points.
7. Verify alpha, dimensions, missing-art fallbacks, smallest-device layout, Reduce Motion, build,
   and tests before checking off a family.

Generated source prompts use the built-in image tool. Chroma sources remain disposable; only
normalized transparent production PNGs belong in the asset catalogue.

## Production prompt templates

Use one output per prompt. Attach the approved animal style anchors and the relevant character
master; for a derived pose also attach the preceding approved pose or legacy timing frame.

### Ollie static state

> Edit the attached approved Ollie master into `{state}`. Preserve the exact head shape, muzzle,
> blaze, coat colors, eye construction, ear asymmetry, body proportions, and tail. `{pose and
> expression direction}`. Rounded layered cut-paper storybook illustration matching the approved animals:
> broad overlapping shapes, subtle paper grain, soft warm internal shading, no exterior keyline,
> no individual fur strands, no pixel art, no glossy 3D finish. Full body on a flat chroma-green
> background, centered on a 1:1 canvas, stable paw baseline, no text, props, collar, or shadow.

### Ollie run frame

> Create run-cycle frame `{01–06}` from the attached approved Ollie identity and timing reference.
> Ollie faces right. Match the reference limb phase only; preserve identical head, muzzle, blaze,
> coat markings, torso length, tail length, apparent scale, and baseline across every frame. Use
> the approved rounded cut-paper animal style. Flat chroma-green 1:1 background; no motion blur,
> scenery, text, accessory, ground, or cast shadow.

### Farm ornament overlay

> Render only `{ornament}` fitted to the attached `{look}` Farm base at its exact neck/head anchor.
> Keep the base character completely unchanged and invisible in the final overlay. Rounded
> cut-paper material, readable at 72 points. Transparent 512×512 canvas in the exact base
> coordinates; no character pixels, scenery, text, or shadow outside the ornament.

### Named sheep — wool ready

> Create `{name}`, a `{breed/coat}` sheep whose permanent identity accessory is `{accessory}`.
> Calm three-quarter full-body pose, cloudlike wool-ready silhouette, charcoal or identity-specific
> face and legs, white circular eyes with solid plum pupils. Match the approved rounded cut-paper
> Shepherd style: broad scalloped fleece shapes, restrained paper grain, soft warm shading, no
> keyline, no individual fibers, no pixels. Flat chroma-green 1:1 background; no scenery, text,
> ground, cast shadow, or extra accessories.

### Named sheep — shorn/regrowing edit

> Edit this exact `{name}` master into `{freshly shorn | intermediate regrowing}`. Preserve the
> face, proportions, coat markings, direction, expression, and permanent `{accessory}` exactly.
> For shorn: a slim smooth body with only a small wool cap, tail tip, and ankle cuffs. For
> regrowing: short-to-medium rounded scalloped torso fleece, clearly between smooth shorn and full
> cloud-wool. Match the approved cut-paper rendering. Flat chroma-green 1:1 background; no text,
> scenery, ground, shadow, or extra objects.

### Selectable Ollie look master

> Reimagine the attached Classic Ollie as `{Grown adult rough-coat border collie | Swift athletic
> smooth-coat border collie | Meadow sable-and-white Shetland sheepdog}` while keeping the same
> friendly shepherd-dog identity. Preserve the Farm pose direction, canvas occupancy, paw baseline,
> head center, and neck-equipment anchor. Match the approved rounded cut-paper animal style.
> No ornament or clothing. Flat chroma-green 1:1 background; no scenery, text, ground, or shadow.
