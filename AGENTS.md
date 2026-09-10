# SmartOffice Backend — AI Coding Agent Instructions

## Quick Start for Any AI Agent

**Always load these 3 core files first** (they contain everything essential):

1. `.ai-rules/core/00-behavioral-guidelines.md` — Mindset & thinking discipline (Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution)
2. `.ai-rules/core/01-smartoffice-hard-rules.md` — Non-negotiable rules (Clean Architecture, DbUp, Changelog, Testing, Outbox-first messaging, Vietnamese preference) + Business overview + repository map + reference implementation (Organization module)
3. `.ai-rules/core/02-spec-workflow.md` — Artifact-first: Core constitution + gate + artifact sequence + primary commands + skill routing + path conventions when use command `/kit-clarify-plan`, `/kit-implement`, or `/kit-status`. MUST read it in full when user use the 3 commands.

## Skill Routing

Source of truth: `.agents/skill-routing.yaml`
Global rules: `.agents/GLOBAL_RULES.md`
Skill index: `.agents/SKILL_INDEX.md`
Workflow reference: `.specify/WORKFLOW.md`

Minimum required mapping:

```text
_01  →  ba-document-review + requirements-traceability + critical-thinking-review
_02  →  ba-document-review + critical-thinking-review
_03  →  technical-planning + requirements-traceability + critical-thinking-review + codegraph-local-memory
_04  →  kit-gen-contracts-and-data-model + requirements-traceability
_05  →  task-decomposition + test-strategy + approval-gate-control
_06  →  implementation-with-evidence + (stack-specific skills)
_07  →  code-review + requirements-traceability + security-review
_08  →  qa-qc-release-readiness + test-strategy + requirements-traceability
_09  →  security-review
_10  →  qa-qc-release-readiness + change-log-documentation + (database-migration-creator if DB changed)
```

Conditional specialist skills:

```text
BDD present       →  bdd-gherkin-review
Sequence present  →  sequence-flow-review
Figma present     →  figma-flow-review
Backend .NET      →  dotnet-clean-architecture
Frontend React    →  react-ui-stack
DB impact         →  database-migration-creator
DB migration      →  database-migration-creator
```

## SmartOffice Stack Rules

See `.ai-rules/core/01-smartoffice-hard-rules.md` — authoritative source for non-negotiable rules (Clean Architecture, DbUp, Changelog, `Result<T>`, 9 audit columns, soft delete, outbox-first, frontend stack, testing stack, paths) plus business overview and repository map.

## Safety Rules

Ask developer confirmation before:

- creating or running destructive migrations
- changing authentication, authorization, permissions, or security-sensitive code
- adding new production dependencies
- deleting files
- touching deployment, CI/CD, infrastructure, or secrets
- expanding scope beyond approved plan

## Skill Catalog

See `.agents/SKILL_INDEX.md` for the full catalog (auto-generated from `.agents/skills/*/SKILL.md`).

## Workflow — 10 Artifacts + 1 Gate

**Core rules + gate**: See `.ai-rules/core/02-spec-workflow.md` (always load) **and** the exact "Gate Requirement Logic" decision procedure in `.agents/GLOBAL_RULES.md`.

The gate is **not** required for planning, proposal, host Plan mode, or small edits outside an active kit feature. It is only required right before actual production writes inside a tracked feature ( when using kit artifact on `.specify/features/*`).

**Read and follow `.specify/WORKFLOW.md` completely**.
**Use Multi-agent when applicable (task list can process in parallel)**

### Quick Reference

- Workspace: `.specify/features/<jira>_<title>/` (never commit)
- Gate: `gates/implementation-approved.md` with `Decision: APPROVED` (token: `APPROVE_IMPLEMENTATION <feature-id>`) — **only required when the intent is to apply/write** (see Proposal vs Apply rules in GLOBAL_RULES)
- Primary commands: `/kit-clarify-plan`, `/kit-implement`, `/kit-status`
- Canonical prompts: `.specify/_prompts/{clarify-plan,implement,status}.md`


## Change log

`change-logs` is required for every code changes