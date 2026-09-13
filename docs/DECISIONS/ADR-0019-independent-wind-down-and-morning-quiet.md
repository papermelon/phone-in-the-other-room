# ADR-0019 — Independent Wind Down and Screen-Free Morning settlement

New-run Farm accounting is superseded by [ADR-0020](ADR-0020-cumulative-farm-credit.md): cumulative credit survives early endings and excludes Brief Access. Legacy settled outcomes remain intact.

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

Authorization and a non-empty selection establish readiness, not proof that limits ran. Runtime
receipts distinguish observed apply/clear evidence, partial evidence, unavailable/legacy evidence,
and protection that was not requested. Brief Access temporarily lifts the selected limits while
the session timer and Screen-Free Morning eligible elapsed time continue, so those minutes are not
described as verified no-screen time.

## Persistence and scheduling

`ollie.windDownMorning.settlementJournal` is the domain authority for hidden outcomes, terminal
delivery/reveal markers, linked occurrences, Sunrise settlement, and replay-safe effects. Farm,
Search Journal, Nights history, and App Group values are projections. The App Group holds only
derived shield schedule/presentation state, including a revisioned registry and tombstones so
stale extension callbacks cannot replace a newer deferred window.

Nights presents Wind Down's factual before-bed minutes, Screen-Free Morning's independent
occurrence ledger, and Phone Away's elapsed record separately. A day containing only Screen-Free
Morning is still a real day record. Legacy combined rows are labeled as legacy and never assigned
shield evidence that was not stored.

## Consequences

The active ritual remains phone-authoritative and has one coordinator. Overnight surfaces never
tease a hidden Farm result. The release-facing name is Screen-Free Morning; nearby help explains
the apps/categories-only boundary, websites/unselected apps, Counting Sheep availability, and
deliberate Brief Access without sleep or medical claims.
