# .NET Core Backend - AI Coding Agent Instructions

> **Template:** A generic instruction set for .NET Core backends (Clean Architecture + CQRS + EF Core). When onboarding a new project: replace the placeholders (see `.ai-rules/TEMPLATE_VARS.md`) and fill in the real stack + business overview in `.ai-rules/core/01-project-hard-rules.md`.

> **Single source of truth:** **`.ai-rules/` is the root.** Every skill/agent/command must read and follow `.ai-rules/` and must not define overlapping rules. A skill is only an orchestration layer - the rules live in `.ai-rules/`.

## Quick Start for Any AI Agent

**Always load these 3 core files first** (they contain everything essential):

1. `.ai-rules/core/00-behavioral-guidelines.md` - Mindset & thinking discipline (Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution)
2. `.ai-rules/core/01-project-hard-rules.md` - Non-negotiable rules (Clean Architecture, migration policy, changelog, testing, outbox-first messaging) + project map + language policy + this project's stack
3. `.ai-rules/core/02-spec-workflow.md` - Workflow: task classification + approval gate + plan file + the flow from BA documents to code + primary skills

## Stack Rules

See `.ai-rules/core/01-project-hard-rules.md` - the authoritative source for non-negotiable rules (Clean Architecture, migration tool, changelog, `Result<T>`, audit columns, soft delete, outbox-first, testing stack, paths) plus the business overview and repository map.

For topic detail, see the rule file list in `.ai-rules/README.md`.

## Language

Rules in `.ai-rules/` are written in English. The output language (code comments, user-facing messages, logs, chat replies) is defined in the Language Policy section of `core/01-project-hard-rules.md` - the template default is Vietnamese.

## Safety Rules

Ask developer confirmation before:

- creating or running destructive migrations
- changing authentication, authorization, permissions, or security-sensitive code
- adding new production dependencies
- deleting files
- touching deployment, CI/CD, infrastructure, or secrets
- expanding scope beyond the approved plan

## Workflow - Plan + Approval Gate

**Core rules + gate**: See `.ai-rules/core/02-spec-workflow.md` (always load).

Business requirements come from the BA. The agent derives the technical plan from those documents, the developer approves it, and only then is production code written.

The gate is **not** required for questions, analysis, proposals, or host Plan mode. It only blocks actual production writes that have no approved plan.

### Quick Reference

- Gate: developer approves the plan in chat (for Architectural tasks prefer the token `APPROVE_IMPLEMENTATION <task-id>`)
- Plan file: `.plans/<task-id>.md` - required for Architectural tasks, local only, never committed
- Skills (`.agents/skills/`):
  - `implement-feature` - BA documents -> technical plan -> approval -> code + test + verify
  - `database-migration-creator` - migration script + database docs for every DB change
  - `code-review` - pre-merge quality gate

## Change log

`change-logs` is required for every code change when the project enables the changelog policy (template default: enabled). See `.ai-rules/15-commit-change-log.md`.
