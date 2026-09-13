# AGENTS.md — Counting Sheep

This is the canonical repository guide. Read it once; load linked references only when relevant to the task.

## Authority and completion

- Explicit current founder instructions take precedence over repository guidance. Update affected decisions when the founder changes direction; earlier agent wording is not immutable product intent.
- Document order: this guide → current topic decisions and [Product direction](docs/PRODUCT_DIRECTION.md) → project brief/principles/architecture → playbooks/skills → historical audits and legacy README/PRD/implementation notes. A decision explicitly superseding an older one controls that topic.
- Distinguish technical, platform, legal, and privacy constraints from product hypotheses. The belonging test is a decision aid, not a veto over founder direction.
- Complete authorized implementation, inspect the result, run applicable checks, and fix failures introduced by the change. Do not stop at a first draft when verification or repair remains. A review-only request produces findings; a request to fix them includes the repair loop.
- Existing authorization remains valid. Routine local edits, project regeneration, and validation necessary to an authorized task need no repeated confirmation. Ask only for a genuinely unresolved decision or an action outside authorization; finish independent preparation first.
- New dependencies, new targets/capabilities/entitlements, signing changes, and changes to the four-tab product structure need explicit authorization if not already granted. Production activation, deployment, distribution, and destructive account/data operations require authorization for that action; source implementation alone does not grant it or prove completion.
- For a new release/TestFlight archive, use `python3 scripts/archive-release.py --latest-uploaded <confirmed-highest-uploaded-build>` per [release archive workflow](docs/PLAYBOOKS/release-archive.md). Do not substitute a raw archive command or a one-time build-number bump. Reuse an existing archive for upload retries. Confirm the uploaded maximum from current evidence; never assume the local project number is the server maximum.
- Preserve unrelated working-tree changes. Commit only when requested or included in the task's agreed completion criteria. Never push, force-push, amend, rebase, or tag without explicit instruction. Never discard unrelated work. See [Git workflow](docs/PLAYBOOKS/git-workflow.md) for Git operations.
- Report what changed, actual validation, and material remaining limitations. Keep planned, implemented, deployed, and physically validated states separate. Record concrete unresolved follow-ups in [the backlog](docs/FUTURE_AGENT_TASKS.md).

## Product invariants

- Product: **Counting Sheep**; repository/target name: **Phone in the Other Room**. The person is the shepherd; **Ollie** is their capable border collie.
- The primary ritual is **Wind Down**: put the phone in another room around sleep. **Phone Away** is the secondary mode. **Screen-Free Morning** is the release name; `NightWatch*`, `FocusRun`, `SunriseTrail*`, and other persisted compatibility names remain stable.
- Four release tabs: **Home, Nights, Farm, Settings**. `HomeView` owns routing; active Wind Down becomes the live Home journey, other tabs remain reachable, and terminal receipts temporarily override the shell.
- Slumber Party is a core invite-only shared ritual. Farm, The Barn, Ollie's Search, Search Journal, lifecycle, wool, Shop, and customization are approved production features. General Friends/discovery/chat are separate decisions. Never wire `MVPMockData` or `Views/MVP/` into release flows or add new files to those quarantined layers.
- Timer, permission, NFC, Watch, and app history do not prove continuous physical placement, sleep, total screen avoidance, or routine completion. No medical claims. Distinguish requested protection from observed apply/clear evidence and unknown/failed states.
- New Wind Down, Screen-Free Morning, and Phone Away starts require Family Controls authorization and a non-empty opaque selection. Shield only the consented apps/categories for the eligible session, including Wind Down overnight through morning quiet. Preserve emergency exit; runtime apply/restore failure fails open, records no false evidence, and routes to repair before another start.
- New guard choices are App Shielding or optional NFC + App Shielding. Keep legacy Watch-placement/QR decoding, but do not expose those choices in release setup. The Watch mirrors the phone; it does not authorize, advance, or end protection.
- Cumulative Farm credit survives early endings and excludes Brief Access. Wind Down includes eligible overnight timer time up to actual/planned end, excludes the separately rewarded morning window, and opens a search at 420 cumulative minutes. Phone Away has its own 100-minute meter with no three-night gate. Both grow wool. Factual before-bed minutes, completion counts, Health, and social metrics remain separate; preserve settled rewards and idempotent supported-history backfill (ADR-0020).
- Farms are owned by verified immutable account UUIDs. Account use includes automatic private synchronization. Sign-in loads only that account's Farm; sign-out removes it from active play without deleting the server Farm. Another account never inherits it. Apple and username/handle-or-email plus password are supported directions. Guest data stays a distinct local scope; prior declined upload consent needs explanation and acceptance, not silent enrollment (ADR-0023).
- Farm/progress/search/reward ledgers and the device-only settlement journal use versioned JSON transaction storage in Application Support with recovery copies. Other settings/history remain in UserDefaults. Never upload this local document wholesale: use the private Farm payload contract. Authentication alone proves neither loaded Farm nor confirmed server save.
- Slumber Party sharing is bounded by the accepted versioned agreement and server capability. No unconsented fields, private pre-join backfill, inferred exact-app identity, or raw Health uploads. Singapore/SEA exact-app export remains unproven. Missing data is unknown, not misconduct. See topic references before changing sharing.

