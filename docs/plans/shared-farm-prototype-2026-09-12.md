# Shared Farm prototype — living meadow (12 September 2026)

Status: **prototype, not release-wired.** Everything below is gated behind the
`\.sharedFarmPrototype` environment value (nil in release) and the DEBUG launch
argument `--shared-farm-prototype`. Nothing was deployed, committed or pushed.
Data is disposable (`SharedFarmPrototypeFixtures`, isolated defaults suite).

## 1. Assessment of the current app

Compared against source and the 10 September evidence set, plus Simulator captures
of the current build (`docs/evidence/slumber-grounded-farm-20260910/`, `/tmp` baselines).

**What holds together.** Home, Nights and Farm share the pixel design system, the
Ollie voice, and truthful copy about what the app can and cannot observe. The
personal Farm already has a real character engine (`PastureSceneController`):
drag, wander, chase, ambient behaviour, Reduce Motion and Wind Down quieting, and a
persisted arrangement. The Slumber Party V4 detail is factually careful.

**What fragments the experience.**

- *Two Farms that do not know each other.* The personal pasture is playful and
  touchable; the shared Farm is a static row of portraits. Nothing from one
  appears in the other, so there is no reason to return to the party except to read.
- *Party detail is a long report.* Header, notice, farm row, cheers, night loop,
  people, habits, activities, round progress, group details — ten stacked cards
  before a small phone shows anything interactive. History and rounds compete
  with people for the first screen.
- *Repetition.* Member cards showed two "Not shared yet" cells for the same
  absence; the Home section, the party header and the people section each restate
  status. Received cheers and visitors were listed in more than one place.
- *Exposed implementation.* "0 min · Completed" is a truthful number (before-bed
  minutes are zero when Wind Down began at or after bedtime) presented like a
  bug. Users cannot tell whether it is a defect.
- *Social actions without a mental model.* A cheer is one tap on a fixed icon.
  It is not clear what the friend's app will show, when, or whether they were
  "notified". Nothing distinguishes touching a character (local) from sending
  something (remote).

**Data vs. presentation.** The connection-warning flash was already a data-state
fix on 10 September (observation enum). Remaining stale notices are per-screen
presentation. "0 min · Completed" is correct data with wrong wording. "Not shared
yet" duplication was pure presentation.

## 2. Directions considered

| | A — Living shared meadow | B — Campfire timeline | C — Postcards |
|---|---|---|---|
| Idea | One dusk meadow; members' characters stand together; a member can send one of their own sheep to *visit* for a week; drag anyone around locally; drop your character beside a friend to *offer* a greeting | Members sit around a fire; nightly updates appear as a vertical story; cheers attach to entries | Each night you may send one hand-picked "postcard" (cheer + sheep sticker); the party is a mailbox |
| Character presence | Strong; reuses pasture engine and sheep art | Weak; portraits only | Medium; sticker, not character |
| Connects to personal Farm | Yes — your real sheep leaves and comes back | No | Partly |
| Local vs. sent clarity | Natural: touch is local, a card confirms sending | Clear but flat | Clear |
| Risk | Overlap on small phones; needs an additive backend capability | Adds another list | Feels like chat lite |

**Chosen: A.** It is the only direction that makes the personal Farm and the
party one product (the sheep you earned is the thing that travels), it reuses
production renderers and the pasture engine rather than inventing new UI, and
the touch model separates "play" from "send" without a modal warning.

## 3. What was built

### Shared domain (`Shared/`, tested in `Tests/SharedMeadowTests.swift`)

- `SharedMeadow.swift`: `SharedFarmVisit` (7-night stay, `nightsRemaining`),
  `SharedFarmGreeting` + `SharedFarmGreetingContext` (`update`, `visit`, `meadow`)
  + `SharedFarmGreetingDelivery` (`pending`, `accepted`, `receivedByApp`, `failed`;
  never "seen" or "read"), `SharedFarmSocialCopy` (sender preview, recipient line,
  visit lines, truthful `updateLine`), `SharedMeadowOccupant`, versioned
  `SharedMeadowArrangement` (local only), `SharedMeadowLayout` (seeded two-row
  positions, ≤3 in the front row, greeting-candidate detection).
- `PastureScene.swift`: generic settle over `PastureSceneNeighbour`s and
  `nudgePlan` — the dropped character lands where it was put; overlapped
  neighbours step aside deterministically.
- `NightFlockPresentation.swift`: zero-minute copy — "Started after bedtime ·
  no before-bed minutes" instead of "0 min".

### App (all prototype-gated unless noted)

- `SharedFarmPrototypeStore` — simulated backend: visits, greetings, delivery
  transitions (700 ms accept/fail, +1.4 s received-by-app), idempotent sends,
  retry, "friend activity" injection, local arrangement persistence.
- `SharedMeadowSceneController` — `@Observable` scene over `SharedMeadowOccupant`
  using the pasture engine's behaviours; ambient motion off under Reduce Motion
  and during active Wind Down.
- `PastureCharacterHitTarget` generalised over `PastureInteractionControlling`
  (release `PastureSceneController` conforms; no behaviour change).
- `SlumberPartySharedMeadowView` — the meadow, nameplates, visitor strip,
  "Send a sheep to visit" (hidden during active Wind Down), "Everyone as a list".
