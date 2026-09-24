# Shop and wardrobe expansion — 22 September 2026

Status: expansion direction with a first implementation slice on 23 September. See
[coat and clothing layers](wardrobe-layers-2026-09-23.md) for actual delivery and verification.
Other breeds, clothing positions and Farm collections below remain proposals.
Founder direction: expand Ollie's breeds, coat lengths and clothes, the Shepherd wardrobe,
and relevant Farm objects while preserving the simple textured painted style. Clothes in
different positions must coexist: a hat must never exclude a shirt or coat.

## Current audit

- Ollie: six purchased garments, one persisted accessory choice, one shared fitted renderer.
  Home tilt/blink, Farm idle, Fetch and journey run, settle/rest/rise have authored neck landmarks.
  Breed and coat length are not selectable. The procedural fluffy-ruff trial was removed after
  visual inspection: adding a neck shape did not produce a convincing new coat.
- Shepherd: three headwear items and four outfits. `accessoryItemID` and `outfitItemID` are
  already independent through purchase, wear, removal and the shared Canvas renderer. Shop
  try-on preserves the other choice. The cream shirt/trousers is the default appearance.
  Current outfits are whole clothing looks; a separately selected shirt under a separately
  selected coat is not implemented.
- Farm: eight decorations use six named placement zones; objects in the same zone replace
  each other. Six keepsakes share four shelf positions. Capacity upgrades are functional and
  should remain clearly distinguished from decorative purchases.
- This pass groups the owned Shepherd wardrobe into Headwear and Clothing, explains what a
  purchase replaces, labels each Wear/Take off action for VoiceOver, and stacks rows at
  accessibility text sizes. Regression coverage exercises every existing hat/outfit pair,
  either purchase order, swaps, removal, save/restore and the private backup path.

## Art direction and review gate

[Concept board](../../output/design/wardrobe-expansion-20260922/concept-board.png) is a direction
study generated from actual app art, not a production sprite sheet. The dogs explore distinct
silhouettes; simplify the board's small garment seams, checks and prop details further for
runtime sizes. The board cannot establish animation fit or approve a new runtime asset.

Use broad matte gouache/watercolour shapes, restrained paper grain, soft imperfect edges and
the existing moss, cream, dusk blue, ochre and plum palette. Keep the established character
faces and proportions. Avoid pixel edges, glossy metal, heavy outlines and miniature ornamental
detail. Grain belongs to each material and must not crawl or flicker during motion.

An item needs both a shop thumbnail and a believable worn/placed appearance. Inspect at actual
Home and Farm sizes, on dark and light scenes, moving and still. Hat bands sit around the head;
hair has front/back overlap; paws, hands and muzzles occlude garments; straps disappear behind
the appropriate limb. Use the current Canvas for Shepherd clothing and simple Farm objects.
Use authored raster base art for Ollie's coat/anatomy changes. Never attach a shop thumbnail to
a character or use an enlarged neckwear path to represent longer fur.

## Ollie: appearance before wardrobe

Keep Ollie's name, companion relationship, abilities and progress when changing appearance.
The existing border collie stays the default. Breed is a visual choice with no reward or timer
advantage. Coat choices are discrete authored styles per breed, not a universal length slider.
No need to offer every coat option for every breed.

| Appearance family | Distinguishing silhouette | Proposed coat choices | Production order |
| --- | --- | --- | --- |
| Border Collie | Existing face, ear shape and leg proportions | Current; fuller cheeks, chest, legs and tail | First complete coat pack |
| Shetland Sheepdog | Narrow muzzle, tipped ears, flowing chest/tail | Full; extra fluffy | Next medium-body candidate |
| Australian Shepherd | Broader head, folded ears, feathering | Medium; full | Medium-body batch |
| German Shepherd | Tall ears, longer muzzle, distinct back and tail | Short; long | Separate anatomy pack |
| Golden Retriever | Drop ears, soft broad muzzle, feathered tail | Smooth-looking; feathered | Separate anatomy pack |
| Corgi | Low chest, short legs, long torso | Standard; fluffy | Early stress test for garment fitting |
| Old English Sheepdog | Rounded shaggy body, folded ears, face fringe | Shaggy; tidier face | High-volume coat batch |
| Tibetan Mastiff | Large paws, broad head, heavy mane and tail | Full; winter-full | High-volume coat batch |
| Snow Lion | Deliberately mythic companion with distinct mane/tail | One coherent initial form | Separate mythic collection, not a dog breed |

Treat these as art choices, not real animal grooming guidance. Snow Lion needs its own visual
reference review before final artwork; do not derive it by recolouring a Mastiff.

For each selectable pack, supply every unique production frame required by the existing
manifest (currently 23 in the wardrobe review), including sit/blink/head tilt, run, lying down,
rest, waking and neutral fallback. Register neck/chest attachment, chin/fur occlusion and ground
contact for that anatomy. Reuse action timing where it fits; inspect Corgi stride and heavy-coat
movement independently. Keep a complete pack per action: missing frames must not flash back
to the default breed. Validate the entire pack before exposing it in the picker.

