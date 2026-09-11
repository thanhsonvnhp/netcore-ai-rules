# 08 - EF Core 10 / .NET 10 Operational Rules

---

## DO

1. **Dùng `AsNoTracking()`** (hoặc NoTrackingWithIdentityResolution) cho mọi query read-only. Module có ReadOnly*DbContext variant (QueryTrackingBehavior.NoTracking) được đăng ký riêng.

2. **Migration**: Dùng **DbUp** (không ef migrations + Database.Migrate trong prod). Mỗi module có folder script trong `.dbup/Scripts/{database}/<schema>/` (Schema + Static). Chạy qua .dbup project.

3. **Optimistic Concurrency**: Hỗ trợ qua `RowVersion` (long / bigint/ byte[], concurrency check) trên OutboxEvent và các entity cần. (xmin PostgreSQL native có thể dùng nếu cần).

4. **Explicit transaction**: Hỗ trợ qua `ITransactionalDbContext.BeginTransaction` / CommitAsync / Rollback (Base DbContext của dự án (ví dụ `BaseAppDbContext`) implement). TransactionBehavior chỉ wrap khi chưa có active tx.

5. **Bulk**: Có thể dùng `ExecuteUpdateAsync` / `ExecuteDeleteAsync` khi cần (EF Core hỗ trợ). LƯU Ý: tự quản lý transaction (không dùng implicit tx của EF Core) nếu muốn rollback toàn bộ batch. Xem ví dụ trong backend-coding-standard.md:5.2.

6. **CommandTimeout + resilience**: Đặt trong options (BB Add* methods có thể nhận configure). Base dùng `CreateExecutionStrategy()` + retry cho transient trong implicit tx path.

**Registration thực tế** (bắt buộc dùng NpgsqlDataSource singleton để tránh pool phân mảnh):

```csharp
// AppContext flag (timestamp behavior)
// AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true); // Không cần bật cờ này lên

var dataSourceBuilder = new NpgsqlDataSourceBuilder(connStr);
dataSourceBuilder.EnableDynamicJson();
// (MapEnum, plugins, logging nếu cần)
var dataSource = dataSourceBuilder.Build();

builder.Services.AddSingleton<DbDataSource>(dataSource);
builder.Services.AddSingleton<NpgsqlDataSource>(dataSource);

builder.Services.AddDbContext<TDbContext>((sp, opt) =>
{
    var ds = sp.GetRequiredService<NpgsqlDataSource>();
    opt.UseNpgsql(ds)
       .UseSnakeCaseNamingConvention();
});
```

Có variant read-only (QueryTrackingBehavior.NoTracking). Interceptors: UpdateAuditableEntities + OutboxDomainEvent (Persistence BB). Xem chi tiết + JSONB/PL/pgSQL bên dưới và backend-coding-standard.md:5 + Tiêu chuẩn thiết kế DB.xlsx.

## DON'T

1. **KHÔNG** gọi `Database.MigrateAsync()` tự động khi app startup ở production.
   Chỉ cho phép ở development/testing.

2. **KHÔNG** dùng `Include()` chain dài (>3 cấp) trong write-path handler.
   Đây là dấu hiệu cần tách query riêng (CQRS read path).

3. **KHÔNG** để transaction mở suốt toàn bộ request scope mà không cần thiết.
   Tăng lock contention, giảm concurrency.

4. **KHÔNG** dùng EF Core cho read path phức tạp.
   Dùng Dapper + Stored Procedure (xem `ai-rules/02-cqrs-pattern.md`).

5. **KHÔNG** viết SQL thuần trong code C# cho read path. Dùng PostgreSQL functions.

6. **KHÔNG** bỏ qua `DbUpdateConcurrencyException`.
   Phải xử lý rõ ràng: reload entity -> apply conflict resolution -> trả lỗi 409 Conflict cho client.

7. **KHÔNG** share DbContext giữa các thread.
   Mỗi request phải có DbContext scope riêng (đã được DI container đảm bảo mặc định).
   DBContext không thread-safe. KHÔNG chạy song song asyc query trên cùng DbContext instance.

