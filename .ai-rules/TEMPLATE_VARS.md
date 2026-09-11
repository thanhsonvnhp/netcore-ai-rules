# Template Variables

Khi onboard bộ `netcore-ai-rules` cho một dự án mới, thay **mọi** placeholder dưới đây. Tìm bằng `grep -r "{Placeholder}" .ai-rules/`.

| Placeholder | Ý nghĩa | Ví dụ |
|---|---|---|
| `{ProjectName}` | Tên solution / repo | `MyApp`, `AcmePlatform` |
| `{Company}` | Namespace prefix (company/product) | `Acme`, `Contoso` |
| `{Module}` | Bounded context / microservice | `Catalog`, `Ordering`, `Identity` |
| `{database}` | Tên database (PostgreSQL/SQL Server) | `myapp`, `acme_db` |
| `{schema}` | DB schema | `app`, `catalog`, `ordering` |
| `{namespace}` | OTel `service.namespace` | `acme`, `my-product` |
| `{ServiceName}` | Tên service trong trace/log | `catalog-api`, `ordering-worker` |
| `{Aggregate}` | Tên aggregate/entity ví dụ | `Product`, `Order`, `Invoice` |

## Ví dụ thực tế (điền gì cho dự án mới)

> Mỗi placeholder là một giá trị dự án thực tế. Dưới đây là 2 ví dụ để bạn hình dung — chọn 1 bộ và điền vào.

| Placeholder | Ví dụ A — Monolith nội bộ | Ví dụ B — Microservice SaaS | Gợi ý đặt tên |
|---|---|---|---|
| `{ProjectName}` | `CRM` | `AcmePlatform` | Tên solution/repo, PascalCase, không dấu |
| `{Company}` | `CRM` | `Acme` | Namespace prefix, PascalCase ngắn gọn |
| `{Module}` | `Identity`, `Workflow`, `MasterData` | `Catalog`, `Ordering`, `Billing` | Mỗi bounded context một giá trị khác nhau — **không replace hàng loạt** |
| `{database}` | `CRM` | `acme_db` | snake_case, trùng tên DB thực tế trên Postgres/SQL Server |
| `{schema}` | `app`, `master`, `workflow` | `catalog`, `ordering` | snake_case, mỗi module một schema riêng; không dùng `public` cho bảng nghiệp vụ |
| `{namespace}` | `CRM` | `acme` | OTel `service.namespace`, kebab/lowercase |
| `{ServiceName}` | `identity-api`, `workflow-worker` | `catalog-api`, `ordering-worker` | Tên service trong trace/log, kebab-case |
| `{Aggregate}` | `Staff`, `Document`, `LeaveRequest` | `Product`, `Order`, `Invoice` | Tên entity chính trong ví dụ code — thay theo từng aggregate thực tế |

**Ví dụ A** copy-paste cho lệnh cài:
```powershell
./install.ps1 -Target ../CRM -Company CRM -ProjectName CRM -Database CRM -Schema app -Namespace CRM -Force
```
**Ví dụ B:**
```powershell
./install.ps1 -Target ../AcmePlatform -Company Acme -ProjectName AcmePlatform -Database acme_db -Schema catalog -Namespace acme -Force
```

Sau khi cài, mở `.ai-rules/core/01-project-hard-rules.md` và điền thêm:
- **Business Overview** — 2–5 bullet mô tả domain thực tế (ví dụ: "Quản lý nhân sự, chấm công, phê duyệt nghỉ phép").
- **Frameworks & Architecture** — stack thực tế: .NET 8/10, Postgres/SQL Server, Redis/Valkey, MassTransit/RabbitMQ...
- **Migration tool** — chọn 1: DbUp (`.dbup/Scripts/{database}/<schema>/`) hoặc EF Migrations (`Infrastructure/Migrations/`).
- **Frontend stack** (nếu có) — ví dụ: React + Vite + Tailwind + TanStack Query.

## Cách replace nhanh

```powershell
# PowerShell - chạy từ root repo đã copy rules vào
$vars = @{
  "{ProjectName}" = "MyApp"
  "{Company}"     = "Acme"
  "{database}"    = "myapp"
  "{namespace}"   = "acme"
}
foreach ($k in $vars.Keys) {
  Get-ChildItem .ai-rules -Recurse -File |
    ForEach-Object {
      $c = Get-Content $_.FullName -Raw
      if ($c.Contains($k)) {
        $c.Replace($k, $vars[$k]) | Set-Content $_.FullName -NoNewline
      }
    }
}
```

Sau khi replace, điền thêm vào `.ai-rules/core/01-project-hard-rules.md`:
- Business Overview (mô tả domain thực tế)
- Frameworks & Architecture (stack thực tế: .NET version, DB provider, event bus, cache)
- Migration tool đã chọn (DbUp vs EF Migrations) và path
- Frontend stack (nếu có)
- Changelog policy bật/tắt

## Lưu ý

- `{Module}` và `{Aggregate}` xuất hiện nhiều lần trong ví dụ code — **không thay hàng loạt** bằng một giá trị duy nhất. Mỗi module/aggregate thay riêng (ví dụ: `Catalog` → `Ordering` → `Identity`). Chỉ auto-replace các placeholder toàn cục (`{Company}`, `{ProjectName}`, `{database}`, `{namespace}`, `{schema}` mặc định).
- Một số file có note `> **Template:` ở đầu - đó là placeholder chưa replace.
- Sau khi onboard, xóa file này hoặc giữ làm reference đều được.
