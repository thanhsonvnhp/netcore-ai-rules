# 06 – Observability Rules

> **Root concept**: OpenTelemetry is the sole observability backbone. All services emit logs, traces, and metrics via OTLP to a collector, which forwards to Elastic APM (production-like) or the Aspire Dashboard (local dev). No Serilog, no Application Insights — just OTel + `Microsoft.Extensions.Logging`.

---

## Architecture Overview

```text
┌──────────┐   OTLP/gRPC    ┌─────────────────┐   OTLP/gRPC    ┌──────────────────┐
│ 4 APIs   │ ───────────────→│ otel-collector  │ ───────────────→│ Elastic APM      │
│ (OTel    │   :4317         │ (contrib 0.153) │   :8200         │ Server 8.17      │
│  SDK)    │                 │                 │                 │ → Elasticsearch  │
└──────────┘                 │ pipeline:       │                 │ → Kibana         │
                             │ traces/metrics/ │                 └──────────────────┘
                             │ logs + batch    │
                             └─────────────────┘
                                      │
                              (alternative for local dev)
                                      │
                                      ▼
                             ┌──────────────────┐
                             │ Aspire Dashboard │
                             │ :18888 (UI)      │
                             │ :18889 (OTLP)    │
                             └──────────────────┘
```

**Dashboard options** (choose one for local dev):

| Stack | Compose file | When to use |
| ------ | ------------ | ------------ |
| ELK (Elasticsearch + Kibana + APM Server + Collector) | `docker-compose.elk-stack.yml` | Full production-like observability; heavy (~2 GB RAM) |
| Aspire Dashboard | `docker/docker-compose.aspire-dashboard.yml` | Lightweight local dev; structured logs + traces + metrics in one UI |

Both expose standard OTLP ports (gRPC `:4317`, HTTP `:4318`). Switch by changing the `OpenTelemetry:OtlpEndpoint` config value in each service's `appsettings.Development.json`.

---

## Shared Building Block

All observability configuration lives in a single shared library:

- **Project**: `src/BuildingBlocks/SmartOffice.BuildingBlock.Observability/`
- **Key file**: `OpenTelemetryExtensions.cs`
- **NuGet packages**: `OpenTelemetry.Extensions.Hosting`, `OpenTelemetry.Exporter.OpenTelemetryProtocol`, instrumentation for ASP.NET Core, HTTP, EF Core, Redis, Runtime

Every service calls the same two extension methods at startup:

```csharp
// Program.cs — identical pattern in all 4 services
builder.ConfigureOtelLog();              // Logs → OTLP
builder.AddOtelTracingAndMetrics();      // Traces + Metrics → OTLP
```

**Exporter modes** (configured via `OpenTelemetry:Exporter` in `appsettings.json`):

| Value | Behavior |
| ------ | ---------- |
| `"otlp"` | Full telemetry: ASP.NET Core, HttpClient, EF Core, Redis, Runtime → OTLP endpoint |
| `"console"` | Traces + metrics to console (excludes Redis); ideal for quick local debugging |
| `"none"` | No exporters registered; telemetry disabled |

---

## DO

1. **Use structured logging with `Microsoft.Extensions.Logging`** — the `LoggingBehavior` pipeline demonstrates the pattern:

   ```csharp
   // LoggingBehavior.cs — active in every service via Mediator pipeline
   _logger.LogInformation("Handling {RequestName}", typeof(TRequest).Name);
   _logger.LogInformation("Handled {RequestName} in {ElapsedMs}ms", typeof(TRequest).Name, elapsedMs);
   ```

   Always use named placeholders (`{DocumentId}`, not `{0}`) to enable structured querying in Kibana / Aspire Dashboard.

2. **Log at appropriate levels**:

   - `Debug` / `Trace` — fine-grained diagnostic data; never in production hot paths
   - `Information` — key business events (document published, user logged in, workflow transitioned)
   - `Warning` — retries triggered, circuit breaker opened, degraded dependency, slow handler (>500 ms — `LoggingBehavior` already does this)
   - `Error` — unhandled exceptions only (caught by `GlobalExceptionHandler`); never for business rule violations
   - `Critical` — data loss, unrecoverable infrastructure failure

3. **Include `traceId` in every API error response**:

   All APIs already enrich `ProblemDetails`:

   ```csharp
   // Program.cs or GlobalExceptionHandler.cs
   ctx.ProblemDetails.Extensions["traceId"] = ctx.HttpContext.TraceIdentifier;
   ctx.ProblemDetails.Extensions["timestamp"] = DateTime.UtcNow;
   ```

   All services must follow this pattern. The `traceId` lets users correlate error responses with backend traces.

4. **Emit health checks with live/ready split**:

   ```csharp
   builder.Services.AddHealthChecks()
       // .AddNpgSql(connectionString, name: "postgres", tags: ["ready"])
       // .AddRedis(redisConnection, name: "redis", tags: ["ready"])
       .AddCheck("self", () => HealthCheckResult.Healthy(), tags: ["live"])
      ;

   app.MapHealthChecks("/health/live",
       new() { Predicate = r => r.Tags.Contains("live") });
   app.MapHealthChecks("/health/ready",
       new() { Predicate = r => r.Tags.Contains("ready") });
   ```

   - `/health/live` — is the process running? (always lightweight, no external deps)
   - `/health/ready` — can the service handle requests? (DB, Redis must be reachable)

   NuGet packages `AspNetCore.HealthChecks.NpgSql` and `AspNetCore.HealthChecks.Redis` are already declared in `Directory.Packages.props`.

