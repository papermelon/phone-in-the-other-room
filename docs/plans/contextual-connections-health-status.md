# Contextual connections and truthful Health status

2026-08-28. Planning and read-only audit only; no implementation or phone update in this pass.
Companion to [shared habits](slumber-party-shared-habits-and-guide.md).

## Report and confirmed cause

The founder's `IMG_7293.PNG` shows Connections saying “Access requested” while `IMG_7294.PNG`
shows 4h55m of sleep with stages in Nights. These screenshots do not establish the installed
binary or current permission state, but the inspected source explains the mismatch:

- `Services/HealthSleepService.swift:9,38,46` stores `ollie.health.sleep.requested` after a
  request completes without error. It is not a read-permission flag.
- `Views/SettingsDetailViews.swift:253,262` always renders the requested message for that flag
  and removes the Health action after requesting, regardless of samples already displayed.
- `ViewModels/FocusRunViewModel.swift:3058,3117` requests authorization and queries actual
  recent sleep; Nights renders observed samples independently.
- `Views/FocusStatsView.swift:46` refreshes on appearance after the request marker is set.
  `Views/HomeView.swift:114` refreshes Screen Time on activation but not Health.
- `Views/FocusStatsContextSections.swift:119,248` routes disconnected Health/Screen Time
  contexts to Settings. Its Screen Time picker binding at line 258 is constant.
- `Services/ScreenTimeAuthorizationService.swift:44` already requests native individual
  authorization; the existing selection service can persist the chosen opaque selection.

This confirms a presentation/action gap and a foreground refresh gap. It does not demonstrate a
failed Health consent or prove that previously fetched samples establish ongoing permission.

## Permission facts

HealthKit deliberately does not expose read-authorization status. Request success means the
request completed, not that every read was granted. An empty query cannot distinguish denied
read access from absent samples. Previously answered permissions may need changing in Health
or system Settings; repeating a request does not guarantee another sheet.
[Authorization status](https://developer.apple.com/documentation/healthkit/hkhealthstore/authorizationstatus(for:)),
[request completion](https://developer.apple.com/documentation/healthkit/hkhealthstore/requestauthorization(toshare:read:completion:)).

Family Controls does expose authorization status and native request/revoke APIs. This does not
mean a report is populated, a selection is nonempty, shielding is applied, or app identities are
exportable to a group. [AuthorizationCenter](https://developer.apple.com/documentation/familycontrols/authorizationcenter).

## Proposed controls and state

Retain Connections as an optional overview; make Nights and the relevant own-member/join context
capable of connecting in place. Do not require visiting the app's Settings hub. Do not add
Health permission prompts to another member's card or automatically prompt at every visit.

| Observed state | Owner-facing presentation and action |
| --- | --- |
| Health not requested | **Connect Apple Health** opens the existing native request in place. |
| Query in progress | **Checking for sleep data…**; prevent duplicate requests. |
| Fresh readable sleep samples | **Sleep data available**, with latest sample date / last checked; **Refresh** and secondary permission help. |
| Completed query without matching samples | **No sleep data available for this period**; **Refresh** and **Manage access** help. Never “Denied” inferred from emptiness. |
| Cached data or query error | Preserve dated data only as last retrieved, label stale/error; **Retry**. Do not label an error or stale cache as a fresh successful read. |
| Health unavailable on device | Explain availability; no dead authorization control. Joining remains possible. |
| Screen Time unapproved | **Connect Screen Time** invokes native individual authorization; factual error/help if it cannot proceed. |
| Screen Time approved, no selection | **Choose apps and categories** presents the picker in place. |
| Screen Time approved with selection | Show report configuration and **Change selection**; protection status remains separate. |

A normal Connect/Manage control is preferable to a toggle that falsely claims to switch Apple's
Health read permission. If a local enable/disable switch is later added, it must be labeled as
Counting Sheep's own reading behavior, not system consent, and separately scoped. Do not add
that extra local control in this repair or reintroduce per-field party-sharing switches.
Screen Time revocation affects protection, so do not add a casual disconnect toggle that silently
disables an active run. Preserve emergency exit, readiness checks and failure/repair semantics.

Use one observable presentation derived from the existing request state plus query result,
freshness and error. Do not persist a new “authorized” Boolean. Refresh after native request,
when the relevant screen appears, and on foreground return with bounded/coalesced work. Cancel or
ignore obsolete queries so an older completion cannot overwrite a newer result. Do not request
permissions on foreground, continually poll, or copy raw Health samples into social storage.
Reconcile restored system access after reinstall/local reset without treating the local request
marker as Apple's permission truth. Let the owner use Connect/Refresh to recover.

## Ownership and acceptance

- **Terra High:** existing Health/Screen Time services, bounded connection intents in
  `FocusRunViewModel`, pure presentation policy in Shared with tests, freshness/cancellation and
  foreground integration. Keep actual Health queries in Services; no parallel session state.
- **Luna High:** focused reusable connection UI, `SettingsDetailViews`,
  `FocusStatsContextSections` and `ScreenTimeBookendCard` picker wiring; later own-member/join
  reuse. Do not grow the already oversized `FocusStatsView` or change global Theme/tabs.
- **Sol High:** acceptance, native screenshots and cross-flow checks. Serialize shared join-view
  ownership with the social lane. No entitlement/target/signing changes are implied.

Pure tests must cover requested-with-data, empty, old data plus error, no request, unavailable,
loading and out-of-order refresh; Screen Time unapproved/empty/selected without false shield
claims. Existing shielding readiness tests remain unchanged in meaning.

Physical QA: readable Health data resolves the screenshot mismatch; no-data and denied-read
cases stay ambiguous; changed permissions refresh on return without switching tabs; already
answered requests do not create a dead loop; both connection sheets return to their origin.
Test Screen Time prompt, picker cancel/save, report display and authorization loss during active
protection. Verify no silent session end or loss of emergency exit. Joining succeeds without
Health data. Check small screens, accessibility text, VoiceOver and 44-point controls.

After implementation, run XcodeGen when needed, full app build/unit suite and native checks.
Tests of derived presentation do not prove physical HealthKit or DeviceActivity behavior.
