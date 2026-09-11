---
name: database-migration-creator
description: Create or amend a versioned DB migration script + update docs/database/{database}.<schema>.md per .ai-rules/14-database-rule.md. Trigger on any table/column/constraint/index/comment/entity/migration change.
---

# Skill: database-migration-creator

## Nguồn chân lý

`.ai-rules/14-database-rule.md` + `.ai-rules/08-ef-core.md`. Skill KHÔNG định nghĩa rule riêng, chỉ điều phối việc áp rule.

## Vì sao skill này tồn tại?

- Rule DB dài (~200 dòng: naming, type, PK, audit columns, FK order, COMMENT). Agent tự đọc dễ sót 1-2 mục -> DB lệch chuẩn, phải migration sửa.
- Skill đảm bảo **mọi lần tạo/sửa migration đều chạy cùng checklist** và **máy làm phần máy làm được**: tìm sequence tiếp theo, đặt đúng path, tạo/cập nhật docs/database.

## Vì sao KHÔNG copy rule vào skill?

Copy -> 2 nguồn chân lý -> drift. Skill chỉ **load rule tại thời điểm chạy**.

## Đầu vào (input)

| Input | Bắt buộc | Ví dụ |
|-------|----------|-------|
| Schema đích | Có | `app`, `catalog`, `ordering` |
| Tên bảng + mô tả nghiệp vụ | Có | `tasks` - Danh sách công việc |
| Danh sách cột (tên, type, nullable, default, constraint) | Có | `title TEXT NOT NULL`, `priority SMALLINT DEFAULT 2` |
| Enum (nếu có) | Không | `priority: 1=Low, 2=Medium, 3=High` |
| FK (bảng tham chiếu) | Không | `assigned_user_id -> users(id)` |
| Loại thay đổi | Có | `Schema` (tạo/sửa bảng) hay `Static` (seed/config data) |

> Nếu thiếu schema hoặc `{database}` chưa được cấu hình trong `core/01-project-hard-rules.md` / `TEMPLATE_VARS.md` -> hỏi, không đoán.

## Mandatory first step

1. Đọc `.ai-rules/14-database-rule.md` (toàn bộ).
2. Đọc `.ai-rules/08-ef-core.md` (muc  Migration, Registration).
3. Đọc `.ai-rules/core/01-project-hard-rules.md` + `TEMPLATE_VARS.md` để biết `{database}` và cơ chế migration của dự án:
   - **DbUp** -> script tại `.dbup/Scripts/{database}/<schema>/<Schema|Static>/000XXX_*.sql`
   - **EF Core Migrations** -> `dotnet ef migrations add` trong `Infrastructure/Migrations/`
   Phần dưới mô tả chi tiết cho **DbUp**; EF Migrations làm tương tự nhưng thay path.

## Actions (DbUp)

1. **Cấp số sequence**: `ls .dbup/Scripts/{database}/<schema>/Schema/*.sql` (và `Static/` nếu seed), lấy max + 1, format 6 chữ số `000XXX`. Không đoán, không ghi đè file đã tồn tại.
2. **Viết script** theo Canonical Table trong `14-database-rule.md`: snake_case, `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`, đúng type, 8 audit columns (+ `tenant_id`/`workspace_id` chi khi du an co multi-tenant/workspace - OPTIONAL ADD-ON, xem `core/01-project-hard-rules.md`), FK bằng `ALTER TABLE ADD CONSTRAINT` sau `CREATE TABLE`, index `idx_*`, `COMMENT ON TABLE/COLUMN` tiếng Việt.
3. **Cập nhật `docs/database/{database}.<schema>.md`** theo muc 7 Database Documentation Procedure trong `14-database-rule.md` (column list, PK, indexes, constraints, audit, Change Log ở cuối). Dẫn đúng path script vừa tạo. Tạo file mới nếu chưa có.
4. **Không chỉ sửa Entity/DbContext** mà bỏ qua script + docs - cả ba phải đi cùng.
5. **Validate checklist** cuối `14-database-rule.md` trước khi trả kết quả. Thiếu mục nào -> sửa ngay.
6. **Verify**: `dotnet build` (Entity/Configuration khớp script) và `dotnet ef dbcontext optimize --check` nếu dự án có compiled model.

## Khi có spec-kit (`.specify/features/<id>/`)

- Nếu `_03_technical_plan.md` / `_06_implementation_progress.md` / `_10_release_readiness.md` tồn tại -> ghi thêm script, docs, cách kiểm chứng, rủi ro vào đó.
- Không block nếu dự án không dùng spec-kit.

## Output

- 1 script `.sql` đúng path + đúng sequence
- `docs/database/{database}.<schema>.md` khớp SQL thực tế
- (nếu có spec-kit) artifact đã cập nhật

## Stop conditions

- Không xác định được schema hoặc `{database}` -> hỏi.
- Sequence conflict (file cùng số đã tồn tại) -> tăng số, không ghi đè.
- Checklist `14-database-rule.md` chưa pass -> không trả kết quả.
