# ADR-0019 — Independent Wind Down and Screen-Free Morning settlement

- Status: Accepted
- Date: 2026-08-23
- Decider: Founder
- Related: ADR-0012, ADR-0014, ADR-0018

## Decision

Wind Down and Screen-Free Morning are linked occurrences with independent qualification,
settlement, and presentation. Wind Down becomes entitled at the factual 420-minute eligible
phone-away span. Its deterministic outcome is resolved privately then, delivered only after an
authorized terminal action, and revealed only by a finite receipt. Morning choices and minutes do
not alter that outcome or its guarantee/drought track.

Screen-Free Morning uses the existing internal `MorningQuiet*` compatibility names. It can start
now, remain at the usual time, or be skipped for tonight without editing recurring preferences.
Eligible actual minutes (15-minute minimum, capped by configured duration) bank into Sunrise
Trail. Every 100-minute fill gives one wool and a separate Sunrise search. Its first three
searches, chance ladder, and fourth-search bad-luck guarantee are isolated from Wind Down and
Phone Away.

New Wind Down, Screen-Free Morning, and Phone Away starts require Family Controls authorization
and a non-empty opaque app/category selection. Runtime failure remains fail-open and repairable.
The picker is not proof of a named-app selection. Screen-Free Morning data, purpose cues, and
Brief Access remain local and never enter Slumber Party.

## Persistence and scheduling

`ollie.windDownMorning.settlementJournal` is the domain authority for hidden outcomes, terminal
delivery/reveal markers, linked occurrences, Sunrise settlement, and replay-safe effects. Farm,
Search Journal, Nights history, and App Group values are projections. The App Group holds only
derived shield schedule/presentation state, including a revisioned registry and tombstones so
stale extension callbacks cannot replace a newer deferred window.

## Consequences

The active ritual remains phone-authoritative and has one coordinator. Overnight surfaces never
tease a hidden Farm result. The release-facing name is Screen-Free Morning; nearby help explains
the apps/categories-only boundary, websites/unselected apps, Counting Sheep availability, and
deliberate Brief Access without sleep or medical claims.