8. **KHÔNG** `await` query/DB call bên trong vòng lặp (`foreach`/`for`).
   Đây là anti-pattern N+1: mỗi vòng lặp phát sinh một round-trip tới DB -> chậm tuyến tính theo số phần tử.
   **Thay vào đó**: tải trước dữ liệu cần thiết bằng **một** query batch (dùng `Contains`/`IN`, `GroupBy`, hoặc projection),
   nạp vào `Dictionary`/`HashSet`/`Lookup`, rồi so khớp trong bộ nhớ khi lặp.
   - Với ghi hàng loạt: load một lần -> sửa trên tracked entities -> `SaveChangesAsync()` một lần (hoặc `ExecuteUpdateAsync`).
   - **Ngoại lệ hợp lệ** (bắt buộc mới dùng): mỗi vòng phụ thuộc kết quả vòng trước (tuần tự không thể batch),
     hoặc phải giới hạn tài nguyên/bậc song song có chủ đích. Khi buộc phải làm, ghi rõ lý do bằng comment.
   - **KHÔNG** "sửa" N+1 bằng cách chạy song song nhiều query trên cùng một DbContext (vi phạm rule #7).

## Ví dụ minh họa

```csharp
// -- Concurrency conflict handling trong Controller
[HttpPut("{id:guid}")]
public async Task<IActionResult> Update(Guid id, UpdateDocumentCommand cmd, CancellationToken ct)
{
    var result = await Sender.Send(new UpdateDocumentCommand(id, cmd.Title), ct);
    return result.ToApiResponse();
}

// GlobalExceptionHandler catch DbUpdateConcurrencyException
// -> map sang Error.Conflict() -> trả 409 Conflict

// -- AsNoTracking cho read đơn giản
public async Task<IReadOnlyList<DocumentSummaryDto>> GetDocuments(
    Guid tenantId, CancellationToken ct)
{
    return await _db.Documents
                    .AsNoTracking()
                    .Where(d => d.TenantId == tenantId)
                    .OrderByDescending(d => d.CreatedAt)
                    .Select(d => new DocumentSummaryDto(d.Id, d.Title.Value, d.Status))
                    .ToListAsync(ct);
}

// -- Bulk delete
public async Task<int> ArchiveOldDocuments(DateTime cutoff, CancellationToken ct)
{
    return await _db.Documents
                    .Where(d => d.Status == DocumentStatus.Draft
                             && d.CreatedAt < cutoff)
                    .ExecuteDeleteAsync(ct);
}

// -- DbContext configuration
protected override void OnConfiguring(DbContextOptionsBuilder o)
{
    o.UseNpgsql(_connStr, npgsql =>
    {
        npgsql.CommandTimeout(30);
        npgsql.EnableRetryOnFailure(2);
    });
}
```

**JSONB + Complex Types (.NET 10)**: Dùng `ComplexProperty` (không phải `OwnsOne` cũ) để hỗ trợ ExecuteUpdate/ExecuteDelete trực tiếp trên JSONB (không shadow key, hiệu năng cao). Xem ví dụ + batch update pattern trong backend-coding-standard.md:5.2.

**PL/pgSQL routines**: Function (SELECT, không tx) vs Procedure (CALL, cho phép tx nội bộ nhưng **KHÔNG** dùng COMMIT/ROLLBACK bên trong - quản lý tx ở Application layer). Prefix: param `p_`, local var `v_`. Gọi an toàn từ C#:

- EF: `dbContext.Database.ExecuteSqlAsync($"CALL schema.proc({p1}, {p2})");` (FormattableString -> parameterized).
- ADO Npgsql thuần: positional `$1, $2` (tối ưu nhất).

Perf analysis function/procedure: dùng `SET auto_explain.log_min_duration=0; log_analyze=true; log_nested_statements=ON;` rồi chạy routine (xem output trong pgAdmin Messages). Chi tiết + ví dụ proc đầy đủ (FOR UPDATE lock, exception, v_) trong backend-coding-standard.md:6 + Tiêu chuẩn thiết kế DB.xlsx.

Xem thêm 14-database-rule.md và source Tiêu chuẩn files.
