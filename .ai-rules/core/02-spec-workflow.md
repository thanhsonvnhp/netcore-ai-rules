# 02 - Spec-Driven, Artifact-First Workflow (Core - Always Load)

**This file is intentionally concise.**
The complete, current workflow definition, commands, skill routing, paths, and process steps live in:
**→ `.specify/WORKFLOW.md`** (When User use the `/kit-clarify-plan`, `/kit-implement`, or `/kit-status` commands, MUST read this file in full at the start of every feature)

## Core Constitution (non-negotiable)

This repository uses a **spec-driven, artifact-first** workflow.

**Gate logic (must follow every turn):**

Use the precise **"Gate Requirement Logic"** decision procedure defined in `.agents/GLOBAL_RULES.md`:

Before mutating any production file:

1. Is a kit feature workflow active for this work?
2. Will this action actually write production files **now** (not just propose)?
3. Does `gates/implementation-approved.md` (APPROVED) exist?

If 1+2+3 → gate required.  
Otherwise (planning, proposal, AI Agent Plan mode, small direct edit with no active feature) → **no gate from this kit**.

The gate is **not** a general "you must finish full planning" tax. It is only a guard on actual writes inside an active feature.

**Required developer token:**

```text
APPROVE_IMPLEMENTATION <feature-id>
```

## Workspace

```text
.specify/features/<jira_task_id>_<task_title>/
```

Session-local only — **never commit**.

## Minimal Artifact Sequence

`01_ba_document_review` → `02_clarification_qa` → `03_technical_plan` → `04_contracts_and_data_model` → `05_task_breakdown`  
→ **Gate** (developer approval)  
→ `06_implementation_progress` → `07..._10` reviews

See `.specify/WORKFLOW.md` for the exact current list, decision values, and required content per artifact.

## Primary Commands (use these)

`kit-clarify-plan` → clarify and plan the feature, produce artifacts _01 → _05
`kit-implement` → implement the feature, produce artifacts _06 → _10
`kit-status` → report current status of the feature, produce a summary of all artifacts

See detailed on `.specify/WORKFLOW.md` → section "Primary slash commands (3 commands)".

## SmartOffice Hard Policies (in addition to WORKFLOW.md)

- Every schema or static data change **must** be done via the `database-migration-creator` skill → produces `.dbup/Scripts/smart_office/<schema>/...` + update to `docs/database/smart_office.<schema>.md`.
- Behavior / API / contract / DB impact changes **must** include a changelog entry in `change-logs/YYYY/MM/YYYY-MM-DD.md` using the `change-log-documentation` skill.
- Follow the rest of the rules in `.ai-rules/core/01-smartoffice-hard-rules.md`.