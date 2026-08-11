# ADR-0003: Gated Features and Reintroduction Criteria (Farm / Friends / Shop)

- Status: Partially superseded by ADR-0015
- Date: 2026-07-07
- Deciders: Founder
- Related: ADR-0001 (positioning), `docs/PROJECT_BRIEF.md` (MVP scope), ADR-0004 (which outranks this work post-build-1)

## Context

The repo contains a substantial mock-driven UI layer —
`PhoneInTheOtherRoomApp/Views/MVP/AssetReadyScreens.swift` (1,413 lines) with Farm, Sheep
Collection, Missions, Friends, Shop, and Doghouse screens, fed by
`PhoneInTheOtherRoomApp/MockData/MVPMockData.swift` — wired into the shipping tab bar but
disconnected from real `UserProgress`. It makes the app feel like it does five things when
one is real, and it is the single strongest temptation for future agents to "finish".

## Decision

The legacy mock Farm, Friends, and Shop screens remain behind the DEBUG launch flag. ADR-0015
supersedes the former gate on a real Farm and nested Farm Shop: those destinations now ship from
persisted production models and must never read `MVPMockData`. Friends remains gated and is never
shipped as a "coming soon" placeholder.

The launch surface is Home, Nights, Farm, and Settings. Ordinary Debug navigation matches Release.
Internal mock screens appear inside Settings only when launched with
`-ollie.debug.enableMockScreens YES` (ADR-0007).

## Historical reintroduction gates

The Farm and Shop parts of these gates are superseded by the founder decision in ADR-0015. They
remain below only as the history of why the mock screens were withheld. The Friends gate remains.

- **Gate 0 — Shipped and stable.** TestFlight build 1 is live; no P0 bugs; core loop
  stable across ~2 weeks of tester use.
- **Gate 1 — Retention evidence.** Testers complete bedtime runs on 5+ of their first 14
  nights (the brief's success criterion), and qualitative feedback organically asks for
  more progression/collection. If nobody asks, these features stay gated.
- **Gate 2 — Technical readiness.** Farm reads `SheepSearchState` for found sheep, wanted
  posters, habitats, and cosmetic rarity (no `MVPMockData` in any release path), and
  persisted-model changes have backwards-compatible decoding with tests.
- **Gate 3 — Art readiness.** The relevant asset set is complete per
  `docs/SCREEN_ASSET_MAP.md` (no placeholder-shape fallbacks on shipped screens).

## Reintroduction order and method

1. **Farm.** Implemented as a root destination backed by individual search outcomes and
   `FarmState`, alongside Home, Nights, and Settings.
2. **Shop, nested in Farm.** Implemented by ADR-0015 with a local wool balance, fixed
   catalogues, capacity upgrades, and cosmetic equipment. It is not a root tab.
3. **Friends last — or never.** Requires a backend, accounts, and moderation, and is the
   feature most at odds with the anti-addiction principles (social comparison). Requires
   its own ADR before any work starts. Default answer is no.

Method, per feature: one destination at a time; wire to real data *before* flipping the gate;
apply the belonging test (`PRODUCT_PRINCIPLES.md`) and `docs/PLAYBOOKS/pre-merge-review.md`;
human approves the gate flip.

Note: per ADR-0004, watch-independent bedtime sessions **outrank** all of this in
post-build-1 priority — they grow who can use the app; these deepen it for existing users.

## Consequences

- Build 1 is legible and honest; the mock layer stops being a TestFlight liability.
- ~1,400 lines of gated code carry a maintenance shadow (kept compiling under DEBUG).
  Accepted: deleting would discard useful scaffolding and history shows we want it later.
- Agents must distinguish the production Farm/Shop authorized by ADR-0015 from the legacy mock
  layer that remains gated here.
