# 12 - Caching Strategy Rules

---

## DO

1. **Dùng caching tập trung**: `AddAppCaching  // tên thực tế do dự án đặt, ví dụ Add{ProjectName}Caching(configuration)` đăng ký `ICacheService` (và HybridCache nếu có). Impl dùng Redis/Valkey khi multi-instance hoặc `IMemoryCache` cho monolith single-instance.
   - Tránh `IMemoryCache` cho data cần consistent giữa instances.

2. **Áp dụng Cache-Aside Pattern** - không bao giờ để cache là nguồn sự thật duy nhất:

   ```
   1. Đọc từ cache
   2. Cache miss -> đọc từ DB
   3. Ghi vào cache với TTL
   4. Trả về data
   ```

3. **Cache key phải include TenantId** để tránh cross-tenant data leak (trừ các thông tin public/global):

   ```csharp
   var key = CacheKeys.Document(_tenantContext.TenantId, documentId);
   // -> "tenant:{tenantId}:doc:{documentId}"
   ```

4. **Luôn đặt TTL rõ ràng** - không bao giờ cache không có expiry:

   ```csharp
   var options = new DistributedCacheEntryOptions
   {
       AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(10),
   };
   ```

5. **Invalidate cache chủ động** sau khi write:

   ```csharp
   await _cache.RemoveAsync(CacheKeys.Document(tenantId, documentId), ct);
   ```

6. **Inject ICacheService** (từ BB) vào Handler/Query cho cache-aside.

7. **Serialize dùng System.Text.Json** (mặc định của framework).

8. **Graceful fallback**: log warning + đọc từ nguồn thật (DB) khi cache down.

## DON'T

1. **KHÔNG** cache data nhạy cảm (nội dung văn bản mật, thông tin PII) mà không mã hóa.

2. **KHÔNG** cache cross-tenant data - mỗi cache entry phải scoped theo TenantId:

   ```csharp
   // [FAIL] WRONG - key không có tenantId
   var key = $"documents:{id}";
   // [OK] CORRECT
   var key = $"tenant:{tenantId}:documents:{id}";
   ```

3. **KHÔNG** cache mãi mãi (TTL = null) cho data thay đổi thường xuyên.

4. **KHÔNG** để cache miss block toàn bộ request nếu Redis down - implement fallback.

5. **KHÔNG** cache kết quả query phân trang động (vì filter/page thay đổi liên tục) - chỉ cache entity đơn lẻ theo ID.

6. **KHÔNG** dùng `IMemoryCache` cho data cần consistent giữa nhiều instance API.

## TTL Reference

| Loại data | TTL gợi ý |
|---|---|
| Master data (danh mục, cấu hình) | 60 phút |
| Thông tin user/tenant | 15 phút |
| Document detail | 10 phút |
| Cây tổ chức (ltree) | 30 phút |
| Token/session | = thời gian hết hạn token |

## Ví dụ minh họa

```csharp
// -- Infrastructure/Caching/ICacheService.cs
public interface ICacheService
{
    Task<T?> GetAsync<T>(string key, CancellationToken ct = default);
    Task SetAsync<T>(string key, T value, TimeSpan? expiry = null, CancellationToken ct = default);
    Task RemoveAsync(string key, CancellationToken ct = default);
    Task<T> GetOrCreateAsync<T>(string key, Func<Task<T>> factory, TimeSpan? expiry = null, CancellationToken ct = default);
}

// -- Infrastructure/Caching/CacheKeys.cs
public static class CacheKeys
{
    public static string Document(Guid tenantId, Guid docId) =>
        $"tenant:{tenantId}:doc:{docId}";

    public static string OrgTree(Guid tenantId) =>
        $"tenant:{tenantId}:org-tree";

    public static string UserPermissions(Guid tenantId, Guid userId) =>
        $"tenant:{tenantId}:user:{userId}:permissions";
}

// -- Cache-aside in Query Handler
internal sealed class GetDocumentByIdQueryHandler(
    IApplicationDbContext dbContext,
    ICacheService cache) : IQueryHandler<GetDocumentByIdQuery, Result<DocumentResponse>>
{
    public async ValueTask<Result<DocumentResponse>> Handle(
        GetDocumentByIdQuery query, CancellationToken ct)
    {
        var key = CacheKeys.Document(_tenant.TenantId, query.DocumentId);

        // Step 1: Try cache
        var cached = await cache.GetOrCreateAsync(
            key,
            async () =>
            {
                var doc = await dbContext.Documents
                    .AsNoTracking()
                    .FirstOrDefaultAsync(d => d.Id == new DocumentId(query.DocumentId), ct);
                return doc is null ? null : doc.ToResponse();
            },
            TimeSpan.FromMinutes(10), ct);

        if (cached is null)
            return DocumentErrors.NotFound;

        return cached;
    }
}

// -- Cache invalidation in Command Handler
internal sealed class UpdateDocumentCommandHandler(IApplicationDbContext dbContext, ICacheService cache)
    : ICommandHandler<UpdateDocumentCommand, Result>
{
    public async ValueTask<Result> Handle(UpdateDocumentCommand cmd, CancellationToken ct)
    {
        // ... update logic ...
        await cache.RemoveAsync(CacheKeys.Document(_tenant.TenantId, cmd.Id), ct);
        return Result.Success();
    }
}
```
