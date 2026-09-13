# Shared habits agreement repair — 29 August 2026

## Outcome

The agreement failure is repaired in the Release backend. At 02:29 SGT the founder
confirmed that the installed phone build now opens the summaries, with screenshots
showing the agreement card removed. This verifies receipt loading on the affected
installation; it does not yet verify overnight sleep ingestion or publication to a
second member. The compact disclosure and improved retry state are local app changes,
not a new distributed phone build.

## Diagnosis

The agreement command could succeed while its following state request failed to
decode. PostgreSQL returned calendar dates as `YYYY-MM-DD`; the actual Swift
`NightFlockLocalDate` Codable contract expects `{year, month, day}`. An empty state
decoded before agreement, masking the incompatibility. Once a receipt existed,
decoding failed at `agreement.firstEligibleSleepNight`. Archive record dates and
period ending dates had the same mismatch. Publication had the reverse mismatch:
Swift sent a keyed date object but the Edge validator required a string.

Read-only production inspection found saved agreement/command records and no missing
active membership epochs. The SQL definitions and constraints matched the local
source. This was not a rejected Health permission or a failure to save consent.
The original validation missed the Swift-to-Edge wire boundary despite separately
passing domain and backend tests.

## Changes

- Edge normalizes strictly validated object/string publication dates to the existing
  canonical SQL string before hashing and RPC dispatch. Shared-habits state alone
  adapts receipt, record and period calendar dates to Swift's existing keyed format.
  Timestamps, privacy fields, consent cutoff, revisions and cursors are unchanged.
- Agreement submission now has a per-party in-flight state and error. Durable pending
  receipts no longer falsely display an active “Saving” operation. Duplicate taps
  are blocked, stale pre-confirmation reads cannot replace the receipt, and receipt
  refresh begins after the save marker is released.
- Joining intent and idempotency seed remain until canonical receipt reconciliation;
  retries retain the saved contributor timezone. Routine failures stay on the card;
  genuine account recovery retains the existing recovery route.
- The disclosure initially shows what is shared, current/future audience, lifetime
  retention after leaving, and deletion availability. “See more” exposes coverage,
  private fields and leaving details. Errors and confirmation remain visible without
  expanding. The disclosure has an expanded/collapsed accessibility value.

No database migration, agreement rewrite, capability expansion, app identity sharing,
new dependency, build-number change or TestFlight upload was made for this repair.

## Deployment and independent validation

- Only Release `night-flock-command` and `night-flock-state` were redeployed, both
  version 3, ACTIVE, JWT verification retained. Unauthenticated requests return 401.
- Downloaded deployed function sources match the reviewed local files by SHA-256.
- A synthetic, rolled-back local PostgreSQL fixture exercised the real agreement,
  publication and state RPCs. A compiled replay uses actual repository Shared Swift
  types, not a re-created decoder. Raw SQL JSON reproduces the original failure at
  `agreement.firstEligibleSleepNight`. The downloaded deployed adapter makes the
  same response decode with one agreement, one record and nine periods. The real
  Swift encoder's publication passes the downloaded deployed command validator.
- Final iOS simulator build: **BUILD SUCCEEDED**. Full unit suite: **763 tests,
  zero failures**. Deno entrypoint checks passed; **27 backend tests passed**.
- Independent scoped source review found no remaining blocking issue after fixing
  the intermediate re-confirmation state, error scope and retry timezone.
- Native iPhone 17 Screenbook fixture: “See more” and “See less” changed visible
  content and accessibility state; collapsed card retained its confirmation action.
  No real user's agreement was accepted through the synthetic fixture.

Local evidence: `/tmp/counting-sheep-agreement-repair-20260829/`, including
`build-final.log`, `tests-final.xcresult`, `deno-tests.log`, `deployed-wire-replay.log`,
`deployed-swift-publication-validation.log`, `production-auth-check.json`, deployed
source downloads, and `consent-{collapsed,expanded}-standard.png`.

## Remaining checks / release gates

1. Observe the next eligible sleep night after the saved contributor-timezone cutoff,
   then refresh Health and summaries. Compare a real populated value and coverage on
   both member phones. Missing data must remain distinct from zero or missed habits.
2. Complete a qualifying post-consent Wind Down / Phone Away, verify summary delivery
   to another current member, and verify retry does not duplicate archive records.
3. Exercise the new compact card's failure/retry state, ordinary touch scrolling and
   VoiceOver on the next app candidate. Automation verified disclosure toggling but
   did not establish ordinary swipe/wheel movement. The simulator text-size command
   did not persist (reported `large`), so maximum Dynamic Type is **not** signed off.
4. The Screenbook capture CLI currently rejects the two inherited shared-habits
   scenario IDs against its stable registry; this turn launched the native fixture
   directly. Repair that tooling drift before relying on automatic captures.
5. Archive, distribute and physically check a new build before claiming the compact
   card or retry-state improvements are on testers' phones. Existing backend repair
   and founder-confirmed receipt loading do not depend on that update.

The repository has substantial inherited uncommitted work. This repair preserved it;
the whole candidate was not committed or pushed as part of this scoped change.
