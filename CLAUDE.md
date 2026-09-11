# Claude Code - Project Instructions

@AGENTS.md

## How to Use

- MUST load the 3 core files into context at the beginning of every session/task (listed in Quick Start).
- During **Plan** and **Tasks** phases, explicitly list which reference rules you will follow.
- When you need deeper details (EF Core conventions, API contract rules, testing patterns, changelog template, vertical slice guide, event bus design...), use the `read_file` tool to load the specific file from `.ai-rules/*.md`.
- Feature workspaces: `.specify/features/<task-id>_<title>/` (session-local, not committed) - nếu dự án dùng spec-kit.
- Spec-kit with artifact workflow with 3 commands `/kit-clarify-plan`, `/kit-implement` and `/kit-status`. AI Agent MUST read the full workflow process: always read `.ai-rules/core/02-spec-workflow.md` and `.specify/WORKFLOW.md` (02-spec-workflow.md is only the short core constitution + gate).
- Apply **Surgical Changes** and **Simplicity First** on every code edit.
- Trước khi dùng bộ rules cho dự án mới: đọc `.ai-rules/TEMPLATE_VARS.md` và replace các placeholder (`{ProjectName}`, `{Company}`, `{Module}`, `{database}`).

## Reference Rules (read on demand)

See `.ai-rules/` for 15+ detailed rules:

- Event Bus & Outbox design
- Vertical Slice implementation guide
- EF Core, API Contract, Testing, Security, Error Handling, and more

## Claude Code Notes

- All behavior rules (Clean Architecture, outbox-first, migration policy, changelog, testing strategy) are defined in the 3 core files and delegated sources above.
- Project-specific values (DB name, schema, service names, stack choices) live in `.ai-rules/core/01-project-hard-rules.md` - điền khi onboard dự án mới.
