# 06 - Observability Rules

> **Root concept**: OpenTelemetry is the observability backbone. Every service emits logs, traces, and metrics via OTLP to a collector, which forwards them to the project's observability backend (Elastic APM, the Grafana stack, Jaeger, Azure Monitor, Aspire Dashboard...). Use `Microsoft.Extensions.Logging` - if the project wants Serilog instead, record that explicitly in `core/01-project-hard-rules.md`.

> **Template:** Replace `{Company}`, `{ServiceName}`, `{namespace}` with real values. Pick **one** observability backend for the project and record it in the core file.

---

## Architecture Overview

```text
+----------+   OTLP/gRPC    +-----------------+   exporter    +------------------+
| APIs     | ---------------->| otel-collector  | -------------->| Project backend  |
| (OTel    |   :4317         |                 |               | (Elastic APM /   |
|  SDK)    |                 | pipeline:       |               |  Grafana+Tempo / |
-----------+                 | traces/metrics/ |               |  Jaeger / Azure) |
                             | logs + batch    |               -------------------+
                             ------------------+
                                      |
                              (local dev - lightweight)
                                      v
                             +------------------+
                             | Aspire Dashboard |
                             | :18888 (UI)      |
                             | :18889 (OTLP)    |
                             -------------------+
```

**Dashboard options** (pick one for local dev):

| Stack | When to use |
| ------ | ------------ |
| Full production-like backend (Elastic / Grafana) | Need production parity; heavy on RAM |
| Aspire Dashboard | Lightweight local dev; structured logs + traces + metrics in one UI |
| Jaeger / Tempo + Grafana | Trace-centric, lean |

Both expose standard OTLP ports (gRPC `:4317`, HTTP `:4318`). Switch via the `OpenTelemetry:OtlpEndpoint` config in `appsettings.Development.json`.

---

## Shared Observability Setup

Gather observability configuration into **one single place** that every service/API shares. The exact shape depends on the project's architecture:

- **Modular / microservices** (has a shared library): split it into its own project, for example `src/BuildingBlocks/{Company}.BuildingBlock.Observability/` or `src/Shared/`.
- **Monolith** (a single API): a dedicated project is NOT needed. Put the extension method under `Infrastructure/Observability/` (or `Common/`, `Shared/`) in the solution itself - as long as there is one single configuration point.

- **Key file**: `OpenTelemetryExtensions.cs`
- **NuGet packages**: `OpenTelemetry.Extensions.Hosting`, `OpenTelemetry.Exporter.OpenTelemetryProtocol`, instrumentation for ASP.NET Core, HTTP, EF Core, the cache client, Runtime

Every entry point calls the same extension methods at startup:

```csharp
// Program.cs
builder.ConfigureOtelLog();              // Logs -> OTLP
builder.AddOtelTracingAndMetrics();      // Traces + Metrics -> OTLP
```

**Exporter modes** (configured via `OpenTelemetry:Exporter` in `appsettings.json`):

| Value | Behavior |
| ------ | ---------- |
| `"otlp"` | Full telemetry: ASP.NET Core, HttpClient, EF Core, cache, Runtime -> OTLP endpoint |
| `"console"` | Traces + metrics printed to the console; handy for local debugging |
| `"none"` | No exporter; telemetry disabled |

---

## DO

1. **Structured logging with `Microsoft.Extensions.Logging`** - the `LoggingBehavior` pipeline is the standard example:

   ```csharp
   // LoggingBehavior.cs - active in every service through the Mediator pipeline
   _logger.LogInformation("Handling {RequestName}", typeof(TRequest).Name);
   _logger.LogInformation("Handled {RequestName} in {ElapsedMs}ms", typeof(TRequest).Name, elapsedMs);
   ```

   Always use a named placeholder (`{DocumentId}`, never `{0}`) so the observability backend can query structured fields.

2. **Log at the right level**:

   - `Debug` / `Trace` - detailed diagnostics; never on a production hot path
   - `Information` - a significant business event (document published, user logged in, workflow transitioned)
   - `Warning` - a retry fired, a circuit breaker opened, a degraded dependency, a slow handler (>500 ms)
   - `Error` - unhandled exceptions only (caught in `GlobalExceptionHandler`); never for a business rule violation
   - `Critical` - data loss, an unrecoverable infrastructure failure

3. **Include `traceId` in every API error response**:

   ```csharp
   // Program.cs or GlobalExceptionHandler.cs
   ctx.ProblemDetails.Extensions["traceId"] = ctx.HttpContext.TraceIdentifier;
   ctx.ProblemDetails.Extensions["timestamp"] = DateTime.UtcNow;
   ```

   Every service must follow this pattern - `traceId` lets a user correlate an error response with a trace in the backend.

4. **Split health checks into live/ready**:

   ```csharp
   builder.Services.AddHealthChecks()
       // .AddNpgSql(connectionString, name: "db", tags: ["ready"])
       // .AddRedis(redisConnection, name: "cache", tags: ["ready"])
       .AddCheck("self", () => HealthCheckResult.Healthy(), tags: ["live"]);

   app.MapHealthChecks("/health/live",
       new() { Predicate = r => r.Tags.Contains("live") });
   app.MapHealthChecks("/health/ready",
       new() { Predicate = r => r.Tags.Contains("ready") });
   ```

   - `/health/live` - is the process running? (lightweight, no external dependency)
   - `/health/ready` - can the service handle a request? (DB/cache must be reachable)

   Add the health check package matching the project's database/cache (for example `AspNetCore.HealthChecks.NpgSql`, `AspNetCore.HealthChecks.Redis`, `AspNetCore.HealthChecks.SqlServer`).

