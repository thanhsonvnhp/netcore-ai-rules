# 01 - Clean Architecture Rules (Hybrid Vertical Slice + Clean Architecture)

> **Root concept**: See `docs/apply-vertical-slice-clean-architecture-dotnet-api.md` - Clean Architecture for the **dependency boundary** + Vertical Slice for **feature/use-case organization** inside it (especially `Application/Features/...`).

---

## DO

1. **Follow the dependency rule absolutely (Clean Architecture boundaries):**

    ```text
Domain <- Application <- Infrastructure <- API
    ```

   (see the hybrid Vertical Slice + Clean Architecture detail in `docs/apply-vertical-slice-clean-architecture-dotnet-api.md`)

   `Domain` and `Application` must not import any package from Infrastructure (EntityFrameworkCore, Dapper, an event bus (MassTransit / RabbitMQ / ...), Polly...).

1. **Place the Aggregate Root, Value Objects, and Domain Events** in the `Domain` layer for the project's core bounded contexts.

3. **Folder & Namespace Convention (Vertical Slice inside Clean Architecture):**
   - Organize by **use-case/feature** (Vertical Slice) inside the CA boundary layers.
   - Application: `Features/{Area}/Commands/{UseCase}Command/` (Command.cs + Validator + Handler + Response) or `Features/{Area}/Queries/{UseCase}Query/` (Query.cs + Handler + Response + Mapping). The file name must have the `Command` or `Query` suffix.
   - Domain: `Aggregates/{Aggregate}/` (entity + events + errors + strong ID value objects).
   - Example (sample module `Acme.Catalog` - replace with the project's real module):

    ```text
    Acme.Catalog.Domain/Aggregates/Products/Product.cs

    Acme.Catalog.Application/Features/Products/Commands/CreateProduct/CreateProductCommand.cs
    Acme.Catalog.Application/Features/Products/Commands/CreateProduct/CreateProductCommandHandler.cs
    Acme.Catalog.Application/Features/Products/Queries/GetProductById/GetProductByIdQueryHandler.cs

    Acme.Catalog.Infrastructure/Persistence/Configurations/ProductConfiguration.cs
    ```

   - File-scoped namespace, 4-space indent. Detailed coding conventions are in section `7. **Code Style & Modern C# Naming**` of this file.
   - See also: `docs/apply-vertical-slice-clean-architecture-dotnet-api.md` (sections 7-10: hybrid structure, checklists, worked examples).

4. Use `[Table]`/`[Column]` EF annotations directly on a Domain entity only for simple cases - use Fluent Configuration in `Infrastructure` for complex configuration/mapping.

5. **Use simple CRUD** (no Aggregate Root, no Value Object) for supporting entities such as Setting or Master Data.

6. **Apply an Architecture Test** (NetArchTest / ArchUnitNET) to enforce the dependency rule in the CI pipeline (add when the project needs it).

7. **Each bounded context** (for example Catalog, Ordering, Identity, Notification...) is its own module/project (Domain/Application/Infrastructure/Api) that owns its migration scripts (see `.ai-rules/14-database-rule.md`).

8. **Code Style & Modern C# Naming**: full tables and `.editorconfig` live in the project's own standards file (see `docs/backend-coding-standard.md` when the project has one). Enforce via the root `.editorconfig` + PR review. Key excerpts:

| Element | Casing | Prefix / Suffix | Example |
|---|---|---|---|
| Namespace | PascalCase | - | Enterprise.BillingService.Core |
| Class/Record/Struct/Enum | PascalCase | - | InvoiceProcessor, PaymentStatus |
| Interface | PascalCase | `I` | IOrderRepository |
| Abstract Class | PascalCase | `Base` | ControllerRepositoryBase |
| Extension Class | PascalCase | `Extensions` | ByteArrayExtensions |
| Method | PascalCase | verb / verb-noun | CalculateDiscount, SaveInvoiceAsync |
| Property/Constant | PascalCase | - | CreatedAtUtc, MaxRetryAttempts |
| Local/Arg | camelCase | - | invoiceTotal, customerId |
| Private/Internal field | camelCase | `_` (or `__` for internal use) | `_logger`, `__dbContext` |
| Static field/const | PascalCase / UPPER_SNAKE | `s_` (when needed) | CacheInterval |

**Variable names must be meaningful - no abbreviations, no generic names**:

- A name must say *what it holds*. Avoid meaningless names like `query`, `q`, `data`, `list`, `item`, `tmp`, `res`, `obj`, `val`, `dto`.
- Combine the business noun with the variable's role - the `<businessNoun><Role>` convention: `customerQuery`, `activeOrderList`, `latestInvoice`.

```csharp
// Correct - the name says exactly what it holds
var customerQuery = repository.GetQueryable();
var activeOrderList = await customerQuery.Where(o => o.IsActive).ToListAsync();
var latestInvoice = invoices.FirstOrDefault(i => i.IsLatest);
var dtoLatestInvoice = invoices.FirstOrDefault(i => i.IsLatest);

// Wrong - no idea what these hold
var query = repository.GetQueryable();
var data = await q.Where(o => o.IsActive).ToListAsync();
var item = invoices.FirstOrDefault(i => i.IsLatest);
var dto = invoices.FirstOrDefault(i => i.IsLatest);
```

- Exception: short names are fine for a tiny, obvious scope - a loop variable (`i`, `j`), a one-line lambda param (`o => o.IsActive`).
- `result` is acceptable when the variable holds exactly one `Result<T>` (the idiomatic Result-pattern name); otherwise name it after the value it holds.

**Primary constructor (C# 12+)**: for a `record` -> PascalCase params (become public props); for a `class`/`struct` -> camelCase params.

**C# 14**:

- Use the `field` keyword for property validation (avoid manually declaring a backing field).
- Use `extension(T t) { public X Prop => ...; }` instead of a static `*Extensions` helper class.

**Formatting (Allman, 4 spaces, 1 statement/line)**:

- `{`/`}` on their own line, aligned.
- Catch specific exceptions + log.
- `// Comment` on its own line, capitalized, ends with `.`.
- `///` XML doc for public/protected members.
- Always use `var`. Use an explicit target type when it improves clarity.
- Always use `string.Empty` instead of `""`.

**Code comments**: follow `16-code-comments.md` in full - do not duplicate that content here.

**Repository Pattern is optional (and usually unnecessary with EF Core).**

- Recommended pattern: an `I*DbContext` abstraction (for example `ICatalogDbContext`) exposed from the module's Infrastructure, inheriting the project's base DbContext + `ITransactionalDbContext` (when it has one).
- A handler injects `ICatalogDbContext` and uses the `DbSet` + `PrepareOutboxEvent` (for Integration Events) directly.
- When a higher abstraction is actually needed (testability / swapping persistence), define the interface in the Application layer and implement it in Infrastructure.
- Outbox, interceptors, and the read-only context pattern live in the shared Persistence layer (a separate BuildingBlocks/Persistence project when modular; under Infrastructure/Common for a monolith).

## DON'T

1. Do **NOT** let a controller or any Infrastructure class inherit from or inject directly into a Domain entity.

2. Do **NOT** let the Domain layer reference `Microsoft.EntityFrameworkCore`, an event bus (MassTransit / RabbitMQ / ...), or any infrastructure framework.

3. Do **NOT** create a "God Service" that holds logic for multiple different Aggregates.

4. Do **NOT** apply full DDD (Aggregate Root, Domain Events, Specification) to Setting/Master Data - that is over-engineering.

## Illustrative example

```csharp
// -- Folder & Namespace Convention (Vertical Slice + CA)
// src/{Module}.Domain/Aggregates/{Aggregate}/
namespace Acme.Catalog.Domain.Aggregates.Products;

// src/{Module}.Application/Features/{Area}/{UseCase}/
namespace Acme.Catalog.Application.Features.Products.Commands.CreateProduct;

// See the full hybrid structure + checklists in:
// docs/apply-vertical-slice-clean-architecture-dotnet-api.md
```

// WRONG - EF annotation on a Domain entity
public class {Entity} : AggregateRoot
{
    [Column("doc_title")]
    public string Title { get; set; }
}

// CORRECT - a pure Domain entity (Aggregate + strong ID + Result + Domain Event)
namespace Acme.Catalog.Domain.Aggregates.Products;

public sealed class Product : AggregateRoot<ProductId>
{
    // ... private fields, EF ctor + private ctor
    public static Result<Product> Create(string name, string description, decimal price)
    {
        if (string.IsNullOrWhiteSpace(name)) return ProductErrors.NameEmpty;
        if (price <= 0) return ProductErrors.InvalidPrice;

        var p = new Product(ProductId.New(), name, description, price, DateTime.UtcNow);
        p.RaiseDomainEvent(new ProductCreatedDomainEvent(p.Id, p.Name, p.Price));
        return Result<Product>.Success(p);
    }
}

// CORRECT - Fluent config + value converter in Infrastructure (snake_case, no annotations on the Domain entity)
namespace Acme.Catalog.Infrastructure.Persistence.Configurations;

internal sealed class ProductConfiguration : IEntityTypeConfiguration<Product>
{
    public void Configure(EntityTypeBuilder<Product> builder)
    {
        builder.ToTable("products");
        builder.HasKey(p => p.Id);
        builder.Property(p => p.Id)
               .HasConversion(id => id.Value, v => new ProductId(v))
               .HasColumnName("id");
        // ... other props, no [Table]/[Column] on the Domain entity
    }
}

// CORRECT - I*DbContext abstraction (usually replaces a Repository) in Application
// (the module exposes ICatalogDbContext : ITransactionalDbContext from Infrastructure)
namespace Acme.Catalog.Application.Abstractions.Data;

public interface ICatalogDbContext : ITransactionalDbContext
{
    DbSet<Product> Products { get; }
    DbSet<OutboxEvent> OutboxEvents { get; }
    void PrepareOutboxEvent(OutboxEvent evt);   // for Integration Events
}

// A handler uses it directly (no need for a generic repo unless swapping persistence is a real requirement):
// var product = ...; dbContext.Products.Add(product); await dbContext.SaveChangesAsync(ct);

// Read-only context pattern (NoTracking, optimized queries)
public interface IReadOnlyCatalogDbContext
{
    DbSet<Product> Products { get; }
}

```

```csharp
// Architecture Test (recommended - add an ArchitectureTests project and run it in CI)
[Fact]
public void Domain_Should_Not_Reference_Infrastructure()
{
    var result = Types.InAssembly(typeof(Product).Assembly)
        .ShouldNot()
        .HaveDependencyOn("Acme.Catalog.Infrastructure")
        .GetResult();
    Assert.True(result.IsSuccessful);
}

// Similarly check that Application references only Domain (+ a shared layer when there is one).
// Put these tests in a dedicated project `{Company}.ArchitectureTests` (see the vertical slice design doc checklist).
```
