# ADR-0003: Gated Features and Reintroduction Criteria (Farm / Friends / Shop)

- Status: Accepted
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

**Farm, Friends, and Shop are hidden from release builds — code kept, gated behind a
DEBUG launch flag — until the milestone gates below are met.** They are not deleted, and
they are never shipped as "coming soon" placeholders.

The launch surface is Home, Nights, and More. Ordinary Debug navigation matches Release.
Internal mock screens appear inside More only when launched with
`-ollie.debug.enableMockScreens YES` (ADR-0007).

## Reintroduction gates (all must pass, in order)

- **Gate 0 — Shipped and stable.** TestFlight build 1 is live; no P0 bugs; core loop
  stable across ~2 weeks of tester use.
- **Gate 1 — Retention evidence.** Testers complete bedtime runs on 5+ of their first 14
  nights (the brief's success criterion), and qualitative feedback organically asks for
  more progression/collection. If nobody asks, these features stay gated.
- **Gate 2 — Technical readiness.** Farm reads `SheepSearchState` for found sheep, wanted
  posters, habitats, and cosmetic rarity (no `MVPMockData` in any release path), and
  persisted-model changes have backwards-compatible decoding with tests. It does not expose
  coins, balances, sheep power, or minute-based sheep values.
- **Gate 3 — Art readiness.** The relevant asset set is complete per
  `docs/SCREEN_ASSET_MAP.md` (no placeholder-shape fallbacks on shipped screens).

## Reintroduction order and method

1. **Farm first.** Farm visualizes the cumulative flock from `totalCompletedRuns`. If it
   earns a root destination, Home/Nights/Farm remain the three tabs and More becomes a
   top-right utility sheet.
2. **Shop later, nested in Farm.** Shop is never a root tab and cannot revive a coin or
   scarcity economy. Its value and mechanics require a new reviewed scope.
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
- Agents get a citable refusal: work on these screens without the gates met is out of
  scope by decision, not by opinion.
