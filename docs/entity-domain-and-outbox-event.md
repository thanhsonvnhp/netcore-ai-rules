# Sự kiện Miền, Sự kiện Tích hợp và Mô hình OutboxEvent Giao dịch

> Tài liệu này mô tả cách tách Domain Event / Integration Event và dùng OutboxEvent để đảm bảo publish bền vững cùng transaction (outbox-first).
> Đọc khi cần hiểu flow buffer → flush → commit → publish sau commit trong BaseDbContext.

**Phạm vi**: Persistence Building Block + các contract Application + cách sử dụng trong module. Xem AGENTS.md phần Event Bus (hiện đang outbox-first).

## 1. Mục đích và Các đảm bảo

Mục tiêu là giải quyết vấn đề dual-write khi phát thông báo vượt ranh giới dịch vụ, đồng thời giữ Domain thuần khiết và tách biệt rõ hai loại sự kiện:

- **Domain Event**: phản ứng nội bộ trong tiến trình (in-process), có thể tham gia cùng transaction.
- **Integration Event**: ý định xuất bản ra message broker (Kafka/Rabbit) cho service khác hoặc hệ thống ngoài.

**Đảm bảo then chốt**:
- Nếu commit nghiệp vụ thành công thì bản ghi bền vững (OutboxEvent row) đã được ghi cùng transaction.
- Publish là best-effort (khi bus được đăng ký) hoặc được relay (tương lai) xử lý sau.
- Không captive dependency (interceptor/behavior dùng GetService "nếu có thì").
- Domain chỉ raise sự kiện; không biết outbox hay broker.

## 2. Ba khái niệm cốt lõi

### 2.1 IDomainEvent ({Company}.BuildingBlocks.Domain.Shared.Primitives)
Sự kiện quan trọng đã xảy ra bên trong mô hình miền, diễn đạt bằng ngôn ngữ nghiệp vụ (ubiquitous language). Chỉ nội bộ bounded context.

**Đặc điểm**:
- Interface marker có metadata: `OccurredOnUtc?`, `EntityType`, `EventType`, `CorrelationId?`.
- Chỉ AggregateRoot/Entity được phép gọi `RaiseDomainEvent` (protected method trong `Entity<TId>`).
- Tồn tại chỉ trong bộ nhớ (private List), bị `OutboxDomainEventInterceptor` harvest rồi clear, bị EF Core bỏ qua (NotMapped + explicit Ignore trong `OnModelCreating` của Base).
- Harvest tự động trong `SavingChanges` / `SavingChangesAsync`.

Ví dụ (Domain):
```csharp
public sealed record class ProductCreatedDomainEvent(
    ProductId ProductId, string Name, decimal Price, string? CorrelationId = null)
    : IDomainEvent
{
    public DateTime? OccurredOnUtc => DateTime.UtcNow;
    public string EventType => nameof(ProductCreatedDomainEvent);
    public string EntityType => nameof(Product);
}
```

### 2.2 IIntegrationEvent (Application.Abstractions.Events)
Sự kiện/hợp đồng được xuất bản ra broker để các thành phần bên ngoài phản ứng.

**Tính linh hoạt**:
- 1 Domain Event → 0, 1 hoặc N Integration Event (fan-out).
- Có thể chỉ có Integration Event mà không có Domain Event tương ứng ("chủ động build").
- Được xây dựng hoặc nội suy từ Domain Event trong Application layer.

**Đặc điểm**:
- Plain record/POCO, chỉ implement marker rỗng `IIntegrationEvent`.
- Không được raise trên entity.
- Thu thập qua `IIntegrationEventCollector` (Scoped).
- Hiện tại được chuẩn bị thủ công thành OutboxEvent row (sau SaveChanges) để đảm bảo độ bền.

### 2.3 OutboxEvent ({Company}.BuildingBlocks.Persistence.Outbox)
Bản ghi bền vững của "ý định publish", được ghi vào DB **cùng transaction** với dữ liệu nghiệp vụ qua buffer + flush của BaseDbContext.

**Cấu trúc bảng** (DbUp, schema theo module, ví dụ `{schema}.outbox_events`):
- `id`, `occurred_on_utc`, `entity_type`, `event_type`, `payload` (jsonb), `payload_event_type`, `error`, `processed_on_utc`, `correlation_id`.
- Đầy đủ cột audit (`IAuditable`) + `row_version` để thống nhất với các bảng khác.
- Chỉ số: `ix_outbox_events_processed_on_utc`, `ix_outbox_events_occurred_on_utc`.

**Mục đích**:
- Đảm bảo ý định publish sống sót qua crash, restart, scale.
- Relay (chưa triển khai) sẽ đọc các row chưa xử lý, deserialize (dựa `EventType`/`PayloadEventType`), gọi `IMessagePublisher`, đánh dấu `ProcessedOnUtc`.

Hiện tại OutboxEvent được dùng cho cả Domain Event (harvest tự động) lẫn Integration Event (chuẩn bị thủ công).

## 3. Phát hành, Harvest và Buffer

- **Phát hành**: Chỉ aggregate gọi `RaiseDomainEvent` (ví dụ trong `Product.Create`).
- **Harvest**: `OutboxDomainEventInterceptor` (Scoped) thực thi trong `SavingChanges*`:
  - Reflection duyệt `ChangeTracker` thu thập `DomainEvents`.
  - Với mỗi DE: tạo `OutboxEvent` (serialize DE làm Payload), gọi `PrepareOutboxEvent` (buffer) + `AddPendingDomainEventForPostCommit`.
  - Clear sự kiện trên entity qua reflection.
- **Buffer**: `BaseDbContext` giữ `_preparedOutboxEvents` và `_pendingDomainEventsForPostCommit` nội bộ. Không Add trực tiếp vào DbSet ngay trong interceptor (theo spec).

