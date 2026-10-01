---
name: implement-feature
description: Implement a feature from BA documents - self-plan (technical plan + task breakdown), get developer approval, then code + migration + test + verify. Use when the BA has delivered business documents (Use Case, Gherkin, SRS...) that need to become code.
---

# Skill: implement-feature

## Source of truth

- Workflow, gate, plan file format: `.ai-rules/core/02-spec-workflow.md`
- Mindset: `.ai-rules/core/00-behavioral-guidelines.md`
- Project rules: `.ai-rules/core/01-project-hard-rules.md` + topic files in `.ai-rules/*.md`
- This skill defines no workflow or rules of its own. It only orchestrates.

## Why this skill exists

- The BA has already done the business planning (Use Case, Activity Diagram, Function Design List, Screen Flow, Gherkin, SRS). The developer does not re-clarify the business from scratch.
- Between the BA documents and code there is still a missing step: the **technical plan** (architecture, contract, data model, task breakdown). This skill produces that plan, agrees it with the developer, and only then writes code.
- Every implementation goes through the same sequence: read BA -> plan -> developer approves -> code + test -> verify -> self-review.

## When NOT to use

- Small change with a clear requirement (bug fix, add a field, change a config) -> code directly per `.ai-rules/`. No skill needed.
- No BA documents and the requirement is still vague -> not enough input. Ask the BA/developer first.
- Feasibility question only (Spike) -> answer it, do not write code.

## Input

| Input | Required | Source |
|-------|----------|--------|
| **BA documents** (at least one type) | Yes | Use Case, Activity Diagram, Function Design List, Screen Flow, Gherkin Scenario, or SRS |
| **Task ID** | Recommended | Jira/Azure DevOps ID - names the plan file and is used in the changelog and commit message |
| **Scope hint** | No | Limits this run (for example API only, or one use case from the document) |

> Missing critical business information (business rule, validation, valid states) -> **ask, do not guess**. State the exact question and stop.

## Actions

1. **Resume check**: if `.plans/<task-id>.md` exists, read it first. Continue from the last Progress entry and do not re-plan approved work. Otherwise start at step 2.
2. **Read the rules first**: `core/00-behavioral-guidelines.md`, `core/01-project-hard-rules.md`, `core/02-spec-workflow.md`. Load further `.ai-rules/` files by scope (API -> `04`, EF/DB -> `08` + `14`, auth -> `03`, errors -> `09` + `02-constants-errors.md`...).
3. **Read the BA documents** and summarize your understanding: use case, actors, business rules, validation, states, acceptance criteria. List gaps and contradictions.
4. **Classify the task** per `core/02-spec-workflow.md` (Spike / Bounded / Architectural) and announce the chosen path.
5. **Write the technical plan** and present it to the developer:
   - Architecture: layers touched, where the slice/feature folder lives.
   - API contract: endpoints, request/response, HTTP status, error codes.
   - Data model: new tables/columns/indexes/constraints, whether a migration is needed.
   - Task breakdown: each task + how to verify it (Goal-Driven Execution format from `core/00`).
   - Rules referenced: state them explicitly (for example "Referenced: 04-api-contract.md, 08-ef-core.md, 14-database-rule.md").
   - Risks, assumptions, out-of-scope items.
   - Architectural task -> save it to `.plans/<task-id>.md` using the format in `core/02-spec-workflow.md`.
6. **Gate - wait for developer approval**. Do not write production code before explicit approval (see `core/02-spec-workflow.md`). If the developer asks for changes, revise and present again. Record the approval in the plan file.
7. **Implement** exactly per the approved plan:
   - Follow the matching `.ai-rules/` file for each task.
   - A task touching the DB -> invoke the `database-migration-creator` skill (it loads `14-database-rule.md` itself).
   - Write tests per `07-testing.md`. Bug fix -> reproduce with a test first (TDD Iron Law in `core/00`).
   - Deviation from the approved plan -> **stop**, explain why, ask for approval again. Never widen scope on your own.
   - Append to the Progress section of the plan file after each completed task.
8. **Verify** (mandatory, per the Verification Gate in `core/00`): `dotnet build` + `dotnet test` + `dotnet format --verify-no-changes`. Run them for real and read the exit code before reporting completion.
9. **Finish**:
   - Changelog `change-logs/YYYY/MM/YYYY-MM-DD.md` when the project enables the policy (see `15-commit-change-log.md`).
   - `docs/database/{database}.<schema>.md` when there is a DB change.
   - Self-review with the `code-review` skill before reporting completion.

## Output

- Technical plan (in chat; saved to `.plans/<task-id>.md` for Architectural tasks).
- Code + tests + migration scripts per the approved plan.
- Verification evidence: build/test/format output.
- Changelog entry + database docs when applicable.
- List of assumptions, open questions, and out-of-scope items.

## Stop conditions

- BA documents lack a required business rule/validation -> stop, ask.
- Developer has not approved the plan -> stop, write no production code.
- A requirement appears that deviates from the approved plan -> stop, ask for approval again.
- Build/test fails -> fix before reporting completion. Never report done while anything is red.

## Delegation

- Approving the plan is the **developer's decision**. The skill never self-approves.
- DB migration -> `database-migration-creator`. Pre-merge review -> `code-review`.
