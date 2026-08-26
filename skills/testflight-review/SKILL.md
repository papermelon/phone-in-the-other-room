# Skill: TestFlight Readiness Review

## Description

Audit the current state of the Counting Sheep repo/build against the TestFlight
readiness requirements and produce a blocker report with a clear ship/no-ship verdict.
This is a **read-only review skill** — it reports; it does not fix.

## When to use

- Before any planned TestFlight upload
- After large merges that might have regressed release readiness
- When the human asks "how far are we from TestFlight?"

## Inputs expected

- The full repo (must inspect, not assume): `project.yml`, all `*.entitlements` files,
  `Assets.xcassets`, release-reachable views, `Info.plist` settings in `project.yml`
- Reference docs: `AGENTS.md` (esp. §15), `docs/PLAYBOOKS/testflight-readiness.md`
  (the authoritative checklist), `docs/PROJECT_BRIEF.md` (MVP scope), ADR-0003/0004 (gates)
- If available: output of `xcodebuild archive` / `xcodebuild test`, and the current
  App Store Connect state as reported by the human

## Procedure

1. Read `docs/PLAYBOOKS/testflight-readiness.md` fully; it is the checklist you are
   scoring against. Do not invent your own criteria; do flag gaps in the playbook itself.
2. **Verify, don't trust:** for each checklist item, find the evidence in code/config
   (e.g. open `project.yml` to check signing keys; grep for `MVPMockData` references in
   release paths; read the entitlement files). Several legacy docs contain drift
   (`AGENTS.md` §16) — never cite them as evidence.
3. Walk the playbook sections in order (account prerequisites → signing → identity →
   scope/mocks → onboarding → permissions/privacy → crash risks → polish). Mark each
   item: PASS / FAIL / NEEDS-HUMAN (e.g. portal state you cannot see) / NOT-APPLICABLE.
4. Run what you can run: `xcodegen generate`, a Release-configuration build, the test
   suite. Paste real output for anything you claim.
5. Check scope compliance explicitly: two tabs in Release, gated features unreachable,
   no mock data, bedtime-framed stats copy.
6. Rate each FAIL: **Blocker** (upload/review will fail or users hit broken flows) /
   **High** (review-rejection or embarrassment risk) / **Polish**.

## Output format

```
# TestFlight Readiness Review — <date>

Verdict: SHIP / DO NOT SHIP (N blockers)

## Blockers
| # | Item | Evidence (file:line or command output) | Fix owner (agent/human) |

## High risks
(same table)

## Polish
(short list)

## Needs human verification
(portal/account items an agent cannot see)

## What changed since last review (if a prior review exists)
```

## Acceptance criteria

- Every playbook section is covered; every FAIL cites concrete evidence (file path,
  config key, or command output) — no vibes.
- Verdict is honest: one blocker means DO NOT SHIP, regardless of momentum.
- Human-only items (Apple account, portal capabilities, App Store Connect) are clearly
  separated from agent-fixable items.
- The review changed nothing in the repo (read-only), except optionally filing follow-up
  tasks in `docs/FUTURE_AGENT_TASKS.md`.
