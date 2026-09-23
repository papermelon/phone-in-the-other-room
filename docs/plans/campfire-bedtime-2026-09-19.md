# Private Campfire bedtime presentation — 19 September 2026

Founder approved local implementation after the planning review. Deployment,
distribution and physical two-account acceptance remain separate authorization/gates.
See [local evidence](../../output/design/campfire-bedtime-20260919/README.md).

## Current contract

An actual shared primary Wind Down places the customized Shepherd awake at the
Campfire before its admitted `NightWatchPlan.intendedBedtime`, then tucked into a
sleeping bag at/after that frozen instant. A late start or sharing an already-running
session after bedtime appears tucked in immediately. Ordinary schedules never create
presence. Phone Away/additionalQuiet remains awake with its existing intention.

Terminal precedence, planned wake/session expiry, stale observation suppression,
party membership, blocking, account ownership and audience fences remain unchanged.
An offline terminal may remain visible remotely until it syncs or expires, including
crossing into the bedtime pose. Bedtime is visual presentation, never online status,
sleep evidence, a receipt, or a reward/progression event. Screen-Free Morning does
not extend Campfire presence. Subsequent settings changes cannot move the boundary.

## Additive protocol and persistence

`CampfireSession` and `SharedPastureCommand` add optional `intendedBedtime`. New
primary commands capture the admitted plan only when the private server projection
advertises `supportsIntendedBedtime`. This is a technical capability, not an agreement.
Campfire state stays version 1, commands schema 4, and existing sharing receipts stay
valid without another modal, acceptance or consent-version change.

Missing/null/invalid optional presentation metadata renders awake; required session
fields remain strict. Old apps ignore the added projection. Existing queued commands
keep their captured payload and idempotency keys; existing acknowledged legacy
sessions are not enriched. The account-partitioned outbox algorithm is unchanged.

The new migration adds nullable `private.campfire_sessions.intended_bedtime` and
replaces the Campfire layer inside the existing Buddies wrapper chain. Inserts use
explicit columns. First accepted insertion freezes the boundary; terminal updates
preserve it without requiring equality or presence in the terminal command. Edge
normalizes Foundation/ISO timestamps before validation. The boundary may precede
sharing start/acceptance, must be finite and no later than expiry, and is absent for
Phone Away. Shared session start still represents only the consented publication
interval. Projection follows existing party/epoch/agreement/block filters.

## Presentation

Pure Swift derives awake/bedtime only from a current session. The private unified
panel, party-detail clock and private participant card use explicit Timeline dates:
immediate now, future start/bedtime/expiry, existing status expiry and buddy action
boundaries. Dates are sorted/deduplicated and scheduled 1 ms beyond each boundary to tolerate
Timeline timestamp rounding; domain comparisons remain exact. A single trailing entry
keeps the final real boundary from being dropped by a finite explicit Timeline.
Foreground resume re-evaluates now. No network request or sleeping event happens at bedtime. Existing foreground refresh
behavior remains; Global retains its separate coarse-time contract and presentation.

`CampfireShepherdView` reuses the safe social appearance mapping and the production
Shepherd Canvas drawing beneath one paper blanket/pillow. Head, skin, hair, headwear
and visible clothing retain customization. A small five-second blanket breath runs
only when visible/active; Reduce Motion renders a static composition. Parent
participant buttons expose the pose to VoiceOver, without animation announcements.
There is no additional exact-bedtime label. The existing private sharing explanation
names planned-bedtime sharing and the visual transition; practical offline copy stays.

## Rollout sequence, pending deployment and distribution authorization

1. Finish local app/backend checks and visual review; preserve their exact evidence.
2. With deployment authorization, publish the additive `night-flock-command` Edge
   validator before applying `20260919130000_campfire_bedtime.sql`. Verify the hosted
   wrapper chain, privileges, capability and old/new clients using disposable accounts.
   Do not accidentally deploy/activate the unrelated pending Global migration.
3. With distribution authorization, follow the repository release-archive workflow.
4. Validate physical scenarios below. Do not label Simulator checks physical acceptance.

Rollback preserves the nullable column and permissive terminal contract. Stop
advertising the capability to prevent newly captured metadata; continue accepting
queued metadata and terminal commands. Do not revert to the old positional insert
or old Edge allowlist while newer clients/outboxes exist. Reverting the app renders
existing sessions awake and does not undo shared data or change agreements.

## Physical acceptance, outstanding

Use two disposable accounts/devices, preserving the founder's Farms:

- Shared primary start before bedtime: receiver stays open, sender backgrounded or
  terminated; awake switches at bedtime without sender/network work.
- Late primary start and late explicit sharing: sleeping immediately after projection;
  schedule edits mid-run never change the frozen boundary.
- Phone Away (including Resting) across ordinary bedtime stays awake.
- Early end before/after bedtime, online and offline/reconnect; pending remote presence
  disappears with the terminal update and cannot resurrect on delayed start replay.
- Wake expiry while receiver stays open; Screen-Free Morning creates no extra presence.
- Relaunch, receiver background/resume across bedtime/expiry, timezone/DST and clock error.
- Withdrawal, blocking, selected-party filtering, leave/rejoin, account A/B switch and
  mixed old/new clients preserve existing ownership and visibility semantics.
- VoiceOver participant labels and card navigation; Reduce Motion on/off while visible;
  small-screen/large-text layouts; all head/hair/skin/outfit/accessory combinations.
- No extra reward, wool, sheep, lantern, notification or online-status effects.