## Code and design conventions

- Swift 5.9, SwiftUI, iOS 17+, watchOS 10+, MVVM plus `FocusSessionCoordinator`. `project.yml` is the XcodeGen source of truth; never hand-edit generated `project.pbxproj`.
- `supabase-swift` is the sole approved third-party package for authorized backend paths. No CoreData/SwiftData. UserDefaults keys retain `ollie.*`; Screen Time report contexts retain `phone-other.*`.
- Pure domain logic belongs in `Shared/`, without UIKit/SwiftUI, with meaningful tests in `Tests/`. Side effects belong in `Services/`; views read state and send intents. Keep business logic out of view bodies.
- The phone is authoritative. Keep run transitions in the existing coordinator and anchored `NightWatchPlan`; do not create parallel bedtime/morning state machines. Preserve backwards-compatible Codable data and both sides of `WatchMessage`.
- Root view models are `FocusRunViewModel` and `WatchRunViewModel`; child views use `@EnvironmentObject` for shared models. Use `@State` for view-local state and main-actor UI mutations. Prefer async/await; retain existing Combine change forwarding where needed.
- Prefer injected dependencies. New singletons need a strong reason. Name new services `*Service`, view models `*ViewModel`, and Watch types `Watch*`; reserve `*Manager` for existing connectivity managers. Use `OllieFormat` for formatting.
- Screen Time code is guarded by `#if SCREEN_TIME_REPORTS && canImport(...)`. Scoped selections and the explicit Quiet Note widget value use `group.com.ngawangchime.countingsheep`; other core settings remain in standard defaults.
- New screens go in `PhoneInTheOtherRoomApp/Views/`, shared UI in `Views/Components/`. Keep files around 400 lines; do not grow known oversized `FocusStatsView.swift` or `AssetReadyScreens.swift`.
- Use `Design/Theme.swift` and `PixelComponents.swift` tokens (`AppColors`, `pixelFont()`). Extend the design system centrally when needed; do not invent inline colors/fonts/spacing or build new UI on legacy `GameComponents`.
- Follow [asset naming](docs/ASSET_NAMING.md), preserve placeholder fallbacks, and keep bedtime visuals comfortable in a dark room. New views need representative `#Preview` states, including relevant non-happy paths. Check Dynamic Type, VoiceOver, and touch targets for affected UI.
- Copy is warm, adult, concise, and Ollie-voiced. Evaluate urgency, anticipation, and stakes in context; no generic taste veto. Preserve factual, medical, privacy, and enforcement boundaries. Use [copy review](skills/product-copy-review/SKILL.md) when writing/reviewing release-facing strings.
- Comments explain why. Record unfinished work in the backlog rather than adding TODO comments. Keep project.yml/entitlement/signing/tab-structure edits with one editor at a time.

## Read by task

Search the touched code and relevant backlog entries; do not read the entire backlog or repository map by default. Links below are routes, not a mandatory reading list.

