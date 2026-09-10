# 05 – Resilience Pattern Rules

## Scope

This document defines resilience rules for external HTTP calls, retries, timeouts, circuit breakers, message consumers, idempotency, dead-letter queues, and concurrency handling.

---

## Error Classification

Classify errors before applying retry.

| Error Type        | Examples                                                                                 | Retry              |
| ----------------- | ---------------------------------------------------------------------------------------- | ------------------ |
| Transient error   | Network timeout, DNS failure, connection refused, HTTP `408`, `429`, `502`, `503`, `504` | Yes                |
| Business error    | Validation failure, domain rule violation, resource not found, permission denied         | No                 |
| Client error      | HTTP `400`, `401`, `403`, `404`, `409`, `422`                                            | No                 |
| Concurrency error | `DbUpdateConcurrencyException`                                                           | No automatic retry |

Rules:

* Retry transient errors only.
* Do not retry business errors.
* Do not retry validation errors.
* Do not retry authorization errors.
* Do not retry `404 Not Found`.
* Do not retry `409 Conflict`.
* Return business errors through the Result pattern and API error mapping.

---

## HTTP Connector Rules

Create connector projects for service-to-service HTTP calls.

Connector projects contain:

* Connector interface
* Request and response DTOs
* Options class
* Dependency injection registration
* Resilience configuration

Example project file:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <PackageId>SmartOffice.BuildingBlock.Connector.Identity</PackageId>
    <Authors>Dev</Authors>
    <Title>SmartOffice.BuildingBlock.Connector.Identity</Title>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="RestEase.HttpClientFactory" />
    <PackageReference Include="RestEase.SourceGenerator" />
    <PackageReference Include="Microsoft.Extensions.Http.Resilience" />
  </ItemGroup>
</Project>
```

---

## Connector Options

Use strongly typed options for connector configuration.

```csharp
public sealed class IdentityConnectorOptions
{
    public const string SectionName = "Bff:Identity";

    public string BaseUrl { get; init; } = string.Empty;

    public int TimeoutSeconds { get; init; } = 10;

    public int RetryAttempts { get; init; } = 3;

    public int RetryDelayMilliseconds { get; init; } = 300;

    public int CircuitBreakerSamplingSeconds { get; init; } = 30;
}
```

Example configuration:

```json
{
  "Bff": {
    "Identity": {
      "BaseUrl": "http://identity:8080",
      "TimeoutSeconds": 10,
      "RetryAttempts": 3,
      "RetryDelayMilliseconds": 300,
      "CircuitBreakerSamplingSeconds": 30
    }
  }
}
```

Rules:

* Store connector base URL in configuration.
* Do not hardcode service URLs in connector code.
* Use typed options for timeout and retry settings.
* Validate connector options during application startup.

---

## HTTP Client Resilience

Use `HttpClientFactory` with the standard resilience handler for external service calls.

```csharp
public static class DependencyInjection
{
    public static IServiceCollection AddIdentityConnector(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services
            .AddOptions<IdentityConnectorOptions>()
            .Bind(configuration.GetSection(IdentityConnectorOptions.SectionName))
            .Validate(options => !string.IsNullOrWhiteSpace(options.BaseUrl), "BaseUrl is required.")
            .ValidateOnStart();

        services
            .AddHttpClient("IdentityConnector", (serviceProvider, client) =>
            {
                var options = serviceProvider
                    .GetRequiredService<IOptions<IdentityConnectorOptions>>()
                    .Value;

                client.BaseAddress = new Uri(options.BaseUrl);
            })
            .ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler
            {
                AutomaticDecompression =
                    DecompressionMethods.GZip |
                    DecompressionMethods.Deflate
            })
            .AddStandardResilienceHandler((options, serviceProvider) =>
            {
                var connectorOptions = serviceProvider
                    .GetRequiredService<IOptions<IdentityConnectorOptions>>()
                    .Value;

                options.Retry.MaxRetryAttempts = connectorOptions.RetryAttempts;
                options.Retry.Delay = TimeSpan.FromMilliseconds(
                    connectorOptions.RetryDelayMilliseconds);

                options.CircuitBreaker.SamplingDuration = TimeSpan.FromSeconds(
                    connectorOptions.CircuitBreakerSamplingSeconds);

                options.TotalRequestTimeout.Timeout = TimeSpan.FromSeconds(
                    connectorOptions.TimeoutSeconds);
            })
            .UseWithRestEaseClient<IIdentityUserConnector>();

