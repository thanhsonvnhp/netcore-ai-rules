# 13 – Background Jobs & Outbox / Reliable Messaging (Current: Outbox-First)

> **Authoritative design**: `docs/Entity-Domain-And-OutboxEvent.md` (luôn đọc khi làm việc với events/outbox).
> **Current runtime (outbox-event branch)**: Bus registration MassTransit **được comment** trong Program.cs. Không có `IMessagePublisher` implementation được đăng ký. Events tích lũy an toàn trong bảng `outbox_events` (per schema). Relay background processor chưa triển khai.

---

## Outbox Pattern Hiện Tại (Transactional, "publish after commit")

Không phải model "lưu OutboxMessage + BackgroundService poll đơn giản" như một số tài liệu cũ.

**Flow thực tế (auto-tx ICommand)**:

1. Handler: tạo aggregate → `RaiseDomainEvent(...)` (trong Domain) → `dbContext.SaveChangesAsync()`.
2. `OutboxDomainEventInterceptor` (Scoped, trong SavingChanges): harvest Domain Events qua reflection → tạo `OutboxEvent` (serialize DE làm Payload) → `baseCtx.PrepareOutboxEvent(outbox)` (buffer nội bộ, không Add ngay) + `AddPendingDomainEventForPostCommit` → Clear events trên entity.
3. Handler (sau Save): build `IIntegrationEvent` (chủ động hoặc từ DE) → `collector.Add(ie)` (scoped `IIntegrationEventCollector`).
4. Handler: tạo `OutboxEvent` từ IE → `dbContext.PrepareOutboxEvent(outboxEvt)` (thủ công) → collector.Clear(). (Một số path test/InMemory có Save thêm để visible.)
5. `TransactionBehavior` (cho ICommand): đảm bảo commit thực sự (Base flush prepared outbox rows vào `OutboxEvents` DbSet + commit tx).
6. `IntegrationEventPublishBehavior` (post-handler): sau commit, drain collector (nếu còn) + nếu `IMessagePublisher` registered thì `PublishAsync` từng IE (hiện publisher null → chỉ Clear).
7. Post-commit (trong Base): nếu `IDomainEventPublisher` registered → publish in-process domain events (với Polly retry 3 lần, nuốt lỗi vì đã commit).

**Đảm bảo**: Nếu business commit thành công → OutboxEvent row đã được ghi cùng transaction (durable). Publish là best-effort (khi bus enable) hoặc do relay tương lai xử lý.

**Bảng**: `organization.outbox_events` (DbUp script 000002, schema per module). Columns: id, occurred_on_utc, entity_type, event_type, payload (jsonb), payload_event_type, error, processed_on_utc, correlation_id + audit/row_version (để uniform với bảng khác).

**Relay tương lai**: đọc rows chưa `ProcessedOnUtc`, deserialize bằng `EventType`/`PayloadEventType` + Payload, gọi `IMessagePublisher`, mark processed (hoặc delete).

---

## DO (Current Implementation)

1. **Domain chỉ raise**: Aggregate/Entity gọi `RaiseDomainEvent(new MyDomainEvent(...))`. Không biết outbox hay broker.

2. **Application chịu trách nhiệm IE + collector**:
   - Dùng scoped `IIntegrationEventCollector` (đăng ký trong AddApplication).
   - Sau `SaveChangesAsync`, tạo IE → `collector.Add(ie)`.
   - Tạo `OutboxEvent` thủ công → `dbContext.PrepareOutboxEvent(evt)` (để buffer tham gia flush-on-commit của Base).

3. **Persistence BB lo cơ chế**:
   - `OutboxDomainEventInterceptor` (Scoped) harvest DE → Prepare + pending list.
   - `BaseSmartOfficeDbContext` có buffer `_preparedOutboxEvents`, `FlushPreparedOutboxEvents*` (gọi trong commit path), post-commit `PublishPendingDomainEventsAfterCommitAsync` (dùng `IDomainEventPublisher` nếu có + Polly).
   - Hỗ trợ explicit tx (controller tự Begin/Commit) và implicit (Save hoặc TransactionBehavior).
   - Read-only DbContext variant cũng có (NoTracking).