| Task | Relevant references |
|---|---|
| Product behavior, Home, Farm, onboarding, social scope | [Product direction](docs/PRODUCT_DIRECTION.md); [principles](docs/PRODUCT_PRINCIPLES.md) and [brief](docs/PROJECT_BRIEF.md) for rationale |
| SwiftUI behavior/layout | [SwiftUI feature skill](skills/swiftui-feature/SKILL.md); relevant routing/components |
| Architecture, persistence, Watch transport | Relevant sections of [architecture](docs/ARCHITECTURE.md); touched models/services |
| Farm credit/economy | [ADR-0020](docs/DECISIONS/ADR-0020-cumulative-farm-credit.md), [ADR-0015](docs/DECISIONS/ADR-0015-farm-lifecycle-economy-and-customization.md) |
| Account ownership, auth, save/restore | [ADR-0023](docs/DECISIONS/ADR-0023-account-owned-farm-sync.md), [account plan](docs/plans/account-owned-farm-sync.md), [private payload contract](docs/plans/farm-save-contract.md); [ADR-0021](docs/DECISIONS/ADR-0021-account-backed-farm-save.md) for durable-store foundations |
| Onboarding/account handoff | [onboarding account plan](docs/plans/onboarding-account-experience.md), with ADR-0023 superseding Apple-only/manual-backup steps |
| Shielding/NFC/morning settlement | [ADR-0012](docs/DECISIONS/ADR-0012-wind-down-start-and-continuous-shielding.md), [ADR-0019](docs/DECISIONS/ADR-0019-independent-wind-down-and-morning-quiet.md) |
| Slumber Party/sharing | [ADR-0016](docs/DECISIONS/ADR-0016-invite-only-night-flock.md), [social contracts](docs/PRODUCT_DIRECTION.md#slumber-party), relevant capability plan |
| Nontrivial code review | Applicable sections of [pre-merge review](docs/PLAYBOOKS/pre-merge-review.md) |
| Release readiness / blocker repair | [TestFlight skill](skills/testflight-review/SKILL.md), [final-build acceptance](docs/PLAYBOOKS/final-build-acceptance.md), relevant [TestFlight device matrices](docs/PLAYBOOKS/testflight-readiness.md) |

## Validation

This is the shared validation policy; skills/playbooks reference it rather than requiring repeat runs.

- Documentation/instruction-only changes: check changed references, consistency, and whitespace; validate skill metadata when changed. No app build or XcodeGen needed.
- Code changes: build affected targets and run tests covering the changed behavior. Shared logic needs new/updated meaningful tests; persistence/protocol edits include migration/replay/compatibility cases. Inspect affected UI when applicable.
- Generate the project when source membership or project.yml changes, or the generated project is absent. Do not regenerate merely to read or audit the repo.
- The full local app build and unit suite remain the code merge gate. Release candidates additionally require the signed archive, configuration, backend, and physical-device checks in the release playbooks. A Simulator pass does not prove NFC, shielding, Health, Watch, or multi-account device behavior.
- Reuse successful evidence only when it matches the relevant source/configuration; rerun after changes, failures, or unresolved concerns. Do not rerun the same suite simply because another checklist links here.
- Run local validation and repair introduced failures within the authorized task. Confirm isolation before tests that reset accounts/data or contact production; never use the founder's Farm as a disposable fixture.
- Record commands, outcomes and unavailable checks accurately. Do not call a blocked check passed. No CI guarantee is assumed.

Full app merge-gate commands (choose an available iPhone Simulator with `xcrun simctl list devices available`):

```bash
xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator'
xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Documentation maintenance

Keep current rules in their owning topic document and link them here. Move superseded rationale to dated history; do not append a new exception while leaving a conflicting current rule. Product direction and decisions are requirements; verify deployment and validation status against current evidence. Older briefs/playbooks may lag ADR-0020–0023 and must not restore completion-only rewards or optional manual backup as the current contract.

The [7 September instruction cleanup record](docs/agent-instruction-cleanup-2026-09-07.md) maps preserved guidance and validation. The [pre-cleanup snapshot](docs/history/agent-guide-before-cleanup-2026-09-07.md) is historical evidence only; do not load it during ordinary work.