Lưu ý: docstring của interceptor hiện chưa được cập nhật hoàn toàn so với logic thực tế.

## 4. Điều phối Transaction (BaseDbContext)

- `PrepareOutboxEvent(OutboxEvent)`: đưa vào buffer nội bộ.
- `FlushPreparedOutboxEvents*`: (gọi từ Commit/Save implicit) Add vào `Set<OutboxEvent>` + inner `SaveChanges`.
- Xử lý SaveChanges: implicit transaction (kết hợp ExecutionStrategy) hoặc explicit (nếu đã có tx từ Behavior/Controller).
- Commit path (thành công): flush outbox → commit tx → attempt publish domain event sau commit.
- Rollback / exception: clear buffer, rollback.
- Hỗ trợ đặc biệt cho provider không relational (InMemory) dùng trong unit test.

Module DbContext (ví dụ `{Module}DbContext`) kế thừa Base, expose `DbSet<OutboxEvent> OutboxEvents` và `PrepareOutboxEvent` (public delegate).

## 5. Collection Integration Event & Thời điểm Publish

- `IIntegrationEventCollector` (Scoped) + `IntegrationEventCollector`: `Add`, `AddRange`, `Events`, `Clear`.
- Mẫu hiện tại trong handler (sau `SaveChangesAsync`):
  - Tạo `IIntegrationEvent`.
  - `collector.Add(integrationEvent)`.
  - Duyệt → tạo `OutboxEvent` → `dbContext.PrepareOutboxEvent(outbox)`.
  - `collector.Clear()`.
  - (Thêm `SaveChangesAsync` nội bộ nếu cần cho visibility trong test/InMemory.)
- `IntegrationEventPublishBehavior` (Singleton, đăng ký sớm):
  - Chạy sau `next(handler)`.
  - Tạo `AsyncScope` mới → `GetService<IIntegrationEventCollector>` + `GetService<IMessagePublisher>`.
  - Nếu có publisher: drain, Clear, `PublishAsync` từng event.
  - Chỉ có collector: chỉ Clear (tránh leak).
- Tương tác pipeline: `TransactionBehavior` (đăng ký sau) đảm bảo Commit xảy ra trước attempt publish của IntegrationEventPublishBehavior (auto-tx ICommand).

## 6. Các bề mặt Dispatch sau Commit

- `IDomainEventPublisher` (contract trong Persistence): side-effect in-process (ví dụ Mediator notification). Resolve động qua `GetService` + Polly (3 lần retry, exponential backoff) trong Base sau commit thành công. Nuốt lỗi (vì đã commit).
- `IMessagePublisher` (seam Application.Abstractions.Messaging): một method `PublishAsync<T>`. Impl do module Infrastructure (MassTransit adapter) cung cấp. Hiện bus tắt / chưa đăng ký → publisher null → behavior chỉ clear.
- Nguyên tắc nhất quán: "nếu có thì" (GetService, không throw khi chưa đăng ký).

## 7. Flow End-to-End (Auto-tx ICommand)

Thứ tự behavior (đăng ký): Logging → Validation → **IntegrationEventPublishBehavior** → **TransactionBehavior** → Handler.

1. Handler: tạo aggregate → `RaiseDomainEvent` → `Add` → `dbContext.SaveChangesAsync()`.
   - Interceptor harvest DE → prepare OutboxEvent (DE) + pending list → clear.
   - Base Save thực hiện (vì có active tx, không auto commit).
2. TransactionBehavior: `CommitAsync()` → flush prepared outbox (DE + IE thủ công) → commit tx thực sự → (trong Base) attempt `IDomainEventPublisher`.
3. Trở lại IntegrationEventPublishBehavior: attempt `IMessagePublisher` cho các IE đã collect (nếu tồn tại).
4. Thất bại sớm (trước Save hoặc trong handler): rollback → clear list → không có outbox row.

**Explicit transaction** (controller tự quản lý Begin/Commit): TransactionBehavior bỏ qua. Controller chịu trách nhiệm flush/commit; timing publish cần xử lý thủ công hoặc dùng hook tương lai.

## 8. Trách nhiệm theo Layer (Clean Architecture)

- **Domain** (`...Domain`): Chỉ aggregate/entity. Gọi `RaiseDomainEvent`. Không biết gì về OutboxEvent, IMessagePublisher hay broker.
- **Application** (`...Application`): Handler, validator, mapper. Xây dựng IE (chủ động build hoặc nội suy). Dùng collector. Gọi `PrepareOutboxEvent` thủ công (hiện tại). Phụ thuộc `IMessagePublisher` (seam) và `I*DbContext`. Chịu trách nhiệm behaviors (IntegrationEventPublish + Transaction).
- **Persistence Building Block**: `OutboxEvent` + Configuration, `OutboxDomainEventInterceptor`, `BaseDbContext` (toàn bộ buffer/flush/tx/post-commit domain publish), contract `IDomainEventPublisher`, helper đăng ký interceptor (Scoped).
- **Infrastructure** (module): `{Module}DbContext` (kế thừa Base, schema, expose OutboxEvents + Prepare), `I{Module}DbContext`, đăng ký `ITransactionalDbContext`. Sau này: impl `IDomainEventPublisher`, relay processor, wiring `IMessagePublisher` thật.
- **API**: Đăng ký pipeline (Mediator behaviors), controller (nếu dùng explicit tx), health check, telemetry. (Bus registration hiện đang comment.)

## 9. Tài liệu tham khảo

- AGENTS.md / CLAUDE.md (hướng dẫn Event Bus & Outbox-First, hard rules).
- Microsoft .NET Architecture guides: "Domain events: design and implementation" (dispatch từ SaveChanges).
- Transactional Outbox pattern.
