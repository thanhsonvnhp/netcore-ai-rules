# Claude Code - Project Instructions

@AGENTS.md

## How to Use

- MUST load the 3 core files into context at the beginning of every session/task (listed in Quick Start).
- When writing the technical plan and task breakdown, state which reference rules you will follow (for example: "Referenced: 08-ef-core.md, 04-api-contract.md").
- When you need deeper detail (EF Core conventions, API contract rules, testing patterns, changelog template, vertical slice guide, event bus design...), read the specific file in `.ai-rules/*.md`.
- Skills are installed to `.claude/skills/` (mirrored from `.agents/skills/`) so Claude Code discovers them.
- Apply **Surgical Changes** and **Simplicity First** on every code edit.

## Reference Rules (read on demand)

See `.ai-rules/` for 17 detailed rules:

- Event Bus & Outbox design
- Vertical Slice implementation guide
- EF Core, API Contract, Testing, Security, Error Handling, and more

## Claude Code Notes

- All behavior rules (Clean Architecture, outbox-first, migration policy, changelog, testing strategy) are defined in the 3 core files and the delegated sources above.
- Project-specific values (DB name, schema, service names, stack choices) live in `.ai-rules/core/01-project-hard-rules.md` - fill these in when onboarding a new project.
