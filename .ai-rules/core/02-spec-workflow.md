# 02 - Workflow & Approval Gate (Core - Always Load)

Business requirements come from the **BA** (Use Case, Activity Diagram, Function Design List, Screen Flow, Gherkin, SRS). The AI agent owns the **technical plan** derived from those documents, agrees it with the developer, and only then writes code.

## Task Classification (before any design)

Classify every request and announce the path so the human can override:

- **Spike** — feasibility question ("can we...?"). Output is an answer, not kept code. No plan.
- **Bounded** — small change to an existing flow already in the repo (flag, endpoint, one-file fix). Design = 2-3 sentences in chat, then approval. Plan file optional.
- **Architectural** — new subsystem or cross-component change. Full technical plan in a plan file, then approval.

When in doubt, take the heavier path. Hidden complexity upgrades the path mid-task — stop and re-classify.

## Hard Gate (non-negotiable)

**Do not write production code until the developer has approved the design/plan.**

Gate logic (every turn) - before mutating any production file, answer:

1. Will this action actually write production files **now** (not just propose)?
2. Has the developer approved the plan for exactly this work?

If (1) is yes and (2) is no -> **stop**, present the plan, wait for approval.

Approval is an explicit confirmation from the developer in chat ("approved", "go ahead", "đồng ý", "làm đi"). For Architectural tasks, prefer an explicit token to avoid ambiguity:

```text
APPROVE_IMPLEMENTATION <task-id>
```

The gate does **not** apply to answering questions, reading code, analysis, proposing a plan, or host Plan mode. It only blocks **actual writes** without approval.

Approval for one task does not extend to another. Scope outside the approved plan -> stop and ask for approval again.

## Plan File

```text
.plans/<task-id>.md
```

- **Required** for Architectural tasks, optional for Bounded, not used for Spike.
- `<task-id>` is the tracker ID (for example `JIRA-123`). No tracker ID -> use a short kebab-case slug (for example `order-export`) and confirm it with the developer.
- **Personal and local only - never commit.** `.plans/.gitignore` already ignores everything in the folder. Team-visible history lives in commits, PRs, and `change-logs/`.
- Purpose: survive context compaction and new sessions. A multi-day task must be resumable from this file alone.
- On resume: read `.plans/<task-id>.md` first and continue from the last progress entry. Do not re-plan work that is already approved.
- Keep it short. Required sections:

```markdown
# <task-id> - <title>

## Source
Links/paths to the BA documents this plan implements.

## Technical Plan
Layers touched, API contract, data model, rules referenced.

## Tasks
- [ ] 1. <action> -> verify: <command or observable outcome>

## Approval
Approved by developer on YYYY-MM-DD.

## Progress
YYYY-MM-DD - what was done, what was verified, what is next.
```

## Flow

```text
BA documents
  -> Agent reads + summarizes understanding, lists gaps/contradictions (ask if missing)
  -> Classify task (Spike | Bounded | Architectural)
  -> Technical plan: architecture + API contract + data model + task breakdown + verify steps
  -> GATE: developer approves (record it in the plan file)
  -> Implement (code + migration + test) exactly per the plan
  -> Verify: build + test + format (run for real, read the exit code)
  -> Self-review + changelog + database docs
```

Every task in the breakdown needs concrete verification criteria - see **Goal-Driven Execution** and **Verification Gate** in `00-behavioral-guidelines.md`.

## Primary Skills

| Skill | Use when |
|---|---|
| `implement-feature` | Implementing a feature from BA documents: self-plan -> approval -> code + test + verify |
| `database-migration-creator` | Any table/column/constraint/index/entity change -> migration script + database docs |
| `code-review` | Pre-merge quality gate: apply `.ai-rules/` to a diff |

Small, well-defined changes (one-file bug fix, add a field, change a config) -> code directly per `.ai-rules/`, no skill needed.

## Project Hard Policies

- Schema / static data changes **must** go through the project's migration tool (DbUp or EF Migrations) -> see the paths in `01-project-hard-rules.md`.
- Behavior / API / contract / DB impact changes **must** include a changelog entry in `change-logs/YYYY/MM/YYYY-MM-DD.md` (when the project enables the changelog policy).
- Details in `01-project-hard-rules.md`, `../14-database-rule.md`, `../15-commit-change-log.md`.
