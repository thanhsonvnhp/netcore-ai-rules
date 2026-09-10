# 07 – Testing Strategy Rules

---

## DO

1. **Unit Test** bao phủ:
   - Domain entity methods và invariants
   - Value Object creation và validation
   - Domain Event raising
   - FluentValidation validators
   Không cần mock DB — Domain không phụ thuộc DB.

2. **Integration Test** chạy với PostgreSQL  trong Testcontainers-dotnet:

   ```csharp
   var postgres = new PostgreSqlBuilder("18-alpine")
       .WithImage("postgres:18-alpine")
       .Build();
   await postgres.StartAsync();
   ```

3. **Architecture Test** (Will be implemented): Tạo project riêng `SmartOffice.Organization.ArchitectureTests` (hoặc top-level) dùng NetArchTest/ArchUnitNET để enforce Domain không reference Infrastructure, Application chỉ reference Domain, v.v. (xem checklist trong `docs/Apply Vertical Slice in Clean Architecture .NET API.md`).

4. **Contract Test** cho event: verify schema (Pact hoặc snapshot) — áp dụng khi bus re-enable và có consumers thực.

5. **Cấu trúc test thực tế (per-module)**:

   ```
   SmartOffice.Organization.UnitTests/
     Domain/ (ProductTests, ResultTests — không cần DB)
     Application/ (handler tests với fakes)
   SmartOffice.Organization.IntegrationTests/
     Infrastructure/ (WebAppFactory)
     Products/ (endpoint tests — Testcontainers postgres)
   ```

   UnitTests chỉ reference Domain + Application (không Infrastructure). Integration dùng DB thật (Testcontainers), clean sau test (tx rollback hoặc reset container).

6. **Mỗi Integration Test** phải clean up DB sau khi chạy:
   - Dùng transaction rollback: `await using var tx = await db.BeginTransactionAsync()` -> `await tx.RollbackAsync()`
   - Hoặc reset container sau mỗi test class.

## DON'T

1. **KHÔNG** dùng `UseInMemoryDatabase()` cho Integration Test thực (chỉ dùng cho một số unit test đặc biệt của Persistence/Base nếu cần; InMemory thiếu transaction đầy đủ, jsonb, v.v.).

2. **KHÔNG** mock `DbContext` trong Integration Test — dùng DB thật (Testcontainers).

3. **KHÔNG** đặt business/domain logic test vào Integration Test.

4. **KHÔNG** bỏ qua Architecture Test (nên thêm project để enforce CA rules).

5. **KHÔNG** chia sẻ state giữa tests (không shared static, cleanup DB sau mỗi test/class).

6. **KHÔNG** reference Infrastructure trong Unit Tests (chỉ Domain + Application).

## Ví dụ minh họa

```csharp
// ── Architecture Test
[Fact]
public void Domain_Should_Not_Reference_Infrastructure()
{
    var result = Types.InAssembly(typeof(Document).Assembly)
        .ShouldNot()
        .HaveDependencyOn("Infrastructure")
        .GetResult();

    Assert.True(result.IsSuccessful);
}

// ── Unit Test — Domain logic không cần DB
[Fact]
public void Document_Publish_Should_Raise_DocumentPublishedEvent()
{
    // Arrange
    var tenantId = TenantId.New();
    var doc = Document.Create(DocumentTitle.Create("Test Doc"), tenantId);

    // Act
    var result = doc.Publish(publishedBy: UserId.New());

    // Assert
    result.IsSuccess.Should().BeTrue();
    var publishedEvent = doc.DomainEvents.OfType<DocumentPublishedEvent>().Single();
    Assert.Equal(doc.Id, publishedEvent.DocumentId);
}

// ── Integration Test — dùng Testcontainers
public class CreateDocumentTests : IAsyncLifetime
{
    private PostgreSqlContainer _postgres = null!;

    public async Task InitializeAsync()
    {
        _postgres = new PostgreSqlBuilder()
            .WithImage("postgres:18-alpine")
            .Build();
        await _postgres.StartAsync();
    }

    public async Task DisposeAsync() => await _postgres.DisposeAsync();

    [Fact]
    public async Task CreateDocument_Should_Persist_To_Database()
    {
        await using var tx = await _db.BeginTransactionAsync();
        // ... test logic ...
    }
}
```
