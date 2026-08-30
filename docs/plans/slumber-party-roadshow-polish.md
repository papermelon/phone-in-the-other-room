# Slumber Party V4 roadshow polish

**Superseded hierarchy (2026-08-27):** the founder now defines Slumber Party as a core feature.
The list-only/subordinate Home restrictions below no longer apply. Use
`home-social-recovery.md` for current scope. Existing privacy, factual data and reward contracts
remain until explicitly revised; outside-round sharing is a separate pending decision.

- Status: implementation-ready product/UX plan
- Time box: 48 hours
- Scope: presentation and local client behavior only; no backend expansion, account-role changes,
  or core Wind Down/Farm redesign

## Decision summary

The roadshow proposition should be:

> Give your phones some time away — together.

This is clearer than “Wind down together” because V4 also shares daytime Phone Away, and more
inclusive than “Give your phones a bedtime” because the same product must work for couples and
close friends as well as families. Family should be salient in supporting copy—“family, a partner,
or close friends”—without changing the account model.

The P0 pass should make an existing party feel like a small shared ritual, not a group-management
form. It should not add a feed, new social data, new reward rules, or a second dashboard. The V4
list remains the source for lightweight Home/Farm bridges; rich social truth stays in party detail.

Two implementation facts require special care:

1. `phoneAwayActive` is currently published both for a primary Wind Down after the phone has been
   validated away and for an additional Phone Away. It cannot truthfully be presented as proof
   that the member chose the Phone Away mode. P0 copy must say **“Phone is away.”** Distinguishing
   the two live modes would require a contract change and is deferred.
2. A five-minute onboarding practice is excluded from terminal V4 activity and grants, but the
   start path currently calls `publishV4WindDownStarting` before the new run is marked as practice.
   A practice can therefore leak a 30-minute live starting status into active parties. P0 must
   close this gap before the roadshow.

## 1. Current UX diagnosis

### What is already strong

- V4 has the right bounded social primitives: persistent invited groups, fixed seven-night
  windows, member-only curated Farm identities, expiring/revisioned live statuses, durable factual
  activities, and three fixed cheers.
- Local activity is authoritative and the outbox/fan-out model does not make Wind Down wait for
  social transport.
- Party detail has enough data to build a legible social loop without another backend request:
  memberships, current-round activities, current statuses, activity cheers, and live cheers arrive
  together.
- Home/Farm already receive a list-derived `NightFlockHomeSummary`; no rich party-detail fetch is
  needed or appropriate there.
- V4 grants already settle idempotently into the local Farm.

### Where the experience loses the proposition

1. **The landing page opens with mechanics, then repeats administration.** “INVITE-ONLY · SEVEN
   NIGHTS,” a second “YOUR SLUMBER PARTIES” heading, and always-visible create/join forms use much
   of the page before an existing relationship can feel important. The first label can also imply
   that the party expires after seven nights, which is false.
2. **Party detail has one fixed hierarchy for every lifecycle state.** Invitation management is
   always second, even when four people are in an active round. The host’s “Start seven nights”
   action is buried inside rename/delete controls.
3. **User-facing “Round” copy exposes the storage model.** “Round 1 is ready to begin” is accurate
   but does not explain the shared ritual. `Date()` fallback logic also turns an elapsed active
   round into “Day 7 of 7” rather than clearly saying that its seven-night window has ended.
4. **Member cards lead with missing realtime.** “No live update right now” is visually followed by
   a large Farm snapshot, while the latest durable current-round activity is not represented on
   the person. The result feels like a cosmetic directory rather than people doing something
   together.
5. **The current live mode label overclaims.** `.phoneAwayActive` is rendered as “Phone Away is
   underway,” even though the same status is emitted for a primary Wind Down after phone-away
   validation.
6. **Durable activity reads like rows from a ledger.** “THIS ROUND,” a status/minutes line, and
   three equally weighted reaction buttons expose the available data but not the loop: a person
   did their own phone-away activity, it reached the party, and another person can quietly respond.
7. **The reward is real but poorly explained.** V4 currently produces wool grants, yet the Farm
   banner and recent-event row use generic “gift” language and usually omit the amount. The party
   does not preview or explain unearned rewards, which is correct and should remain unchanged.
8. **Home and Farm reuse the same bridge card.** Home needs to connect the user’s next local ritual
   to their party. Farm needs to explain that only a curated identity travels outward and that a
   completed shared moment can return wool. One summary cannot do both jobs well without a surface
   context.
9. **Single-party routing adds an unnecessary stop.** Both bridges always open the hub/list even
   when the list already proves that there is exactly one party. Direct detail routing is safe if
   it falls back to the hub when the cached ID is no longer present.

### Assumptions to reject

- Do not equate no live status with “not started,” inactivity, non-compliance, or a missed night.
- Do not call a count “people done.” The client can count current-round activity records, not
  people who complied or people who put their phone away.
- Do not expose `.phoneAwayActive` as proof of the selected run type.
- Do not promise a seven-night reward, a group threshold, a sheep, or a keepsake. Those are legacy
  V1–V3 concepts, not the V4 grant contract.
- Do not make “family” a membership type. It is a use case expressed through positioning.
- Do not make the party’s elapsed seven-night window sound like every member completed seven
  nights. Time elapsed; participation records remain factual and individual.

## 2. Product hierarchy: before vs after

| Surface | Current hierarchy | P0 hierarchy |
| --- | --- | --- |
| Landing, no parties | Mechanical hero → empty card → create form → join form | Inclusive proposition → truthful how-it-works empty state → **Start a party** / **Join with a code**, revealing only the chosen form |
| Landing, existing parties | Mechanical hero → list → create form → join form | Inclusive compact hero → existing party cards first → compact **Start or join another** disclosure → account/safety |
| Detail, one member | Header → invitation → person → empty round → host controls | Context card with **Invite someone** as the job → invitation → person → party settings |
| Detail, 2+ pending | Header → invitation → people → empty round → buried start | Context card with host **Start 7 nights** or member waiting copy → people → invitation → settings |
| Detail, active | Header → invitation → people → records → controls | **Night N of 7** context → people and live social actions → shared moments and durable cheers → invitation/settings disclosures |
| Detail, elapsed | Header says Day 7 → invitation → people → records → controls | **These 7 nights are complete** + factual shared-moment count → host **Start another 7 nights** or member waiting copy → shared moments → people → settings |
| Home | Generic list metadata bridge | A reminder that the user’s own Wind Down/Phone Away can become a shared moment; no detail fetch |
| Farm | Same generic bridge below several Farm utilities | A lightweight world/reward bridge after the current Farm priority: curated look travels, Farm stays private, completed shared moments can bring wool home |

