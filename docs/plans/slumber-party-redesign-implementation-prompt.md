# Implementation prompt — Counting Sheep Farm and Slumber Party redesign

Use the text below as the task prompt. Recommended starting setting: GPT-6 Astra, XHigh reasoning.
This file prepares the implementation task; creating it does not implement or deploy the redesign.

---

Implement Counting Sheep's agreed Farm and Slumber Party redesign in:

`/Users/ngawangchime/Desktop/Developer Projects/Phone in the Other Room`

The outcome is a beautiful, touchable paper-textured Farm experience, connected to an inviting
shared pasture that supports doing Wind Down and Phone Away together. Complete production source,
backend source/migrations, isolated validation and native visual inspection. A plan, static mockup
or Debug-only prototype is not completion.

## Read and establish the baseline

Read AGENTS.md, current topic decisions in docs/PRODUCT_DIRECTION.md and ADR-0016, then:

- docs/plans/slumber-party-pasture-redesign-2026-09-12.md
- docs/plans/farm-interaction-research-2026-09-12.md
- docs/plans/farm-art-retirement-2026-09-12.md
- docs/plans/shared-farm-prototype-2026-09-12.md
- Relevant entries in docs/FUTURE_AGENT_TASKS.md and actual deployment evidence, including
  docs/evidence/slumber-backend-20260910/deployment.md.

Inspect current release routing, production renderers, prototype gates, activity/cheer selectors,
public/private appearance contracts, membership-scoped status, persistence and reward machinery.
Treat older prose and prototype assumptions as historical where the founder decisions below
supersede them. Verify the current source rather than assuming the handoff still describes it.

Inventory the dirty working tree before editing. Preserve unrelated work and reuse only required
prerequisites. Do not reset, blanket-stage or discard changes. Read deployment evidence as evidence
of that deployed version, not proof that all current backend code is live. Never use the founder's
Farm or real party as disposable data.

Give a concise implementation sequence and baseline gaps, then proceed. Resolve routine design
and engineering choices independently; do not repeat the broad product questionnaire. Ask only
about a material unresolved decision, with a concrete recommendation and evidence, while continuing
independent work. Keep a durable progress/evidence record across long turns.

## Accepted product decisions

### Identity, visitors and ownership

- Every person is their customized Shepherd and canonical name. Ollie and sheep are animals,
  not alternative person identities. Reuse the real head/hair/skin/cosmetic renderers.
- Members explicitly contribute owned sheep: one active sheep per member per party, one party
  per sheep. Visits last until recalled, not seven nights. The sheep appears in the shared pasture
  beside its owner on arrival; keep its private flock entry, progression and visiting badge, but
  do not also draw it in the personal pasture during the visit.
- Everyone may move any Shepherd or sheep and arrange earned group decorations/structures.
  Ownership, appearance changes and sheep recall remain owner-only. Movement is never a greeting.
- Ollie remains a capable companion in the personal Farm. Build a functional fetch/gather
  interaction and test optional owned Ollies in the shared scene for useful behavior, clear owner
  identification and eight-person density. Present the working evidence before settling shared
  inclusion. Do not automatically add one dog per member or replace everyone with a group dog.

### An inhabited paper Farm

- Use a slightly elevated illustrated diorama, with the lantern courtyard as the starting
  composition: an off-centre gathering tree/lantern, grazing area, curved path, gate and rear barn.
  Match the existing front-facing characters; avoid a camera angle requiring invented poses.
- Personal Farm, shared pasture, barns, meadows and related scenery use one paper-textured art
  family. Redraw pixel shapes and edges; a texture overlay on pixel art is insufficient.
- Make distinct personal/shared compositions with consistent scale, lighting and ground shadows.
  Use layers and intentional occlusion. Characters inhabit places rather than standing in a row.
  Keep interactive props separate from background art, with usable paths and movement boundaries.
- Before substantial mechanics work, inspect two- and eight-member native compositions with real
  renderers. Compare the winding-meadow alternative only where it helps resolve a composition
  issue. Iterate on the chosen direction without requiring approval for each routine visual change.
