# 01 - Clean Architecture Rules (Hybrid Vertical Slice + Clean Architecture)

> **Root concept**: Xem `docs/apply-vertical-slice-clean-architecture-dotnet-api.md` - Clean Architecture cho **biên giới dependency** + Vertical Slice cho **tổ chức feature/use-case** bên trong (đặc biệt Application/Features/...).

---

## DO

1. **Tuân thủ dependency rule tuyệt đối (Clean Architecture boundaries):**

    ```text
Domain <- Application <- Infrastructure <- API
    ```

   (xem chi tiết hybrid Vertical Slice + Clean Architecture tại `docs/apply-vertical-slice-clean-architecture-dotnet-api.md`)

   `Domain` và `Application` không được import bất kỳ package nào từ Infrastructure (EntityFrameworkCore, Dapper, event bus (MassTransit / RabbitMQ / ...), Polly...).

1. **Đặt Aggregate Root, Value Objects, Domain Events** vào `Domain` layer cho các bounded context cốt lõi (các bounded context cốt lõi của dự án).

3. **Folder & Namespace Convention (Vertical Slice trong Clean Architecture):**
   - Tổ chức theo **use-case/feature** (Vertical Slice) bên trong các layer biên giới CA.
   - Application: `Features/{Area}/Commands/{UseCase}Command/` (Command.cs + Validator + Handler + Response) hoặc `Features/{Area}/Queries/{UseCase}Query/` (Query.cs + Handler + Response + Mapping). File bắt buộc có hậu tố `Command` hoặc `Query`.
   - Domain: `Aggregates/{Aggregate}/` (entity + events + errors + strong ID value objects).
   - Ví dụ (module mẫu `Acme.Catalog` - thay bằng module thực tế của dự án):

    ```text
    Acme.Catalog.Domain/Aggregates/Products/Product.cs

    Acme.Catalog.Application/Features/Products/Commands/CreateProduct/CreateProductCommand.cs
    Acme.Catalog.Application/Features/Products/Commands/CreateProduct/CreateProductCommandHandler.cs
    Acme.Catalog.Application/Features/Products/Queries/GetProductById/GetProductByIdQueryHandler.cs

    Acme.Catalog.Infrastructure/Persistence/Configurations/ProductConfiguration.cs
    ```

   - File-scoped namespace, indent 4 spaces. Quy chuẩn coding convention chi tiết tại mục `7. **Code Style & Modern C# Naming**` tài liệu này.
   - Xem thêm: `docs/apply-vertical-slice-clean-architecture-dotnet-api.md` (sections 7-10: hybrid structure, checklists, worked examples).

4. Dùng `[Table]`, `[Column]` EF annotation trực tiếp trên Domain entity - dùng Fluent Configuration trong `Infrastructure` cho các cấu hình phức tạp, mapping phức tạp.

5. **Dùng CRUD đơn giản** (không có Aggregate Root, không có Value Object) cho các entity phụ trợ như Setting, Master Data.

6. **Áp dụng Architecture Test** (NetArchTest / ArchUnitNET) để enforce dependency rule trong CI pipeline (will be implemented).

7. **Mỗi bounded context** (ví dụ: Catalog, Ordering, Identity, Notification...) là một module/project riêng (Domain/Application/Infrastructure/Api), tự quản migration scripts riêng (xem `.ai-rules/14-database-rule.md`).

8. **Code Style & Modern C# Naming**: Full tables and .editorconfig live in the Tiêu chuẩn files. Enforce via root .editorconfig + PR review. Key excerpts:

| Thành phần | Kiểu Casing | Tiền tố / Hậu tố | Ví dụ |
|---|---|---|---|
| Namespace | PascalCase | - | Enterprise.BillingService.Core |
| Class/Record/Struct/Enum | PascalCase | - | InvoiceProcessor, PaymentStatus |
| Interface | PascalCase | `I` | IOrderRepository |
| Abstract Class | PascalCase | `Base` | ControllerRepositoryBase |
| Extension Class | PascalCase | `Extensions` | ByteArrayExtensions |
| Method | PascalCase | động từ / động từ-danh từ | CalculateDiscount, SaveInvoiceAsync |
| Property/Constant | PascalCase | - | CreatedAtUtc, MaxRetryAttempts |
| Local/Arg | camelCase | - | invoiceTotal, customerId |
| Private/Internal field | camelCase | `_` (hoặc `__` nội bộ) | `_logger`, `__dbContext` |
| Static field/const | PascalCase / UPPER_SNAKE | `s_` (nếu cần) | CacheInterval |

