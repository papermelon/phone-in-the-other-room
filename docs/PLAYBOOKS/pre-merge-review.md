# Playbook: Pre-Merge Review

Reusable checklist for reviewing any change to this repo — whether written by Codex,
Cursor, another agent, or a human. Apply only sections relevant to the change. A copy
tweak needs product/copy and affected UI checks; a coordinator change needs state,
compatibility and lifecycle checks. [AGENTS.md](../../AGENTS.md) owns authorization and validation.

Output of a review: a verdict (approve / approve-with-nits / request changes), the
checklist findings that matter, and a risk rating.

## 1. Product fit

- [ ] Product tradeoffs are clear and follow current founder direction. The belonging
      test is a decision aid, not an independent approval gate.
- [ ] Relevant current ADR/capability boundaries are met; source implementation is
      distinguished from hosted activation, consent, distribution and physical validation.
- [ ] Evidence/privacy/medical claims are truthful. Pressure and anticipation are judged
      in context using the copy skill. Farm credit follows ADR-0020; account ownership
      and automatic sync follow ADR-0023.
- [ ] Stays in scope: a bug fix is a bug fix — no bundled features or refactors.

## 2. Architecture fit

- [ ] Logic is in the right layer: pure/domain → `Shared/` (+ tests); side effects →
      `Services/`; UI state → view models; presentation → `Views/`.
- [ ] Run state flows through `FocusSessionCoordinator` — no duplicate run state.
- [ ] Existing architecture is used; new singletons have a strong reason and dependency
      injection was considered. New third-party dependencies have explicit approval.
- [ ] Generated project changes come from XcodeGen inputs; regeneration follows the
      root validation policy.
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
      warm, brief, Ollie-voiced; truthful claims, no guilt or medical promises, and
      context-appropriate pressure rather than a blanket urgency ban.
- [ ] Bedtime framing where stats are involved ("nights", not "output").

## 7. Edge cases (check the ones the change touches)

- [ ] Watch unreachable / Bluetooth off mid-run
- [ ] Optional NFC unavailable/cancelled; legacy placement data normalizes safely
- [ ] App backgrounded or killed mid-run; relaunch restore
- [ ] Shield apply/restore failure, Brief Access, permission revocation, and repair
- [ ] Midnight rollover during a run; timezone/DST changes
- [ ] Fresh install, legacy JSON, transaction-store recovery, and reward replay
- [ ] Permission denied/no-data paths for notifications, HealthKit and Screen Time
- [ ] Account switch/sign-out, owner-scoped caches/queues, declined-sync migration,
      offline/reconnect, stale acknowledgements, conflicts and deletion fencing

## 8. Testing

- [ ] `Shared/` logic changes have new/updated tests in `Tests/`.
- [ ] Applicable checks satisfy [the shared validation policy](../../AGENTS.md#validation),
      including the full local app build/unit suite for code merge and release-specific
      acceptance when requested. Documentation-only work needs no app build.
- [ ] Results identify actual commands/outcomes and relevant source/configuration.
      Matching evidence is reused; unavailable checks are reported, not called passed.

## 9. Risk rating (include in the review verdict)

| Rating | Meaning | Examples |
|---|---|---|
| **S** | Isolated; hard to break anything else | copy, single view tweak, doc change |
| **M** | Touches shared state or multiple screens | view model changes, persistence fields, design components |
| **L** | Core loop, protocol, or build config | coordinator, `WatchMessage`, `project.yml`, entitlements, tab structure |

L-rated changes require human review before merge, unless that review/merge action is
already explicitly authorized; local implementation and validation continue meanwhile.
Use relevant checklist sections for every size of change. A risk label does not by itself
require repeating tests, escalating routine local edits, or building documentation changes.
