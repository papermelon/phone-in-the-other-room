# Automatic Wind Down and Campfire loading repair

21 September 2026. Local app changes; no app distribution in this task.

The founder confirmed automatic start was enabled before the missed 10 PM start.
The screenshot showed tomorrow's schedule at 10:09 PM. This rules out switching it
on after the boundary, but does not establish which background callback ran.

## Automatic start

The account-sync publication callback (`didRestore`) also runs for ordinary refreshes
of the same account. It unconditionally erased the saved automatic occurrence and
scheduled a future one. That can discard a due start while its local sharing decision
is being staged. It now compares the existing account/Farm identity: ordinary refresh
preserves the saved occurrence and reconciles it through the existing coordinator;
owner or Farm-lineage changes still clear and cancel it. The scheduler uses the
view model's clock consistently. No persisted schema or shielding entitlement changed.

The toggle and its status/repair action moved from Protection & tags to Edit Wind Down,
directly below the plan. Installed future schedules say “scheduled” rather than “ready.”
This describes scheduling, not proof of app blocking.

## Campfire and shared loader

- Canonical party and Global Campfire reads now have a 12-second cancellation deadline.
  Existing error/retry presentation handles timeout; mutation recovery is unchanged.
- A party-detail response without the requested party throws at the shared service
  boundary instead of leaving observers refreshing forever.
- Repeated identical Global refreshes share the current request. Changing the gathering
  or channel still replaces it, with the existing owner/generation guards.
- Campfire shows loading only for actual requests. A missing snapshot without a request
  shows the existing unavailable/retry presentation.
- The shared loader uses Bramble's six existing running frames, with a visible hop and
  staggered dots. Its rhythm takes inspiration from
  [Loading UI's bouncing dots](https://loading-ui.com/docs/components/bouncing-dots).
  No new dependency or generated art. Reduce Motion keeps it still; background scenes
  pause the animation; VoiceOver receives a stable progress label.

These source defects explain possible long/stuck waits, not measured hosted latency
for the screenshot. No retained request trace was supplied for that incident.

## Acceptance

[Local validation and captures](../../output/design/wind-down-loading-20260921/README.md).
The existing [signed-device automatic-start matrix](wind-down-automatic-recovery-2026-09-17.md#signed-device-acceptance)
still applies: test background/terminated/open starts with ordinary account sync,
selected-app access, overnight/morning boundaries, and a second unattended night.
Also verify Campfire timeout/retry and Bramble motion on the affected phone. Simulator
results cannot establish physical Screen Time enforcement or background callback delivery.
