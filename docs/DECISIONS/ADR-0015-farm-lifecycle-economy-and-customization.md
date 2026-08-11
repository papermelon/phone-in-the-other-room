# ADR-0015: Farm Lifecycle, Economy, Shop, and Customization

- Status: Accepted
- Date: 2026-08-10; wool-only economy amendment accepted 2026-08-11
- Decider: Founder
- Supersedes: the Farm/economy restrictions in ADR-0003, ADR-0007, ADR-0009, and ADR-0010
- Related: ADR-0006, ADR-0014, `docs/REWARDS.md`

## Context

Ollie's sheep search is the narrative result of the Wind Down ritual, but the first shipping
Farm treated found sheep as a small static display. It repeated the latest arrival, rendered the
flock too small to feel owned, and put missing and discovered sheep into a dense horizontal
board. It also had no meaningful decision after a sheep arrived.

Earlier agent-authored guidance treated permanent, equal, cosmetic-only sheep and the absence of
currencies as fixed product boundaries. The founder has replaced that direction. Counting Sheep
should support several legitimate approaches: collecting and expanding, producing wool, trading
sheep to other farms for immediate wool, completing the catalogue, and customizing Ollie, the
shepherd, or the Farm. The initial implementation split these choices across wool and cash, but
that distinction made prices and balances harder to understand without adding a useful decision.

## Decision

### Narrative geography and names

Farm remains one of the four root tabs. Its nested destinations are:

- **The Barn** for the active owned flock, pending arrivals, capacity, shearing, and trading;
- **Trail Board** for missing sheep and the one trail Ollie currently favours;
- **Ollie's Trail Notes** for persisted homecomings and clue history;
- **Farm Shop** for Barn expansion, cosmetics, decoration, and collectibles; and
- **Your Shepherd** for the local human-avatar representation.

Earlier working labels for these destinations are retired from the current product language.

### Discovery and ownership are separate

`SheepDefinition` remains the finite catalogue source for archetype, rarity, breed, habitat,
art, clue, and story. `FarmState` owns individual `FlockSheep` instances created by successful
search outcomes.

The first encounter with a catalogue definition keeps its canonical name. Later encounters with
the same archetype create a separate sheep with a deterministic local name. Every resolved
outcome remains in `SheepSearchState`, and every discovered definition remains in Farm history
even if an owned sheep is later traded to another farm.

This separation lets the Farm have a real lifecycle without erasing what Ollie found or
rerolling a completed Wind Down.

### Capacity and pending arrivals

The active flock begins with room for 12 sheep. Four sequential wool purchases expand capacity
to 24, 36, 48, and finally 60 sheep for 15, 36, 80, and 170 wool respectively.

When a search finds a sheep and the active flock is full, the sheep becomes a persisted pending
arrival. It does not generate wool or appear in the pasture until welcomed. It can be welcomed
after room opens, welcomed automatically by a newly purchased capacity tier, or traded directly.
It is never silently discarded or automatically traded.

### Shearing and wool

Shearing is user-directed and non-destructive. A sheep stays in the active flock and regrows wool
after subsequently completed protected nights:

| Rarity | Wool | Regrowth |
|---|---:|---:|
| Common | 1 | 2 protected nights |
| Uncommon | 2 | 3 protected nights |
| Rare | 4 | 4 protected nights |
| Legendary | 7 | 5 protected nights |

Arrival wool is ready immediately. Wall-clock waiting, app opens, and overnight hours do not
advance regrowth.

### Trading sheep for wool

Active and pending sheep can be traded to another farm for wool:

| Rarity | Base wool |
|---|---:|
| Common | 3 |
| Uncommon | 6 |
| Rare | 13 |
| Legendary | 30 |

A sheep traded while its wool is regrowing returns 75% of its base value, rounded down. Shearing
is recurring income and keeps the sheep; trading provides roughly three to four shearings of wool
immediately and frees capacity. A favourite can still be traded, but the confirmation names it
explicitly. Trading changes ownership, not discovery or Trail Note history.

Automatic expiration, ageing, random disappearance, breeding, and seasonal migration are not
part of this implementation. They remain possible future product decisions.

### Farm Shop and customization

The Farm Shop is a production destination nested in Farm and backed by a fixed local catalogue.
Wool is its only currency. Capacity tiers cost 15/36/80/170 wool; launch cosmetics and
collectibles cost between 3 and 14 wool. Prices remain centralized balance rules.