5. **Keep audit logs separate from technical logs**:

   - **Technical logs** (traces, metrics, handler duration) -> the OTel pipeline -> the observability backend
   - **Audit records** (who did what, login attempts, data mutations) -> a database table (`LoginAudit`, audit columns on the entity)

   Never mix the two streams. The audit interceptor sets the audit columns; audit data lives in the DB, not in a log file.

6. **Enrich the OTel `Resource` with service identity**:

   ```csharp
   ResourceBuilder.CreateDefault()
       .AddService(serviceName: serviceName, serviceVersion: serviceVersion)
       .AddAttributes(new Dictionary<string, object>
       {
           ["service.namespace"] = "{namespace}",           // for example: team/product name
           ["deployment.environment"] = environment.EnvironmentName.ToLowerInvariant(),
           ["deployment.instance-id"] = Environment.MachineName,
       });
   ```

   Each service sets its own name via `OpenTelemetry:ServiceName` in `appsettings.json` (for example `identity-api`, `{Company}.{Module}.Api`).

7. **Wire up the database provider's OpenTelemetry**:

   With Npgsql:

   ```csharp
   var dataSourceBuilder = new NpgsqlDataSourceBuilder(connectionString);
   dataSourceBuilder.UseOpenTelemetry();   // from the Npgsql.OpenTelemetry package
   var dataSource = dataSourceBuilder.Build();
   builder.Services.AddSingleton<DbDataSource>(dataSource);
   ```

   For a different provider (SQL Server, MySQL), use its matching OTel instrumentation. Any service using the shared persistence setup gets command execution spans automatically.

8. **Wire up messaging OpenTelemetry when messaging is enabled**:

   When messaging is enabled, add instrumentation for the bus in use, for example MassTransit:

   ```csharp
   busConfig.UsingRabbitMq((ctx, cfg) =>
   {
       cfg.UseOpenTelemetry();  // instrument message send/consume
   });
   ```

   Add the bus's source name to the trace sources in `AddOtelTracingAndMetrics`.

---

## DON'T

1. Do **NOT** use `Console.WriteLine` / `Debug.WriteLine` on a production code path. Every output goes through `ILogger<T>` or the OTel API.

2. Do **NOT** log sensitive data - passwords, JWT tokens, secret keys, document content, full file payloads:

   ```csharp
   // WRONG
   _logger.LogInformation("User {UserId} authenticated with token {Token}", userId, accessToken);

   // CORRECT
   _logger.LogInformation("User {UserId} authenticated successfully", userId);
   ```

   Log metadata only: `documentId`, `userId`, `action`, `correlationId` (+ `tenantId`/`workspaceId` only when the project has multi-tenant/workspace).

3. Do **NOT** log at `Information` level on a hot path (every HTTP request, every DB query). Use `Debug`/`Trace` for noisy events.

4. Do **NOT** let `/health/ready` fail when a non-critical dependency is down. Use `HealthStatus.Degraded` for an optional dependency.

5. Do **NOT** mix audit logs with technical logs. Audit records live in a database table - not in the OTel/log pipeline.

6. Do **NOT** use exceptions for business rule violations - go through the `Result` pattern (see `09-error-handling.md`).

7. Do **NOT** log an `OperationCanceledException` as an error - a client disconnect is normal.

8. Do **NOT** add multiple logging frameworks side by side. Pick one (this template's default: `Microsoft.Extensions.Logging` + the OTel pipeline) and record it in the core file.

---

## Configuration Reference

### Per-Service OTel Settings (`appsettings.json`)

```json
{
  "OpenTelemetry": {
    "ServiceName": "{ServiceName}",
    "OtlpEndpoint": "http://localhost:4317",
    "Exporter": "otlp"
  }
}
```

| Key | Purpose | Default |
| ---- | ------- | ------- |
| `ServiceName` | Identifies the service in traces/logs/metrics | `"{ProjectName}-api"` |
| `OtlpEndpoint` | gRPC endpoint for the collector or a local dashboard | (empty -> the OTLP exporter is disabled) |
| `Exporter` | `"otlp"`, `"console"`, or `"none"` | `"otlp"` |

Environment variable overrides: `OTEL_SERVICE_NAME`, `OTEL_EXPORTER_OTLP_ENDPOINT`.

### Collector Configuration

`otel-collector-config.yaml` defines the pipeline:

- **Receivers**: OTLP gRPC `:4317` and HTTP `:4318`
- **Processors**: memory limiter, resource enrichment (`deployment.environment`, `service.namespace={namespace}`), batching
- **Exporters**: the project's observability backend + a debug (console) exporter for local dev
- **Health**: the collector's own health check (`:13133`)

In production: drop the `debug` exporter and enable TLS for the endpoint.

---

## Related Rules

- [05-resilience.md](05-resilience.md) - retry/circuit-breaker observability
- [09-error-handling.md](09-error-handling.md) - exception logging in `GlobalExceptionHandler`
- [13-background-jobs.md](13-background-jobs.md) - outbox processing observability
