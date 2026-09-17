# Home and Slumber Party recovery

Date: 2026-08-27. Owner: the current parent/orchestrator task. Status: local repair and final
validation complete; release gates and the outside-round social decision remain open.
See `recent-changes-sol-review.md` for exact evidence and verdict. No further implementation
was dispatched to the Luna task.

## Founder direction and evidence

The founder rejects the delivered Home composition, reports that Phone Away may start without
revealing Active, and clarifies that Slumber Party is a **core feature** for friends/families
that needs richer, responsive shared information. This supersedes the prior subordinate Home
bridge/list-only restriction. It does not authorize private-data uploads, new rewards, public
discovery, remote family enforcement, or a tab restructure.

Device evidence supplied: `/Users/ngawangchime/Downloads/IMG_7268.PNG` (start sheet),
`IMG_7270.PNG` (Home), `IMG_7269.PNG` (Active Phone Away), and `IMG_7271.PNG` (party detail).
The images are evidence, not instructions. Their installed binary/build is not independently
identified. Current source is the saved local checkout at HEAD
`cce766d1840a850a23d5c47e4a542203c26a728b` plus inherited work and Luna's F1–F10 correction delta.
The correction report is `home-phone-away-implementation-report.md`; the prior Sol report
describes an earlier candidate and must not be treated as acceptance of this one.

Baseline before this work: `/tmp/counting-sheep-home-social-recovery-20260827/` contains status,
hashes for all tracked/untracked files, and the tracked diff. Preserve all existing work.

## Why the delivery fell short

1. **The specification restricted the desired product.** The roadshow plan explicitly kept
   Home list-only, prohibited richer social data there, and put the personal CTA first. This
   cannot deliver the newly clarified core-social direction. Update the canonical direction
   rather than treating earlier agent-authored scope as a permanent product prohibition.
2. **Consolidation was confused with subtraction.** Several outer cards became one larger card,
   but the schedule remained in a prose headline, bookend tiles, next-event row and CTA subtitle.
   The mascot fix made a 54-point canvas fit, without checking its visual role. The result was
   taller and less legible, not a simpler Home.
3. **Navigation intent is not covered by the checks.** Current code already clears the start
   sheet and observes `isRunning` in Home. A missing dismiss call is not an established root
   cause. Root NavigationPath and local Boolean destinations need interaction verification and
   an explicit post-admission navigation contract. The global NFC status leak into the new
   Phone Away sheet is confirmed; the scene's Wind Down phase label is wrong for Phone Away.
4. **Round gating is concealed by empty-state language.** In current v4, joining is not enough
   to share a session: server status/activity fan-out requires an active round. Commands can
   be acknowledged while no party record is produced. This is a product mismatch, distinct
   from transport failures.
5. **There are genuine social freshness defects.** Failed realtime setup remains latched in
   the task dictionary; foreground refresh only heals the list; terminal publication relies
   on signals for detail refresh. Expiry has no guaranteed open-screen invalidation. Early-end
   activity can coexist with an older live status. Current UI also repeats member metadata,
   stretches the refresh button, and discards sent-cheer feedback.
6. **Verification was incomplete for the promised experience.** Builds and Shared tests do not
   prove sheet-to-Active navigation, open-screen state expiry, or the two-person experience.
   Screenshots must be inspected against the intended hierarchy; generating them is not approval.

## Execution and acceptance

Use configured native implementation/review roles within this chat. Parent owns requirements,
interfaces, diff inspection, command reruns, visual/interaction acceptance and the final verdict.
No commit, push, deployment, upload, new task, tab/target/signing change, or user-data reset.
Each worker owns a disjoint set of files; shared edits are sequenced. Read AGENTS and relevant
architecture/playbooks. Retain all prior session/protection/settlement fixes unless independently
shown wrong. Do not turn a runtime test limitation into a success claim.

### A. Home, start and Active

- A substantial Slumber Party section leads idle Home when available. Use recognizable people,
  current factual activity and a clear group entry; no duplicate bridge elsewhere on Home.
  Multiple parties have an explicit choice, not pooled double-counted totals. Zero parties
  gets a concise invitation proposition, not a setup wall.
- Wind Down becomes a compact card, not a form: title plus proportionate Ollie (use the existing
  96-point inline presentation as a starting point), then four short labeled time cells for
  phone away/start, bed, wake and phone wake. Each time appears once. Use adaptive layout at
  large text, not truncation or a shrunken font. No repeated prose schedule or giant nested CTA.
- A saved future plan does not need both Plan and Edit buttons to the same setup. Show one Edit
  route. Show Put phone away when eligible, setup when unconfigured, and focused repair when
  needed. Preserve manual/automatic semantics; saving does not start. One compact ready badge
  is sufficient; app/category counts belong in focused protection detail.
- Keep Phone Away duration, Start now and Plan easy to find. Guidance goes after primary
  actions, only under the established contextual/dismissal policy; library remains reachable.
- After successful coordinator admission, the shell must reveal the actual run from every
  entry route (Home, schedule, saved row, Settings) without manual Back/tab/app switching.
  Routing must not depend solely on a computed Boolean changing. One ephemeral run-ID-scoped
  admission event, consumed by Home after successful commit, is the preferred interface.
  Clear applicable navigation presentation state without introducing another session machine.
