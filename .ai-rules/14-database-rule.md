# Database Standards - PostgreSQL-first (SQL Server equivalents inline)

> Illustrative examples below use PostgreSQL syntax (the template's primary database).
> SQL Server projects apply the same rules with equivalent types: `UUID` -> `UNIQUEIDENTIFIER
> DEFAULT NEWID()`, `TIMESTAMPTZ` -> `DATETIME2`, `JSONB` -> `NVARCHAR(MAX)` (JSON),
> `TEXT` -> `NVARCHAR(MAX)`, `BOOLEAN` -> `BIT`, `COMMENT ON` -> extended properties.
> Record the project's database in `core/01-project-hard-rules.md`.

Every agent loading this file must follow it strictly.

## Migration + Database Docs (mandatory)

> **Template:** The project picks **one** migration mechanism - DbUp or EF Core Migrations - and records it in `core/01-project-hard-rules.md`. The section below describes **DbUp** in detail; when using EF Migrations, replace the DbUp path with `src/Services/{Module}/{Company}.{Module}.Infrastructure/Migrations/`.

- Every schema/static data change needs a DbUp script in `.dbup/Scripts/{database}/<schema>/<Schema|Static>/`.
- Script names use an increasing 6-digit sequence number per target folder: `000123_<short_change_desc>.sql`.
- Structural DB changes use the `Schema` folder; config/static/seed data changes use the `Static` folder.
- Every DB change must update or create `docs/database/{database}.<schema>.md`.
- The database docs file must match the real SQL and state which tables, columns, constraints, indexes, and static data were affected.
- In the database docs, always point to the real path of the related DbUp script, for example `.dbup/Scripts/{database}/<schema>/Schema/000004_create_products.sql`.
- Never change only the Entity/DbContext/EF configuration and skip the DbUp script and database docs.
- Use the real `{database}` (the project's database name); never use the default `public` schema for business tables.

## Canonical Table

| Component | Standard | Correct example | Wrong example |
|------------|-----------|------------|-----------|
| Schema | snake_case | app, master, workflow | public |
| Table | snake_case, plural, meaningful business name | tasks, document_histories, workflow_steps | tbl_Product, product |
| Column | snake_case, no abbreviations, readable | created_at, assigned_user_id, document_status | crt_dt, usr_id, sts |
| Primary Key | `id UUID PRIMARY KEY DEFAULT gen_random_uuid()` | `id UUID PRIMARY KEY DEFAULT gen_random_uuid()` | serial, "Id" PascalCase |
| String | long -> TEXT; bounded -> VARCHAR(n) | title TEXT, code VARCHAR(50) | varchar(255) for every field |
| Time | TIMESTAMPTZ | created_at TIMESTAMPTZ NOT NULL DEFAULT NOW() | TIMESTAMP, DATETIME |
| Money | NUMERIC(18,2) | amount NUMERIC(18,2) | float, double |
| Boolean | BOOLEAN NOT NULL DEFAULT FALSE | is_active BOOLEAN NOT NULL DEFAULT FALSE | bit, int (0/1) |
| Dynamic | JSONB NOT NULL DEFAULT '{}' | dynamic_data JSONB NOT NULL DEFAULT '{}' | text JSON, json |
| Enum | SMALLINT + mandatory COMMENT + an enum code | priority SMALLINT ... COMMENT '1=Low...' | VARCHAR enum |
| Audit columns | created_*/updated_*/deleted_* + is_deleted + row_version (+ tenant_id/workspace_id only for multi-tenant/workspace) | see section 3 | missing row_version / is_deleted |
| Versioning | row_version BIGINT NOT NULL DEFAULT 0 | row_version BIGINT NOT NULL DEFAULT 0 | xmin only |
| FK column | xxx_id | user_id, workflow_id | user, fkWorkflow |
| Constraint | fk_<table>_<col>, uq_<table>_<col>, ck_<table>_<meaning>, idx_<table>_<cols> | fk_tasks_assigned_to, uq_users_email | FK_xxx, UX_Email, IX_ |
| FK creation | the table first -> ALTER TABLE ADD CONSTRAINT after | - | an inline REFERENCES |
| Comment | always COMMENT TABLE + COLUMN (project output language) | COMMENT ON TABLE app.tasks IS '...' | no comment |
| Transaction | only at the Service layer; never COMMIT/ROLLBACK inside a Function/Procedure | an explicit tx in the Handler | COMMIT inside PL/pgSQL |
| Password | hashed (bcrypt/Argon2) | password_hash TEXT NOT NULL | password TEXT |
| File | metadata only (file_name, object_key, mime_type, size_bytes) | - | bytea, blob content |

## Checklist (must pass before returning a result)

- [ ] Names follow snake_case correctly (plural tables, xxx_id columns, fk_/uq_/ck_/idx_ constraints).
- [ ] PK = `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`.
- [ ] Data types are correct (TEXT/VARCHAR(n), NUMERIC(18,2), TIMESTAMPTZ, BOOLEAN NOT NULL DEFAULT, JSONB, SMALLINT + enum COMMENT).
- [ ] Audit columns are complete (8 mandatory columns; tenant_id/workspace_id only when the project has multi-tenant/workspace - see `core/01-project-hard-rules.md`).
- [ ] There is a COMMENT ON TABLE and a COMMENT ON COLUMN.
- [ ] FKs are created via ALTER TABLE after the table exists.
- [ ] Indexes use the `idx_` prefix; partial/covering indexes use the right suffix.
- [ ] No transaction logic inside a Function/Procedure.
- [ ] Password = a hash column; file = metadata only.
- [ ] There is a DbUp script at the right path `.dbup/Scripts/{database}/<schema>/<Schema|Static>/000123_<short_change_desc>.sql`.
- [ ] The script's sequence number is correct for the target folder.
- [ ] `docs/database/{database}.<schema>.md` was created/updated.
- [ ] The database docs content matches the real SQL and points to the right DbUp script path.
- [ ] TABLE + COLUMN comments (in the project's output language, clearly stating business meaning) + enum meaning.
- [ ] PL/pgSQL: `p_` for params, `v_` for local vars; NO COMMIT/ROLLBACK inside a Function/Procedure (the transaction is owned by the Application/Handler).
- [ ] Composite index: the column with the highest selectivity comes first.
- [ ] FK: CREATE TABLE first (PK + base columns + inline UQ/CK) -> ALTER TABLE ADD CONSTRAINT fk_ after -> CREATE INDEX. Avoid a circular dependency.

## 1. Detailed Naming Standards

Everything consistently uses **snake_case**.

Tables: plural (`tasks`, `document_histories`).
Columns: singular, meaningful (`assigned_user_id`).
FK columns: `{referenced_table}_id`.
Constraints:
- `fk_{table}_{column}` or `fk_{table}_{ref}_{column}`
- `uq_{table}_{column}`
- `ck_{table}_{meaning}`
- `idx_{table}_{cols}` (partial: `_partial`, covering: `_includes`)

**Mandatory order**: CREATE TABLE (PK + base) -> ALTER TABLE ADD CONSTRAINT fk_ -> CREATE INDEX.

**Correct example (from the source)**:

```sql
CREATE TABLE app.categories (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    code VARCHAR(50) NOT NULL,
    CONSTRAINT uq_categories_code UNIQUE (code)
);

CREATE TABLE app.products (
    id UUID PRIMARY KEY,
    category_id UUID NOT NULL,
    name TEXT NOT NULL,
    price NUMERIC(18,2) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE app.products
ADD CONSTRAINT fk_products_categories_category_id
FOREIGN KEY (category_id) REFERENCES app.categories(id);

CREATE INDEX idx_products_category_id ON app.products(category_id);
CREATE INDEX idx_products_created_at_partial ON app.products(created_at) WHERE is_active = TRUE;
```

## 2. Mandatory Data Types

- id: UUID + gen_random_uuid()
- Long text: TEXT
- Bounded code: VARCHAR(n)
- Money: NUMERIC(18,2)
- Time: TIMESTAMPTZ NOT NULL DEFAULT NOW()
- Boolean: BOOLEAN NOT NULL DEFAULT FALSE
- Dynamic: JSONB NOT NULL DEFAULT '{}'
- Enum: SMALLINT + COMMENT

**A good outbox example**:

```sql
CREATE TABLE outbox_messages (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type         VARCHAR(300) NOT NULL,
    payload      JSONB NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    error        TEXT,
    retry_count  INT NOT NULL DEFAULT 0
);
CREATE INDEX idx_outbox_unprocessed ON outbox_messages (created_at) WHERE processed_at IS NULL;
```

## 3. Audit Columns (mandatory)

The 8 mandatory columns on every business table + `tenant_id` / `workspace_id` only when the project has multi-tenant / workspace sharding (see `core/01-project-hard-rules.md` and `03-security-tenancy.md`):

```sql
-- always present:
created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
created_by    varchar(255),
updated_at    TIMESTAMPTZ,
updated_by    varchar(255),
deleted_at    TIMESTAMPTZ,
deleted_by    varchar(255),
is_deleted    BOOLEAN NOT NULL DEFAULT FALSE,
row_version   BIGINT NOT NULL DEFAULT 0
-- + tenant_id UUID / workspace_id UUID  - only when the project has multi-tenant / workspace sharding (OPTIONAL ADD-ON)
```

- tenant_id / workspace_id: OPTIONAL ADD-ON. Add it only when the project has multi-tenant / workspace sharding (record it explicitly in core/01-project-hard-rules.md). It comes from a trusted JWT/header.
- is_deleted: soft delete + query filter.
- row_version: optimistic concurrency.

## 4. Comment, Enum, Transaction, Security

- **Comment**: always COMMENT ON TABLE and COMMENT ON COLUMN (in the project's output language, clearly business-meaningful).
- **Enum**: SMALLINT + an explanatory COMMENT + the matching enum in code.
- **Transaction**: owned only by the Service/Application layer. No COMMIT/ROLLBACK inside a Function/Procedure.
- **Password**: store only the hash (password_hash).
- **File**: store only metadata (file_name, object_key, mime_type, size_bytes). No blob in the DB.

## 5. A complete table example (app.tasks - a multi-tenant project; single-tenant drops the tenant_id line)

> Single-tenant: drop `tenant_id`, rename `uq_tasks_title_per_tenant` to `uq_tasks_title`, remove every tenant filter.

```sql
CREATE TABLE app.tasks (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title            TEXT NOT NULL,
    description      TEXT,
    priority         SMALLINT NOT NULL DEFAULT 2,
    status           VARCHAR(30) NOT NULL DEFAULT 'NEW',
    assigned_user_id UUID,
    due_at           TIMESTAMPTZ,
    dynamic_data     JSONB NOT NULL DEFAULT '{}',

    tenant_id        UUID,   -- OPTIONAL: multi-tenant / workspace sharding only
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by       varchar(255),
    updated_at       TIMESTAMPTZ,
    updated_by       varchar(255),
    deleted_at       TIMESTAMPTZ,
    deleted_by       varchar(255),
    is_deleted       BOOLEAN NOT NULL DEFAULT FALSE,
    row_version      BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT uq_tasks_title_per_tenant UNIQUE (tenant_id, title),
    CONSTRAINT ck_tasks_priority CHECK (priority BETWEEN 1 AND 3)
);

COMMENT ON TABLE app.tasks IS 'Danh sách công việc';
COMMENT ON COLUMN app.tasks.priority IS '1=Low, 2=Medium, 3=High';
COMMENT ON COLUMN app.tasks.assigned_user_id IS 'Người được giao (FK users.id)';

CREATE INDEX idx_tasks_assigned_user_id ON app.tasks(assigned_user_id);
```

## 6. Additional Rules

- **PL/pgSQL**: input params `p_`, locals `v_`. Function (returns data, called with SELECT, **no** internal tx) vs Procedure (changes state, called with CALL, may own a tx but **never** COMMIT/ROLLBACK inside - the tx belongs to the Service/Application layer).
- **Calling a routine from C#**: EF `ExecuteSqlAsync($"CALL schema.proc({p1}, {p2})")` (safe FormattableString) or a positional `$1,$2` NpgsqlCommand (fastest). Never concatenate strings.
- **Composite index**: the column with the highest selectivity (filtered often, good discrimination) comes first (for example customer_id before status when queries usually filter by customer).
- **FK creation order**: CREATE TABLEs (PK + columns + basic UQ/CK) -> ALTER TABLE ... ADD CONSTRAINT fk_<table>_<ref>_<col> -> CREATE INDEX idx_.... (for a full example see section 1).
- **Comment**: MANDATORY `COMMENT ON TABLE ... IS '...' ` + `COMMENT ON COLUMN ... IS '...'` (project output language, clear business meaning). Enum: SMALLINT + COMMENT + the matching C# enum.
- **Audit** (mandatory for every business table): the 8 `created_*/updated_*/deleted_*` columns + `is_deleted` + `row_version` (BIGINT concurrency) + `tenant_id`/`workspace_id` only when the project has multi-tenant/workspace (OPTIONAL ADD-ON).
- **Other**: hash passwords only (bcrypt/Argon2); files are metadata only (name, object_key, mime, size) - no blob/bytea content; JSONB defaults to '{}'; id = gen_random_uuid(); time = timestamptz; numeric(18,2) for money.
