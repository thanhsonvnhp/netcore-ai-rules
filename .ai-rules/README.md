# .NET Core AI Coding Rules (generic) - Modular Structure

> **Template:** A generic rule set for any .NET Core project. When onboarding a new project, read `.ai-rules/TEMPLATE_VARS.md` and replace the placeholders.

> **Language:** Rules in `.ai-rules/` are written in English (the agent reads them). The output language for code comments, user-facing messages, logs, and chat replies is defined in the Language Policy section of `core/01-project-hard-rules.md` - the template default is Vietnamese.

## Structure

```
.ai-rules/
--- core/                    # <- ALWAYS LOAD IN FULL (3 small files)
|   --- 00-behavioral-guidelines.md
|   --- 01-project-hard-rules.md
|   --- 02-spec-workflow.md
--- 01-clean-architecture.md
--- 02-constants-errors.md
--- 02-cqrs-pattern.md
--- 03-security-tenancy.md
--- 04-api-contract.md
--- 05-resilience.md
--- 06-observability.md
--- 07-testing.md
--- 08-ef-core.md
--- 09-error-handling.md
--- 10-dependency-injection.md
--- 11-configuration.md
--- 12-caching.md
--- 13-background-jobs.md
--- 14-database-rule.md
--- 15-commit-change-log.md
--- 16-code-comments.md
--- TEMPLATE_VARS.md
--- README.md
```

> **Note:** Two files share the `02-` prefix (`02-constants-errors.md`, `02-cqrs-pattern.md`) - kept as-is so existing cross-references do not break.

---

## How an agent uses this (IMPORTANT)

**For every new task:**

1. **Always load the 3 core files** (`core/00-`, `core/01-`, `core/02-`) into context.
2. When writing the technical plan and task breakdown, state the reference rules you will use (for example: "Referenced: 08-ef-core.md, 04-api-contract.md").
3. When you need deeper detail (EF Core conventions, API contract rules, testing patterns, changelog template...), read the matching file in `.ai-rules/`.
4. Strictly apply **Surgical Changes** + **Simplicity First** on every code edit.

## Example bootstrap prompt for an agent

```
You are an AI coding assistant for a .NET Core backend (Clean Architecture, CQRS, EF Core).

Always follow these 3 core files:
- .ai-rules/core/00-behavioral-guidelines.md
- .ai-rules/core/01-project-hard-rules.md
- .ai-rules/core/02-spec-workflow.md

Workflow: BA documents -> Technical plan -> Developer approval -> Implement + Test -> Verify -> Review

Read the matching file in .ai-rules/ when you need a detailed rule.

Start task: [task description]
```

---

## One-command install (for a new project)

> For placeholder detail see `.ai-rules/TEMPLATE_VARS.md`. The examples below are copy-pasteable.

**Windows (PowerShell):**

```powershell
# No clone needed - run straight from GitHub:
irm https://raw.githubusercontent.com/thanhsonvnhp/netcore-ai-rules/main/install.ps1 | iex

# Or, if this repo is already cloned:
./install.ps1 -Target ../CRM -Company CRM -ProjectName CRM -Database crm -Schema app -Force
./install.ps1 -Target ../AcmePlatform -Company Acme -ProjectName AcmePlatform -Database acme_db -Schema catalog -Force
./install.ps1 -Target ../MyProject -DryRun   # preview, writes nothing
```

**macOS / Linux (bash):**

```bash
curl -fsSL https://raw.githubusercontent.com/thanhsonvnhp/netcore-ai-rules/main/install.sh | bash -s -- ../CRM

# With placeholder replacement (env vars):
COMPANY=Acme PROJECT_NAME=AcmePlatform DATABASE=acme_db SCHEMA=catalog ./install.sh ../AcmePlatform
FORCE=1 ./install.sh ../MyProject   # overwrite
```

**Updating an installed rule set (when a new version lands):**

```powershell
./install.ps1 -Target . -Force
./install.ps1 -Target . -Force -Company Acme -ProjectName AcmePlatform -Database acme_db
```

**After installing - what is left to do (required):**

1. Open `.ai-rules/core/01-project-hard-rules.md` and fill in the Business Overview + real stack.
2. See `.ai-rules/TEMPLATE_VARS.md` - the "Placeholders" table explains each placeholder with two worked examples.
