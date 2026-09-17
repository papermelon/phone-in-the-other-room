---
name: testflight-review
description: Assess Counting Sheep TestFlight readiness or verify requested release-blocker fixes against the current release contract. Not a general code-review workflow.
---

# TestFlight readiness

For an audit request, inspect and report without editing product/configuration files.
For an explicit request to fix blockers, complete authorized repairs and revalidate;
this skill does not require stopping at the report. Upload, deployment, signing/capability
changes, and destructive device/account tests retain the authorization boundaries in
[AGENTS.md](../../AGENTS.md#authority-and-completion).

## Evidence and criteria

Start with [final-build acceptance](../../docs/PLAYBOOKS/final-build-acceptance.md).
Use [TestFlight readiness](../../docs/PLAYBOOKS/testflight-readiness.md) for its detailed
platform/device matrices. Consult the current topic ADR/plan where a checklist is stale;
flag the discrepancy rather than enforcing a superseded rule. In particular, account
ownership and automatic sync follow ADR-0023, not prior optional-backup controls.

Inspect the source/configuration/artifact that supports each applicable criterion:
project.yml, relevant entitlements/plists, release routing, mock reachability, privacy
strings, enabled backend capabilities, and exact build/test evidence. Inspect relevant
assets and UI when a presentation or packaging criterion calls for it. A full release
review covers all acceptance areas, but does not require reading every repository file.

Use [the shared validation policy](../../AGENTS.md#validation). Run applicable available
checks, reuse evidence only for matching source/configuration, and record unavailable
checks. Generate the project only when its inputs require it. Local build/test output,
signed archive evidence, production state, and physical-device results are distinct.
Do not erase the founder's Farm or treat production as a disposable test environment.

## Report

Give SHIP / DO NOT SHIP with the scope and exact candidate identified. For each material
finding, include evidence (file/line, artifact, or command result), consequence, severity,
and next action/owner. A table is useful for multiple findings, not mandatory for one.

Classify criteria as PASS / FAIL / UNVERIFIED / NOT APPLICABLE. Unverified required
acceptance prevents SHIP; lack of access is not evidence that a feature fails. Distinguish
an agent-executable missing check from a check requiring unavailable hardware, credentials,
authorization, or human observation. Report relevant differences from prior review if known.

Preserve the current release surface defined in AGENTS.md. Current production Farm/Shop
features are not the quarantined MVP screens. Neither local source nor older deployment
records prove acceptance of newly enabled capabilities.