        return services;
    }
}
```

Rules:

* Set explicit timeout for every external call.
* Use retry with delay.
* Use exponential backoff with jitter.
* Use circuit breaker for unstable dependencies.
* Use one named or typed HTTP client per external service.
* Do not share stateful resilience policy instances between unrelated services.
* Do not disable TLS certificate validation in production code.

---

## Internal Service Headers

Use internal headers only for trusted service-to-service calls.

```csharp
[Header("X-Internal-Api", "true")]
public interface IIdentityUserConnector
{
    [Post("api/internal/users")]
    Task<Response<UserDto>> CreateUserAsync(
        [Body] CreateUserRequestModel user,
        CancellationToken cancellationToken = default);

    [Post("api/internal/users/{userId}/reset-password")]
    Task ResetPasswordAsync(
        [Path] string userId,
        CancellationToken cancellationToken = default);

    [Post("api/internal/users/{userId}/block")]
    Task BlockAsync(
        [Path] string userId,
        CancellationToken cancellationToken = default);

    [Post("api/internal/user-sessions/{sessionId}/revoke")]
    Task RevokeSessionAsync(
        [Path] string sessionId,
        CancellationToken cancellationToken = default);

    [Post("api/internal/user-sessions/revoke-all")]
    Task RevokeAllSessionsAsync(
        [Query] string userId,
        CancellationToken cancellationToken = default);
}
```

Rules:

* Use `X-Internal-Api` only between trusted internal services.
* Remove internal headers at the gateway before forwarding public traffic.
* Do not allow public clients to send trusted internal headers.
* Protect internal APIs with gateway rules, network rules, or service authentication.

---

## Retry Rules

Retry transient failures only.

Allowed retry cases:

* Network timeout
* DNS failure
* Connection refused
* HTTP `408 Request Timeout`
* HTTP `429 Too Many Requests`
* HTTP `502 Bad Gateway`
* HTTP `503 Service Unavailable`
* HTTP `504 Gateway Timeout`

Rules:

* Use a maximum retry count.
* Use backoff delay.
* Use jitter.
* Keep retry count small.
* Log retry attempts with dependency name and attempt number.
* Do not retry immediately without delay.
* Do not use infinite retry loops.
* Do not retry non-idempotent operations unless the request is protected by idempotency.

---

## Timeout Rules

Every external dependency call has an explicit timeout.

Default HTTP timeout:

```text
10 seconds
```

Rules:

* Configure timeout through connector options.
* Keep timeout lower than the caller request timeout.
* Pass `CancellationToken` to every external call.
* Do not block threads while waiting for external services.
* Do not use `.Result` or `.Wait()` for async calls.

---

## Circuit Breaker Rules

Use circuit breaker for external dependencies that can fail repeatedly.

Rules:

* Configure circuit breaker per dependency.
* Return a clear dependency failure when the circuit is open.
* Use fallback only when safe and explicit.
* Do not let one dependency circuit breaker block unrelated services.
* Do not hide dependency failure as successful business response.

Allowed fallback types:

* Cached read response
* Empty degraded read response
* Clear dependency unavailable error
* Queued asynchronous command when the operation supports it

---

## Message Resilience

Use BuildingBlock EventBus MassTransit configuration for message retry, delayed redelivery, outbox, and dead-letter handling.

Rules:

* Use MassTransit retry policies for transient message processing failures.
* Use MassTransit outbox for reliable publish.
* Use MassTransit consumer outbox or inbox for idempotent consumers.
* Do not publish integration events directly outside the configured outbox flow.
* Do not drop messages silently.

---

## Idempotent Consumers

Consumers must be idempotent.

Idempotency key sources:

* `MessageId`
* Business event ID
* Aggregate ID plus event version
* Explicit idempotency key

Rules:

* Reject messages without a required idempotency key.
* Store processed message IDs.
* Check processed message ID before executing side effects.
* Mark message as processed in the same transaction as side effects.
* Return successfully for already processed messages.
* Do not execute side effects twice for the same message.

Example:

```csharp
public sealed class DocumentPublishedConsumer(
    AppDbContext dbContext,
    ILogger<DocumentPublishedConsumer> logger)
    : IConsumer<DocumentPublishedEvent>
{
    public async Task Consume(ConsumeContext<DocumentPublishedEvent> context)
    {
        var cancellationToken = context.CancellationToken;

        var messageId = context.MessageId
            ?? throw new InvalidOperationException("MessageId is required.");

        var alreadyProcessed = await dbContext.ProcessedMessages
            .AnyAsync(x => x.MessageId == messageId, cancellationToken);

        if (alreadyProcessed)
        {
            logger.LogDebug(
                "Message {MessageId} already processed.",
                messageId);

            return;
        }

        await using var transaction = await dbContext.Database
            .BeginTransactionAsync(cancellationToken);

        dbContext.ProcessedMessages.Add(new ProcessedMessage
        {
            MessageId = messageId,
            ConsumerName = nameof(DocumentPublishedConsumer),
            ProcessedAtUtc = DateTime.UtcNow
        });

        // Execute side effects here.

        await dbContext.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
    }
}
```

---

## Consumer Retry and Dead Letter

Use retry for transient consumer failures.

Send non-retryable failures to error queue or dead-letter queue.

Example:

```csharp
public sealed class DocumentPublishedConsumerDefinition
    : ConsumerDefinition<DocumentPublishedConsumer>
{
    public DocumentPublishedConsumerDefinition()
    {
        EndpointName = "document-service.document-published";
    }

    protected override void ConfigureConsumer(
        IReceiveEndpointConfigurator endpointConfigurator,
        IConsumerConfigurator<DocumentPublishedConsumer> consumerConfigurator,
        IRegistrationContext context)
    {
        endpointConfigurator.UseMessageRetry(retry =>
        {
            retry.Exponential(
                retryLimit: 3,
                minInterval: TimeSpan.FromMilliseconds(100),
                maxInterval: TimeSpan.FromSeconds(1),
                intervalDelta: TimeSpan.FromMilliseconds(100));

            retry.Ignore<BusinessException>();
            retry.Ignore<ValidationException>();
            retry.Ignore<UnauthorizedAccessException>();
        });

        endpointConfigurator.UseInMemoryOutbox(context);
    }
}
```

Rules:

* Retry transient processing failures.
* Do not retry business exceptions.
* Do not retry validation exceptions.
* Do not retry authorization exceptions.
* Use error queue or dead-letter queue for failed messages.
* Replay dead-letter messages manually and with approval.
* Do not replay dead-letter messages automatically.

---

## Concurrency Handling

Handle optimistic concurrency explicitly.

Rules:

* Do not automatically retry `DbUpdateConcurrencyException`.
* Reload the entity before retrying a concurrency operation.
* Return `409 Conflict` when the operation cannot be applied.
* Log concurrency conflicts with aggregate ID and operation name.
* Do not overwrite concurrent updates silently.

---

## Observability

Log resilience events.

Required log fields:

* Dependency name
* Operation name
* Attempt number
* Timeout value
* Circuit breaker state
* Message ID
* Correlation ID
* Trace ID
* Error code
* Exception type

Rules:

* Log retry attempts at warning level.
* Log final dependency failures at error level.
* Log duplicate message skips at debug level.
* Do not log tokens, passwords, secrets, or sensitive payloads.

---

## Restrictions

Do not retry business errors.

Do not retry validation errors.

Do not retry authorization errors.

Do not retry `404 Not Found`.

Do not retry `409 Conflict`.

Do not use infinite retry loops.

Do not retry immediately without delay.

Do not share stateful resilience policies between unrelated services.

Do not disable TLS certificate validation in production code.

Do not publish integration events outside the outbox flow.

Do not ignore duplicate `MessageId`.

Do not execute message side effects before idempotency check.

Do not replay dead-letter messages automatically.

Do not swallow dependency failures.

Do not block async calls with `.Result` or `.Wait()`.

---

## Related Components

* `HttpClientFactory`
* `Microsoft.Extensions.Http.Resilience`
* `RestEase.HttpClientFactory`
* `RestEase.SourceGenerator`
* `MassTransit`
* MassTransit Outbox
* MassTransit Consumer Outbox / Inbox
* BuildingBlock EventBus
* `Idempotency-Key`
* `DbUpdateConcurrencyException`
* `CancellationToken`