5. **Separate audit logging from technical logging**:

   - **Technical logs** (traces, metrics, handler durations) → OTel pipeline → Elastic / Aspire
   - **Audit records** (who did what, login attempts, data mutations) → database tables (`LoginAudit`, `OutboxEvent`, `IAuditable` columns)

   Never mix the two streams. The `IAuditable` interceptor (`UpdateAuditableEntitiesInterceptor`) and `LoginAuditService` already follow this pattern — keep audit data in the DB, not in log files.

6. **Enrich OTel `Resource` with service identity**:

   Already done in `OpenTelemetryExtensions.CreateResourceBuilder()`:

   ```csharp
   ResourceBuilder.CreateDefault()
       .AddService(serviceName: serviceName, serviceVersion: serviceVersion)
       .AddAttributes(new Dictionary<string, object>
       {
           ["service.namespace"] = "smart-office",
           ["deployment.environment"] = environment.EnvironmentName.ToLowerInvariant(),
           ["deployment.instance-id"] = Environment.MachineName,  // = Pod name in Kubernetes/Docker
       });
   ```

   Each service sets its own name via `OpenTelemetry:ServiceName` in `appsettings.json` (e.g., `identity-api`, `SmartOffice.OrganizationManagement.Api`, `officemanage-api`, `bff-service`).

7. **Wire Npgsql OpenTelemetry** *(already wired centrally)*:

   The `Npgsql.OpenTelemetry` package is already wired in the shared persistence layer (`SmartOffice.BuildingBlock.Persistence/DependencyInjection.cs` line 40):

   ```csharp
   var dataSourceBuilder = new NpgsqlDataSourceBuilder(connectionString);
   dataSourceBuilder.UseOpenTelemetry();   // extension method from Npgsql.OpenTelemetry package
   dataSourceBuilder.EnableDynamicJson();
   ```

   All services that call `AddSmartOfficePersistence` or `AddSmartOfficeDbContextPostgresSQL` get Npgsql command execution spans automatically. No per-service action needed.

8. **Wire MassTransit OpenTelemetry when messaging is enabled** *(not yet active)*:

   When `EventBus:MassTransit:Enabled` is `true`, add to the bus config:

   ```csharp
   busConfig.UsingRabbitMq((ctx, cfg) =>
   {
       cfg.UseOpenTelemetry();  // Instrument message send/consume
   });
   ```

   Also add `"MassTransit"` as an OTel trace source in `AddOtelTracingAndMetrics`.

---

## DON'T

1. **Do not** use `Console.WriteLine` or `Debug.WriteLine` in production code paths. All output must go through `ILogger<T>` or OTel APIs.

2. **Do not** log sensitive data — passwords, JWT tokens, secret keys, document content/body, or full attachment payloads:

   ```csharp
   // ❌ WRONG
   _logger.LogInformation("User {UserId} authenticated with token {Token}", userId, accessToken);

   // ✅ CORRECT
   _logger.LogInformation("User {UserId} authenticated successfully", userId);
   ```

   Log only metadata: `documentId`, `userId`, `action`, `tenantId`, `correlationId`.

3. **Do not** log at `Information` level in hot paths (every HTTP request, every DB query). Use `Debug` or `Trace` for noisy events.

4. **Do not** let `/health/ready` fail when a non-critical dependency is unavailable. Use `HealthStatus.Degraded` instead of `Unhealthy` for optional dependencies.

5. **Do not** merge audit logs with technical logs. Audit records must live in database tables (`LoginAudit`, `IAuditable` columns, `OutboxEvent`) — never in the OTel/log pipeline.

6. **Do not** use exceptions for business rule violations. These go through the `Result` pattern and must never reach the `GlobalExceptionHandler`.

7. **Do not** log `OperationCanceledException` as an error — client disconnections are normal behavior.

8. **Do not** add Serilog dependencies. The project uses `Microsoft.Extensions.Logging` with the OTel logging pipeline exclusively. No `Serilog`, `Seq`, or `[LogMasked]` attribute.

---

## Configuration Reference

### Per-Service OTel Settings (`appsettings.json`)

```json
{
  "OpenTelemetry": {
    "ServiceName": "identity-api",
    "OtlpEndpoint": "http://localhost:4317",
    "Exporter": "otlp"
  }
}
```

| Key | Purpose | Default |
| ---- | ------- | ------- |
| `ServiceName` | Identifies the service in traces/logs/metrics | `"smart-office-api"` |
| `OtlpEndpoint` | gRPC endpoint for the collector or Aspire Dashboard | (none — OTLP exporter disabled if empty) |
| `Exporter` | `"otlp"`, `"console"`, or `"none"` | `"otlp"` |

Environment variable overrides: `OTEL_SERVICE_NAME`, `OTEL_EXPORTER_OTLP_ENDPOINT`.

### Collector Configuration

`otel-collector-config.yaml` defines the pipeline:

- **Receivers**: OTLP on gRPC `:4317` and HTTP `:4318`
- **Processors**: memory limiter (256 MiB), resource enrichment (`deployment.environment=local`, `service.namespace=smart-office`), batching
- **Exporters**: Elastic APM Server (`apm-server:8200`, insecure TLS) + debug (console)
- **Health**: own health check on `:13133`

For production, remove the `debug` exporter and enable TLS on the Elastic APM endpoint.

---


## Related Rules

- [05-resilience.md](.ai-rules/05-resilience.md) — retry/circuit-breaker observability (logs on retry, metrics on breaker state)
- [09-error-handling.md](.ai-rules/09-error-handling.md) — exception logging in `GlobalExceptionHandler`
- [13-background-jobs.md](.ai-rules/13-background-jobs.md) — outbox processing observability
- `docs/Entity-Domain-And-OutboxEvent.md` — domain event + outbox design