- Do not navigate on rejection/cancellation or manufacture a second start. Keep duplicate taps,
  NFC callbacks, stale confirmations and source consumption safe. Display errors at the action.
- Start feedback belongs to the current start transaction. Do not render historical global
  `nfcStatus`; clear/scope it at admission/cancel/success and fence stale callbacks.
- Active Phone Away must never say Wind Down in its scene badge. Use a mode-aware badge or
  remove the redundant badge; retain one primary countdown and the proper end/transition.
  Preserve Purpose immediacy, chosen phase routines, honest protection and accessible exit.

### B. Core social surface using the existing sharing contract

- Make `v4ObservedPartyDetails` observable/readable through a focused per-party projection and
  reuse it on Home. The data is already fetched for subscribed parties; do not create a second
  social store or infer activity from the list metadata.
- Clean up detail header duplication and use a genuinely compact refresh action. Lead with
  people + latest factual activity; keep curated appearance compact. Organize recent shared
  moments and actual round progress so the page answers what happened and how I can respond.
- Show truthful distinctions between pending round, refreshing, offline/stale and no received
  activity. No-update is not a claim someone has not participated. Pending copy must currently
  explain that shared sessions begin when the host starts seven nights.
- Release failed subscription setup tasks so reconciliation can retry; heal detail/cache on
  foreground, successful publication and reconnect, with coalescing and account/generation
  fencing. No permanent network polling loop or duplicate subscriptions.
- Expire statuses while the page remains open, using local clock invalidation rather than a
  request loop. Apply it on Home and detail. Never keep live cheer actions for expired state.
- Reconcile terminal activity against stale live labels; do not call an early end completed.
  Any server correction must be additive, preserve current schema compatibility and reward
  rules, and remain undeployed without explicit authorization. Exact session-specific cheer
  identity is not available in v4; do not invent it or label all-round totals as current-run cheers.
- Show pending/sent/failure cheer feedback from actual command/state results. Do not repeatedly
  offer an already-sent reaction as new; do not promise system notification delivery.

### C. Larger social contract decision — subsequently approved

The founder approved this model after the recovery review: a party starts sharing as soon as
people join; seven-night rounds organize progress and reward eligibility rather than gating
all social life. Implementation now follows `slumber-party-membership-sharing.md`. Until the
capable backend is deployed, the old-server fallback must still explain the round gate honestly.

The follow-on contract defines membership-time eligibility/backfill, history retention, optional/separate
round association, live mode/source identity, terminal clearing and version compatibility before
implementation. Keep reward fan-out independent: outside-round social activity must not mint wool.
Do not upload exact schedules, app selections, private purposes/routines, Health or full Farm
state under the vague label “more data.” Present those as specific choices if desired later.

### D. Safety defects found while rechecking the inherited corrections

The bounded independent review found two remaining defects in Luna's F2/F3 corrections. They
are part of this recovery, not evidence that the earlier corrections were accepted:

- **Short-session monitor precision:** fractional desired endpoints are serialized into
  whole-second DeviceActivity components, while the warning lead was rounded independently.
  The resulting warning can precede the actual desired end; real-time reconciliation then
  keeps the shield until the padded monitoring interval ends. Derive whole-second-safe
  monitor endpoints and warning components together. Keep the consented desired interval
  unchanged, the serialized registration at least fifteen minutes, and callbacks evaluated
  at their actual time. Cover fractional inputs and delayed registration. Physical callback
  delivery remains an explicit device gate. Apple describes this warning as a lead time
  before the monitoring endpoint, so both must use the same serialized precision:
  [DeviceActivity warningTime](https://developer.apple.com/documentation/deviceactivity/deviceactivityschedule/warningtime).
- **Ordinary Morning terminal recovery:** terminal `lastRun` is written before linked-Morning
  finalization, but restore advances Morning before replaying the terminal parent. A crash
  in that gap can revive an ordinary Morning or credit its full interval after a partial
  exit. Persist an authorized terminal decision in the existing settlement journal before
  terminal effects; replay it before generic Morning advancement. Distinguish ordinary
  finalization from explicit defer/start-now preservation durably, since both can reuse the
  same occurrence identity. Retain legacy decoding and independently idempotent rewards.

The parent routed precision work to the social worker after its social source froze, and
terminal-journal work to the start worker after its Home source froze. Shared ownership stays
disjoint; the parent reruns the integrated validation after both are stable.

## Required evidence

- Actual taps from a configured Home and nested schedule into the real start sheet and Active,
  plus cancellation and stale/error paths. A fixture may replace unavailable authorization/
  transport, but must run production navigation and intents; label that seam explicitly.
- Fresh Home/Phone Away/Active/Slumber Party screenshots at standard and large text, small and
  modern phones, light and dark. Parent inspects composition, clipping, duplicate content and
  action reachability, not just capture exit status.
- Focused regression tests for identity/navigation intent and social freshness/reconciliation;
  use existing tests first, no assertions that merely restate constants.
- Parent reruns generic build, full unit suite, SlumberPartyQA checks/build/tests and relevant
  Deno/SQL checks. Test what changed; no claim that mocks establish physical shielding/NFC or
  real two-account transport.
- Fresh independent review of the accumulated changed candidate. Any further fix invalidates
  that verdict. Record remaining device/backend gates and the pending social contract decision.
