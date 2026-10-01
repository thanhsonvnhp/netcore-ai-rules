# 10 - Dependency Injection & Service Registration Rules

---

## Mediator Library

The project uses **Mediator** (a source generator) + local adapters `ICommand` / `ICommand<T>` / `IQuery<T>` in the shared `Application.Shared.Abstractions.Messaging` namespace (or `{Company}.BuildingBlock.Application.Shared` when modular), implementing Mediator's `IRequest<Result>`.

Do **NOT use MediatR (Jimmy Bogard).**

---

## DO

1. **Organize registration by LAYERED context** with extension methods:

   ```csharp
   // Program.cs - calls module-level extensions only
   builder.Services
       .AddApplicationSServices(builder.Configuration)
       .AddInfrastructure(builder.Configuration)
       .AddApiServices();
   ```

2. **Each layer registers itself** through an `IServiceCollection` extension living in that layer:
   - `Application/DependencyInjection.cs` -> `AddApplicationSServices()`
   - `Infrastructure/DependencyInjection.cs` -> `AddInfrastructure()`
   - `Api/DependencyInjection.cs` -> `AddApiServices()`

3. **Pick the right service lifetime:**

   | Lifetime | Use when | Example |
   |---|---|---|
   | `Singleton` | Stateless, thread-safe, expensive to initialize | `IMemoryCache`, config options |
   | `Scoped` | Bound to an HTTP request, has per-request state | `DbContext`, `ICurrentUser`, `ITenantContext` |
   | `Transient` | Lightweight, stateless, not shared | Simple calculators, validators |

4. **Turn on container validation at startup** so misconfigurations surface immediately:

   ```csharp
   builder.Host.UseDefaultServiceProvider((ctx, opts) =>
   {
       opts.ValidateScopes  = ctx.HostingEnvironment.IsDevelopment();
       opts.ValidateOnBuild = ctx.HostingEnvironment.IsDevelopment();
   });
   ```

5. **Register Mediator and FluentValidation by assembly scan (actual):**

   ```csharp
   services.AddMediator(options =>
   {
       options.Namespace = "Acme.Catalog.Application"; // e.g. sample Catalog module - use the project's real namespace
       options.ServiceLifetime = ServiceLifetime.Scoped;
   });
   services.AddValidatorsFromAssembly(Assembly.GetExecutingAssembly());

   services.AddSingleton(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>));
   services.AddScoped(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));   // Scoped because IValidator is scoped
   services.AddSingleton(typeof(IPipelineBehavior<,>), typeof(IntegrationEventPublishBehavior<,>));
   services.AddScoped(typeof(IPipelineBehavior<,>), typeof(TransactionBehavior<,>)); // for ICommand

   services.AddScoped<IIntegrationEventCollector, IntegrationEventCollector>();
   ```

6. **Keyed Services** (.NET 8+) may be used when multiple implementations of one interface are needed.

## DON'T

1. Do **NOT** inject `IServiceProvider` into a constructor - that is the Service Locator anti-pattern:

   ```csharp
   // [FAIL] WRONG
   public class MyService(IServiceProvider sp)
   {
       var repo = sp.GetRequiredService<IDocumentRepository>();
   }
   // [OK] CORRECT
   public class MyService(IDocumentRepository repo) { }
   ```

2. Do **NOT** register a `DbContext` as Singleton - it causes serious failures in concurrent environments:

   ```csharp
   // [FAIL] WRONG
   services.AddSingleton<AppDbContext>();
   // [OK] CORRECT
   services.AddDbContext<AppDbContext>(options => ..., ServiceLifetime.Scoped);
   ```

3. Do **NOT** register a concrete class directly without an interface - the dependency becomes locked in and hard to test:

   ```csharp
   // [FAIL] WRONG
   services.AddScoped<DocumentService>();
   // [OK] CORRECT
   services.AddScoped<IDocumentService, DocumentService>();
   ```

4. Do **NOT** let `Program.cs` bloat with hundreds of registration lines - move everything into module extensions.

5. Do **NOT** inject a Scoped service into a Singleton - it causes the captive dependency bug:

   ```csharp
   // [FAIL] WRONG - a Scoped DbContext injected into a Singleton -> broken
   public class CacheSingleton(AppDbContext db) { ... }
   // [OK] CORRECT - use IServiceScopeFactory when a manual scope is needed
   public class CacheSingleton(IServiceScopeFactory factory) { ... }
   ```

6. Do **NOT** call `new` directly to create a service in application code.

## Illustrative example

```csharp
// -- Program.cs (lean)
var builder = WebApplication.CreateBuilder(args);

builder.Services
    .AddApplication()
    .AddInfrastructure(builder.Configuration)
    .AddApiServices();

var app = builder.Build();
app.Run();

// -- Application/DependencyInjection.cs
public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddMediator(options =>
        {
            options.Namespace = "{Company}.{Module}.Application";
            options.ServiceLifetime = ServiceLifetime.Scoped;
        });

        services.AddValidatorsFromAssembly(typeof(CreateDocumentCommand).Assembly);

        services.AddSingleton(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>));
        services.AddScoped(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>)); // Scoped - must match IValidator's lifetime (see section 5 above)

        return services;
    }
}

// -- Infrastructure/DependencyInjection.cs
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