## 3. The 48-hour cut

### P0 — ship these five coherent changes

#### P0.1 — Make the landing relationship-first

- Replace the seven-night mechanical eyebrow with **“PRIVATE · INVITE-ONLY.”**
- Use the decided proposition and explicitly explain that a party persists while sets of seven
  nights repeat.
- When parties exist, show all existing cards before acquisition controls.
- Replace the two always-visible forms with a compact **“Start or join another”** disclosure that
  offers two choices and reveals one form at a time.
- When there are no parties, show **Start a party** and **Join with a code** as immediate actions;
  still reveal only one form at a time.
- Honor the existing `prefersJoinEntry` flag from first-run routing by opening the join disclosure
  and focusing its code field. That flag is currently set but never consumed.
- Preserve the five-party limit, Shepherd-name gate, invite preview, account deletion, and safety
  behavior.

#### P0.2 — Add one testable V4 presentation state and drive detail hierarchy from it

- Derive a presentation-only lifecycle from existing V4 data; do not rename Codable models or RPC
  fields:
  - `needsInvite`: one member;
  - `readyToStart`: 2+ members and pending/no current round;
  - `active(night: 1...7)`: round is active and current in its stored timezone;
  - `elapsed`: the fixed seven-night interval has passed, or the model explicitly says completed.
- Never use `day(...) ?? 7`. If an active round is outside its interval, derive elapsed only after
  comparing the local date with `startsOn + 6` in the round timezone.
- Put the state-specific message and host action at the top. Move rename/delete/leave into **Party
  settings**. Invitation is primary only for a one-person party and secondary otherwise.
- Use “7 nights” and “Night N of 7” in presentation copy; keep `round`, `roundID`, and round number
  internal.
- Treat the elapsed message as a calendar statement, not a group achievement.

#### P0.3 — Rebuild member cards around social truth

- Feed each card the member’s latest durable activity in the current round as well as their current
  unexpired live status.
- Use this visual priority:
  1. display name + You/Host badges + safety menu;
  2. live status when present;
  3. latest durable current-round activity when present;
  4. valid quiet-cheer action;
  5. compact curated Farm identity strip.
- Render no-data as **“No shared update yet.”** Do not add “not started,” a gray failure state, a
  progress ring, or an inferred absence.
- Render `.phoneAwayActive` as **“Phone is away.”**
- Keep the curated Shepherd, Ollie ornament, featured sheep, and pasture theme, but reduce artwork
  to a compact strip with smaller avatars and one supporting line. Keep the existing allowlist
  fallback and accessibility label.
- Keep live cheers available only for another member with a current active status accepted by the
  existing server rule. Never allow cheering oneself.

#### P0.4 — Make shared moments and fixed cheers read as the loop; close the practice leak

- Rename the current section to **SHARED MOMENTS** with a one-line factual explanation.
- Present each current-round activity as:
  - person;
  - Wind Down or Phone Away;
  - rounded quiet minutes;
  - Night 1–7;
  - Completed or Ended early;
  - received/sent fixed cheer state.
- Add a visible **“Send a quiet cheer”** label before the three fixed options. Preserve only Warm
  wave, Moon glow, and Paw print; preserve `sentByMe` selected state and exact counts.
- For the user’s own record, show received quiet-cheer totals without reaction controls.
- Keep earlier activity bounded under a collapsed **Earlier shared moments** section. Do not create
  infinite scrolling, posting, comments, or a feed composer.
- Fix start publication so a five-minute practice publishes no V4 live status. Keep the existing
  terminal/practice and late-join exclusions. Centralize this as a pure publication policy so it is
  unit tested rather than relying on call order.

#### P0.5 — Give Home and Farm distinct bridge jobs

- Add a presentation-only destination party ID to the list-derived summary. Exactly one current
  party routes directly to detail; zero or multiple parties route to the hub. If the party vanishes
  before navigation resolves, fall back to the hub.
- **Home:** keep the card after the local Wind Down CTA/guidance. Its copy connects the user’s own
  next activity to the party but shows no member status, completion fraction, or rich detail.
- **Farm:** move the card to immediately after the current Farm priority card—not above the pasture
  or core Farm action. Use Farm-specific copy about the curated identity and local wool trace.
- Use the existing list refresh/realtime behavior; do not fetch party detail for either bridge.
- When a V4 wool grant is applied, show the actual newly applied wool amount in the transient Farm
  message and in the `.slumberPartyGrant` recent-event detail. Do not show an upcoming reward.
- Preserve the active Wind Down boundary: no bridge, direct route, badge, or social card during an
  active Wind Down.

### Suggested 48-hour allocation

| Time | Outcome |
| --- | --- |
| Hours 0–4 | Add pure presentation/publication policies and deterministic tests; update copy sources |
| Hours 4–10 | Landing progressive disclosure and list-card states |
| Hours 10–24 | Detail lifecycle hierarchy, member cards, shared moments, and cheers |
| Hours 24–31 | Home/Farm contextual bridges, direct single-party route, and exact wool receipt copy |
| Hours 31–38 | Build the full preview matrix; Dynamic Type, dark mode, VoiceOver-label review |
| Hours 38–48 | Full build/tests plus two-account TestFlight/physical roadshow rehearsal and bug buffer |

### P1 — only after every P0 acceptance criterion is stable

1. Improve the invitation share payload from a raw code to a brief message containing the party
   name and code. Do not add a public deep link in this window.
