# Claude Code — Project Instructions

@AGENTS.md

## How to Use

- MUST Load  the 3 core files into context at the beginning of every session/task (listed in  Quick Start).
- During **Plan** and **Tasks** phases, explicitly list which reference rules you will follow.
- When you need deeper details (EF Core conventions, API contract rules, testing patterns, changelog template, vertical slice guide, event bus design...), use the `read_file` tool to load the specific file from `.ai-rules/*.md` or `docs/`.
- For agent skills: load `.agents/skills/<name>/SKILL.md` on demand when the task matches the skill's description.
- Feature workspaces: `.specify/features/<jira>_<title>/` (session-local, not committed).
- Spec-kit with artifact workflow with 3 commands `/kit-clarify-plan`, `/kit-implement` and `/kit-status`. AI Agent MUST read the full workflow process: always read  `.ai-rules/core/02-spec-workflow.md` and `.specify/WORKFLOW.md` (02-spec-workflow.md is only the short core constitution + gate).
- Apply **Surgical Changes** and **Simplicity First** on every code edit.

## Reference Rules (read on demand)

See `.ai-rules/` for 15+ detailed rules:

- Event Bus & Outbox design
- Vertical Slice implementation guide
- EF Core, API Contract, Testing, Security, Error Handling, and more

Key authoritative docs (under `docs/`):

- `docs/Apply Vertical Slice in Clean Architecture .NET API.md`
- `change-logs/README.md` (mandatory daily changelogs - MUST be updated before any PR)

## Claude Code Notes

- Claude Code skills specific at `.claude/skills/`. Canonical skills location = `.agents/skills/`.
- All behavior rules (Clean Architecture, outbox-first, mandatory DbUp, changelog requirement, testing strategy, Vietnamese preference) are defined in the 3 core files and delegated sources above.
