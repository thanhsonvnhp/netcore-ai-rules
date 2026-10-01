# 12 - Caching Strategy Rules

---

## DO

1. **Use centralized caching**: `AddAppCaching` registers `ICacheService` (and HybridCache when available). The actual method name is chosen by the project, e.g. `Add{ProjectName}Caching(configuration)` (see `10-dependency-injection.md`). Implementation: Redis/Valkey for multi-instance deployments, `IMemoryCache` for a single-instance monolith.
   - Avoid `IMemoryCache` for data that must stay consistent across instances.

2. **Apply the Cache-Aside Pattern** - the cache is never the sole source of truth:

   ```
   1. Read from cache
   2. On cache miss -> read from DB
   3. Write to cache with a TTL
   4. Return the data
   ```

3. **Scope the cache key to the owner**: when the project has multi-tenant/workspace (see `core/01-project-hard-rules.md`), the key must include `TenantId`/`workspaceId` so tenants cannot read each other's data. For single-tenant or public/global data, scope by owner only (`user:` / `public:`) or not at all:

   ```csharp
   // multi-tenant
   var key = CacheKeys.Document(_tenantContext.TenantId, documentId);
   // -> "tenant:{tenantId}:doc:{documentId}"
   // single-tenant / global
   var key = CacheKeys.Document(documentId);
   // -> "doc:{documentId}"
   ```

4. **Always set an explicit TTL** - never cache without an expiry:

   ```csharp
   var options = new DistributedCacheEntryOptions
   {
       AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(10),
   };
   ```

5. **Invalidate the cache proactively** after a write:

   ```csharp
   await _cache.RemoveAsync(CacheKeys.Document(tenantId, documentId), ct);
   ```

6. **Inject ICacheService** (from the building block) into handlers/queries for cache-aside reads.

7. **Serialize with System.Text.Json** (the framework default).

8. **Graceful fallback**: log a warning and read from the real source (DB) when the cache is down.

## DON'T

1. Do **NOT** cache sensitive data (confidential document content, PII) without encryption.

2. Do **NOT** cache one tenant's data under another tenant's key - every entry must respect the owner scoping in (3) above. For single-tenant projects there is nothing to scope, so do not add fake tenant ids just to match the multi-tenant examples.

   ```csharp
   // [FAIL] WRONG in a multi-tenant project - no tenant scope
   var key = $"documents:{id}";
   // [OK] CORRECT
   var key = $"tenant:{tenantId}:documents:{id}";
   ```

3. Do **NOT** cache data with a null TTL when the data changes over time.

4. Do **NOT** let a cache miss block the whole request when Redis is down - implement a fallback.

5. Do **NOT** cache paginated query results (filters/pages change constantly) - cache single entities by ID.

6. Do **NOT** use `IMemoryCache` for data that must stay consistent across API instances.

## TTL Reference

| Data type | Suggested TTL |
|---|---|
| Master data (catalogs, config) | 60 minutes |
| User/tenant info | 15 minutes |
| Document detail | 10 minutes |
| Org tree (ltree) | 30 minutes |
| Token/session | = token expiry time |

## Illustrative example

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
    // multi-tenant overload
    public static string Document(Guid tenantId, Guid docId) =>
        $"tenant:{tenantId}:doc:{docId}";

    // single-tenant overload
    public static string Document(Guid docId) =>
        $"doc:{docId}";

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
