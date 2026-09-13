# Shop, Ollie's wardrobe and the campfire — 13 September 2026

## Scope and status

Founder requested a collection review, paper-textured art, believable wearing and consistent
Ollie equipment on Home, Farm and active Wind Down/Phone Away. Founder explicitly requested
implementation of the Shop/Ollie changes and a campfire proposal first where it affects them.
The screenshots are visual evidence, not instructions. This document distinguishes the local
implementation from proposed social behavior. No deployment, distribution or sharing-contract
activation is part of this change.

## Findings from source and screenshots

- The old Moss Bandana includes a hollow neck opening, a large triangular bib and an inventory-like
  rim. Neutral Home draws it over Ollie without the Farm's rough gradient depth mask. The Farm mask
  itself is a vertical gradient, not the silhouette of a chin or shoulder.
- Home/Farm motion uses registered overlays for only the first three accessories. The expanded
  collar, scarf and cape have catalog declarations without the same finished art coverage.
- The six-frame chase has its own renderer, previously receiving no equipped accessory ID.
- The Shop mixes detailed pixel illustrations, empty/missing assets and generic system symbols.
  In particular the Hoofprint Tile fallback is a dog paw, not a split sheep hoof.
- The purchase transaction already equips clothing, replaces the decoration in its assigned zone,
  and fills the first free keepsake shelf slot. When the four-slot shelf is full, a newly bought
  keepsake stays owned in storage. The old detail sheet says only that owned items are stored,
  rather than explaining or exposing their actual equipment action.

Evidence: `FarmSharedComponents.swift`, `OllieRitualView.swift`,
`OllieCompanionSpriteRenderer.swift`, `NightJourneyView.swift`, `FarmShopCatalog.swift`,
`FarmShopItemDetailView.swift` and `Shared/FarmShop.swift`.

## Collection revision

Use simple silhouettes, a restrained pigment palette, broad paper wash and fixed fine grain.
Avoid glossy metal, embossed borders, pixel edges and tiny inventory details that vanish in a
50–100 point scene. Existing paper Shepherd rendering supplies the drawing vocabulary and
texture. Catalog IDs, prices, milestone unlocks and earned ownership remain unchanged.

### Ollie — one fitted accessory at a time

| Item | Revised appearance | After bringing home |
| --- | --- | --- |
| Moss Bandana | Small moss cloth hugging the white ruff, soft side knot, simple sheep stitch | Worn across Home, Farm and chase |
| Moon Kerchief | Heather cloth with a cream crescent; same fitted silhouette | Replaces the worn accessory; both remain owned |
| Brass Farm Bell | Slim russet collar with a small matte brass bell | Worn, not attached to the gate; copy corrected |
| Clover Collar | Thin green collar and small clover charm | Worn; no empty thumbnail |
| Sunrise Scarf | Short amber scarf, tucked knot and short tails | Tails remain clear of legs; folded at rest |
| Star-Keeper Cape | Short midnight shoulder cape with one cream star | Draped over the shoulder, folded away during rest |

Shop cards show Ollie wearing each item. The detail sheet offers Sitting, Running and Resting
previews using the production composition. Reduce Motion holds the chase frame. Home and Farm
use the same neutral base and garment renderer. Every existing motion frame and all six running
frames have neck registrations; rest exposes only the visible side/fold. Native cloth removes
the dependency on an inventory cutout or a complete set of bitmap clothing overlays.

The stored `ollieAccessoryItemID` remains the single source of truth. Changing it updates all
subscribed surfaces; previews do not equip until the existing purchase/Wear intent runs. The
wardrobe explains that another worn item goes back into storage. Buying a second item neither
stacks collars nor loses the first purchase.

### Your Shepherd — retain the current fitted paper wardrobe

Wool Field Hat, Moss Work Coat, Moonlit Coat, Clover Headscarf, Moon Beanie, Field Overalls and
Star-Keeper Cloak already use the native fitted Shepherd renderer in Shop previews and actual
avatars. Keep those seven items and their existing headwear/outfit slots. Their curated public
appearance is the natural first connection between purchases and Slumber Party, under the
existing supported appearance agreement.

### Around the Farm — draw the object once, use it in the scene

