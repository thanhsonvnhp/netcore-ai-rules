---
name: database-migration-creator
description: Applied when creating/modifying PostgreSQL database schemas, tables, columns, constraints, indexes, comments, entities, migrations, or any SQL/data model artifacts.
globs: ["**/*.sql", ".dbup/**/*.sql", "docs/database/**/*.md", "**/*Context*.cs", "**/*Entity*.cs", "**/*Domain/**/*Entity*.cs"]
---

# Database Standards – PostgreSQL

Mọi agent khi load file này phải tuân thủ nghiêm ngặt.

## SmartOffice DbUp + Database Docs (bắt buộc)

- Mọi thay đổi schema/static data phải có DbUp script trong `.dbup/Scripts/smart_office/<schema_name>/<Schema|Static>/`.
- Tên script dùng số thứ tự 6 chữ số tăng dần theo folder đích: `000123_<short_change_desc>.sql`.
- Thay đổi cấu trúc DB dùng folder `Schema`; thay đổi dữ liệu cấu hình/static/seed dùng folder `Static`.
- Mọi thay đổi DB phải cập nhật hoặc tạo `docs/database/smart_office.<schema_name>.md`.
- File docs database phải khớp SQL thực tế và ghi rõ bảng, cột, constraint, index, static data bị ảnh hưởng.
- Trong docs database, luôn dẫn đúng path DbUp script liên quan, ví dụ `.dbup/Scripts/smart_office/organization/Schema/000004_add_departments.sql`.
- Không chỉ sửa Entity/DbContext/EF configuration mà bỏ qua DbUp script và docs database.
- Dùng đúng `smart_office`; nếu thấy `smart_ofice` thì coi là lỗi gõ và sửa về `smart_office`.

## Bảng Quy chuẩn Chính (Canonical Table)

| Thành phần | Quy chuẩn | Ví dụ đúng | Ví dụ sai |
|------------|-----------|------------|-----------|
| Schema | snake_case | app, master, workflow | public |
| Table | snake_case, số nhiều, rõ nghĩa nghiệp vụ | tasks, document_histories, workflow_steps | tbl_Product, product |
| Column | snake_case, không viết tắt, dễ đọc | created_at, assigned_user_id, document_status | crt_dt, usr_id, sts |
| Primary Key | `id UUID PRIMARY KEY DEFAULT gen_random_uuid()` | `id UUID PRIMARY KEY DEFAULT gen_random_uuid()` | serial, "Id" PascalCase |
| String | dài → TEXT; hữu hạn → VARCHAR(n) | title TEXT, code VARCHAR(50) | varchar(255) cho mọi field |
| Time | TIMESTAMPTZ | created_at TIMESTAMPTZ NOT NULL DEFAULT NOW() | TIMESTAMP, DATETIME |
| Money | NUMERIC(18,2) | amount NUMERIC(18,2) | float, double |
| Boolean | BOOLEAN NOT NULL DEFAULT FALSE | is_active BOOLEAN NOT NULL DEFAULT FALSE | bit, int (0/1) |
| Dynamic | JSONB NOT NULL DEFAULT '{}' | dynamic_data JSONB NOT NULL DEFAULT '{}' | text JSON, json |
| Enum | SMALLINT + COMMENT bắt buộc + enum code | priority SMALLINT ... COMMENT '1=Low...' | VARCHAR enum |
| Audit columns | tenant_id + created_*/updated_*/deleted_* + is_deleted + row_version | đầy đủ 9 cột (xem bên dưới) | thiếu tenant_id / row_version / is_deleted |
| Versioning | row_version BIGINT NOT NULL DEFAULT 0 | row_version BIGINT NOT NULL DEFAULT 0 | chỉ xmin |
| FK column | xxx_id | user_id, workflow_id | user, fkWorkflow |
| Constraint | fk_<table>_<col>, uq_<table>_<col>, ck_<table>_<meaning>, idx_<table>_<cols> | fk_tasks_assigned_to, uq_users_email | FK_xxx, UX_Email, IX_ |
| FK creation | bảng trước → ALTER TABLE ADD CONSTRAINT sau | — | inline REFERENCES |
| Comment | luôn COMMENT TABLE + COLUMN (tiếng Việt) | COMMENT ON TABLE app.tasks IS '...' | không comment |
| Transaction | chỉ ở Service layer, không COMMIT/ROLLBACK trong Function/Procedure | explicit tx trong Handler | COMMIT trong PL/pgSQL |
| Password | hash (bcrypt/Argon2) | password_hash TEXT NOT NULL | password TEXT |
| File | chỉ metadata (file_name, object_key, mime_type, size_bytes) | — | bytea, blob content |

## Checklist (bắt buộc validate trước khi trả kết quả)

