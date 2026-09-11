# 02 - CQRS Pattern Rules

## Mediator

The project uses `Mediator` source generator packages:

```xml
<PackageVersion Include="Mediator.SourceGenerator" Version="3.0.2" />
<PackageVersion Include="Mediator.Abstractions" Version="3.0.2" />
```

Use local messaging abstractions from `Application.Shared` hoặc `{Company}.BuildingBlock.Application.Shared` (nếu modular) to wrap Mediator request types and return:

* `Result`
* `Result<T>`
* `ResultPaged<T>`

This is base warapping for `IRequest<Result>` and `IRequest<Result<T>>` to avoid direct dependency on MediatR in the application layer:

```csharp
public interface ICommand : IRequest<Result> { }

public interface ICommand<out TResponse> : IRequest<Result<TResponse>> { }

public interface IQuery<out TResponse> : IRequest<Result<TResponse>> { }

public interface IQueryPaging<TResponse> : IRequest<ResultPaged<TResponse>>
{
    long PageNumber { get; }
    long PageSize { get; }
}
```

Do not use MediatR.

---

## CQRS Decision Matrix

| Operation    | Implementation                                 | Rule                                                 |
| ------------ | ---------------------------------------------- | ---------------------------------------------------- |
| Create       | EF Core with Change Tracking                   | Use handler and domain factory/method                |
| Update       | EF Core with Change Tracking                   | Load aggregate, call domain method, save changes     |
| Delete       | EF Core with Change Tracking                   | Use domain method; prefer soft delete when supported |
| Simple read  | EF Core ReadOnlyDbContext                      | Use `AsNoTracking()` and map to DTO                  |
| Complex read | EF Core LINQ projection or PostgreSQL function | Project directly to DTO                              |

---

## Vertical Slice Structure

Each API endpoint or use case has its own feature folder:

```text
Features/{Area}/Commands/{UseCase}Command/
Features/{Area}/Queries/{UseCase}Query/
```

Use this file structure:

```text
Features/Product/Commands/CreateProductCommand/
  CreateProductCommand.cs
  CreateProductCommandValidator.cs
  CreateProductCommandHandler.cs
  CreateProductResponse.cs
Features/Product/Queries/FilterProductQuery/
  FilterProductQuery.cs
  FilterProductQueryValidator.cs
  FilterProductQueryHandler.cs
  FilterProductResponse.cs
```

**Naming rule**: All command record files MUST end with `Command` (e.g., `CreateProductCommand.cs`). All query record files MUST end with `Query` (e.g., `FilterProductQuery.cs`). Validator and Handler files follow the same stem: `{UseCase}CommandValidator.cs`, `{UseCase}CommandHandler.cs`, `{UseCase}QueryHandler.cs`.

Use `Command` for write use cases.

Use `Query` for read use cases.

Do not share one handler between different use cases.

---

## Pipeline Behaviors

The application pipeline contains these behaviors:

| Behavior                          | Lifetime  | Scope                                              |
| --------------------------------- | --------- | -------------------------------------------------- |
| `LoggingBehavior`                 | Singleton | All requests                                       |
| `ValidationBehavior`              | Scoped    | FluentValidation input validation                  |
| `IntegrationEventPublishBehavior` | Singleton | Publish integration events after handler execution |
| `TransactionBehavior`             | Scoped    | Commands only                                      |

Effective execution order:

```text
Logging
-> Validation
-> IntegrationEventPublish
-> Transaction
-> Handler
```

`TransactionBehavior` controls transaction begin, commit, and rollback for commands.

`IntegrationEventPublishBehavior` publishes integration events after transaction commit.

Handlers do not create explicit transactions in standard command flows.

---

## Command Rules

Command handlers use EF Core with Change Tracking.

Command handlers follow this flow:

```text
Input validation by pipeline
-> Domain factory/method
-> Domain event raised by aggregate
-> Add or update aggregate
-> SaveChangesAsync
-> Domain events harvested by interceptor
-> Outbox event prepared
-> Integration event collected when required
-> Transaction committed by pipeline
-> Integration event published by pipeline
```

Rules:

* Use domain factory or domain method for business operations.
* Use EF Core DbContext for writes.
* Call `SaveChangesAsync(ct)` inside the handler.
* Add integration events to `IIntegrationEventCollector` when required.
* Prepare outbox events in the same transaction.
* Keep `CancellationToken` as the last handler parameter.
* Inject and use ILogger<> to log process to ELK telemetry

---

## Query Rules

Simple query handlers use EF Core read context:

```text
ReadOnlyDbContext
-> AsNoTracking()
-> Filter
-> Project or map to response DTO
-> Return Result<TResponse>
```

Complex query handlers use direct DTO projection:

