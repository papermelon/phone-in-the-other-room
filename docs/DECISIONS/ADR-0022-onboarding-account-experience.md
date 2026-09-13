# ADR-0022: Dedicated onboarding account invitation

- Status: Superseded for first-run order by the 8 September plan-first direction, and for
  account enrollment/restoration by ADR-0023; retained rules are in the linked current plan
- Date: 2026-09-06
- Decider: Founder
- Related: ADR-0018, ADR-0021, [implementation plan](../plans/onboarding-account-experience.md)

## Current authority

[Product direction](../PRODUCT_DIRECTION.md#first-run-and-guidance) and the
[current onboarding plan](../plans/onboarding-account-experience.md) own the 8 September
plan-first route and preserved legacy drafts. [ADR-0023](ADR-0023-account-owned-farm-sync.md)
owns Apple/password authentication, verified account Farm activation, and automatic private
synchronization. Authentication alone still proves neither loaded Farm nor confirmed save.

## Historical decision — 6 September 2026

The following original decision is historical. Its account-stage order, Apple-only controls,
optional-backup enrollment, and explicit routine-restore flow are no longer current rules.

Returning players get a Sign in entrance on the first welcome page. New players meet
Ollie, may complete the existing starting-point chapter, and choose their independent
Shepherd welcome gift before one optional account invitation. That screen explains the
Farm benefit, uses native Continue with Apple, and offers Continue without an account.
Schedule, routine, protection, and optional reminders follow. The final first-run action
is Go to Home; it must not suggest that local plan saving is online Farm backup.

A fetched account Farm is previewed before an explicit restoration choice. Only successful
restoration routes a returning player past questionnaire/gift setup, with the route preserved
across Back and relaunch. This phone still needs its own schedule and permission setup.
The existing Farm owner, pending-settlement, recovery-copy, and no-merge rules remain in force.

Apple authentication, accepting the backup disclosure, and confirmed server saves are
separate events. The existing private Farm payload boundary remains unchanged. No additional
personalization answers, routines, Health, selected-app identity, or device credentials are
uploaded. A local player retains the same welcome-gift entitlement as a signed-in player.

## Historical consequences

Account creation has a clear place in the first-run story instead of competing with each
page's primary action. Settings remains the permanent account/backup management location.
Cancellation and network errors preserve local setup. An existing account without a Farm
can continue through new-player onboarding without being treated as a successful restore.

This decision prepares a coherent account experience; it does not authorize a paywall,
StoreKit products, additional authentication providers, analytics collection, or expanded
cloud data. Native physical sign-in and restoration validation remain separate from
simulator build, unit tests, and visual fixtures.
