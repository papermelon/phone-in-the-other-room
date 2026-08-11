# Character Asset Production

The production checklist for moving Ollie and the flock from the legacy pixel sprites to the
rounded cut-paper style established by Your Shepherd. This file tracks artwork contracts; the
runtime and persistence decisions remain in `AGENTS.md`, `docs/ARCHITECTURE.md`, and ADR-0015.

## Approved style anchors

- Rendering authority: `farm/farm_shepherd_default_idle`
- Classic Ollie identity: `dog/dog_classic_idle`
- Common-sheep direction: the approved broad cloud-body concept; canonical named sheep still
  require individual production assets.
- Shapes: broad overlapping geometry, no exterior keyline, no pixel edges, no individual fur or
  fleece strands.
- Face: white circular eyes with solid plum pupils, no iris or highlight. Keep animal eyes smaller
  than the Shepherd's proportional eye size so expressions remain calm.
- Surface: restrained paper grain and soft internal gradients; no glossy 3D finish.
- Output: sRGB RGBA PNG with transparent corners and no matte fringe.

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
- [x] `dog_classic_farm_idle`
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

1. Generate one character per request using the Shepherd plus the approved identity master.
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

Use one output per prompt. Attach the approved Shepherd style anchor and the relevant character
master; for a derived pose also attach the preceding approved pose or legacy timing frame.

### Ollie static state

> Edit the attached approved Ollie master into `{state}`. Preserve the exact head shape, muzzle,
> blaze, coat colors, eye construction, ear asymmetry, body proportions, and tail. `{pose and
> expression direction}`. Rounded layered cut-paper storybook illustration matching the Shepherd:
> broad overlapping shapes, subtle paper grain, soft warm internal shading, no exterior keyline,
> no individual fur strands, no pixel art, no glossy 3D finish. Full body on a flat chroma-green
> background, centered on a 1:1 canvas, stable paw baseline, no text, props, collar, or shadow.

### Ollie run frame

> Create run-cycle frame `{01–06}` from the attached approved Ollie identity and timing reference.
> Ollie faces right. Match the reference limb phase only; preserve identical head, muzzle, blaze,
> coat markings, torso length, tail length, apparent scale, and baseline across every frame. Use
> the approved rounded cut-paper Shepherd style. Flat chroma-green 1:1 background; no motion blur,
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
> head center, and neck-equipment anchor. Match the approved rounded cut-paper Shepherd style.
> No ornament or clothing. Flat chroma-green 1:1 background; no scenery, text, ground, or shadow.