| Item | Revised illustration | Placement |
| --- | --- | --- |
| Clover Patch | Broad clover leaves, four cream flower heads | Left meadow |
| Barn Lanterns | Matte amber frames and a quiet candle-colored pane | Right meadow beside Barn; personal décor |
| Moon Gate | Cream slats, dusk-blue posts and a small moon ornament | Center horizon |
| Twilight Banner | Cream cloth, floral stitch and restrained tassels | Left fence |
| Story Bench | Simple timber seat with a berry cushion | Left meadow; shares a slot with Clover Patch |
| Sheep Trough | Wooden trough with visible still water | Right meadow; shares a slot with Barn Lanterns |
| Dusk Pond | Low water ellipse, reeds and a lily | Water edge |
| Old Oak | Broad rounded canopy, visible forked trunk | Barn corner |

The same native illustration appears in the card and placed Farm prop. The fixed-zone placement
model remains in use; the detail sheet explains replacement rather than promising free placement.
Personal décor does not automatically become group property or appear in every Slumber Party.

### Keepsakes — objects with a visible home

| Item | Revised illustration | Use now |
| --- | --- | --- |
| Brass Search Pin | Matte circular landscape pin with a winding path | Four-slot keepsake shelf |
| Storybook Bell | Small brass bell on a closed book | Shelf |
| Hoofprint Tile | Terracotta tile impressed with a split hoof | Shelf; replace the generic dog paw |
| Wool Almanac | Moss book, sheep cover motif and ribbon bookmark | Shelf; replace the generic book symbol |
| Sunrise Compass | Matte brass dial and simple two-tone needle | Shelf |
| High Moor Star | Silver-blue star with a small display base | Shelf |

Do not make every keepsake wearable: a book, tile and large compass belong on the shelf. A later
small charm/pin slot could let the Search Pin or High Moor Star clip to Ollie's bandana/collar.
That is a separate extension requiring compatibility rules, fitted art at chase scale, persisted
slot migration and public-appearance allowlisting. It is not silently introduced in this pass.

Second, Hill, Moon and Wide Pasture retain their 24/36/48/60 capacity effects and receive coherent
miniature paper pasture illustrations. They are capacity upgrades, not placed decorations.

## Campfire direction — implementation authorized

The founder subsequently authorized implementation. The [current implemented contract](campfire-implementation-2026-09-13.md)
now owns consent, validity, transport and rollout details; the following design rationale remains
useful context. Hosted activation is still separate.

### Product role

Make **Campfire** a gathering area inside each existing Slumber Party, reachable through its
Home and Farm entries. Keep the four release tabs and the approved wide shared meadow. The
campfire is an interaction layer and focal point within that meadow, not a replacement backdrop.
It is available from the first member and costs no wool or contributions. Participation rewards
can improve the surroundings after people already have a useful place to gather.

Represent people with their customized Shepherds. Keep Ollie personal as currently decided;
his clothing remains consistent on all personal surfaces. Visiting sheep continue their existing
owned, recallable visit contract, independently of whether the owner's session is active.

### What the two existing lanterns actually do

1. **Barn Lanterns (Shop):** 3 wool; a personal fixed-zone decoration. Buying them does not
   enable presence, group gathering or a shared session.
2. **Our lantern (Slumber Party):** the first completed Wind Down or Phone Away receiving an
   eligible existing round grant counts once per member per party-day. Twelve contributions
   unlock one movable group prop. Progress persists across rounds and membership changes.
   Early endings retain their personal Farm credit but add no lantern contribution.

The second is implemented in local source, with migration `20260912120000_shared_pasture.sql`;
the 12 September evidence records hosted activation as outstanding. The 10 September deployment
record proves the earlier social backend, not this newer feature. This review has not inspected
or changed today's hosted configuration or the installed TestFlight build. The user's screen
cannot be assumed to expose the latest local code.

A lantern is a useful earned object but an unclear foundation for body doubling: the gathering
place should work before anyone earns it. Recommendation: retain the lantern and its contributions
as an improvement beside the free campfire. Preserve any existing earned balance/unlock and ID;
do not reset the project or convert paid Barn Lanterns into an admission requirement.

### Proposed flow

1. Before a session, Home can show “At the campfire · 2 shared sessions” with a party name.
   Tap opens that party's meadow; the same place remains available from Farm.
2. A person chooses Wind Down or Phone Away using the existing local start flow. For Phone Away,
   offer an optional bounded intention: Reading, Studying, Making something, Chores, Resting,
   or just Phone Away. Wind Down can stay simply “Wind Down.” No extra confirmation for every
   start after the relevant sharing agreement has been accepted.