2. Add a collapsed **How sharing works** explainer: individual local activity remains
   authoritative; only the allowed curated profile, current-round factual records, expiring
   statuses, and fixed cheers are shared; the Farm stays local.
3. Give **Earlier shared moments** clearer grouping by available `roundID` and Night 1–7. Do not
   invent missing historical round names or dates, and do not expand the state RPC merely for this.

### Deferred

- Parent/child roles, household administration, remote control, app-monitoring dashboards,
  compliance, family scores, or guardian alerts.
- A distinct live `windDownActive`/`phoneAwayActive` contract. P0 uses “Phone is away” because the
  current contract cannot distinguish them.
- Rich Home/Farm counts, member avatars, live status, cheer controls, or party-detail prefetch.
- Shared Farms, shared pastures, party inventories, wool pooling, group thresholds, reward previews,
  legacy milestone rewards, or a party reward roadmap.
- Feeds, comments, chat, photos, follower/friend graphs, discovery, leaderboards, comparisons, or
  public profiles.
- Host transfer, recurring/scheduled auto-started rounds, longer challenges, goals, readiness, or
  legacy sharing matrices.
- Social UI during active Wind Down or new push/in-app interruption behavior.
- Backend schema/function changes solely for this polish pass.

## 4. Screen-by-screen wireframe hierarchy

### Slumber Party landing — no parties

1. Eyebrow: **PRIVATE · INVITE-ONLY**
2. Title: **Give your phones some time away — together.**
3. Body: persistent-party/family-partner-friends explanation.
4. Empty-state card:
   - **Start with people you trust.**
   - each person uses their own local ritual; shared moments stay inside the party.
5. Primary button: **Start a party**
6. Secondary button: **Join with a code**
7. Reveal only the chosen create/join form in place.
8. Account and safety disclosure.

### Slumber Party landing — one or more parties

1. Compact proposition header.
2. **YOUR SLUMBER PARTIES** and persistent-group supporting line.
3. Party cards, ordered by the server-provided list order.
4. Compact **Start or join another** disclosure; forms hidden by default.
5. Account and safety disclosure.

Party card:

```text
[group icon]  Moonlit Neighbours                         >
              Host · 3 people
              Night 3 of 7
```

Use a state line instead of a round number. The entire card is one accessible navigation action.

### Party detail — one member

1. Party name + **1 person · You’re hosting**.
2. Primary context card: **Invite someone to begin**.
3. Invitation card with create/show/copy/share as applicable.
4. **PEOPLE** with the host’s compact member card.
5. **PARTY SETTINGS** disclosure.
6. Do not render a large empty Shared Moments section before the invite job.

### Party detail — 2+ members, not started

Host order:

1. Party name + member count.
2. Primary context card: **Ready to start 7 nights together** + **Start 7 nights**.
3. **PEOPLE**.
4. Invitation disclosure.
5. Party settings disclosure.

Member order:

1. Party name + member count.
2. Context card: **Waiting for the host to begin**; no fake primary action.
3. **PEOPLE**.
4. Invitation disclosure; members may retrieve/share an existing active invite.
5. Leave-party action inside Party settings.

### Party detail — active

1. Party name + **Night N of 7** + member count.
2. **PEOPLE** member cards; active statuses and live quiet cheers are visible here.
3. **SHARED MOMENTS** current-round durable activity; completed-record cheers live here.
4. **Invite someone else** disclosure.
5. **PARTY SETTINGS** disclosure.

There is no global “done” number and no detail-screen CTA that starts the user’s local activity.
Their Wind Down/Phone Away continues to start from the existing local product surfaces.

### Party detail — elapsed seven-night window

1. Party name + **These 7 nights are complete**.
2. Factual recap line: **N shared moments reached the party.**
3. Host: **Start another 7 nights**. Member: waiting-for-host text only.
4. **SHARED MOMENTS** from the elapsed round.
5. **PEOPLE**.
6. Invitation and settings disclosures.

“Complete” describes the fixed window. Do not use confetti, a score, “everyone did it,” or a
completion percentage.

### Member card

```text
Moss                         Host                     ···
Phone is away
Latest shared · Wind Down · 30 min · Night 2
[ Send a quiet cheer ▾ ]
[Shepherd] [Ollie] [sheep]  Midnight · Moonlit pasture
```

If there is neither a current live status nor a durable current-round activity, replace both
status lines with **No shared update yet.** The Farm identity remains present but visually smaller
than the person and social truth.

### Shared-moment card

```text
Moss
Phone Away · 30 quiet min
Night 3 · Completed
Send a quiet cheer
[Warm wave 1] [Moon glow 0] [Paw print 2]
```

For the user’s own activity, replace the action row with received cheer totals. Do not display an
exact clock time from `occurredAt`; ADR-0016 treats timestamps as transport/coarse-ordering fields,
not an exact schedule surface.

### Home bridge

Keep the existing compact card position after the local primary CTA and guidance. It may show
party name, member count, role-relevant state, and Night N of 7 from list data only. One party opens
detail; zero or multiple open the landing/list.

### Farm bridge

Place after the Farm’s current priority card. It explains the curated identity and local reward
trace, then routes back to Slumber Party. It does not contain member states, party progress, or
cheer controls.

## 5. Exact copy deck

### Landing and acquisition

| Location/state | Exact copy |
| --- | --- |
| Hero eyebrow | `PRIVATE · INVITE-ONLY` |
| Hero title | `Give your phones some time away — together.` |
| Hero body | `A private group for family, a partner, or close friends. Keep the same party and start 7 nights together whenever you’re ready.` |
| Existing-list support | `Your invited groups stay together between each set of 7 nights.` |
| Empty title | `Start with people you trust.` |
| Empty detail | `Each person uses their own Wind Down or Phone Away. Shared moments appear only inside the party.` |
| Empty primary | `Start a party` |
| Empty secondary | `Join with a code` |
| Existing-party acquisition disclosure | `Start or join another` |
| Create eyebrow | `START A PARTY` |
| Create prompt | `Name your group.` |
| Create field | `Party name` |
| Create CTA | `Create party` |
| Join eyebrow | `JOIN WITH A CODE` |
| Join prompt | `Use a code from someone you know.` |
| Join CTA 1 | `Preview invitation` |
| Join CTA 2 | `Join this party` |
| Five-party cap | `You’re already in five Slumber Parties. Leave one before starting or joining another.` |

