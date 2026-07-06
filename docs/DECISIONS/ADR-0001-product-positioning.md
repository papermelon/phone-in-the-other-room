# ADR-0001: Product Positioning — Bedtime Phone Separation

- Status: Accepted
- Date: 2026-07-07
- Deciders: Founder
- Related: `docs/PROJECT_BRIEF.md`, `docs/PRODUCT_PRINCIPLES.md`, ADR-0003, ADR-0004

## Context

Counting Sheep sits in a crowded space: focus apps (Forest, Opal, one sec), hardware
blockers (Brick, Unpluq), sleep trackers (AutoSleep, Sleep Cycle), and habit trackers.
A small team with limited hours cannot win by being a broader version of any of these.
The codebase already reflects the temptation to broaden: mock Farm/Friends/Shop screens,
a large stats surface, and Screen Time scaffolding all accumulated before the core loop
had shipped once.

## Decision

**Counting Sheep is a bedtime phone-separation ritual, and nothing else, until that
ritual is proven on TestFlight.**

1. **The niche is bedtime doomscrolling, addressed by physical separation.** Distance is
   the one intervention that survives 11pm willpower, and verifying it (Watch proximity
   today, tag/QR destinations later per ADR-0004) is our unique mechanic. "Nights your
   phone slept in the other room" is the north-star measure.
2. **It must not become a generic productivity app.** No pomodoro framing, no work-session
   language, no "maximize your focus" positioning. Generic focus is a red-ocean market and
   would dissolve the bedtime identity that makes the app legible.
3. **It must not become a medical sleep app.** We count nights and minutes; we never score
   sleep quality or make health claims. This avoids regulatory/App Review risk and, more
   importantly, keeps the tone warm rather than clinical.
4. **Gamification must be restrained.** Ollie, sheep, stars, and collectible rewards exist
   to make the ritual warm — celebration, not compulsion. Anti-addiction boundaries in
   `docs/PRODUCT_PRINCIPLES.md` are hard constraints: no variable-ratio bait, no
   loss-aversion streaks, no engagement notifications. A sleep-adjacent app that
   manufactures compulsion would be self-defeating and testers would smell it.

## Consequences and tradeoffs

**Accepted costs:**

- **Smaller addressable market** than "focus app for everyone". We accept this; a legible
  niche is how a small product gets adopted and talked about.
- **Hardware funnel** — the Watch/UWB verification narrows the initial audience (mitigated
  by ADR-0004's watch-independent direction, sequenced after build 1).
- **Weaker vanity metrics.** Restrained gamification means less DAU/retention theater.
  Success is measured by completed bedtime runs, not opens.
- **Saying no often.** Features that pass tests for other apps (leaderboards, sleep scores,
  work modes) fail our belonging test. This ADR is the citation for those refusals.

**Benefits:**

- One-sentence pitch ("it gets your phone out of the bedroom, and there's a dog").
- Clear editorial line for copy, design, and roadmap decisions — usable by AI agents
  without human adjudication in most cases.
- Room to eventually own "bedtime screen time" (late-night Screen Time report,
  wind-down rituals) as the product's category.

## Revisit criteria

Revisit this positioning only if TestFlight evidence shows the bedtime ritual itself does
not retain (criteria in `docs/PROJECT_BRIEF.md` §Success), or if a materially different
user segment adopts the app organically for another time-of-day ritual.