- Scene and a useful action must be visible on an SE-sized screen above the tab bar. Support
  larger groups with connected areas/panning, readable names and 44-point minimum touch targets.
  Selection clearly identifies member or animal and owner. Provide an equivalent accessible list.
- Image generation is authorized where helpful for scenery/props. Use the image-generation skill
  and tool, prefer Image gen 2.5 if selectable, and report actual tool/model availability honestly.
  Generated lookalikes must not replace production characters or fitted outfits.

### Navigation, hierarchy and copy

- Retain Home, Nights, Farm and Settings. Keep Slumber Party entries on both Home and Farm,
  using one shared destination/state source. Home offers a timely session/response cue; Farm is
  the stable connection between personal identity/animals and the shared place. Preserve return
  navigation to the originating tab and appropriate one/multiple/no-party routing.
- Preserve the joined-party Farm card verbatim:
  - Eyebrow: SLUMBER PARTY · YOUR FARM
  - Title: Your Farm look travels with you
  - Detail: Your curated Farm look appears in your parties. Completed shared moments can bring wool home.
  Keep the existing appropriate no-party create/join variant and consent/capability handling.
- Party detail: one compact title, usable pasture, current peer/session cue, and People/Sheep/
  improvement controls. Remove repeated introductory cards and the second full People-card roster.
  Character selection and the accessible list open the same member sheet.
- Put latest eligible update, date/context, permitted summaries and response action in that sheet.
  Keep one chronological group stream, with earlier history on demand and links to the same update.
  Preserve discoverability of agreed plans, rounds, allowed sleep summaries and group controls.
- Differentiate empty, stale, unavailable and unsupported states without filling the screen with
  repeated missing-data notices or engineering explanations. Apply the repository copy skill.
- Investigate apparently duplicated activity cards by stable activity/run/round/membership IDs,
  pagination and retry projections. Preserve distinct sessions with identical rounded text and
  existing cheer references; never delete records or deduplicate by display text alone.
- Verify zero-minute producers and rounding before claiming someone started after bedtime.
  Use neutral recorded-minute wording when the data does not establish that cause.

### Play, body doubling and responses

- Extend a common interaction foundation for both Farms: grab, drag, release, grounded settling,
  bounded nudges/collisions, short petting responses and useful Ollie behavior. Reuse existing
  PastureScene logic and renderers; avoid parallel physics/business systems or an automatic rewrite.
- Separate ground position from visual bounce/tilt and foot shadows. Use stable timing, bounded
  velocity/impulses, controllable resting anchors and appropriate depth. Avoid per-frame disk/network
  writes. Distinguish tap, hold/drag and camera/scroll gestures; provide explicit accessible actions.
- Deliberate shared placements persist across accounts' devices and relaunches. Use normalized
  anchors, scene revisions, per-entity revision checks and idempotent commands. A stale competing
  move reconciles to canonical state; delayed offline moves must not overwrite newer placements.
  Keep local ambient animation bounded, without repeatedly undoing shared arrangements.
- Timely app-reported Wind Down/Phone Away cues are required now, not deferred with full live
  multiplayer. Reuse membership-scoped statuses and canonical reconciliation, with expiry and
  freshness. Distinguish planned timing, fresh session report, stale/unknown, and completed update.
  Membership/ambient animation does not prove online presence, sleep or phone placement.
- The interactive shared pasture is allowed during active Wind Down. Provide a clear route from
  live Home and back, retaining session state. Visiting/playing must not pause the ritual, clear
  shielding, fabricate Brief Access or generate credit. Preserve emergency/completion routing,
  existing notification policy, night comfort and Reduce Motion. Full live multiplayer is later.
- Put understandable responses beside their original update, with clear intention and recipient.
  Reuse existing cheer meanings/transport where compatible; do not silently change persisted
  meanings. Touching/moving a character never sends a message automatically.
- Preserve sender, recipient and original update through pending, server-accepted, recipient-app
  received and retryable failure. Never equate sending or app receipt with seen. Recipients can
  reopen the original context. Durable idempotency must prevent duplicate sends and repeated
  recipient celebrations after taps, retry, reconnect or relaunch. A context-free greeting needs
  an explicit capability, not a fabricated update.

