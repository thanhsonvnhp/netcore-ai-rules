---
name: code-review
description: Review staged changes / PR diff against .ai-rules (and the BA documents when available) before merge. Use for the pre-merge quality gate.
---

# Skill: code-review

## Source of truth

`.ai-rules/` - especially `01-clean-architecture.md`, `03-security-tenancy.md`, `04-api-contract.md`, `08-ef-core.md`, `09-error-handling.md`, `14-database-rule.md`, `15-commit-change-log.md`, `16-code-comments.md`, and `core/01-project-hard-rules.md`.

This skill defines no rules of its own. It **loads the rules and applies them to the diff**.

## Why this skill exists

- While implementing or fixing a bug, the focus is "does it run yet". A systematic review against CA / security / error handling / DB / contract / changelog must run **separately, with a report**, before merge.
- A diff can touch many layers, and the agent that built the feature tends to miss cross-cutting issues. This skill forces a scan of **every hard rule relevant to the diff**.

## Input

| Input | Required | Example |
|-------|----------|---------|
| Diff | Yes | `git diff --staged`, `git diff main...HEAD`, or a PR URL |
| BA documents | When available | Use Case, Gherkin, SRS... - to check the diff implements the requirement |
| Plan file | When available locally | `.plans/<task-id>.md` - see note below |
| Scope hint | No | `BE-`, `FE-`, `DB-` - to load the relevant rules |

> **The review must work from the diff alone.** `.plans/` is personal and never committed, so a reviewer on another machine will not have it. When it exists locally, use it as a bonus to check traceability (does the diff fully and only implement the plan). Never block a review because the plan file is missing.

## Mandatory first step

1. Read `core/01-project-hard-rules.md` + `core/00-behavioral-guidelines.md` + `01-clean-architecture.md`.
2. If BA documents or a local plan file exist -> load them to check acceptance criteria, API contract, and data model.
3. Determine what the diff touches -> load the matching detailed rules:
   auth/tenancy -> `03`, API -> `04`, EF/DB -> `08` + `14`, Result/ProblemDetails -> `09` + `02-constants-errors.md`, changelog -> `15`.

## How to review (do not copy rules - load and apply them)

For each file in the diff, check against the **original rule file** (cite `file:line - rule section X` when raising a finding). Skip sections unrelated to the diff.

Rule groups that must be scanned:

- CA boundaries + vertical slice folder/namespace
- Outbox-first when there is a cross-service write
- DB migration/docs/audit columns/COMMENT
- Changelog for behavior/API/DB/shared changes
- Centralized `Result`/`Error` + `ProblemDetails` + HTTP status
- Tests for the handlers/entities touched
- Security/tenancy/permissions per the requirement
- C# style (`field`, `extension(T)`, file-scoped namespace, casing)

> The list above is a **grouping hint**, not a fixed checklist. The source of truth is the content of the `.ai-rules/` files at review time.

## Output

An inline markdown report (plus `gh pr comment` when reviewing a PR and the `gh` CLI is available) with a Decision:
`CODE_REVIEW_PASSED` | `APPROVED_WITH_MINOR_NOTES` | `CHANGES_REQUESTED` | `BLOCKED`.

Each finding: `file:line - rule section X - severity - suggested fix`. Never pass while a hard-rule violation remains.

Write the report in the project's output language (see Language Policy in `core/01-project-hard-rules.md`).

## Stop conditions

- Unfixed hard-rule violation -> `CHANGES_REQUESTED` or `BLOCKED`.
- Missing migration/docs/changelog/tests for a related change -> `CHANGES_REQUESTED`.