- `SlumberPartyFriendCardView` — friend/me card: latest update in plain words,
  three-step greeting (choose → preview what their app will show → send) with
  delivery rows and Retry; my card shows "For you" and visiting-sheep controls.
  `SharedFarmVisitPickerView` picks from the *real* active flock.
- `SharedFarmForYouSection` — one card merging durable cheer receipts (existing
  contract) and prototype greetings; visitors are not repeated here.
- `SharedFarmHomeLine` — one line on idle Home's Slumber Party card: the newest
  thing a friend actually did. Silent when nothing new.
- `SlumberPartyV4PartyDetailView` — when the store is present: meadow replaces
  the static farm row, people stay on the first screen, and night loop /
  activities / habits / rounds collapse into "History, habits and rounds".
- **Release-path changes (not gated):** `PastureSceneController.finishDrag` now
  uses `nudgePlan` on the personal Farm; `SlumberPartyV4MemberCard` shows one
  "Sleep and Wind Down summaries not shared yet" line; `NightsDayDetailView`
  labels zero-minute rows "started after bedtime".

### Fixture route

`--shared-farm-prototype` boots the ordinary four-tab shell on disposable data.
Flags: `--prototype-open-party`, `--prototype-open-card=<moss|juniper|rowan|me>`,
`--prototype-suggest-greeting`, `--prototype-sent-greeting`,
`--prototype-fail-first-send`, `--prototype-open-visit-picker`,
`--prototype-friend-reply`, `--prototype-home-section`, `--prototype-meadow-section`,
`--prototype-wind-down-active`, `--prototype-accessibility`, `--prototype-hide-controls`.
An on-screen "Moss replies" chip stands in for the second phone.

## 4. Experimental decisions

- **Touch is local; a card sends.** Dragging anyone rearranges *your* view only
  (`SharedMeadowArrangement`, never uploaded). Dropping your own character next to
  a friend opens their card with a suggested greeting; nothing leaves the phone
  until "Send …" is tapped, after a sentence stating exactly what the friend's app
  will show.
- **Visiting sheep are the bridge.** A visit shares the sheep's catalogue id and
  name for 7 nights, nothing else from the Farm. One visit per member at a time.
- **Delivery states are participant-only facts.** "Saved to the party" and
  "Reached their app" mirror the existing acknowledgement contract; there is no
  read receipt and copy says so.
- **Nudges, not collisions.** Neighbours step aside (`.reacting`) and settle in
  0.9 s (10 ms under Reduce Motion). No physics, no bouncing.
- **Party hierarchy.** People and the meadow first; everything historical behind
  one disclosure. Not applied to the release path pending decision.

## 5. Backend contracts for eventual integration

All additive; the existing v4 list/detail/react/acknowledge commands remain.

1. `shared_farm_visits` — capability `sharedFarmVisitsVersion: 1` on the list
   response. Row: `visit_id, party_id, member_id, sheep_definition_id (catalogue
   id only), sheep_display_name (≤ 24 chars, profanity-filtered client+server),
   sent_at, expires_at (= sent_at + 7 nights in member tz)`. One current row per
   `(party_id, member_id)`; replace semantics. Membership-scoped read; cascades on
   leave/block like update streams.
2. Greetings with `context = update` reuse `reactMembership` and the existing
   receipt projection (`updateCheerReceipts`). No new table.
3. Greetings with `context = visit | meadow` — new command `greetMember`
   `(party_id, recipient_member_id, cheer, context_kind, context_id?, client_id)`
   idempotent on `client_id`; server returns `accepted_at`; recipient app posts
   the existing acknowledgement to produce `received_by_app_at`. Same 90-day
   retention as update cheers.
4. Never uploaded: `SharedMeadowArrangement`, personal Farm document, positions,
   any wool/shop/search state.
5. Quiet boundary unchanged: no push for greetings or visits; they appear on next
   refresh. Active Wind Down hides send controls and stops ambient motion.

## 6. Validation evidence

- `xcodegen generate` (new files) — succeeded.
- `xcodebuild build … -destination 'generic/platform=iOS Simulator'` — **BUILD SUCCEEDED**.
- `xcodebuild test … -destination 'platform=iOS Simulator,id=60935BFC-…'` (iPhone SE
  review simulator) — **967 tests, 0 failures**, including new `SharedMeadowTests`
  and the zero-minute presentation test.
- Simulator captures in `docs/evidence/shared-farm-prototype-20260912/` (iPhone SE,
  small screen): party detail with meadow (dark, light, accessibility 3), Moss card
  (idle, suggested greeting, sent with delivery rows, failed with Retry), my card,
  visit picker from the real flock, Home section before/after a simulated reply,
  meadow during active Wind Down (send control hidden), personal Farm tab unchanged,
  Reduce Motion capture (static frame; timing difference is not visible in a still).

## 7. Limits and remaining work

- No touch automation was available on this machine, so drag/nudge/greeting-candidate
  gestures were exercised only through unit tests, previews and scripted fixture
  routes, not by finger. Needs a device pass.
- Reduce Motion, VoiceOver focus order and haptics need a physical device.
- The fixture party's "Clover" presentation is seeded separately from the personal
  Farm shepherd; production should derive both from the account profile.
- Release adoption requires the founder decision recorded in
  [FUTURE_AGENT_TASKS.md](../FUTURE_AGENT_TASKS.md) and the contracts above.