### Party/list lifecycle

| State | Exact copy |
| --- | --- |
| One member | `Invite someone to begin` |
| One-member detail | `Slumber Party starts with 2 people. Your group stays together after these 7 nights.` |
| 2+ pending, host | `Ready to start 7 nights together` |
| Pending host detail | `Each person uses their own Wind Down or Phone Away.` |
| Pending host CTA | `Start 7 nights` |
| 2+ pending, member | `Waiting for the host to begin` |
| Pending member detail | `You’ll still use your own Wind Down or Phone Away.` |
| Active | `Night {N} of 7` |
| Active detail | `Shared Wind Down and Phone Away moments from these 7 nights appear below.` |
| Elapsed | `These 7 nights are complete` |
| Elapsed factual recap, singular | `1 shared moment reached the party.` |
| Elapsed factual recap, plural | `{N} shared moments reached the party.` |
| Elapsed host CTA | `Start another 7 nights` |
| Elapsed member | `Waiting for the host to start another 7 nights.` |
| Generic list state | `Ready for the next 7 nights` |

### People, status, and activity

| Location/state | Exact copy |
| --- | --- |
| People section | `PEOPLE` |
| No live/durable member state | `No shared update yet` |
| `.windDownStarting` | `Wind Down is starting` |
| `.phoneAwayActive` | `Phone is away` |
| `.windDownCompleted` without durable record yet | `Wind Down completed` |
| `.phoneAwayCompleted` without durable record yet | `Phone Away completed` |
| Latest completed Wind Down | `Latest shared · Wind Down · {N} min · Night {D}` |
| Latest early-ended Wind Down | `Latest shared · Wind Down ended early · {N} min · Night {D}` |
| Latest completed Phone Away | `Latest shared · Phone Away · {N} min · Night {D}` |
| Latest early-ended Phone Away | `Latest shared · Phone Away ended early · {N} min · Night {D}` |
| Live action | `Send a quiet cheer` |
| One live cheer | `1 quiet cheer` |
| Multiple live cheers | `{N} quiet cheers` |
| Curated identity with sheep | `Featured {sheep} · {pasture}` |
| Curated identity without sheep | `Your Shepherd, Ollie · {pasture}` |

### Shared moments and cheers

| Location/state | Exact copy |
| --- | --- |
| Section title | `SHARED MOMENTS` |
| Section support | `Factual Wind Down and Phone Away activity from these 7 nights.` |
| Empty title | `No shared update yet.` |
| Empty detail | `Someone may be offline or away from the app. Only updates that reach this party appear here.` |
| Completed record line | `{mode} · {N} quiet min` |
| Completed state line | `Night {D} · Completed` |
| Partial state line | `Night {D} · Ended early` |
| Completed cheer prompt | `Send a quiet cheer` |
| Cheer 1 | `Warm wave` |
| Cheer 2 | `Moon glow` |
| Cheer 3 | `Paw print` |
| History disclosure | `Earlier shared moments` |
| Invitation disclosure after party exists | `Invite someone else` |
| Settings disclosure | `Party settings` |

### Home bridge

| State | Title/detail |
| --- | --- |
| No parties | `Give your phones time away — together.` / `Start a private group for family, a partner, or close friends.` |
| One member | `{party}` / `Invite someone, then start 7 nights together.` |
| Pending host | `{party}` / `Ready to start 7 nights together.` |
| Pending member | `{party}` / `Waiting for the host to start 7 nights.` |
| Active | `{party}` / `{N} people · Your Wind Down or Phone Away can become a shared moment.` |
| Elapsed host | `{party}` / `These 7 nights are complete · Ready for another.` |
| Elapsed member | `{party}` / `These 7 nights are complete · Waiting for the host.` |
| Multiple | `{N} Slumber Parties` / `Choose a party to see its current 7 nights.` |
| Eyebrow with active round | `SLUMBER PARTY · NIGHT {N} OF 7` |
| Default eyebrow | `SLUMBER PARTY` |

### Farm bridge and settled grant

| Location | Exact copy |
| --- | --- |
| Farm bridge eyebrow | `SLUMBER PARTY · YOUR FARM` |
| No-party title | `Bring your Farm look to a Slumber Party` |
| No-party detail | `Only your curated Farm look travels. Your Farm stays yours.` |
| Existing-party title | `Your Farm look travels with you` |
| Existing-party detail | `Your curated Farm look appears in your parties. Completed shared moments can bring wool home.` |
| Applied grant banner, singular | `1 wool came home from Slumber Party.` |
| Applied grant banner, plural | `{N} wool came home from Slumber Party.` |
| Recent event title | `A shared moment brought wool home.` |
| Recent event detail | `{N} wool · {date}` |

## 6. Required state matrix

| State | Primary message | Primary action | Secondary information | Must **not** be inferred |
| --- | --- | --- | --- | --- |
| 1. No parties | `Give your phones some time away — together.` | **Start a party**; **Join with a code** is secondary | Private group for family, a partner, or close friends; each person uses their own local activity | That social setup is required for Wind Down; that a family role will be created; that seven nights starts on create/join |
| 2. Existing party, one member | `Invite someone to begin` | Create/show/share the invitation | 1 person; persistent party; minimum is 2 | That the party has started; that another person is expected to comply; that inviting earns anything |
| 3. 2+ members, not started | Host: `Ready to start 7 nights together`; member: `Waiting for the host to begin` | Host: **Start 7 nights**. Member: no required action; sharing an existing invite is secondary | People and curated identities | Readiness, a shared goal, a common bedtime, or automatic start on join |
| 4. Active, no shared updates yet | `Night {N} of 7` + `No shared update yet.` | No global action; user continues their own activity from existing Home surfaces | Member identities and truthful empty explanation | That nobody started, everybody is inactive, data is complete, or realtime silence is a failure |
| 5. Active with live Wind Down | `Wind Down is starting` on that member | **Send a quiet cheer** when viewing another member | Expiring live status; latest durable activity may also remain below it | Completion, exact schedule, duration, phone location, or that the status will remain after expiry |
| 6. Active with live Phone Away | `Phone is away` | **Send a quiet cheer** when viewing another member | Expiring status and quiet-cheer totals | That the app knows this is specifically Phone Away rather than a Wind Down whose phone is validated away; completion or remaining time |
| 7. Active with completed factual activities | `Shared moments from these 7 nights` | Fixed completed-record cheer on another member’s record | Person, mode, rounded minutes, Night 1–7, Completed/Ended early, exact cheer counts | “People done,” compliance, sleep, a full-night claim, or that a partial record earned wool |
| 8. Completed seven-night window | `These 7 nights are complete` | Host: **Start another 7 nights**. Member: no required action | Exact count of current-round activity records and those factual records | That every member participated, that the group succeeded, that a seven-night reward exists, or that the party ended |
| 9. Multiple parties | `{N} Slumber Parties` | Choose a party card | Each card: member count, role, and list-derived lifecycle | Cross-party totals, deduplicated “people done,” comparative ranking, or rich detail not present in list state |

