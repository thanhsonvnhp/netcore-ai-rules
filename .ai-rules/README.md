# .NET Core AI Coding Rules (generic) - Modular Structure

> **Template:** Bộ rules generic cho mọi dự án .NET Core. Khi onboard dự án mới, đọc `.ai-rules/TEMPLATE_VARS.md` và replace các placeholder (`{ProjectName}`, `{Company}`, `{Module}`, `{database}`, `{schema}`).

## Cấu trúc
```
.ai-rules/
--- core/                    # <- LUÔN LOAD ĐẦY ĐỦ (3 file nhỏ)
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

> **Ghi chú:** Có 2 file cùng số `02-` (`02-constants-errors.md`, `02-cqrs-pattern.md`) - giữ nguyên để không break cross-reference hiện có.

---

## Cách sử dụng cho Agent (QUAN TRỌNG)

**Mọi task mới:**
1. **Luôn load 3 file core** (`core/00-`, `core/01-`, `core/02-`) vào context.
2. Trong phase **Plan** và **Tasks**, ghi rõ các rule reference cần dùng (ví dụ: "Referenced: 08-ef-core.md, 04-api-contract.md").
3. Khi cần chi tiết sâu (EF Core convention, API contract rules, testing pattern, changelog template...), dùng tool `read_file` để load file tương ứng trong `.ai-rules/`.
4. Tuân thủ nghiêm ngặt **Surgical Changes** + **Simplicity First** khi edit code.

## Ví dụ prompt khởi tạo cho agent
```
Bạn là AI coding assistant cho backend .NET Core (Clean Architecture, CQRS, EF Core).

Luôn tuân thủ 3 file core sau:
- .ai-rules/core/00-behavioral-guidelines.md
- .ai-rules/core/01-project-hard-rules.md
- .ai-rules/core/02-spec-workflow.md

Quy trình: Spec-Driven (Specify -> Clarify -> Plan -> Tasks -> Implement -> QA/Review)

Khi cần rule chi tiết, hãy đọc file trong .ai-rules/ bằng read_file.

Bắt đầu task: [mô tả task]
```

---

## Cài đặt one-command (cho dự án mới)

> Chi tiết placeholder xem `.ai-rules/TEMPLATE_VARS.md` — dưới đây là 2 ví dụ copy-paste được.

**Windows (PowerShell):**
```powershell
# Không cần clone — chạy trực tiếp từ GitHub:
irm https://raw.githubusercontent.com/thanhsonvnhp/netcore-ai-rules/main/install.ps1 | iex

# Hoặc nếu đã clone repo này:
./install.ps1 -Target ../CRM -Company CRM -ProjectName CRM -Database CRM -Schema app -Force
./install.ps1 -Target ../AcmePlatform -Company Acme -ProjectName AcmePlatform -Database acme_db -Schema catalog -Force
./install.ps1 -Target ../MyProject -DryRun   # xem trước, chưa ghi file
```

**macOS / Linux (bash):**
```bash
curl -fsSL https://raw.githubusercontent.com/thanhsonvnhp/netcore-ai-rules/main/install.sh | bash -s -- ../CRM
FORCE=1 ./install.sh ../MyProject  # ghi đè
```

**Cập nhật bộ rules đã cài (khi có bản mới):**
```powershell
./install.ps1 -Target . -Force
./install.ps1 -Target . -Force -Company Acme -ProjectName AcmePlatform -Database acme_db
```

**Sau khi cài — việc còn lại (bắt buộc):**
1. Mở `.ai-rules/core/01-project-hard-rules.md` điền Business Overview + stack thực tế.
2. Xem `.ai-rules/TEMPLATE_VARS.md` — bảng "Ví dụ thực tế" giải thích từng placeholder + gợi ý đặt tên.
