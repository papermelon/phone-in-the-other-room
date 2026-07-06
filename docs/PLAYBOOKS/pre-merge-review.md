# Playbook: Pre-Merge Review

Reusable checklist for reviewing any change to this repo — whether written by Codex,
Cursor, another agent, or a human. Apply proportionally: a copy tweak needs §1 and §6;
a coordinator change needs everything.

Output of a review: a verdict (approve / approve-with-nits / request changes), the
checklist findings that matter, and a risk rating.

## 1. Product fit

- [ ] Passes the belonging test (`docs/PRODUCT_PRINCIPLES.md`): ritual, bedtime,
      kindness, subtraction, cost.
- [ ] Does not touch gated features without their gates met (ADR-0003, ADR-0004).
- [ ] No anti-addiction violations: no loss-aversion streaks, engagement bait,
      variable-ratio teasing, guilt/shame states, urgency pressure.
- [ ] Stays in scope: a bug fix is a bug fix — no bundled features or refactors.

## 2. Architecture fit

- [ ] Logic is in the right layer: pure/domain → `Shared/` (+ tests); side effects →
      `Services/`; UI state → view models; presentation → `Views/`.
- [ ] Run state flows through `ProximitySessionCoordinator` — no duplicate run state.
- [ ] No new singletons, no new architecture patterns, no new dependencies without
      explicit human approval.
- [ ] `project.yml` edited (never `project.pbxproj`); `xcodegen generate` run if files
      were added/moved.
- [ ] Persisted Codable models remain backwards-decodable; legacy-decode test still passes.
- [ ] Watch protocol changes update both sides of `WatchMessage` and preserve the
      queue/fallback transport strategy.

## 3. Code quality

- [ ] No force unwraps in production paths; failures degrade gracefully.
- [ ] Main-actor discipline for UI mutations (existing `Task { @MainActor in ... }` pattern).
- [ ] Naming follows conventions (`*ViewModel`, `*Service`, `Watch*`, `ollie.*` keys).
- [ ] No dead code, commented-out blocks, debug prints, or TODO comments (file follow-ups
      in `docs/FUTURE_AGENT_TASKS.md` instead).
- [ ] Files stay under ~400 lines; known oversized files were not grown.

## 4. SwiftUI quality

- [ ] Views are thin; no business logic in view bodies.
- [ ] State ownership correct: `@StateObject` only at roots, `@EnvironmentObject` for
      shared view models, `@State` for view-local UI state only.
- [ ] Design tokens from `Theme.swift` / `PixelComponents.swift` — no inline colors,
      fonts, or magic spacing; no new UI built on legacy `GameComponents`.
- [ ] `#Preview` exists for new/changed views, including a non-happy-path state.
- [ ] No layout that breaks under Dynamic Type or on the smallest supported iPhone.

## 5. Accessibility

- [ ] Interactive elements have labels; decorative art is hidden from VoiceOver.
- [ ] State changes users must know about (run state, warnings) are announced or visible
      to assistive tech.
- [ ] Text uses scalable styles; contrast is sufficient in dark, dim-room conditions.
- [ ] Touch targets ≥ 44pt.

## 6. Copy tone

- [ ] All new/changed user-facing strings pass `skills/product-copy-review/SKILL.md`:
      warm, brief, Ollie-voiced; no guilt, urgency, medical claims, or productivity jargon.
- [ ] Bedtime framing where stats are involved ("nights", not "output").

## 7. Edge cases (check the ones the change touches)

- [ ] Watch unreachable / Bluetooth off mid-run
- [ ] Non-UWB device (`unsupported` path)
- [ ] App backgrounded or killed mid-run; relaunch restore
- [ ] Signal lost then recovered; repeated warnings
- [ ] Midnight rollover during a run; timezone/DST changes
- [ ] Fresh install (empty UserDefaults) and legacy persisted JSON
- [ ] Permission denied paths (notifications; later HealthKit/Screen Time)

## 8. Testing

- [ ] `Shared/` logic changes have new/updated tests in `Tests/`.
- [ ] Full suite passes locally:
      `xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,name=iPhone 15'`
- [ ] Build succeeds for iOS + Watch (the shared scheme builds both).
- [ ] Claims of "tested" are backed by pasted output, not assertion.

## 9. Risk rating (include in the review verdict)

| Rating | Meaning | Examples |
|---|---|---|
| **S** | Isolated; hard to break anything else | copy, single view tweak, doc change |
| **M** | Touches shared state or multiple screens | view model changes, persistence fields, design components |
| **L** | Core loop, protocol, or build config | coordinator, `WatchMessage`, `project.yml`, entitlements, tab structure |

L-rated changes require a human in the loop before merge, and should get a Bugbot-style
review pass. M-rated changes need the full checklist. S-rated changes need §1, §6, and a
green build.