## 7. Truth and source-of-data mapping

| New presentation | Authoritative source | Derivation/guardrail |
| --- | --- | --- |
| Party name | `NightFlockV4PartySummary.name` | Display verbatim within existing validation; never derive identity from invite text |
| Party count | `NightFlockV4ListStateResponse.parties.count` | Maximum five remains server-enforced |
| Member count on list | `NightFlockV4PartySummary.memberCount` | Say “people,” never completion count |
| Member count/detail identities | `NightFlockV4PartyDetail.memberships` | Use membership IDs; never infer “You” from display name |
| Host/You | `membership.role`, `party.myMemberID`, `summary.myRole` | “You” only when opaque member IDs match |
| One-person invite state | `party.memberships.count == 1` | Invitation is the job; do not imply the round started |
| Pending state | `currentRound == nil` or `currentRound.status == .pending` | With 2+ people, host may start; member waits. A nil summary is “ready for the next 7 nights,” not a historical claim |
| Night N of 7 | `NightFlockV4RoundRules.day(at:round:)` | Only show for `.active` and a non-nil day 1...7 in the stored timezone |
| Elapsed seven nights | Round `startsOn`, `timeZoneIdentifier`, status | Derive only when the local day is after start + 6, or status is explicitly `.completed`; this describes elapsed time, not member success |
| Current live status | `party.liveStatuses` | Require same party/round/member, `expiresAt > now`; keep existing revision ordering. Expired or absent means no current shared live update only |
| `Wind Down is starting` | `.windDownStarting` | Exclude practice before enqueueing |
| `Phone is away` | `.phoneAwayActive` | Deliberately mode-neutral because current publisher emits it for primary and additional activity |
| Latest durable member activity | `party.activities` | Filter to current `roundID` and member ID; choose greatest `occurredAt` for ordering but do not display exact time |
| Shared moment mode/status/minutes/night | `NightFlockV4Activity.kind/status/roundedMinutes/day` | `completed` → Completed; `partlyCompleted` → Ended early; keep server-rounded minutes and day 1...7 |
| “N shared moments” | Count of activities filtered to current `roundID` | Count records, including partial records; never label as members, completions, or nights achieved |
| Live quiet-cheer availability | Current live status + another member | Client shows action only for `.windDownStarting` or `.phoneAwayActive`; server remains authoritative and rejects invalid targets |
| Live cheer total | `NightFlockV4LiveCheerSummary` | Sum summaries for that target member; never expose sender identity |
| Completed-record cheer count/selection | `NightFlockV4CheerSummary.count/sentByMe` | Only the three fixed cheers; no free text |
| Curated Farm identity | `membership.profile.presentation` | Render only after `isAllowlisted()`: Shepherd look, Ollie ornament, featured sheep definition, pasture theme |
| Single-party direct destination | Exactly one `NightFlockV4PartySummary.partyID` | If missing/stale at navigation time, open the hub instead |
| Home/Farm lifecycle metadata | V4 list state only | No detail fetch, live count, activity count, or “done” fraction outside party detail |
| Applied V4 wool | `NightFlockV4GrantInboxItem` → `NightFlockRewardLedger` → `.slumberPartyGrant` transaction | Show an amount only after the local durable ledger applied it; never from an unacknowledged preview or inferred activity |

## 8. Farm/reward integration analysis

### What V4 can currently cause

The deployed V4 path is narrower than the legacy local reward engine:

1. A non-practice primary Wind Down or additional Phone Away publishes a factual terminal record.
   Early-ended activity publishes `partlyCompleted`; successful activity publishes `completed`.
2. The server fans that source activity out to every eligible active party whose fixed round
   contains the activity end time, up to the five-party membership cap.
3. Each party gets at most one activity record per source ledger entry. For `completed` only, the
   current V4 migration inserts one grant for that user/party/source. Its default and deployed
   values are `kind = wool`, `woolAmount = 1`.
4. Therefore one completed local activity can currently yield one wool per eligible active party.
   A partial record yields no grant. Invite, join, start round, cheer, profile changes, opening a
   party, and settings changes yield no grant.
5. The account grant inbox is adapted with the server grant UUID intact. The local reward ledger
   applies it once, increments the user’s own wool, appends a `.slumberPartyGrant` Farm transaction,
   then acknowledges the server grant. Relaunch/failed acknowledgement remains idempotent.
6. Deleting a party does not erase an already earned account grant.

### What V4 does not currently cause

- No shared Farm or shared pasture.
- No group wool balance.
- No fixed seven-night completion reward.
- No V4 keepsake, item, or sheep-search grant. The local engine still supports legacy
  `itemOrWool` and `sheepSearch` kinds, but the deployed V4 grant creation path emits wool only.
- No reward for a partial activity or five-minute practice.
- No reward preview or upcoming threshold that can be stated truthfully.

### Smallest P0 communication change

