---
name: database-migration-creator
description: Create or amend a versioned DB migration script + update docs/database/{database}.<schema>.md per .ai-rules/14-database-rule.md. Trigger on any table/column/constraint/index/comment/entity/migration change.
---

# Skill: database-migration-creator

## Source of truth

`.ai-rules/14-database-rule.md` + `.ai-rules/08-ef-core.md`. This skill defines no rules of its own. It only orchestrates applying them.

## Why this skill exists

- The DB rules are long (~200 lines: naming, types, PK, audit columns, FK order, COMMENT). An agent reading them ad hoc misses one or two items, the schema drifts from the standard, and a corrective migration is needed.
- This skill guarantees that **every migration runs the same checklist** and that **the machine does the mechanical part**: find the next sequence number, use the right path, create/update the database docs.

## Why NOT copy the rules into this skill

Copying creates two sources of truth, which drift. The skill **loads the rules at run time** instead.

## Input

| Input | Required | Example |
|-------|----------|---------|
| Target schema | Yes | `app`, `catalog`, `ordering` |
| Table name + business description | Yes | `tasks` - work item list |
| Column list (name, type, nullable, default, constraint) | Yes | `title TEXT NOT NULL`, `priority SMALLINT DEFAULT 2` |
| Enum (if any) | No | `priority: 1=Low, 2=Medium, 3=High` |
| FK (referenced table) | No | `assigned_user_id -> users(id)` |
| Change type | Yes | `Schema` (create/alter table) or `Static` (seed/config data) |

> If the schema is unknown or `{database}` is not configured in `core/01-project-hard-rules.md` -> ask, do not guess.

## Mandatory first step

1. Read `.ai-rules/14-database-rule.md` in full.
2. Read `.ai-rules/08-ef-core.md` (Migration and Registration sections).
3. Read `.ai-rules/core/01-project-hard-rules.md` for `{database}` and the project's migration mechanism:
   - **DbUp** -> script at `.dbup/Scripts/{database}/<schema>/<Schema|Static>/000XXX_*.sql`
   - **EF Core Migrations** -> `dotnet ef migrations add` into `Infrastructure/Migrations/`
   The steps below detail **DbUp**; EF Migrations works the same way with a different path.

## Actions (DbUp)

1. **Assign the sequence number**: `ls .dbup/Scripts/{database}/<schema>/Schema/*.sql` (and `Static/` for seed data), take max + 1, format as 6 digits `000XXX`. Do not guess and never overwrite an existing file.
2. **Write the script** per the Canonical Table in `14-database-rule.md`: snake_case, `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`, correct types, the 8 audit columns (plus `tenant_id`/`workspace_id` **only** when the project has multi-tenant/workspace - OPTIONAL ADD-ON, see `core/01-project-hard-rules.md`), FKs via `ALTER TABLE ADD CONSTRAINT` after `CREATE TABLE`, `idx_*` indexes, and `COMMENT ON TABLE/COLUMN` in the project's output language.
3. **Update `docs/database/{database}.<schema>.md`** per the "Migration + Database Docs" section of `14-database-rule.md` (column list, PK, indexes, constraints, audit, Change Log at the end). Reference the exact path of the script just created. Create the file if it does not exist.
4. **Never change only the Entity/DbContext** and skip the script + docs - all three go together.
5. **Validate the "Checklist" section** of `14-database-rule.md` before returning a result. Anything missing -> fix it now.
6. **Verify**: `dotnet build` (Entity/Configuration matches the script) and `dotnet ef dbcontext optimize --check` if the project uses a compiled model.

## When invoked from `implement-feature`

- The script must match the data model in the approved technical plan. Any deviation -> stop and report back.
- Report: script path, docs updated, how it was verified, and risks (locking a large table, data backfill...).

## Output

- One `.sql` script at the correct path with the correct sequence number
- `docs/database/{database}.<schema>.md` matching the actual SQL

## Stop conditions

- Schema or `{database}` cannot be determined -> ask.
- Sequence conflict (a file with the same number exists) -> increment, never overwrite.
- The `14-database-rule.md` checklist does not pass -> do not return a result.
