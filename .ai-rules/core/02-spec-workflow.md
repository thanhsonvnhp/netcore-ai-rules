# 02 - Spec-Driven, Artifact-First Workflow (Core - Always Load)

**This file is intentionally concise.**
The complete, current workflow definition, commands, paths, and process steps live in:
**-> `.specify/WORKFLOW.md`** (When User use the `/kit-clarify-plan`, `/kit-implement`, or `/kit-status` commands, MUST read this file in full at the start of every feature)

## Core Constitution (non-negotiable)

This repository uses a **spec-driven, artifact-first** workflow.

**Gate logic (must follow every turn):**

Before mutating any production file, answer:

1. Is a kit feature workflow active for this work?
2. Will this action actually write production files **now** (not just propose)?
3. Does `gates/implementation-approved.md` (APPROVED) exist?

If 1+2+3 -> gate required.  
Otherwise (planning, proposal, AI Agent Plan mode, small direct edit with no active feature) -> **no gate from this kit**.

The gate is **not** a general "you must finish full planning" tax. It is only a guard on actual writes inside an active feature.

**Required developer token:**

```text
APPROVE_IMPLEMENTATION <feature-id>
```

## Workspace

```text
.specify/features/<task_id>_<task_title>/
```

Session-local only - **never commit**.

## Minimal Artifact Sequence

`01_ba_document_review` -> `02_clarification_qa` -> `03_technical_plan` -> `04_contracts_and_data_model` -> `05_task_breakdown`  
-> **Gate** (developer approval)  
-> `06_implementation_progress` -> `07..._10` reviews

See `.specify/WORKFLOW.md` for the exact current list, decision values, and required content per artifact.

## Primary Commands (use these)

`kit-clarify-plan` -> clarify and plan the feature, produce artifacts _01 -> _05
`kit-implement` -> implement the feature, produce artifacts _06 -> _10
`kit-status` -> report current status of the feature, produce a summary of all artifacts

See detailed on `.specify/WORKFLOW.md` -> section "Primary slash commands (3 commands)".

## Project Hard Policies (in addition to WORKFLOW.md)

- Schema / static data changes **must** đi qua migration tool của dự án (DbUp hoặc EF Migrations) -> tham chiếu path trong `.ai-rules/core/01-project-hard-rules.md`.
- Behavior / API / contract / DB impact changes **must** include a changelog entry trong `change-logs/YYYY/MM/YYYY-MM-DD.md` (nếu dự án bật changelog policy).
- Chi tiết trong `.ai-rules/core/01-project-hard-rules.md` và `.ai-rules/14-database-rule.md`, `15-commit-change-log.md`.