Keep reward explanation out of party status cards so it does not turn the ritual into a points
race. On Farm, change the already-existing post-application banner and recent transaction detail
to show the exact applied wool amount. The Farm bridge may use the non-promissory line “Completed
shared moments can bring wool home.” Do not add a reward meter, party threshold, or grant inbox UI.

## 9. Home/Farm bridge specification

### Shared presentation input

Extend `NightFlockHomeSummary` (or replace it with an equivalently small non-Codable presentation
value) with:

- lifecycle (`none`, `needsInvite`, `readyHost`, `readyMember`, `active(night)`, `elapsedHost`,
  `elapsedMember`, `multiple`);
- party count;
- member count when exactly one party;
- optional destination party ID only when exactly one party;
- surface-neutral facts, not rich party detail.

Give `NightFlockHomeCard` an explicit `.home` / `.farm` context that selects the copy deck above.
Do not put user-facing copy policy in `PixelHomeDashboard` or `FarmView` conditionals.

### Home behavior

- Keep the bridge below the user’s own local CTA and any compact Wind Down guidance.
- The card’s job is “my own Wind Down/Phone Away belongs to something shared.”
- Exactly one party: route directly to current detail.
- No parties or multiple parties: route to landing/list.
- Do not load detail, show avatars, status dots, activity counts, or cheers.
- Preserve the `viewModel.isRunning` navigation guard and the active-ritual UI boundary.

### Farm behavior

- Move the bridge from below search sources/balances to immediately after `priorityCard`, keeping
  pasture and the current Farm priority ahead of it.
- The card’s job is “my curated identity travels; my Farm remains mine; settled participation can
  leave a wool trace here.”
- Use the same single-party routing rule as Home.
- Do not make Farm a party dashboard and do not expose party detail in Farm state.
- For a settled `.slumberPartyGrant`, include `transaction.woolDelta` in the existing Recent Events
  detail. If a future non-wool V4 grant arrives, fall back to the existing generic transaction
  presentation rather than describing it as wool.

## 10. File-level implementation map

| File | Implementation responsibility |
| --- | --- |
| `Shared/NightFlockPresentation.swift` | Add V4-only lifecycle, list-card, detail-context, member, shared-moment, and Home/Farm bridge presentation derivations. Keep V1–V3 functions untouched and explicitly labeled legacy. Inject `now` for deterministic timezone tests. |
| `Shared/NightFlockV4Outbox.swift` or a new small `Shared/NightFlockV4PublicationPolicy.swift` | Centralize which local roles/practice states may publish starting, active, and terminal V4 signals. No persistence schema change. |
| `PhoneInTheOtherRoomApp/Views/NightFlock/SlumberPartyV4ListView.swift` | Replace hero/list copy, prioritize existing parties, add one-at-a-time acquisition disclosure, consume `prefersJoinEntry`, update party card state labels. Split helpers if the file would exceed ~400 lines. |
| `PhoneInTheOtherRoomApp/Views/NightFlock/SlumberPartyV4PartyDetailView.swift` | Use the lifecycle presentation to order sections and place contextual host actions; rename/reframe shared moments; collapse invitation/settings when secondary; remove `?? 7` copy fallback. Split invitation/settings/activity components into new production files if needed. |
| `PhoneInTheOtherRoomApp/Views/NightFlock/SlumberPartyV4MemberCard.swift` | Accept the latest current-round activity presentation, make status/social action primary, compact the existing allowlisted Farm identity, retain safety and accessibility behavior. |
| `PhoneInTheOtherRoomApp/Views/NightFlock/SlumberPartyV4Previews.swift` | Add deterministic fixtures/previews for the nine required states, including expired status, no updates, partial activity, multiple people, AX3, and dark mode. |
| `PhoneInTheOtherRoomApp/Views/NightFlock/NightFlockHomeCard.swift` | Add Home/Farm context and exact context-specific copy/accessibility hints; keep it list-data only. |
| `PhoneInTheOtherRoomApp/ViewModels/NightFlockViewModel+V4.swift` | Reuse presentation helpers as needed; preserve state/detail fetch behavior. Do not add Home/Farm detail fetching. |
| `PhoneInTheOtherRoomApp/ViewModels/FocusRunViewModel.swift` | Determine practice before publishing the initial V4 Wind Down status and apply the shared publication policy. Preserve local run authority and existing callbacks. This file is high-conflict; make the smallest targeted edit. |
| `PhoneInTheOtherRoomApp/ViewModels/FocusRunViewModel+Farm.swift` | Sum/display only newly applied V4 wool amounts in the existing Farm message; do not change reward rules or idempotency. |
| `PhoneInTheOtherRoomApp/Views/PixelHomeDashboard.swift` | Pass `.home` bridge context and optional direct destination; preserve its current position and local CTA priority. |
| `PhoneInTheOtherRoomApp/Views/HomeView.swift` | Carry an optional party ID through the existing Farm-tab navigation handoff; retain active-run suppression and clear stale routes. |
| `PhoneInTheOtherRoomApp/Views/FarmView.swift` | Pass `.farm` context, move the bridge after `priorityCard`, route one party directly with safe fallback, and show exact wool delta for a settled Slumber Party transaction. |
| `Tests/NightFlockV4Tests.swift` or new `Tests/NightFlockV4PresentationTests.swift` | Cover lifecycle, truth-priority, copy, counts, direct destination, and publication policy. Keep existing wire/decode tests unchanged. |
| `docs/PROJECT_BRIEF.md` | Replace “create and join always visible” and administrative list wording after implementation ships. |
| `docs/PLAYBOOKS/slumber-party-qa.md` | Add practice non-publication, the presentation truth rules, direct-route fallback, and roadshow rehearsal to physical QA. |

No changes are planned for `Shared/NightFlockV4Models.swift`, `Shared/NightFlockV4Rewards.swift`,
the V4 SQL/functions, entitlements, `project.yml`, tab structure, or gated legacy/mock screens.

## 11. Regression and privacy risks

1. **Practice status leakage:** highest-priority integrity risk. Compute practice before any V4 start
   publication; do not rely on terminal guards.
2. **Mode overclaim:** `.phoneAwayActive` cannot distinguish a validated Wind Down from Phone Away.
   The P0 generic copy is required unless the server/client contract changes later.