**Tên biến phải rõ nghĩa - không viết tắt, không tên chung chung**:

- Tên phải nói rõ *nó chứa gì*. Tránh tên vô nghĩa như `query`, `q`, `data`, `list`, `item`, `tmp`, `res`, `obj`, `val`, `dto`.
- Ghép danh từ nghiệp vụ với vai trò của biến - quy ước `<danhTừ><VaiTrò>`: `customerQuery`, `activeOrderList`, `latestInvoice`.

```csharp
// Đúng - biết ngay biến chứa gì
var customerQuery = repository.GetQueryable();
var activeOrderList = await customerQuery.Where(o => o.IsActive).ToListAsync();
var latestInvoice = invoices.FirstOrDefault(i => i.IsLatest);
var dtoLatestInvoice = invoices.FirstOrDefault(i => i.IsLatest);

// Sai - không biết đang chứa gì
var query = repository.GetQueryable();
var data = await q.Where(o => o.IsActive).ToListAsync();
var item = invoices.FirstOrDefault(i => i.IsLatest);
var dto = invoices.FirstOrDefault(i => i.IsLatest);
```

- Ngoại lệ: tên ngắn được chấp nhận khi phạm vi cực nhỏ và ý nghĩa hiển nhiên - biến vòng lặp (`i`, `j`), lambda param một dòng (`o => o.IsActive`).
- `result` được chấp nhận khi biến chứa đúng một `Result<T>` (idiom xử lý `Result` pattern); ngoài trường hợp đó, đặt tên theo giá trị nó chứa.

