# ADR-0017 — Progressive Guide, Phone Away, and Sleep-Habit Guidance

## Status

Accepted, 2026-08-13.

## Decision

Counting Sheep keeps a short three-step Home orientation and introduces the four root tabs and
consequential first-use moments through one-time contextual spotlights. These reuse Home's dimmed
screen, highlighted real control, and floating coach mark so guidance cannot be mistaken for app
content. They are optional, VoiceOver-friendly, dismissible, and suppressed during an active Wind
Down or Phone Away. A tip is marked seen only when acknowledged; leaving the screen does not erase
it. A completed legacy tour may receive each new spotlight once; skipped or dismissed guidance
remains quiet until replay or resume.

**Wind Down** is the capitalized nightly sleep-bookends ritual. **Phone Away** is the capitalized
secondary start-now, scheduled, or repeating phone-away mode. Its actions are **Put phone away**,
**Start now**, and **Plan**; the mode name is not forced into awkward verbs. It records factual minutes, can use
the existing optional shielding, and does not create protected nights, streaks, Slumber Party state,
sleep claims, automatic wool, or an overnight phase.

Phone Away minutes feed a separate, centrally configured 100-minute meter. Eligible completed runs
credit at least 15 minutes and at most the configured 100-minute amount per run; practice and early
endings earn none. After three protected Wind Downs, the next eligible completed Phone Away resolves one deterministic bonus search at 20%, 30%,
40%, 50%, then guaranteed after four consecutive clue-only results. Remainders carry, and this
counter never changes Wind Down odds or starter guarantees. Legacy persisted names and fields decode.

The locally bundled guidance library adds cautious NHLBI-sourced cards about leaving personally
suitable room after a heavy meal and trying an earlier personal caffeine cutoff. Guidance appears
beside private routine choices, on Home, and in phase-appropriate moments; the full source library
is reached through **“About these ideas and sources.”** “Finite guide” is never user-facing copy.
Routine steps are suggestions with no checkmarks, verification, reward, score, streak, or claim
that they were completed. This is general sleep-health education, not insomnia treatment; no fixed
universal cutoff, score, reward, or treatment claim is shipped, and this ADR does not claim that
qualified clinical review has occurred. A later optional seven-night experiment may combine passive
HealthKit wake-time context with one chosen topic (morning light, late meals, or caffeine timing),
one end reflection, and no sharing or reward; qualified sleep/CBT-I review is a release gate for
that future slice.

## Consequences

The app teaches the interface near the moment it matters without turning first launch into a tour of
every screen or adding tutorial cards that look like permanent features. Phone Away remains legible
as a secondary phone-away tool while its bonus search gives the meter a visible, honest payoff.
