# 13 - Background Jobs & Outbox / Reliable Messaging (Outbox-First)

> **Template:** This file defines the **transactional Outbox** pattern for reliable messaging. When the project has no messaging/event-driven flows, skip the Outbox part and apply only the Background Jobs part.

---

## Outbox Pattern (Transactional, "publish after commit")

Do not use a "store an OutboxMessage + poll with a separate BackgroundService detached from the transaction" model. The Outbox row must be written **in the same transaction** as the business data.

**Standard flow**:

1. Handler: create the aggregate -> `RaiseDomainEvent(...)` (in Domain) -> `dbContext.SaveChangesAsync()`.
2. `OutboxDomainEventInterceptor` (Scoped, runs in SavingChanges): harvest Domain Events -> create an `OutboxEvent` (serialize the event as the payload) -> internal buffer (`PrepareOutboxEvent`) -> clear events on the entity.
3. Handler (after Save): build the `IIntegrationEvent` (built directly or mapped from a Domain Event) -> add it to the scoped `IIntegrationEventCollector`.
4. `TransactionBehavior` (for commands): flush the buffered outbox rows into the `OutboxEvents` DbSet + commit the transaction.
5. `IntegrationEventPublishBehavior` (post-handler): after commit, `PublishAsync` each integration event when `IMessagePublisher` is registered.
6. Post-commit: publish in-process domain events when `IDomainEventPublisher` exists (best-effort with light retry - the data is already committed, so swallow errors but log them).

**Guarantee**: a successful business commit means the outbox rows were written in the same transaction (durable). Publishing to the broker is best-effort; a relay/processor guarantees eventual delivery.

**Outbox table**: `<schema>.outbox_events` - columns: `id`, `occurred_on_utc`, `entity_type`, `event_type`, `payload` (jsonb), `payload_event_type`, `error`, `processed_on_utc`, `correlation_id` + audit/`row_version` (uniform with the other tables).

**Relay/processor**: a hosted service reads rows with `processed_on_utc` still null, deserializes via `event_type`/`payload_event_type`, calls `IMessagePublisher`, and marks the row processed (or deletes it). Use `FOR UPDATE SKIP LOCKED` (PostgreSQL) or the equivalent when multiple instances run.

---

## DO

1. **Domain only raises**: the aggregate/entity calls `RaiseDomainEvent(new MyDomainEvent(...))`. The Domain knows nothing about the outbox or the broker.

2. **Application owns integration events + collector**:
   - Use the scoped `IIntegrationEventCollector` (registered in `AddApplication`).
   - After `SaveChangesAsync`, create the IE -> `collector.Add(ie)`.
   - Create the `OutboxEvent` -> `dbContext.PrepareOutboxEvent(evt)` (buffer; flush-on-commit happens in the base DbContext).

3. **Persistence layer owns the mechanism**:
   - `OutboxDomainEventInterceptor` harvests domain events -> buffer + pending list.
   - The base DbContext holds the `_preparedOutboxEvents` buffer + flushes it in the commit path + publishes pending domain events after commit.
   - Supports explicit and implicit transactions.
   - A read-only DbContext variant (NoTracking) for queries.

4. **Pipeline behaviors** (registered in the module's `AddApplication`):
   - `IntegrationEventPublishBehavior` - publishes after commit.
   - `TransactionBehavior` - commands only; skipped when an active transaction already exists.

5. **`IMessagePublisher`** (an abstraction in `Application.Abstractions.Messaging`) is the only publish surface code may depend on. Its implementation (MassTransit, RabbitMQ client, Azure Service Bus, Kafka...) is provided by Infrastructure / a shared layer and **must be replaceable**.

6. **Each module has its own schema** for the outbox table (for example `catalog.outbox_events`). The migration script lives in the module's folder (see `14-database-rule.md`).

7. **Idempotency / replay**: the relay must rely on `message_id` or a processed flag; consumers must be idempotent.

8. **Relay metrics**: processed count, errors, latency, queue depth (see `06-observability.md`).

## DON'T

1. Do **NOT** publish directly to the broker inside a transaction/handler (use the collector + `PrepareOutboxEvent` so it is durable).

2. Do **NOT** call `dbContext.OutboxEvents.Add(...)` for a prepared event - use `PrepareOutboxEvent` so buffering flushes at commit time.

3. Do **NOT** assume `IMessagePublisher` always exists - resolve it optionally (`GetService`) and skip when messaging is not configured, so the code runs with messaging disabled.

4. Do **NOT** poll the outbox table manually from business code (the relay/hosted service owns that).

5. Do **NOT** forget to clear the collector after draining it (avoid scope leaks).

6. Do **NOT** use a scheduler library (Hangfire/Quartz) for the outbox relay - use a dedicated processor or hosted service.

---

## Background Jobs (when the project needs them)

- Recurring background jobs: `IHostedService`/`BackgroundService` for simple jobs; a dedicated scheduler (Hangfire, Quartz) when retry, a dashboard, or complex cron is needed - pick one and record the stack in `core/01-project-hard-rules.md`.
- A job must be idempotent and have a timeout.
- A job must not hold a long transaction; split the work into small batches.
- Configure via the Options pattern (see `11-configuration.md`), never hardcode intervals.

## Illustrative example

```csharp
// Domain (raises only)
product.RaiseDomainEvent(new ProductCreatedDomainEvent(product.Id, product.Name, product.Price));

// Handler (after Save + collector)
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

// Relay (hosted service): read WHERE processed_on_utc IS NULL ... FOR UPDATE SKIP LOCKED
// Deserialize via EventType/PayloadEventType, call IMessagePublisher, set ProcessedOnUtc.
```