3. **Stale realtime:** filter by current party, round, member, revision rules, and `expiresAt`. Never
   retain a prior live label after expiry merely to make the screen feel populated.
4. **Elapsed-round timezone:** derive the seven-night end in the round’s stored timezone, not the
   device’s current timezone or `7 * 86_400` seconds. DST must not shift the presentation day.
5. **False group completion:** “These 7 nights are complete” refers to the calendar window. Pair it
   only with a count of records that actually reached the party.
6. **Cross-round leakage:** latest member activity and shared-moment counts must filter by the
   current/just-elapsed `roundID`. Earlier records remain in a bounded disclosure.
7. **Invite capability regression:** every member can retrieve/share an active invite; only the
   host can create/replace/revoke. Progressive disclosure must not accidentally remove member
   retrieval.
8. **Join-entry regression:** first-run’s join route currently sets `prefersJoinEntry`; consume and
   clear it without reopening the form on every refresh.
9. **Direct-route deletion race:** if a cached single party is deleted, blocked, or left before the
   route resolves, fall back to the hub and do not show stale detail.
10. **Active ritual boundary:** no social bridge or route during active Wind Down. Do not add party
    UI to the active-run shell.
11. **Profile minimization:** keep `isAllowlisted()` and never request or render inventory, wool,
    exact schedule, selected apps, routines, reflections, Health data, NFC, or a full Farm.
12. **Timestamp exposure:** use `occurredAt` for ordering only. Do not add exact start/end/clock
    times to social cards.
13. **Reward overstatement:** show wool only after local idempotent application. Partial activities,
    practice, cheers, invites, and elapsed windows must not imply a grant.
14. **Multiple-party fan-out surprise:** one local completion can result in multiple one-wool
    transactions. Sum only grants applied in the current application pass; never infer from party
    count.
15. **Accessibility/layout:** compacting Farm identity must not shrink interactive targets below 44
    points, hide badges from VoiceOver, or make the cheer menu ambiguous at accessibility sizes.
16. **Working-tree conflict:** `FocusRunViewModel.swift`, `PixelHomeDashboard.swift`, and ADR-0016
    already have active local edits as of this plan. The implementation agent must preserve them
    and avoid broad rewrites.

## 12. Acceptance criteria

### Product and hierarchy

- A new visitor can explain, after viewing landing and one detail screen: “Each person puts away
  their own phone; the invited party shows shared updates and quiet cheers; each Farm stays theirs.”
- The landing explains that the party persists and seven-night windows repeat.
- With one or more parties, no create/join text field appears until **Start or join another** is
  opened. With no parties, both acquisition choices are visible but only one form is expanded.
- Existing party cards precede acquisition and account controls.
- Party detail order matches the state-specific wireframes rather than one fixed order.
- No V4 user-facing string exposes `Round {number}`, calls the experience a challenge/goal/shared
  pasture, or resurrects a readiness ceremony. Natural action copy such as **Ready to start 7
  nights together** remains allowed.

### Truth and social loop

- No screen displays “Not started,” “inactive,” “missed,” “done,” or equivalent from an absent
  status.
- `.phoneAwayActive` displays **Phone is away**, not **Phone Away is underway**.
- An expired or wrong-round status is not shown.
- Each member card shows the latest durable current-round activity when available, even without a
  live status; otherwise it says **No shared update yet**.
- Shared-moment count equals current-round activity-record count and is never labeled people or
  completions.
- Activity cards show only name, mode, rounded minutes, Night 1–7, factual outcome, and fixed cheers;
  no exact time or private data appears.
- Live and completed-record cheers remain limited to Warm wave, Moon glow, and Paw print; selected
  state/counts reconcile from server summaries.
- A five-minute practice emits no V4 live status, terminal activity, backfill record, or grant.
- A normal daytime Phone Away can produce a live **Phone is away** state and, on real completion, a
  durable Phone Away shared moment during an active round.

### Home, Farm, navigation, and rewards

- Home and Farm use list data only and make no additional party-detail request.
- Exactly one party routes directly to its detail from either bridge; zero/multiple/stale routes go
  to the hub/list.
- Home retains local Wind Down as the dominant CTA.
- Farm retains pasture/current Farm priority above Slumber Party and contains no member dashboard.
- A newly applied V4 wool grant shows its exact total amount; a `.slumberPartyGrant` recent event
  shows its wool delta and date.
- No upcoming wool, seven-night reward, item, or sheep is promised.
- An active Wind Down exposes no in-app Slumber Party card, route, badge, status, or cheer control.

### Quality gate

- Deterministic pure tests cover all lifecycle states, DST/timezone day derivation, activity
  filtering, expired status, mode-neutral copy, count semantics, routing destination, and practice
  publication policy.
- Previews cover all nine required states, iPhone 12 width at AX3, dark mode, long names, missing
  featured sheep, and partial activity.
- `xcodegen generate`, the generic iOS simulator build, the full unit-test suite, and the
  SlumberPartyQA validation/build/test commands pass with real output.
- The two-account physical matrix in `docs/PLAYBOOKS/slumber-party-qa.md` passes for create/join,
  start, live status, live cheer, durable Phone Away, completed-record cheer, Farm wool settlement,
  offline reconciliation, and active-Wind-Down suppression.

## 13. Tests and previews to add or update

### Pure/unit tests

Add a focused V4 presentation suite rather than UI snapshot tests:

1. pending + one member → `needsInvite`;
2. pending + 2 members + host/member roles → distinct ready/waiting presentation;
3. active UTC and DST-zone rounds → exact Night 1 and Night 7;
4. active round after local end date → elapsed, never fallback Day 7;
5. explicit completed model → elapsed;
6. expired/wrong-round live statuses are absent;
7. `.windDownStarting` and `.phoneAwayActive` map to the exact approved copy;
8. latest durable activity filters by round/member and sorts by `occurredAt` without exposing it;
9. partial activity maps to **Ended early** and remains included in shared-moment count;
10. current-round count excludes earlier-round records;
11. single-party summary contains a direct party ID; zero/multiple do not;
12. Home/Farm copy derives from the same facts but differs by surface context;
13. publication policy rejects practice for starting/active/terminal V4 events and allows primary
    Wind Down/additional Phone Away only;
