# 07 - Testing Strategy Rules

---

## DO

1. **Unit Test coverage**:
   - Domain entity methods and invariants
   - Value Object creation and validation
   - Domain Event raising
   - FluentValidation validators
   No DB mocking needed - Domain has no DB dependency.

2. **Integration Test** runs against PostgreSQL in Testcontainers-dotnet:

   ```csharp
   var postgres = new PostgreSqlBuilder("18-alpine")
       .WithImage("postgres:18-alpine")
       .Build();
   await postgres.StartAsync();
   ```

3. **Architecture Test** (add when the project needs it): create a dedicated project `{Company}.{Module}.ArchitectureTests` (or top-level) using NetArchTest/ArchUnitNET to enforce that Domain does not reference Infrastructure, Application only references Domain, etc.

4. **Contract Test** for events: verify the schema (Pact or snapshot) - apply once the bus is enabled and real consumers exist.

5. **Real per-module test structure**:

   ```
   {Company}.{Module}.UnitTests/
     Domain/ (ProductTests, ResultTests - no DB needed)
     Application/ (handler tests with fakes)
   {Company}.{Module}.IntegrationTests/
     Infrastructure/ (WebAppFactory)
     Products/ (endpoint tests - Testcontainers postgres)
   ```

   UnitTests reference only Domain + Application (never Infrastructure). Integration tests use a real DB (Testcontainers), cleaned up after each test (transaction rollback or container reset).

6. **Every Integration Test** must clean up the DB after it runs:
   - Transaction rollback: `await using var tx = await db.BeginTransactionAsync()` -> `await tx.RollbackAsync()`
   - Or reset the container after each test class.

## DON'T

1. Do **NOT** use `UseInMemoryDatabase()` for real Integration Tests (reserve it for specific Persistence/Base unit tests when needed; InMemory lacks full transaction support, jsonb, etc.).

2. Do **NOT** mock `DbContext` in Integration Tests - use a real DB (Testcontainers).

3. Do **NOT** put business/domain logic tests inside Integration Tests.

4. Do **NOT** skip Architecture Tests (add a project to enforce CA rules).

5. Do **NOT** share state between tests (no shared static state; clean up the DB after every test/class).

6. Do **NOT** reference Infrastructure from Unit Tests (Domain + Application only).

## Illustrative example

```csharp
// -- Architecture Test
[Fact]
public void Domain_Should_Not_Reference_Infrastructure()
{
    var result = Types.InAssembly(typeof(Document).Assembly)
        .ShouldNot()
        .HaveDependencyOn("Infrastructure")
        .GetResult();

    Assert.True(result.IsSuccessful);
}

// -- Unit Test - Domain logic needs no DB
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

// -- Integration Test - uses Testcontainers
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
