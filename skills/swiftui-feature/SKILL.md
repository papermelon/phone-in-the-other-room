# Skill: SwiftUI Feature Work

## Description

Procedure for adding or modifying SwiftUI features in Counting Sheep so that changes land
in the right layer, match repo conventions, and arrive tested. Applies to new screens,
changes to existing screens, and feature behavior changes.

## When to use

Any task that adds or changes user-facing functionality in the iOS or Watch app.
Not for: build config work, pure copy edits (use `product-copy-review`), or doc changes.

## Required context (read before writing code)

1. `AGENTS.md` — conventions, gates, validation commands (non-negotiable)
2. `docs/PRODUCT_PRINCIPLES.md` — run the belonging test on the feature *first*;
   refuse or escalate if it fails
3. `docs/ARCHITECTURE.md` §3–§5 — which layer your change belongs in
4. The files you'll touch, plus their neighbors (e.g. read `HomeView.swift` routing
   before adding any screen)
5. `docs/FUTURE_AGENT_TASKS.md` — the task may already be scoped with acceptance criteria

## Implementation steps

1. **Confirm scope and gates.** If the feature touches Farm/Friends/Shop, Screen Time,
   HealthKit, or blocking (ADR-0003/0004 territory) and the gates aren't met: stop and
   report instead of building.
2. **Domain first.** Put pure logic in `Shared/` as testable functions/types. Write the
   unit tests in `Tests/` *now*, keyed to the acceptance criteria.
3. **Side effects second.** New system interactions go in an existing or new
   `Services/*Service.swift`. No new singletons unless unavoidable; prefer injecting into
   the coordinator/view model.
4. **View model third.** Expose state and intents via the existing root view models
   (`FocusRunViewModel` / `WatchRunViewModel`) or the coordinator — do not create parallel
   sources of truth for run state.
5. **View last.** Build on `Theme.swift` / `PixelComponents.swift` tokens. Hook navigation
   through `HomeView`'s existing routing. Keep the view thin.
6. **Wire assets** by the naming in `docs/ASSET_NAMING.md`; missing art must fall back to
   the placeholder system, never crash or show empty boxes.
7. **Copy pass**: run all new strings through `skills/product-copy-review/SKILL.md`.
8. **Validate**: `xcodegen generate` (if files added), build iOS + Watch, run the full
   test suite, and exercise the feature in the simulator. Paste outputs.

## Preview expectations

- Every new or substantially changed view has a `#Preview`.
- Include at least one non-happy-path preview state where the view has one
  (empty progress, `unsupported` device, Watch unreachable, early-ended run).
- Previews must not depend on live services — use fixture state, not `MVPMockData`
  (that file is quarantined to the gated MVP screens).

## Testing expectations

- New `Shared/` logic: unit tests in `Tests/`, covering the edge cases from
  `docs/PLAYBOOKS/pre-merge-review.md` §7 that apply.
- Changed persisted models: a backwards-decoding test alongside the legacy one.
- Full suite green locally; command and tail of output included in the report.

## Review checklist (self-review before handing off)

Run `docs/PLAYBOOKS/pre-merge-review.md` §1–§8 and include the risk rating (§9) in your
summary. L-rated changes must flag that a human review is required before merge.

## Anti-patterns (instant rework)

- Business logic in view bodies; run state duplicated outside the coordinator
- New singletons, new SPM dependencies, new design tokens or inline styling
- Editing `project.pbxproj` by hand
- Building on `GameComponents` or wiring anything to `MVPMockData` / `Views/MVP/`
- Growing `FocusStatsView.swift`, `AssetReadyScreens.swift`, or `PixelComponents.swift`
- Breaking the `unsupported`/fallback paths, or the Watch message queue/fallback strategy
- Guilt/urgency mechanics or copy (see `docs/PRODUCT_PRINCIPLES.md` — hard boundary)
- "Done" without pasted build/test output
