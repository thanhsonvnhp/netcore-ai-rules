# netcore-ai-rules

Bộ quy tắc và kỹ năng AI dùng chung cho mọi dự án .NET - copy 1 lệnh là chạy. Giúp AI (Claude, Cursor, Copilot...) viết code đúng Clean Architecture, CQRS, EF Core, Outbox-first và convention thống nhất của team.

## Có gì bên trong

- `.ai-rules/` - 3 file core luôn load + 16 file on-demand (CA, CQRS, API contract, EF Core, DB, testing, security...)
- `.agents/skills/` - `code-review`, `database-migration-creator`, `kit-implement`
- `docs/` - Vertical Slice + OutboxEvent + chuẩn code BE
- `.ai-rules/TEMPLATE_VARS.md` - bảng placeholder và 2 ví dụ điền thực tế

## Cài đặt

**Windows (PowerShell) - không cần clone:**

```powershell
irm https://raw.githubusercontent.com/thanhsonvnhp/netcore-ai-rules/main/install.ps1 | iex
```

**Đã clone repo này:**

Chạy từ thư mục chứa `install.ps1`, thay các giá trị trong `<...>` bằng thông tin dự án của bạn (chạy **1 lệnh**):

```powershell
./install.ps1 -Target ../<ProjectName> -Company <Company> -ProjectName <ProjectName> -Database <database> -Schema <schema> -Force
```

Giải thích tham số:

| Tham số | Ý nghĩa | Ví dụ |
|---|---|---|
| `-Target` | Đường dẫn tới thư mục dự án .NET cần cài rules vào | `../CRM`, `../MyApp` |
| `-Company` | Namespace prefix (thay `{Company}`) | `CRM`, `Acme` |
| `-ProjectName` | Tên solution / repo (thay `{ProjectName}`) | `CRM`, `AcmePlatform` |
| `-Database` | Tên database (thay `{database}`) | `CRM`, `acme_db` |
| `-Schema` | DB schema mặc định (thay `{schema}`) | `app`, `catalog` |
| `-Force` | Ghi đè file đã tồn tại (dùng khi cài lại / cập nhật) | |

Ví dụ điền giá trị thật:

```powershell
./install.ps1 -Target ../AcmePlatform -Company Acme -ProjectName AcmePlatform -Database acme_db -Schema catalog -Force
```

Xem trước sẽ copy những file nào (không ghi gì):

```powershell
./install.ps1 -Target ../<ProjectName> -DryRun
```

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/thanhsonvnhp/netcore-ai-rules/main/install.sh | bash -s -- ../<ProjectName>
```

Đã clone thì chạy trực tiếp (thêm `FORCE=1` để ghi đè):

```bash
./install.sh ../<ProjectName>
FORCE=1 ./install.sh ../<ProjectName>
```

> `install.sh` không nhận tham số `-Company`/`-ProjectName`/... như PowerShell. Sau khi cài, mở `.ai-rules/TEMPLATE_VARS.md` và thay các placeholder thủ công (hoặc dùng script replace trong file đó).

Chi tiết placeholder xem `.ai-rules/TEMPLATE_VARS.md`.

## Sau khi cài

1. Mở `.ai-rules/core/01-project-hard-rules.md` điền Business Overview + stack thực tế.
2. Chạy `git add .ai-rules .agents CLAUDE.md AGENTS.md` và commit.