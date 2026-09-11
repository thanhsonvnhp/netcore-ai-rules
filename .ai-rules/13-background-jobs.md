# 13 - Background Jobs & Outbox / Reliable Messaging (Outbox-First)

> **Template:** File này định nghĩa pattern **transactional Outbox** cho messaging đáng tin cậy. Nếu dự án không có messaging/event-driven flow, bỏ qua phần Outbox và chỉ áp dụng phần Background Jobs.

---

## Outbox Pattern (Transactional, "publish after commit")

Không dùng model "lưu OutboxMessage + BackgroundService poll rời rạc khỏi transaction". Outbox row phải được ghi **cùng transaction** với business data.

**Flow chuẩn**:

1. Handler: tạo aggregate -> `RaiseDomainEvent(...)` (trong Domain) -> `dbContext.SaveChangesAsync()`.
2. `OutboxDomainEventInterceptor` (Scoped, chạy trong SavingChanges): harvest Domain Events -> tạo `OutboxEvent` (serialize event làm payload) -> buffer nội bộ (`PrepareOutboxEvent`) -> clear events trên entity.
3. Handler (sau Save): build `IIntegrationEvent` (chủ động hoặc map từ Domain Event) -> thêm vào `IIntegrationEventCollector` (scoped).
4. `TransactionBehavior` (cho command): flush các outbox row đã buffer vào `OutboxEvents` DbSet + commit transaction.
5. `IntegrationEventPublishBehavior` (post-handler): sau commit, nếu `IMessagePublisher` được đăng ký thì `PublishAsync` từng integration event.
6. Post-commit: nếu có `IDomainEventPublisher` -> publish in-process domain events (best-effort, retry nhẹ - dữ liệu đã commit nên nuốt lỗi có log).

**Đảm bảo**: business commit thành công -> outbox row đã được ghi cùng transaction (durable). Publish ra broker là best-effort; relay/processor đảm bảo eventual delivery.

**Bảng outbox**: `<schema>.outbox_events` - columns: `id`, `occurred_on_utc`, `entity_type`, `event_type`, `payload` (jsonb), `payload_event_type`, `error`, `processed_on_utc`, `correlation_id` + audit/`row_version` (uniform với các bảng khác).

**Relay/processor**: hosted service đọc rows chưa `processed_on_utc`, deserialize bằng `event_type`/`payload_event_type`, gọi `IMessagePublisher`, mark processed (hoặc delete). Dùng `FOR UPDATE SKIP LOCKED` (PostgreSQL) hoặc tương đương khi nhiều instance.

---

## DO

1. **Domain chỉ raise**: aggregate/entity gọi `RaiseDomainEvent(new MyDomainEvent(...))`. Domain không biết gì về outbox hay broker.

2. **Application chịu trách nhiệm integration events + collector**:
   - Dùng scoped `IIntegrationEventCollector` (đăng ký trong `AddApplication`).
   - Sau `SaveChangesAsync`, tạo IE -> `collector.Add(ie)`.
   - Tạo `OutboxEvent` -> `dbContext.PrepareOutboxEvent(evt)` (buffer, flush-on-commit ở base DbContext).

3. **Persistence layer lo cơ chế**:
   - `OutboxDomainEventInterceptor` harvest domain events -> buffer + pending list.
   - Base DbContext có buffer `_preparedOutboxEvents` + flush trong commit path + publish pending domain events sau commit.
   - Hỗ trợ explicit transaction và implicit transaction.
   - Read-only DbContext variant (NoTracking) cho query.

4. **Pipeline behaviors** (đăng ký trong `AddApplication` của module):
   - `IntegrationEventPublishBehavior` - publish sau commit.
   - `TransactionBehavior` - chỉ áp dụng cho command, skip nếu đã có active transaction.

5. **`IMessagePublisher`** (abstraction trong `Application.Abstractions.Messaging`) là bề mặt publish duy nhất code được depend. Implementation (MassTransit, RabbitMQ client, Azure Service Bus, Kafka...) do Infrastructure / shared layer cung cấp và **thay thế được**.

6. **Mỗi module có schema riêng** cho outbox table (ví dụ `catalog.outbox_events`). Script migration nằm trong thư mục của module (xem `14-database-rule.md`).

7. **Idempotency / replay**: relay phải dựa trên `message_id` hoặc processed flag; consumer phải idempotent.

8. **Metrics cho relay**: số processed, error, latency, queue depth (xem `06-observability.md`).

## DON'T

1. **KHÔNG** publish trực tiếp sang broker bên trong transaction/handler (dùng collector + `PrepareOutboxEvent` để durable).

2. **KHÔNG** gọi `dbContext.OutboxEvents.Add(...)` cho event chuẩn bị - dùng `PrepareOutboxEvent` để buffer flush đúng lúc commit.

3. **KHÔNG** assume `IMessagePublisher` luôn tồn tại - resolve optional (`GetService`) + skip nếu chưa cấu hình, để code chạy được khi messaging chưa bật.

4. **KHÔNG** poll outbox table thủ công từ code nghiệp vụ (relay/hosted service lo).

5. **KHÔNG** quên clear collector sau drain (tránh leak scope).

6. **KHÔNG** dùng thư viện scheduler (Hangfire/Quartz) cho outbox relay - dùng dedicated processor hoặc hosted service.

---

## Background Jobs (khi dự án cần)

- Job chạy nền định kỳ: dùng `IHostedService`/`BackgroundService` cho job đơn giản; scheduler chuyên dụng (Hangfire, Quartz) khi cần retry, dashboard, cron phức tạp - chọn 1, ghi rõ stack vào `core/01-project-hard-rules.md`.
- Job phải idempotent và có timeout.
- Job không được hold transaction dài; tách batch nhỏ.
- Cấu hình qua Options pattern (xem `11-configuration.md`), không hardcode interval.

## Ví dụ minh họa

```csharp
// Domain (chỉ raise)
product.RaiseDomainEvent(new ProductCreatedDomainEvent(product.Id, product.Name, product.Price));

// Handler (sau Save + collector)
var ie = new ProductCreatedIntegrationEvent(product.Id, product.Name);
integrationEventCollector.Add(ie);
foreach (var e in integrationEventCollector.Events)
{
    dbContext.PrepareOutboxEvent(new OutboxEvent
    {
        OccurredOnUtc = DateTime.UtcNow,
        EventType = e.GetType().AssemblyQualifiedName!,
        Payload = JsonSerializer.Serialize(e, e.GetType()),
        // EntityType, CorrelationId, PayloadEventType...
    });
}
integrationEventCollector.Clear();

// Relay (hosted service): đọc WHERE processed_on_utc IS NULL ... FOR UPDATE SKIP LOCKED
// Deserialize bằng EventType/PayloadEventType, gọi IMessagePublisher, set ProcessedOnUtc.
```