### Shared improvements and compatible backend

- Implement one visible shared improvement: the lantern gathering spot. Build on existing eligible
  participation and server grant foundations; preserve existing personal Farm credit/wool grants.
  No new currency, screen-open rewards, cheer farming or sheep-presence reward multiplier.
- Inspect existing eligibility, then propose concrete project qualifying events and thresholds
  with two/eight-member pacing examples, early endings, multiple parties and round transitions.
  Numeric pacing remains unresolved: prepare a configurable, tested source implementation and
  fixture values while seeking a focused decision before fixing release policy. Progress should
  survive absence and membership changes; settlement must be replay-safe and exactly once.
- Include required backend source, migrations and isolated permission/compatibility tests for
  visits, layout, improvement state and any necessary response/status extensions. Extend existing
  identity/membership/activity/reward systems. Do not create general friends, chat or discovery.
- Validate contributed-sheep ownership server-side with bounded public appearance. Do not upload
  a private Farm document/inventory or expose missing private appearance fields as a shortcut.
  Migrate old Ollie/sheep avatar selections to agreed Shepherd presentation compatibly, preserving
  accepted sharing agreements and explicit consent for newly shared fields where required.
- Cover account switching, membership epochs, blocks, leaving, removal/trade/recall, party deletion,
  unauthorized users, old clients and unsupported servers. Keep historical records separate from
  current scene visibility. Validate shared edits and preserve a recoverable arrangement.

## Approved asset lifecycle

The founder accepted Active → Replacement candidate → Retired. Follow the retirement register.
Replace active scenery consumers coherently, including onboarding and Shop previews where reused.
Review PixelAssetImage sampling for paper artwork without changing unrelated pixel assets blindly.
Preserve logical asset/catalogue IDs, appearance compatibility, required masks and fitted cosmetics.

For each candidate, verify static/dynamic references, fallbacks, all target resource usage and
recoverability. Once replacements are integrated and verified, remove confirmed superseded runtime
files in that batch; marking them old is insufficient. Git history can recover previously committed
art, but uncommitted files may be the only copy. Preserve unrelated artwork/design output. Keep
generation intermediates outside runtime catalogs under the approved ignored workspace. Do not
rewrite Git history. Measure source and compiled bundle resources separately before/after cleanup.

## Delivery and acceptance

Work in small connected batches: baseline; native paper composition/hierarchy; shared interaction
foundation; visits/layout/status/response contracts and integration; shared improvement; retirement
and final verification. Use disposable fixtures and ordinary previews, then integrate actual release
screens. Screenbook remains shelved. Do not stop at another simulated-backend demonstration.

Run repository-required project generation when needed, affected builds, full local app build and
unit suite. Add meaningful domain, replay, migration, concurrency and permission tests. Inspect the
native UI and repair failures introduced by the work. Capture two/four/eight members, distinct outfits,
owned sheep, selection, empty/stale/offline/unsupported states, failed-send retry, recipient feedback,
project progress/completion and active Wind Down. Check SE sizing, light/dark, Dynamic Type,
VoiceOver, Reduce Motion, hit targets and actual drag/pan/tap behavior where tooling permits.

Use isolated backend tests to establish server permission and compatibility behavior. Physical
two-device checks must cover status freshness/expiry, concurrent moves, reconnect, account isolation,
recipient acknowledgement and active-session protection. If unavailable, record them as outstanding;
a still image does not prove motion, and a Simulator does not prove shielding or physical placement.

Finish with integrated production behavior, native screenshots, exact build/test evidence, backend
source versus deployed capability, asset removals/resource measurements, and concrete remaining
device/rollout checks in the backlog. Update owning decisions to match the accepted final behavior.

This task authorizes local implementation, necessary image generation, safe scoped asset retirement
and isolated validation. It does not authorize deployment, production sharing activation, release
upload, commits, pushes, new dependencies/targets/entitlements, signing changes or tab restructuring.
Complete the reviewable source and evidence before requesting any additional action authorization.