3. On a successful local session start, enqueue the permitted session cue to eligible parties.
   Local timing/protection never waits for the server. The member's Shepherd gathers at the
   campfire after an accepted, current session status is available to that viewer.
4. Each person has a short visible label: “Wind Down” or “Phone Away · Reading.” This means a
   shared app session plus a chosen intention, not verified activity, sleep or physical placement.
   A member sheet explains “Reading is their chosen plan.” No precise countdown is needed.
5. Show the viewer's publication state truthfully: “Sharing your session…” while queued,
   “Session shared” on acknowledgement, and “Your session is running. Sharing will retry.” if
   offline. Never fabricate other members' presence to fill the scene.
6. On foreground/open, refresh the bounded party projection; retain the current supported
   transport. Use revisioned start/end events, session identity, observed time and explicit
   expiry. A higher-revision end or cancellation overrides delayed starts. With stale data,
   label “Last update…” and remove the active-session emphasis once its validity ends.
7. On completion/early end, the campfire presence ends independently of reward settlement.
   Keep the latest permitted activity in the existing finite group stream. No shame animation,
   disappearance-as-misconduct label, or reward for leaving the screen open.
8. Opening the campfire during a run retains the local active journey and a “Back to your
   session” route. Backgrounding it is expected. Shielding and emergency exit remain governed
   by the coordinator, and the Watch stays a mirror.

### Presence mechanics that need an explicit implementation contract

- Existing `windDownStarting` and `phoneAwayActive` statuses already expire. They do not by
  themselves promise an accurate whole-night “currently winding down” state. The new feature
  needs an agreed validity rule across overnight phases, end/cancel, app termination and offline
  devices. Do not require frequent foreground heartbeats that defeat putting the phone away.
- A bounded server-accepted validity interval can retain “Wind Down session” while the app is
  backgrounded. Once that interval expires or observation is stale, downgrade the wording. An
  offline early end can remain unknown to other devices until reconnect; the UI must admit that.
- Do not persist automatic campfire arrivals as user-authored drag positions. Save each member's
  ordinary meadow position, derive their temporary campfire seat from accepted presence and
  stable membership identity, and restore the ordinary layout afterward. Resolve seating
  deterministically; tap/list access remains available with dense or large-type layouts.
- Multiple eligible parties receive the user's agreed cue, subject to each agreement. Being in
  one party's screen is never interpreted as having left another session.
- Recipients only see currently authorized members. Leave, block, account switching and rejected
  agreement immediately stop new publication locally; server revocation/expiry handles readers.

### Sharing and shop implications

| Purchase or reward | Personal use | Proposed social connection |
| --- | --- | --- |
| Shepherd clothing | Fitted avatar | Existing curated public appearance travels with its owner |
| Ollie accessories | Home/Farm/chase | Keep personal; no duplicate Ollie crowd at the campfire |
| Keepsakes | Shelf | Later: explicitly chosen small memento on a member sheet, with new allowlisting if needed |
| Barn Lanterns and other bought décor | Personal Farm | No automatic upload or transfer into shared ownership |
| Earned group lantern | Shared project prop | Place beside the free campfire after the current 12-contribution threshold |
| Future shared bench/banner | None required | Earn together through eligible participation; no paywall on presence |

Current shared-habits contracts exclude custom text and do not automatically authorize the new
Phone Away intention field. Add a bounded activity ID with a versioned disclosure and capability;
existing members must accept the expansion before it uploads. Private task titles remain private.
Any later free-text sharing needs its own explicit decision and privacy/moderation treatment.
No new social fields or automatic sharing are implemented by the shop renderer work.

## Acceptance and rollout sequence

1. Validate the current shop pass: every sold item renders; every garment fits all supported
   Home/motion/run poses; previews and purchase/re-equip/storage use the same representation.
   Inspect small Farm silhouettes, dark mode, Reduce Motion, large text and VoiceOver labels.
2. Campfire direction is authorized and implemented with a free gathering spot, Shepherd
   identities and the earned lantern improvement separate.
3. Source implements versioned session presence and optional intention transport, expiry,
   terminal precedence, offline retry, membership/account isolation and compatibility tests.
4. Test on two disposable accounts/devices while app backgrounding and shielding are real.
   Validate the source/backend capability matrix and authorized deployment separately.

Native screenshots, commands and results for the local shop pass are recorded in
[the implementation evidence](../../output/design/shop-ollie-20260913/README.md).