4. **Pipeline behaviors** (đăng ký trong AddApplication của module):
   - `IntegrationEventPublishBehavior` (Singleton, GetService "nếu có").
   - `TransactionBehavior` (Scoped, chỉ ICommand, skip nếu đã có active tx).

5. **IMessagePublisher** (seam Application.Abstractions.Messaging) là bề mặt publish duy nhất code nên depend. Impl do EventBus building block cung cấp khi enable (hiện null).

6. **Table per schema + DbUp**: Mỗi module có schema riêng (organization.outbox_events, ...). Script trong `.dbup/Scripts/smart_office/<schema>/Schema/`.

7. **Idempotency / replay**: Relay tương lai phải xử lý (dựa MessageId hoặc processed flag). Consumer tương lai cần idempotent.

8. **Metrics cho relay (tương lai)**: số processed, error, latency, queue depth.

**Không dùng** (hiện tại):

- Không có `OutboxProcessor : BackgroundService` đang chạy.
- Không có bảng ProcessedMessages / Inbox.
- Không có Hangfire/Quartz.
- Bus + consumers bị comment.

## DON'T (Current)

1. **KHÔNG** publish trực tiếp sang broker bên trong transaction/handler (dùng collector + PrepareOutboxEvent để durable).

2. **KHÔNG** gọi `dbContext.OutboxEvents.Add(...)` trực tiếp cho các event chuẩn bị (dùng `PrepareOutboxEvent` để buffer nội bộ của Base, flush đúng lúc commit).

3. **KHÔNG** assume `IMessagePublisher` luôn có (dùng GetService + "nếu có thì" pattern trong behavior/interceptor — tránh captive + khi bus bị comment vẫn chạy).

4. **KHÔNG** poll outbox table thủ công từ code nghiệp vụ (để relay tương lai lo).

5. **KHÔNG** bỏ qua việc clear collector sau drain (tránh leak scope).

6. **KHÔNG** dùng Hangfire/Quartz cho outbox relay (dùng dedicated processor hoặc hosted service khi triển khai).

## OutboxEvent Table (thực tế từ DbUp + Configuration)

Bảng `outbox_events` (trong schema của module, ví dụ `organization`):

- id (uuid PK), occurred_on_utc, entity_type, event_type, payload (jsonb), payload_event_type, error, processed_on_utc, correlation_id
- - created_at/created_by/updated_at/updated_by/is_deleted/deleted_at/row_version (uniform với các bảng khác, interceptor audit set)
- Index: ix_outbox_events_processed_on_utc, ix_outbox_events_occurred_on_utc

Script: `.dbup/Scripts/smart_office/organization/Schema/000002_outbox_events.sql`

## Ví dụ minh họa (thực tế code Organization + Persistence BB)

```csharp
// Domain (chỉ raise)
product.RaiseDomainEvent(new ProductCreatedDomainEvent(product.Id, product.Name, product.Price));

// Handler (sau Save + collector)
var ie = new ProductCreatedIntegrationEvent(...);
integrationEventCollector.Add(ie);
foreach (var e in integrationEventCollector.Events)
{
    dbContext.PrepareOutboxEvent(new OutboxEvent
    {
        OccurredOnUtc = DateTime.UtcNow,
        EventType = e.GetType().AssemblyQualifiedName ?? ...,
        Payload = JsonSerializer.Serialize(e, e.GetType()),
        // EntityType, CorrelationId, PayloadEventType...
    });
}
integrationEventCollector.Clear();

// (Optional extra Save cho InMemory/test visibility của OutboxEvents.Local)
if (dbContext.OutboxEvents.Local.Any()) await dbContext.SaveChangesAsync(ct);

// Sau này (relay): đọc WHERE processed_on_utc IS NULL ... FOR UPDATE SKIP LOCKED
// Deserialize bằng EventType/PayloadEventType, gọi IMessagePublisher, set ProcessedOnUtc.
```

Xem chi tiết luồng + trách nhiệm layer trong `docs/Entity-Domain-And-OutboxEvent.md` (section 3-8).