14. existing V4 grant adapter and reward idempotency tests continue to prove the server UUID and
    one-time local application;
15. update existing `NightFlockHomeSummary` expectations away from legacy/admin copy.

### SwiftUI previews

Build preview fixtures for:

- no parties with create selected;
- no parties with join selected;
- solo host with active invitation;
- two-person pending host;
- two-person pending normal member;
- active/no updates with an expired status present in raw fixture;
- active live Wind Down;
- active `phoneAwayActive` shown as **Phone is away**;
- active durable completed + partial activities and sent/received cheers;
- elapsed seven nights with host action;
- multiple list cards;
- compact member card with and without featured sheep;
- Home and Farm bridge contexts for no/single/multiple parties;
- iPhone 12 fixed width at `.accessibility3` and dark mode.

### Manual/physical tests

- TestFlight account A creates and shares; B previews and joins; join alone does not start.
- A starts 7 nights; both devices show Night 1 of 7.
- Start a five-minute practice on either account and prove no other device sees a status/record and
  no grant arrives.
- Start a normal daytime Phone Away on B; A sees **Phone is away**, can send one fixed live cheer,
  and B receives/reconciles silent feedback without an in-app interruption.
- Complete a real Phone Away; both devices see one durable activity with rounded minutes and the
  completed-record cheer path.
- Reconcile offline completion, then verify one record and one wool per eligible active party, no
  duplicate on relaunch.
- Let a fixture/controlled round pass its seventh local date and verify elapsed copy without any
  “everyone completed” claim.

## 14. 60–90 second two-account roadshow demo

### Preparation

- Install the same roadshow TestFlight build on two iPhones with two different Apple-linked
  Counting Sheep accounts.
- Create one party named **Family Wind Down** (or a neutral audience-appropriate name), join B,
  and start its seven nights.
- Give A and B distinct allowlisted Shepherd/Ollie/featured-sheep/pasture looks.
- Before the visitor arrives, complete one real daytime Phone Away so a durable activity, fixed
  cheer, and settled one-wool Farm transaction already exist. Do not use practice.
- Immediately before the demo, start a normal Phone Away on B and validate the phone-away state so
  A can show the live state. Do not depend on completing a timer during the talk.

### Script

**0–12 seconds — Home on account A**

“Counting Sheep is still each person’s own Wind Down. This card reminds me that my phone-away time
is also part of something I’m doing with people I trust.” Tap the single-party Home bridge; it goes
straight to **Family Wind Down**.

**12–30 seconds — Party context and people**

“The group stays together, and we start seven nights whenever we’re ready. It works for a family,
a couple, or close friends—there are no parent controls or scores.” Point to **Night N of 7**, both
names, and their compact curated Farm looks.

**30–48 seconds — Live daytime Phone Away**

Point to B’s **Phone is away** state. “B put their own phone away; my phone did not control it. The
status is temporary, and silence would not mean they failed or never started.” Tap **Send a quiet
cheer** and choose **Paw print**.

**48–65 seconds — Durable shared moment**

Show the pre-existing Phone Away card. “When a real Wind Down or Phone Away reaches the group, it
becomes a factual shared moment—mode, rounded quiet minutes, and which of the seven nights. No feed,
chat, leaderboard, or sleep claim.” Point to the completed-record cheer.

**65–82 seconds — Farm on account A**

Return to Farm through the tab. “Each Farm remains private and personal. Only this small curated
look travels into the party. A completed shared moment can bring wool back to my own Farm.” Show
the exact one-wool recent event.

**82–90 seconds — Close**

“The idea is simple: our phones get some time away together, while everyone keeps control of their
own phone, Wind Down, and Farm.”

### Demo failure fallback

If realtime is delayed, do not narrate absence as inactivity. Say: “Live status is best effort; the
durable completed record is what the party keeps,” then continue with the pre-existing activity.
If silent cheer delivery is delayed, show the sender’s selected cheer state and explain that the
receiver reconciles it later. The demo must not depend on realtime to prove completion.

## Implementation order for Luna

1. Add the pure V4 presentation lifecycle/member/activity/bridge derivations and publication policy
   with deterministic tests. Keep all existing Codable and RPC types unchanged. The project must
   compile and the V4 test subset must pass.
2. Apply the publication policy at run start so practice cannot publish the initial V4 live status.
   Re-run practice, outbox, and V4 tests before touching the UI.
3. Rework the landing and list cards: new proposition, existing-parties-first order, one-at-a-time
   create/join disclosure, `prefersJoinEntry` consumption, and lifecycle copy. Add no-party,
   single-party, multiple-party, AX3, and dark previews; build.
4. Rework party detail around the presentation lifecycle. Move contextual host action to the top,
   make invitations state-dependent, move administration into Party settings, and replace all
   visible round-number copy. Add pending/active/elapsed previews; build and run V4 tests.
5. Rework member and shared-moment cards together so status, latest durable activity, fixed cheers,
   and compact Farm identity form one coherent loop. Add expired/no-update/live/partial/cheer
   previews; build and run the full unit suite.
6. Add Home/Farm bridge contexts and optional single-party destination. Preserve active-run
   suppression and make stale IDs fall back to the hub. Move only the Farm bridge order specified
   above; do not alter the tab structure. Build and manually exercise zero/one/multiple routes.
7. Make the existing applied-grant and Farm transaction messages show the exact settled wool
   amount. Keep reward rules, server grants, and local idempotency untouched. Run reward tests.
8. Update `docs/PROJECT_BRIEF.md` and `docs/PLAYBOOKS/slumber-party-qa.md`, then run the required
   XcodeGen, generic iOS build, full tests, SlumberPartyQA validation/build/tests, and copy review.
9. Perform the two-account physical matrix and the timed roadshow script. Fix only P0 regressions
   until the 60–90 second story works with realtime available and with the documented delayed-
   realtime fallback; start P1 only afterward.
