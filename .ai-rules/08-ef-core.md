# 08 - EF Core 10 / .NET 10 Operational Rules

---

## DO

1. **Use `AsNoTracking()`** (or `NoTrackingWithIdentityResolution`) for every read-only query. The module's `ReadOnly*DbContext` variant (`QueryTrackingBehavior.NoTracking`) is registered separately.

2. **Migration**: use whichever mechanism the project chose in `core/01-project-hard-rules.md` - DbUp (scripts in `.dbup/Scripts/{database}/<schema>/`, folders `Schema` + `Static`) or EF Core Migrations (`Infrastructure/Migrations/`). Either way, **never** call `Database.Migrate()` automatically at app startup in production.

3. **Optimistic Concurrency**: supported via `RowVersion` (long / bigint / byte[], a concurrency check) on OutboxEvent and other entities that need it. (PostgreSQL's native xmin can be used when needed.)

4. **Explicit transaction**: supported via `ITransactionalDbContext.BeginTransaction` / `CommitAsync` / `Rollback` (implemented by the project's base DbContext, for example `BaseAppDbContext`). `TransactionBehavior` wraps a call only when there is no active transaction yet.

5. **Bulk operations**: `ExecuteUpdateAsync` / `ExecuteDeleteAsync` may be used when needed (EF Core supports them). NOTE: manage the transaction yourself (do not rely on EF Core's implicit tx) if the whole batch needs to roll back together. See the example in `docs/backend-coding-standard.md` section 5.2.

6. **CommandTimeout + resilience**: set it in options (the building block's `Add*` methods can accept a configure callback). The base DbContext uses `CreateExecutionStrategy()` + retry for transient failures on the implicit tx path.

**Actual registration** (a singleton `NpgsqlDataSource` is mandatory to avoid pool fragmentation):

```csharp
// AppContext flag (timestamp behavior)
// AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true); // no need to set this flag

var dataSourceBuilder = new NpgsqlDataSourceBuilder(connStr);
dataSourceBuilder.EnableDynamicJson();
// (MapEnum, plugins, logging as needed)
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

There is a read-only variant (`QueryTrackingBehavior.NoTracking`). Interceptors: `UpdateAuditableEntities` + `OutboxDomainEvent` (Persistence building block). See the JSONB/PL-pgSQL detail below and `docs/backend-coding-standard.md` section 5.

## DON'T

1. Do **NOT** call `Database.MigrateAsync()` automatically at app startup in production.
   Only allow it in development/testing.

2. Do **NOT** use a long `Include()` chain (>3 levels) in a write-path handler.
   That is a sign the query should be split out into a dedicated read path (CQRS).

3. Do **NOT** keep a transaction open for the entire request scope without a real need.
   It increases lock contention and reduces concurrency.

4. Do **NOT** write convoluted EF Core LINQ for a read path with heavy joins/aggregation that EF cannot translate efficiently.
   Prefer a PostgreSQL function (see `.ai-rules/02-cqrs-pattern.md` Query Rules), or Dapper + a stored procedure as a non-mandatory alternative.
   Never concatenate raw SQL strings in C# code - use parameterized queries.

5. Do **NOT** write raw SQL in C# code for the read path. Use PostgreSQL functions.

6. Do **NOT** ignore `DbUpdateConcurrencyException`.
   Handle it explicitly: reload the entity -> apply conflict resolution -> return 409 Conflict to the client.

7. Do **NOT** share a DbContext across threads.
   Every request must have its own DbContext scope (the DI container guarantees this by default).
   DbContext is not thread-safe. Never run async queries concurrently on the same DbContext instance.

8. Do **NOT** `await` a query/DB call inside a loop (`foreach`/`for`).
   This is the N+1 anti-pattern: every iteration triggers a DB round-trip -> cost grows linearly with the number of elements.
   **Instead**: pre-load the data you need with **one** batch query (using `Contains`/`IN`, `GroupBy`, or a projection),
   load it into a `Dictionary`/`HashSet`/`Lookup`, then match against it in memory while iterating.
   - For bulk writes: load once -> mutate the tracked entities -> `SaveChangesAsync()` once (or `ExecuteUpdateAsync`).
   - **A valid exception** (use only when truly required): each iteration depends on the previous one's result (inherently sequential, cannot batch),
     or resource/parallelism must be deliberately bounded. When this is unavoidable, state the reason in a comment.
   - Do **NOT** "fix" N+1 by running multiple queries in parallel on the same DbContext (that violates rule #7).

## Illustrative example

```csharp
// -- Concurrency conflict handling in a Controller
[HttpPut("{id:guid}")]
public async Task<IActionResult> Update(Guid id, UpdateDocumentCommand cmd, CancellationToken ct)
{
    var result = await Sender.Send(new UpdateDocumentCommand(id, cmd.Title), ct);
    return result.ToApiResponse();
}

// GlobalExceptionHandler catches DbUpdateConcurrencyException
// -> maps it to Error.Conflict() -> returns 409 Conflict

// -- AsNoTracking for a simple read
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

**JSONB + Complex Types (.NET 10)**: use `ComplexProperty` (not the old `OwnsOne`) to support `ExecuteUpdate`/`ExecuteDelete` directly on JSONB (no shadow key, high performance). See the example + batch update pattern in `docs/backend-coding-standard.md` section 5.2.

**PL/pgSQL routines**: a Function (SELECT, no tx) vs a Procedure (CALL, may own an internal tx but must **NEVER** use COMMIT/ROLLBACK inside it - the transaction is managed by the Application layer). Prefix: param `p_`, local var `v_`. Call it safely from C#:

- EF: `dbContext.Database.ExecuteSqlAsync($"CALL schema.proc({p1}, {p2})");` (FormattableString -> parameterized).
- Raw ADO Npgsql: positional `$1, $2` (fastest).

Routine perf analysis: `SET auto_explain.log_min_duration=0; log_analyze=true; log_nested_statements=ON;` then run the routine (check the output in pgAdmin Messages). Full detail + a complete procedure example (FOR UPDATE lock, exception, `v_`) in `docs/backend-coding-standard.md` section 6.

See also `14-database-rule.md`.
