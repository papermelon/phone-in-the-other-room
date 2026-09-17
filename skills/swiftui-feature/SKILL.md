---
name: swiftui-feature
description: Implement Counting Sheep SwiftUI screens and UI behavior using its existing state and design system. Excludes pure copy, documentation, and build-configuration work.
---

# SwiftUI feature work

Deliver the requested behavior in the existing app architecture, with appropriate visual
inspection and validation. [AGENTS.md](../../AGENTS.md) owns conventions, authorization,
current product boundaries, and validation; do not repeat its reading or test steps.

## Context by change

- Read the touched view and the state it actually consumes. Read `HomeView` routing when
  navigation changes, not for every view edit.
- For new behavior or a product tradeoff, consult the relevant section of
  [Product direction](../../docs/PRODUCT_DIRECTION.md) and its current decision. The
  belonging test helps explain tradeoffs; it does not veto explicit founder direction.
- For state ownership, persistence, side effects, or Watch transport changes, read the
  relevant [architecture](../../docs/ARCHITECTURE.md) section and current topic contract.
- Search the relevant [backlog](../../docs/FUTURE_AGENT_TASKS.md) entry if the task refers
  to planned work or needs existing acceptance criteria.

## Required result

- Keep pure logic in Shared, side effects in Services, and UI intents/state in the existing
  view models/coordinator. Choose implementation order to suit the change; presentation
  fixes do not require new domain/service layers.
- Preserve the phone-authoritative run and existing Home routing. Use Theme/PixelComponents
  tokens; add reusable tokens centrally when needed. Keep asset placeholders working.
- Give new views representative previews and relevant empty/error states using fixture
  state, without live service dependencies or quarantined MVP mock data.
- Inspect the affected UI, including relevant Dynamic Type, VoiceOver, small-screen, and
  dark-room states. Do not claim physical platform behavior from a simulator or preview.
- Use [copy review](../product-copy-review/SKILL.md) for new/changed release-facing text.
- Apply [the shared validation policy](../../AGENTS.md#validation): meaningful tests for
  changed logic, compatibility coverage for persisted/protocol changes, and applicable builds.
  Use relevant sections of [pre-merge review](../../docs/PLAYBOOKS/pre-merge-review.md)
  for nontrivial changes. Existing matching validation evidence can satisfy multiple checks.

Continue through inspection and repair of introduced failures. Report actual behavior,
validation, and remaining external gates. Already-authorized work does not require another
scope confirmation; unresolved product/capability decisions follow the root guide.