Suggested first wearable batch: Heather Kerchief and Dawn Check Bandana (existing fitted
kerchief pattern), Acorn Collar (collar pattern), then a Meadow Rain Cape with authored back/
chest coverage. Later: a soft harness and small trail satchel, after body attachment is supported.
Do not sell independent neckwear/body combinations until those slots and their overlap masks
exist. A cape's fastening may visually cover a collar without clearing the saved collar.

## Shepherd: independent clothing positions

The next real clothing expansion should introduce slots only alongside supported items.
Do not put scarves, boots and bags into the existing single headwear field.

| Position | Candidate items | Replacement/overlap rule |
| --- | --- | --- |
| Headwear | Current hats; soft rain hat, knitted beret | One head item; hair choice remains saved underneath |
| Top | Cream linen shirt, berry knit, dusk striped shirt | Replaces the top only |
| Outerwear | Current coats/cloak; raincoat, open cardigan | Replaces outerwear only; preserves and may cover the top |
| Bottoms | Field trousers, corduroy trousers, long skirt | Replaces bottoms only |
| Footwear | Clay boots, moss wellies, felt shoes | Replaces shoes only |
| Neckwear | Wool scarf, small neckerchief | One neck item; fitted to collar/coat neckline |
| Carry | Canvas satchel, journal pouch | One carry item; strap behind near arm and over clothing |
| One-piece | Current overalls; work apron dress | Explicitly occupies top + bottoms; leaves hat, coat, shoes and bag alone |

Selecting an item changes only its occupied positions. Covered garments remain selected.
Taking a coat off reveals the selected shirt. The current overalls can be worn over the selected shirt; that shirt remains saved and its
sleeves show beside the bib. Future one-piece conflicts must be explicit in preview and must
not delete covered selections or ownership. Keep the current appearance when
migrating legacy outfits; their built-in trousers/shoes become baseline pieces. Unknown future
IDs survive save/restore even when the current renderer uses a fallback.

Clothing remains independent of skin, head shape, eyes and hair. Fit headwear across all head
shapes and hair silhouettes. Render shirt, torso garment, sleeves, hands, neckwear, bag straps,
hair and hat in the appropriate front/back order. An oversized hat/hood conflict must be
authored or visibly disclosed; never silently delete an unrelated selection.

## Collections with a clear destination

| Collection | Wearables | Farm objects | Keepsakes and where they appear |
| --- | --- | --- | --- |
| Meadow mornings | Heather Kerchief; linen shirt/beret | Lavender planter, bird bath | Pressed-flower frame on the keepsake shelf |
| Rainy rounds | Ollie rain cape; Shepherd raincoat/wellies | Rain barrel, simple stepping stones | Small painted cloud tile on the shelf |
| Quiet reading | Dawn Check Bandana; cardigan/satchel | Woven mat, blanket over log seat | Pocket journal and leaf bookmark, arranged on the shelf |
| Mountain evenings | Warm collar/scarf; wool layers | Low stone marker, small sheltered bench | Trail map or carved mountain token on the shelf |

Keep purchases intelligible: show 'worn on...', 'placed beside...' or 'displayed on...' before
buying. Preview scale, placement and replacement alongside the owner's current choices.
Keep existing prices, ownership and unlocks; price new cosmetic items only after the first
batch is reviewed against the current wool economy. No made-up rewards or novelty currencies.

Farm expansion first needs placement review: the current bench and clover patch share a zone,
so a themed collection cannot promise they all coexist yet. Add specific extra placements only
where the scene has room, with grounded scale, sheep/Fetch clearances and foreground depth.
Keep small collections readable rather than filling every area with props.

Campfire candidates: personal blanket/mat, seat cushion and a journal or closed book beside an
active Shepherd. These are appearance choices, not proof that reading or another task occurred.
Use the person's explicitly shared activity label for that claim. Cosmetics must not seat an
inactive member or obscure name/activity labels. Shared party decoration and gifting need
their own ownership/placement behavior; neither is implemented by this study. Extend the
existing bounded appearance payload, capability and disclosure as needed when slots ship;
do not send new private profile fields wholesale.

## Delivery order and acceptance

1. Current headwear/clothing clarity and regression checks (this pass).
2. Review one full-coat Border Collie master in sit, run and rest, with Moss Bandana fitted.
   Then author the remaining frames and integrate a persisted appearance choice. A concept
   portrait alone is not a selectable breed.
3. Add a small fitted colour/motif batch for Ollie. Introduce independent Shepherd top/outerwear
   with one shirt and one open coat, then cover migration, backup, restore and shared rendering.
4. Add footwear/neckwear/carry as complete art + state slices, followed by a placed Farm and
   shelf collection. Review one Corgi pack to expose anatomy-specific fitting issues early.
5. Expand remaining breeds and opt-in social cosmetics using the validated workflow.

Checks: all supported hat/clothing pairs; taking off one leaves the other; both purchase orders;
same-slot replacement; shirt preserved under coat; one-piece conflicts; unknown/legacy IDs;
private backup round-trip; current social fallback; Home/Farm/Fetch/journey/Shop consistency;
rest-to-run transitions; large text, VoiceOver and Reduce Motion. Rendering assertions verify
state, while actual frames and motion establish the visual fit.
