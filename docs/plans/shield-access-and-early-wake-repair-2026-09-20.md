# Repeated Brief Access and early-wake shielding repair

20 September 2026. Founder reported that shielding sometimes fails to return after repeated five-minute access, and sometimes does not apply after “Start Screen-Free Morning now”. They also identified the sleep phrase as inappropriate for an early-wake transition. Source repair is authorized; no distribution, signing or backend work is included.

## Confirmed source defects and changes

1. **Restore warning before grant expiry.** The old Brief Access restore envelope retained fractional seconds, while `dateComponents` drops them. Its rounded-up warning could therefore arrive before the saved expiry. The reconciliation policy correctly left an unexpired grant clear, but the next callback could be the end of the fifteen-minute envelope. The restore plan now reuses `QuietTimeShieldMonitoringPolicy`, which rounds serialized endpoints up and warning lead down. For example, a grant expiring at 06:23:00.750 now schedules its warning no earlier than 06:23:01.000. This fixes deterministic rounding, not arbitrary platform delivery latency.
2. **One restore name reused across grants.** A late callback from a stopped grant could act on the next grant's state, including rejecting its pending admission. New grants derive the monitor name from their existing nonce. The extension accepts only a callback matching the current grant, and retires only that callback's monitor. Owner-driven teardown removes all recognized restore names, preserving unrelated monitors. Legacy fixed-name saved grants still decode and reconcile. Callback ledger archival is nonce-fenced.
3. **Early-wake handoff reused a monitor about to be removed.** `coversMorning` returned true for the early morning contained inside the original overnight window. The service returned without creating an independent morning entry, but terminal cleanup then removed the parent. The coordinator now explicitly tells the service that the parent is ending, including inside the terminal transaction before `self.run` has been updated. A replacement is installed before parent cleanup. Ordinary morning still reuses a genuinely active parent monitor.
4. **Independent morning skipped Brief Access reconciliation and rebuilt its snapshot.** It now reuses unchanged windows/identity, prepares the existing access ledger and handles pending/active/expired grants through the same reconciliation as Wind Down. A fresh early-wake morning identity retires the previous overnight grant rather than carrying its unlock into the new morning.

Apple documents the fifteen-minute minimum and warning callbacks, and notes that interval callbacks depend on device use. These platform constraints are why a successful Simulator test cannot establish physical restoration timing: [minimum interval](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/monitoringerror/intervaltooshort), [warning time](https://developer.apple.com/documentation/deviceactivity/deviceactivityschedule/warningtime), [DeviceActivityCenter](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter).

## Early-wake experience

For App Shielding, “Start Screen-Free Morning now” opens a dedicated confirmation with a **Start Screen-Free Morning** button and no typing. The action still uses the existing owner/session-bound, single-use coordinator confirmation and persisted terminal handoff. NFC sessions retain the existing tag authorization. This changes the UI confirmation for continuing protection, not the independent reward or settlement contract.

Deferring or skipping turns protection off, so those choices retain typed confirmation with intent-specific words (“Start my morning at the usual time” / “Skip my morning today”). Ordinary terminal exits and five-minute access retain their existing challenge. Changed/cancelled/replayed sheet requests are rejected. Morning's routine action is now labelled **My morning** in the app and shield. The early-wake choice explains that deferring unblocks apps until the usual wake time.

The existing `MorningQuietIntent` enum moved into a small Shared file so shield extensions can compile the same presentation intent without importing the full settlement model. No persisted enum raw values, capability, entitlement or signing setting changed.

## Validation and physical acceptance

[Validation evidence](../../output/design/shield-recovery-20260920/README.md) records actual outcomes. Pure tests cover six consecutive fractional-second grants, matching/stale/legacy callback identities, expiry policy and ledger counts, parent reuse eligibility and intent-specific confirmation. An isolated native probe exercises coordinator handoff, rejection of altered/replayed requests and fake-monitor scheduling/cleanup; no real Family Controls selection or founder account is used.

On a signed physical build, use disposable sessions/accounts and record the app build, OS, phase, request/expiry times and existing protection status (never raw selection tokens):

- Six consecutive five-minute accesses during overnight, with the app backgrounded. Try a selected app after each expiry without reopening Counting Sheep first; verify shielding returns. Repeat with category selection.
- Early wake during an active access grant: Start now must end that grant, start the full planned morning and apply the selected limits. An old restore callback must not clear, extend or terminate the new morning.
- Repeat access during independent Morning, then normal planned wake and an access window crossing that boundary. Verify timer, grant count and protection state separately.
- Last seconds of a session: access clamps to the actual end; no shield is reapplied after expiry. Test locked phone, killed app, reopen and time-zone change.
- Missing/revoked permission, empty selection and monitoring failure: no false “applied” evidence; existing fail-open/repair behavior remains. Cancellation, stale confirmation and failed NFC leave the current run unchanged.
- Start now, defer, skip and ordinary exit: correct confirmation, planned morning duration, unchanged recurring settings, no duplicate Farm/Sunrise settlement. Verify VoiceOver, large text and keyboard-free Start now.

No Simulator capture proves selected apps were physically blocked. No new archive or TestFlight upload is part of this repair.