- [ ] Tên dùng snake_case đúng quy tắc (bảng số nhiều, cột xxx_id, constraint fk_/uq_/ck_/idx_).
- [ ] PK = `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`.
- [ ] Kiểu dữ liệu đúng (TEXT/VARCHAR(n), NUMERIC(18,2), TIMESTAMPTZ, BOOLEAN NOT NULL DEFAULT, JSONB, SMALLINT + COMMENT enum).
- [ ] Audit columns đầy đủ 9 cột (tenant_id, row_version, is_deleted bắt buộc).
- [ ] Có COMMENT ON TABLE và COMMENT ON COLUMN.
- [ ] FK tạo bằng ALTER TABLE sau khi bảng tồn tại.
- [ ] Index prefix idx_, partial/covering đúng hậu tố.
- [ ] Không có transaction logic trong Function/Procedure.
- [ ] Password = hash column; file = chỉ metadata.
- [ ] Có DbUp script đúng path `.dbup/Scripts/smart_office/<schema_name>/<Schema|Static>/000123_<short_change_desc>.sql`.
- [ ] Số thứ tự script tăng đúng sequence trong folder đích.
- [ ] Có cập nhật/tạo `docs/database/smart_office.<schema_name>.md`.
- [ ] Nội dung docs database khớp với SQL thực tế và dẫn đúng path DbUp script.
- [ ] Comment TABLE + COLUMN (tiếng Việt, rõ nghiệp vụ) + enum meaning.
- [ ] PL/pgSQL: param p_, biến v_; KHÔNG COMMIT/ROLLBACK bên trong Function/Procedure (quản lý tx ở Application/Handler).
- [ ] Composite index: cột có selectivity cao nhất để trước.
- [ ] FK: CREATE TABLE trước (chỉ PK + cột cơ bản + UQ/CK nội tuyến) → ALTER TABLE ADD CONSTRAINT fk_ sau → CREATE INDEX. Tránh circular dep.

## 1. Quy chuẩn Đặt tên chi tiết

Toàn bộ dùng **snake_case** nhất quán.

Bảng: số nhiều (tasks, document_histories)
Cột: số ít, rõ nghĩa (assigned_user_id)
FK cột: {bảng_tham_chiếu}_id
Ràng buộc:
- fk_{table}_{column} hoặc fk_{table}_{ref}_{column}
- uq_{table}_{column}
- ck_{table}_{meaning}
- idx_{table}_{cols} (partial: _partial, covering: _includes)

**Thứ tự bắt buộc**: CREATE TABLE (PK + cơ bản) → ALTER TABLE ADD CONSTRAINT fk_ → CREATE INDEX.

**Ví dụ đúng (từ nguồn)**:

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

## 2. Kiểu dữ liệu bắt buộc

- id: UUID + gen_random_uuid()
- Text dài: TEXT
- Code/hữu hạn: VARCHAR(n)
- Tiền: NUMERIC(18,2)
- Thời gian: TIMESTAMPTZ NOT NULL DEFAULT NOW()
- Boolean: BOOLEAN NOT NULL DEFAULT FALSE
- Dynamic: JSONB NOT NULL DEFAULT '{}'
- Enum: SMALLINT + COMMENT

**Ví dụ outbox tốt**:

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

## 3. Audit Columns (bắt buộc)

```sql
tenant_id     UUID,
created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
created_by    varchar(255),
updated_at    TIMESTAMPTZ,
updated_by    varchar(255),
deleted_at    TIMESTAMPTZ,
deleted_by    varchar(255),
is_deleted    BOOLEAN NOT NULL DEFAULT FALSE,
row_version   BIGINT NOT NULL DEFAULT 0
```

- tenant_id: lấy từ JWT/header đáng tin cậy.
- is_deleted: soft delete + query filter.
- row_version: optimistic concurrency.

## 4. Comment, Enum, Transaction, Security

- **Comment**: luôn COMMENT ON TABLE và COMMENT ON COLUMN (tiếng Việt, rõ nghiệp vụ).
- **Enum**: SMALLINT + COMMENT giải nghĩa + enum tương ứng trong code.
- **Transaction**: chỉ quản lý ở Service/Application layer. Không COMMIT/ROLLBACK trong Function/Procedure.
- **Password**: chỉ lưu hash (password_hash).
- **File**: chỉ lưu metadata (file_name, object_key, mime_type, size_bytes). Không lưu blob trong DB.

## 5. Ví dụ bảng hoàn chỉnh (app.tasks)

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

    tenant_id        UUID,
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

## 6. Quy tắc bổ sung

- **PL/pgSQL**: param input `p_`, local `v_`. Function (trả data, gọi SELECT, **không** tx nội bộ) vs Procedure (thay đổi state, gọi CALL, cho phép tx nhưng **không** COMMIT/ROLLBACK bên trong — tx do Service/Application layer đảm bảo).
- **Gọi routine từ C#**: EF `ExecuteSqlAsync($"CALL schema.proc({p1}, {p2})")` (FormattableString an toàn) hoặc NpgsqlCommand positional `$1,$2` (hiệu năng cao nhất). Tuyệt đối không nối chuỗi.
- **Index composite**: cột selectivity cao (hay filter, phân biệt tốt) để trước (ví dụ customer_id trước status nếu query hay lọc theo customer).
- **FK creation order**: CREATE TABLEs (PK + cột + UQ/CK cơ bản) → ALTER TABLE ... ADD CONSTRAINT fk_<table>_<ref>_<col> → CREATE INDEX idx_.... (xem ví dụ đầy đủ md:4.1).
- **Comment**: BẮT BUỘC `COMMENT ON TABLE ... IS '...' ` + `COMMENT ON COLUMN ... IS '...' ` (tiếng Việt, ý nghĩa nghiệp vụ rõ). Enum: SMALLINT + COMMENT + enum C# tương ứng.
- **Audit 9 cột + row_version** (bắt buộc cho mọi bảng nghiệp vụ): tenant_id, created_*/updated_*/deleted_* (timestamptz + uuid by), is_deleted (soft delete + query filter), row_version (BIGINT concurrency).
- **Khác**: Password chỉ hash (bcrypt/Argon2); file chỉ metadata (name, object_key, mime, size) — không blob/bytea content; JSONB default '{}'; id = gen_random_uuid(); time = timestamptz; numeric(18,2) cho tiền.
