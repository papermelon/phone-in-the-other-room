# Repository skills

Use the workflow relevant to the request. [AGENTS.md](../AGENTS.md) owns authority,
current constraints, task routing, and validation; skills add only task-specific guidance.

| Skill | Use when |
|---|---|
| [SwiftUI feature](swiftui-feature/SKILL.md) | Implementing a screen or UI behavior, excluding pure copy/config/docs |
| [Product copy](product-copy-review/SKILL.md) | Writing or reviewing release-facing text and accessibility wording |
| [TestFlight review](testflight-review/SKILL.md) | Assessing release readiness or verifying requested blocker repairs |

These files remain at their existing repository paths. Invoke one by naming its path
or use the root guide's routing. Frontmatter identifies the skill; this directory alone
is not a claim that every agent host automatically discovers it. Cursor's adapter points
to the same root guide. Other agents and humans can read the relevant file directly.

Add a skill when a recurring workflow needs non-obvious guidance. Keep its description
short and specific, with exclusions only where misrouting is likely. Use the body for
essential outcomes/constraints and conditional references for substantial details.
There is no required six-section template or fixed implementation order. Do not duplicate
product gates, validation commands, or entire reference documents. Preserve current user
intent and authorization; validate metadata and try representative tasks after meaningful
workflow changes.