**Primary constructor (C# 12+)**: record -> params PascalCase (trở thành public props); class/struct -> params camelCase.

**C# 14**:

- Dùng `field` keyword cho property validation (tránh khai báo thủ công backing field).
- Dùng `extension(T t) { public X Prop => ...; }` thay vì static *Extensions helper class.

**Formatting (Allman, 4 spaces, 1 stmt/line)**:

- `{`/`}` dòng riêng, thẳng hàng.
- Bắt exception cụ thể + log.
- `// Comment` dòng riêng, viết hoa, kết `.`.
- `///` XML doc cho public/protected.
- Luôn dùng `var`. Dùng kiểu đích khi cần rõ ràng.
- Luôn dùng `string.Empty` thay vì `""`.

**Code comment**:

- **Ngôn ngữ**: Tiếng Việt cho tất cả comment giải thích nghiệp vụ.
- **Mục đích**: Comment giải thích **ý nghĩa nghiệp vụ** của hàm/block - không mô tả lại những gì code đã nói rõ bằng tên biến/hàm.
- **Mức độ**: Comment ở cấp hàm hoặc block logic quan trọng, không comment từng dòng.
- Comment = **tại sao** hoặc **ý nghĩa nghiệp vụ**, không phải **làm gì**.
- Một dòng rõ ràng đủ - không viết block comment nhiều đoạn.
- Khi nào cần comment
| Trường hợp | Ví dụ |
|---|---|
| Hàm xử lý nghiệp vụ phức tạp | Command handler, domain method có nhiều điều kiện |
| Business rule không hiển nhiên từ tên | Constraint, invariant ẩn, edge case đặc thù |
| Workaround / limitation kỹ thuật | EF Core quirk, outbox pattern, integration contract |
| Quyết định thiết kế cần giải thích | Tại sao không dùng cách A mà dùng cách B |
|API Action/Dto model dùng làm tài liêu OpenAPI | Giải thích ngắn gọn chức năng API, Giải thích các tham số, các Property |

- Khi nào KHÔNG comment

  - Tên hàm/property đã nói rõ mục đích (`GetStaffById`, `IsLocked`, `CreateStaff`).
  - CRUD đơn giản không có logic nghiệp vụ đặc biệt.
  - Code đã có test mô tả hành vi đầy đủ.
  - Comment chỉ nhắc lại tên hàm theo cách khác.

**Repository Pattern là optional (và thường không cần với EF Core).**

- Pattern khuyến nghị: abstraction `I*DbContext` (ví dụ `ICatalogDbContext`) expose từ module Infrastructure, kế thừa base DbContext của dự án + `ITransactionalDbContext` (nếu có).
- Handler inject `ICatalogDbContext` và dùng trực tiếp `DbSet` + `PrepareOutboxEvent` (cho Integration Events).
- Nếu cần abstraction cao hơn (testability / thay thế persistence) thì định nghĩa interface trong Application layer, impl trong Infrastructure.
- Outbox, interceptors, read-only context pattern nằm ở lớp Persistence chung (shared - nếu modular thì tách thành BuildingBlocks/Persistence; monolith thì đặt trong Infrastructure/Common).

## DON'T

1. **KHÔNG** để controller hoặc Infrastructure class nào kế thừa hoặc inject trực tiếp vào Domain entity.

2. **KHÔNG** để Domain layer tham chiếu `Microsoft.EntityFrameworkCore`, `event bus (MassTransit / RabbitMQ / ...)` hoặc bất kỳ framework infrastructure nào.

3. **KHÔNG** tạo "God Service" chứa logic của nhiều Aggregate khác nhau.

4. **KHÔNG** áp dụng full DDD (Aggregate Root, Domain Events, Specification) cho Setting/Master Data - đây là over-engineering.

## Ví dụ minh họa

```csharp
// -- Folder & Namespace Convention (Vertical Slice + CA)
// src/{Module}.Domain/Aggregates/{Aggregate}/
namespace Acme.Catalog.Domain.Aggregates.Products;

// src/{Module}.Application/Features/{Area}/{UseCase}/
namespace Acme.Catalog.Application.Features.Products.Commands.CreateProduct;

// Xem đầy đủ hybrid structure + checklists tại:
// docs/apply-vertical-slice-clean-architecture-dotnet-api.md
```

// WRONG - EF annotation trong Domain
public class {Entity} : AggregateRoot
{
    [Column("doc_title")]
    public string Title { get; set; }
}

// CORRECT - Domain entity thuần (Aggregate + strong ID + Result + Domain Event)
namespace Acme.Catalog.Domain.Aggregates.Products;

public sealed class Product : AggregateRoot<ProductId>
{
    // ... private fields, ctor EF + private
    public static Result<Product> Create(string name, string description, decimal price)
    {
        if (string.IsNullOrWhiteSpace(name)) return ProductErrors.NameEmpty;
        if (price <= 0) return ProductErrors.InvalidPrice;

        var p = new Product(ProductId.New(), name, description, price, DateTime.UtcNow);
        p.RaiseDomainEvent(new ProductCreatedDomainEvent(p.Id, p.Name, p.Price));
        return Result<Product>.Success(p);
    }
}

// CORRECT - Fluent config + value converter trong Infrastructure (snake_case, no annotations on Domain)
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
        // ... other props, no [Table]/[Column] trên entity Domain
    }
}

// CORRECT - Abstraction I*DbContext (thường dùng thay Repository) trong Application
// (module expose ICatalogDbContext : ITransactionalDbContext từ Infrastructure)
namespace Acme.Catalog.Application.Abstractions.Data;

public interface ICatalogDbContext : ITransactionalDbContext
{
    DbSet<Product> Products { get; }
    DbSet<OutboxEvent> OutboxEvents { get; }
    void PrepareOutboxEvent(OutboxEvent evt);   // cho Integration Events
}

// Handler dùng trực tiếp (không cần generic repo trừ khi thực sự cần thay thế persistence):
// var product = ...; dbContext.Products.Add(product); await dbContext.SaveChangesAsync(ct);

// Read-only context pattern (NoTracking, query tối ưu)
public interface IReadOnlyCatalogDbContext
{
    DbSet<Product> Products { get; }
}

```

```csharp
// Architecture Test (recommended - thêm project ArchitectureTests + chạy trong CI)
[Fact]
public void Domain_Should_Not_Reference_Infrastructure()
{
    var result = Types.InAssembly(typeof(Product).Assembly)
        .ShouldNot()
        .HaveDependencyOn("Acme.Catalog.Infrastructure")
        .GetResult();
    Assert.True(result.IsSuccessful);
}

// Tương tự kiểm tra Application chỉ reference Domain (+ shared layer nếu có).
// Hiện tại solution chưa có project ArchitectureTests riêng (xem vertical slice design doc checklist).
```
