---
name: code-review
description: Review staged changes / PR diff against approved spec + .ai-rules before merge. Use for pre-merge quality gate.
---

# Skill: code-review

## Nguồn chân lý

`.ai-rules/` - đặc biệt `01-clean-architecture.md`, `03-security-tenancy.md`, `04-api-contract.md`, `08-ef-core.md`, `09-error-handling.md`, `14-database-rule.md`, `15-commit-change-log.md`, `16-code-comments.md` và `core/01-project-hard-rules.md`.

Skill KHÔNG định nghĩa rule riêng, chỉ **load rule rồi áp lên diff**.

## Vì sao skill này tồn tại?

- `implement`/`fix-bug` thường chỉ quan tâm "chạy được chưa". Review hệ thống theo CA / security / error handling / DB / contract / changelog cần chạy **riêng, có báo cáo** trước merge.
- Diff có thể chạm nhiều layer, agent làm feature dễ mù điểm chéo. Skill này bắt buộc quét **toàn bộ hard-rule liên quan tới diff**.

## Đầu vào (input)

| Input | Bắt buộc | Ví dụ |
|-------|----------|-------|
| Diff | Có | `git diff --staged`, `git diff main...HEAD`, hoặc PR URL |
| Approved spec | Nếu có spec-kit | `.specify/features/<id>/_01.._05` |
| Scope hint | Không | `BE-`, `FE-`, `DB-` - để load rule liên quan |

> Không có spec-kit -> review trực tiếp trên diff. Có spec-kit -> load thêm spec để check traceability.

## Mandatory first step

1. Đọc `core/01-project-hard-rules.md` + `core/00-behavioral-guidelines.md` + `01-clean-architecture.md`.
2. Nếu có `.specify/features/<id>/` -> load `_01_ba_document_review.md`, `_03_technical_plan.md`, `_04_contracts_and_data_model.md`, `_05_task_breakdown.md`, `_06_implementation_progress.md` (nếu tồn tại).
3. Xác định diff chạm gì -> load rule chi tiết tương ứng:
   auth/tenancy -> `03`, API -> `04`, EF/DB -> `08`+`14`, Result/ProblemDetails -> `09`+`02-constants-errors.md`, changelog -> `15`.

## Cách review (không copy rule - chỉ load và áp)

Với mỗi file trong diff, check theo **rule file gốc** (ghi `file:line - rule muc X` khi raise finding). Bỏ qua mục không liên quan tới diff.

Nhóm rule bắt buộc quét:

- CA boundaries + vertical slice folder/namespace
- Outbox-first nếu có cross-service write
- DB migration/docs/audit columns/COMMENT
- Changelog cho behavior/API/DB/shared change
- `Result`/`Error` tập trung + `ProblemDetails` + HTTP status
- Tests cho handler/entity chạm tới
- Security/tenancy/permission theo spec
- C# style (`field`, `extension(T)`, file-scoped namespace, casing)

> Danh sách trên chỉ là **gợi ý nhóm**, không phải checklist cố định. Nguồn chân lý là nội dung trong các file `.ai-rules/` tại thời điểm review.

## Output

| Có spec-kit | Không có spec-kit |
|-------------|-------------------|
| `_07_code_review_report.md` trong `.specify/features/<id>/` với Decision: `CODE_REVIEW_PASSED` \| `APPROVED_WITH_MINOR_NOTES` \| `CHANGES_REQUESTED` \| `BLOCKED`. Không approve nếu còn vi phạm hard-rule. | Báo cáo markdown inline + `gh pr comment` nếu có `gh` CLI |

Mỗi finding: `file:line - rule muc X - severity - đề xuất fix`. Không pass nếu còn hard-rule violation.

## Stop conditions

- Vi phạm hard-rule chưa fix -> `CHANGES_REQUESTED` hoặc `BLOCKED`.
- Thiếu migration/docs/changelog/test cho change liên quan -> `CHANGES_REQUESTED`.