Purchases are atomic and idempotent. Owned and equipped IDs live in `FarmState`; visible items
use real bundled art with a code-native fallback for capacity tiers. The Shop uses a responsive,
non-scrolling category grid, one visible wool balance, category ownership progress, and explicit
affordability, owned, and equipped states. The initial catalogue contains all four capacity
tiers, three Ollie accessories, three shepherd wearables, four Farm decorations, and two
collectibles.

Shop presentation keeps inventory thumbnails and equipped render art as separate contracts.
Inventory thumbnails remain 384×384 Shop illustrations. Character equipment uses a neutral
full-body Ollie sprite plus same-canvas accessory overlays, and Shepherd hats use fitted
same-canvas overlays for each supported hairstyle; a Shop thumbnail is never positioned over a
character. Outfit masks remain the source of truth for the existing Shepherd skin/hair/outfit
system. Missing presentation art falls back to a symbol in inventory surfaces or leaves the
equipped overlay absent without removing ownership.

Equipment actions are pure `FarmState` intents: wear/take off one Ollie accessory, wear/take off
one Shepherd outfit, wear/take off one Shepherd accessory, place/put away a Farm decoration, and
display/store a collectible. Each character slot is exclusive; wearing a new item replaces only
the matching slot. Purchases may immediately apply the corresponding intent. Farm decorations
use stable bounded ground anchors, and displayed collectibles appear in the production Farm as a
small keepsake display. These surfaces are separate from the gated legacy reward shelf.

`Your Shepherd` is a private local avatar, not a social profile. Its first implementation has
skin-tone and hair-style choices plus purchased outfit and accessory slots. The shepherd, Ollie
accessory, and Farm decoration are visible in the pasture.

### Search tracking

The Trail Board allows one eligible, undiscovered sheep to be tracked. Tracking does not change
the overall encounter probability. After a successful encounter roll, the tracked sheep's
selection weight is multiplied by three. The UI states that Ollie favours rather than guarantees
that trail. Tracking clears on discovery.

### Persistence and migration

`FarmState` is versioned JSON stored under `ollie.farm.state` in standard UserDefaults. It is
separate from legacy `UserProgress.sheepBalance` and `coinBalance`; those values keep decoding but
are not reinterpreted as wool. `FarmState` schema version two retires the version-one Farm cash
balance and converts it once at five cash per wool, rounding a remainder up so a saved balance is
never silently discarded. The conversion is recorded idempotently, historical cash transaction
deltas remain audit-only compatibility data, and new encodes no longer write `cashBalance`.

Migration creates one individual sheep for every historical found `SheepSearchOutcome`, using
the outcome ID as stable identity. A legacy `foundSheepID` without an outcome receives a stable
synthetic identity. Reconciliation is idempotent, and overflow becomes pending rather than being
lost. Local reset includes the new key.

### Presentation and architecture

The Farm root renders paged pastures with up to 12 active sheep each. A fresh, bounded arrangement
is derived from stable sheep IDs whenever the Farm appears, while fixed ground slots prevent overlap,
floating sheep, or obstructed controls. Wool state, equipped customization, Ollie, and the shepherd
make the scene reflect real data.
One context-sensitive action is shown above compact flock, discovery, and wool status.

Pure capacity, lifecycle, migration, pricing, purchase, equipment, and tracking logic lives in
`Shared/` with unit tests. `PersistenceService` owns JSON storage. The existing coordinator
settles a new Farm arrival beside its persisted search outcome. `FocusRunViewModel` exposes Farm
intents; views contain no economy rules. No new target, root tab, dependency, entitlement,
backend, or session state machine is introduced.

## Consequences

- Wind Down now has a visible narrative result and a continuing Farm-management loop.
- Collectors, wool producers, traders, catalogue completers, and decorators can prioritize
  different outcomes while sharing the same underlying protected-night ritual.
- Discovery history grows independently from the finite active flock.
- Balance constants are explicit and testable, but will need tuning from real play data.
- The local UserDefaults schema is richer; bounded transactions and a 60-sheep active ceiling
  keep it appropriate at the current scale.
- The gated `MVPMockData` Farm/Shop layer remains an internal historical preview and is not a
  production data source.

## Future decisions

- Additional sheep profiles and dedicated cosmetic raster art
- Sheep-specific cosmetic slots
- Ageing, breeding, visiting, seasonal migration, or other lifecycle systems
- Economy tuning from observed player strategies
- Whether any future commercial purchase layer belongs; this ADR adds no real-money path
- Friends or social features, which remain a separate decision
