---
name: kit-implement
description: Turn approved spec-kit planning into running code. Validates gate, resolves task subset, and drives execution (+ reviews when subset = ALL). Only meaningful when .specify/WORKFLOW.md + .specify/features/<id>/ exists.
---

# Skill: kit-implement

## Nguồn chân lý

- Workflow: `.specify/WORKFLOW.md` + `.ai-rules/core/02-spec-workflow.md`
- Rule nghiệp vụ: `.ai-rules/` (đặc biệt `core/01-project-hard-rules.md`)
- Skill KHÔNG định nghĩa workflow hay rule riêng, chỉ điều phối.

## Vì sao skill này tồn tại?

- BA đã có Use Case / Activity Diagram / Function Design List / Screen Flow / Gherkin - không cần clarify thêm.
  Nhưng vẫn cần một bước **từ task breakdown đã duyệt -> code + migration + test + review có audit**, chặn bằng gate `APPROVE_IMPLEMENTATION`.
- Tự động hóa phần máy làm được: validate workspace, resolve subset, chạy song song `[P]` tasks, cập nhật `_06`, và (khi full) chạy chuỗi `_07->_10`.

## Khi nào KHÔNG dùng?

- Dự án không có `.specify/` (không dùng spec-kit) -> bỏ skill, code trực tiếp theo BA docs + `.ai-rules/`.
- Yêu cầu còn thô/thiếu và chưa có planning artifact -> chưa đủ đầu vào.

## Đầu vào (input) - liệt kê rõ

| Input | Bắt buộc | Nguồn |
|-------|----------|-------|
| **BA docs** (ít nhất 1 trong các loại) | Có | Use Case, Activity Diagram, Function Design List, Screen Flow, **Gherkin Scenario**, hoặc **SRS** |
| **`_05_task_breakdown.md`** (đã duyệt) | Có | ` .specify/features/<id>/_05_task_breakdown.md` - mỗi task có `FR-XXX` trace, acceptance criteria, dependency |
| **`_03_technical_plan.md`** + **`_04_contracts_and_data_model.md`** | Có | Kiến trúc, DB schema, API contract đã chốt |
| **Gate `gates/implementation-approved.md`** với `Decision: APPROVED` + token `APPROVE_IMPLEMENTATION <feature-id>` | Có (trước khi write) | Developer cấp token trong prompt `/kit-implement <id> APPROVE_IMPLEMENTATION <id>` |
| **Subset hint** (optional) | Không | `phase:N`, `req:FR-XXX`, `pg:PG-XXX`, list IDs `BE-001 FE-010`, `--next`, hoặc none (= batch pending tiếp) |

> Skill không nhận "chỉ Gherkin thô" hay "chỉ SRS thô" làm đủ. Cần ít nhất BA docs + `_03/_04/_05` đã được duyệt.
> Nếu chỉ có Gherkin/SRS mà chưa có `_03/_04/_05` -> phải tạo chúng trước (thủ công hoặc từ BA).

## Inputs (parse từ prompt)

Prompt tự do `/kit-implement ...`. Parse:

- Feature ID (bắt buộc - thư mục `.specify/features/<id>/`).
- Subset hint (ưu tiên): `phase:N` > `req:FR-XXX` > `pg:PG-XXX` > literal IDs > `--next` > none.
- Token (optional): literal `APPROVE_IMPLEMENTATION <feature-id>`.

## Actions

1. **Parse intent**. Nếu subset mơ hồ -> ghi `Q-IMPL-NNN` vào `_02_clarification_qa.md` muc 3 với options từ `_05` rồi dừng.
2. **Validate planning gate**: kiểm tra `_01->_05` đã tồn tại và `_02` không còn `NEEDS_CLARIFICATION`. Nếu repo có `scripts/validate-feature-workspace.py` thì gọi nó; không có thì check thủ công.
3. **Gate `gates/implementation-approved.md`**:
   - Có token trong prompt -> tạo file với `Decision: APPROVED` (hoặc gọi `scripts/approve-implementation.py` nếu có).
   - Thiếu gate + thiếu token -> ghi `Q-GATE-001` vào `_02` muc 2 rồi dừng.
4. **Resolve subset** từ `_05_task_breakdown.md`. In danh sách đã resolve trước khi chạy.
5. **Chạy tasks**:
   - `[P]` tasks -> song song nếu an toàn; còn lại tuần tự.
   - Mỗi task tuân `.ai-rules/` tương ứng; task chạm DB -> gọi `database-migration-creator` (load `14-database-rule.md`).
   - Không tự thêm scope ngoài `_05`; lệch scope -> ghi `Q-DEV-NNN` vào `_02` muc 3 và tag `TBD` trong `_06` muc 8.
6. **Cập nhật `_06_implementation_progress.md`** liên tục: status, files, commands, test evidence.
7. **Khi subset xong**:
   - Subset = ALL -> set `_06` = `IMPLEMENTATION_COMPLETE`, chạy review chain:
     `code-review` -> `_07`, QA -> `_08`, security -> `_09`, release readiness -> `_10`.
     Cập nhật `change-logs/YYYY/MM/YYYY-MM-DD.md` (theo `15-commit-change-log.md`) và `docs/database/{database}.<schema>.md` nếu có DB change.
   - Subset partial -> set `_06` = `IMPLEMENTATION_PARTIAL` rồi dừng.

## Output

- `_06_implementation_progress.md` (luôn)
- `_07_code_review_report.md` ... `_10_release_readiness.md` (khi subset = ALL)
- `change-logs/...` + `docs/database/{database}.<schema>.md` (khi có thay đổi tương ứng)
- Audit `Q-*` trong `_02_clarification_qa.md` cho mọi lần dừng/độ lệch.

## Stop conditions

- Planning validation fail -> dừng, hướng dẫn tạo/bổ sung `_01->_05`.
- Thiếu token gate -> dừng với `Q-GATE-001`.
- Subset mơ hồ -> dừng với `Q-IMPL-NNN`.
- Task muốn lệch khỏi plan đã duyệt -> dừng với `Q-DEV-NNN`.

## Delegation

- Hard gate decision `APPROVE_IMPLEMENTATION <feature-id>` là **token của developer**, skill không tự approve.
