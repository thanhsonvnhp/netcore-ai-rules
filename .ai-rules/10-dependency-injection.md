# 10 – Dependency Injection & Service Registration Rules

---

## Mediator Library

Dự án dùng **Mediator** (source generator) + local adapters `ICommand` / `ICommand<T>` / `IQuery<T>` trong `BuildingBlock.Application.Shared.Abstractions.Messaging` (implement `IRequest<Result>` của Mediator).
**KHÔNG dùng MediatR (Jimmy Bogard).**

---

## DO

1. **Tổ chức registration theo LAYERED context** bằng extension methods:

   ```csharp
   // Program.cs — chỉ gọi module-level extensions
   builder.Services
       .AddApplicationSServices(builder.Configuration)
       .AddInfrastructure(builder.Configuration)
       .AddApiServices();
   ```

2. **Mỗi layer tự đăng ký qua `IServiceCollection` extension** đặt trong layer đó:
   - `Application/DependencyInjection.cs` → `AddApplicationSServices()`
   - `Infrastructure/DependencyInjection.cs` → `AddInfrastructure()`
   - `Api/DependencyInjection.cs` → `AddApiServices()`

3. **Chọn service lifetime đúng:**

   | Lifetime | Khi nào dùng | Ví dụ |
   |---|---|---|
   | `Singleton` | Stateless, thread-safe, khởi tạo tốn kém | `IMemoryCache`, config options |
   | `Scoped` | Gắn với HTTP request, có trạng thái per-request | `DbContext`, `ICurrentUser`, `ITenantContext` |
   | `Transient` | Lightweight, stateless, không share | Simple calculators, validators |

4. **Bật validation container ở startup** để phát hiện lỗi ngay:

   ```csharp
   builder.Host.UseDefaultServiceProvider((ctx, opts) =>
   {
       opts.ValidateScopes  = ctx.HostingEnvironment.IsDevelopment();
       opts.ValidateOnBuild = ctx.HostingEnvironment.IsDevelopment();
   });
   ```

5. **Register Mediator và FluentValidation theo assembly scan (thực tế):**

   ```csharp
   services.AddMediator(options =>
   {
       options.Namespace = "SmartOffice.OrganizationManagement.Application";
       options.ServiceLifetime = ServiceLifetime.Scoped;
   });
   services.AddValidatorsFromAssembly(Assembly.GetExecutingAssembly());

   services.AddSingleton(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>));
   services.AddScoped(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));   // Scoped vì IValidator scoped
   services.AddSingleton(typeof(IPipelineBehavior<,>), typeof(IntegrationEventPublishBehavior<,>));
   services.AddScoped(typeof(IPipelineBehavior<,>), typeof(TransactionBehavior<,>)); // cho ICommand

   services.AddScoped<IIntegrationEventCollector, IntegrationEventCollector>();
   ```

6. **Keyed Services** (.NET 8+) có thể dùng khi cần nhiều impl (chưa thấy nhiều trong Organization hiện tại).

## DON'T

1. **KHÔNG** inject `IServiceProvider` vào constructor — đây là Service Locator anti-pattern:

   ```csharp
   // ❌ WRONG
   public class MyService(IServiceProvider sp)
   {
       var repo = sp.GetRequiredService<IDocumentRepository>();
   }
   // ✅ CORRECT
   public class MyService(IDocumentRepository repo) { }
   ```

2. **KHÔNG** đăng ký `DbContext` là Singleton — gây lỗi nghiêm trọng trong concurrent environment:

   ```csharp
   // ❌ WRONG
   services.AddSingleton<AppDbContext>();
   // ✅ CORRECT
   services.AddDbContext<AppDbContext>(options => ..., ServiceLifetime.Scoped);
   ```

3. **KHÔNG** đăng ký concrete class trực tiếp mà không có interface — khóa chặt dependency, khó test:

   ```csharp
   // ❌ WRONG
   services.AddScoped<DocumentService>();
   // ✅ CORRECT
   services.AddScoped<IDocumentService, DocumentService>();
   ```

4. **KHÔNG** để `Program.cs` phình to với hàng trăm dòng registration — tách hết vào module extensions.

5. **KHÔNG** inject Scoped service vào Singleton — gây captive dependency bug:

   ```csharp
   // ❌ WRONG — DbContext (Scoped) inject vào Singleton → lỗi
   public class CacheSingleton(AppDbContext db) { ... }
   // ✅ CORRECT — dùng IServiceScopeFactory nếu cần tạo scope thủ công
   public class CacheSingleton(IServiceScopeFactory factory) { ... }
   ```

6. **KHÔNG** dùng `new` trực tiếp để tạo service trong application code.

## Ví dụ minh họa

```csharp
// ── Program.cs (gọn)
var builder = WebApplication.CreateBuilder(args);

builder.Services
    .AddApplication()
    .AddInfrastructure(builder.Configuration)
    .AddApiServices();

var app = builder.Build();
app.Run();

// ── Application/DependencyInjection.cs
public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddMediator(options =>
        {
            options.Namespace = "{Namespace}.Application";
            options.ServiceLifetime = ServiceLifetime.Scoped;
        });

        services.AddValidatorsFromAssembly(typeof(CreateDocumentCommand).Assembly);

        services.AddSingleton(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>));
        services.AddSingleton(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));

        return services;
    }
}

// ── Infrastructure/DependencyInjection.cs
public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services, IConfiguration config)
    {
        // Database
        services.AddDbContext<AppDbContext>(opts =>
            opts.UseNpgsql(config.GetConnectionString("Postgres"),
                npgsql => npgsql.CommandTimeout(30)));

        // Outbox processor
        services.AddHostedService<OutboxProcessor>();

        // Redis cache
        services.AddStackExchangeRedisCache(opts =>
            opts.Configuration = config["Redis:ConnectionString"] ?? config.GetConnectionString("Redis"));

        return services;
    }
}
```