```text
EF Core LINQ projection
or
PostgreSQL function
-> DTO
-> Return Result<TResponse>
```

Rules:

* Query handlers return response DTOs.
* Query handlers do not return domain aggregates.
* Query handlers do not call domain repositories.
* Query handlers do not use long `Include()` chains.
* Query handlers use projection instead of loading full aggregate graphs.

---

## Validation Rules

FluentValidation validates input shape only:

* Required fields
* Length
* Format
* Range
* Enum value
* Cross-field input consistency

Domain entities enforce business rules.

Business validation examples that belong in domain logic:

* A published document cannot be modified.
* A deleted aggregate cannot be updated.
* A workflow transition is not allowed from the current state.

---

## Pagination

Use the standard pagination result model:

```csharp
public record PagedResult<T>(
    IReadOnlyList<T> Items,
    int TotalCount,
    int PageNumber,
    int PageSize);
```

Paged query handlers return `ResultPaged<T>` when the project abstraction requires it.

---

## Restrictions

Do not use MediatR.

Do not use raw SQL in command handlers.

Do not use Dapper for write operations.

Do not place business rules in FluentValidation validators.

Do not query domain repositories from query handlers.

Do not map domain aggregates manually after loading large object graphs.

Do not share handlers between different use cases.

Do not make Dapper or stored procedures mandatory for read paths.

Do not use long EF Core `Include()` chains in query handlers.

---

## Command Example

```csharp
public sealed record CreateProductCommand(
    string Name,
    string Description,
    decimal Price)
    : ICommand<ProductId>;

internal sealed class CreateProductCommandHandler(
    IOrganizationDbContext dbContext,
    IIntegrationEventCollector integrationEventCollector,
    ILogger<CreateProductCommandHandler> logger)
    : ICommandHandler<CreateProductCommand, ProductId>
{
    public async ValueTask<Result<ProductId>> Handle(
        CreateProductCommand command,
        CancellationToken ct)
    {
        var result = Product.Create(
            command.Name,
            command.Description,
            command.Price);

        if (result.IsFailure)
        {
            return Result<ProductId>.Failure(result.Error);
        }

        var product = result.Value;

        dbContext.Products.Add(product);

        await dbContext.SaveChangesAsync(ct);

        var integrationEvent = new ProductCreatedIntegrationEvent(
            product.Id.Value,
            product.Name,
            product.Price);

        integrationEventCollector.Add(integrationEvent);

        foreach (var evt in integrationEventCollector.Events)
        {
            dbContext.PrepareOutboxEvent(new OutboxEvent
            {
                // Populate from integration event
            });
        }

        integrationEventCollector.Clear();

        if (dbContext.OutboxEvents.Local.Any())
        {
            await dbContext.SaveChangesAsync(ct);
        }

        return Result<ProductId>.Success(product.Id);
    }
}
```

---

## Query Example

### Simple Query

```csharp
public sealed record GetProductByIdQuery(Guid ProductId)
    : IQuery<GetProductByIdResponse>;

internal sealed class GetProductByIdQueryHandler(
    IOrganizationDbContext dbContext)
    : IQueryHandler<GetProductByIdQuery, GetProductByIdResponse>
{
    public async ValueTask<Result<GetProductByIdResponse>> Handle(
        GetProductByIdQuery query,
        CancellationToken ct)
    {
        var product = await dbContext.Products
            .AsNoTracking()
            .FirstOrDefaultAsync(
                p => p.Id == new ProductId(query.ProductId),
                ct);

        if (product is null)
        {
            return ProductErrors.NotFound;
        }

        return product.ToResponse();
    }
}
```

### Paging Query

```csharp
public sealed record GetProductsQuery(long Page, long PageSize)
    : IQueryPaging<GetProductItemResponse>;

internal sealed class GetProductsQueryHandler(
    IOrganizationReadOnlyDbContext dbContext)
    : IQueryHandler<GetProductsQuery, ResultPaged<GetProductItemResponse>>
{
    public async ValueTask<ResultPaged<GetProductItemResponse>> Handle(
        GetProductsQuery query,
        CancellationToken ct)
    {
        var baseQuery = dbContext.Products
            // .Where(x => .....) // Lamda filter
            .OrderByDescending(x => x.CreatedAt);

        var itemsQuery = await baseQuery
            .Select(p => new GetProductItemResponse(
                p.Id.Value,
                p.Name,
                p.Price));

        return ResultPaged<GetProductItemResponse>.ToPageResult(
            query.PageNumber, query.PageSize, cancellationToken);
    }
}
```

---

## Related Documents

* `docs/apply-vertical-slice-clean-architecture-dotnet-api.md`
* `docs/entity-domain-and-outbox-event.md`
* `docs/13-background-jobs.md`
