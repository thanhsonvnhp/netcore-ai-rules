# 06 - Observability Rules

> **Root concept**: OpenTelemetry là observability backbone. Mọi service emit logs, traces, metrics qua OTLP tới một collector, collector forward tới backend observability của dự án (Elastic APM, Grafana stack, Jaeger, Azure Monitor, Aspire Dashboard...). Dùng `Microsoft.Extensions.Logging` - nếu dự án muốn dùng Serilog thì ghi rõ vào `core/01-project-hard-rules.md`.

> **Template:** Thay `{Company}`, `{ServiceName}`, `{namespace}` bằng giá trị thực tế. Chọn **một** backend observability cho dự án và ghi vào file core.

---

## Architecture Overview

```text
+----------+   OTLP/gRPC    +-----------------+   exporter    +------------------+
| APIs     | ---------------->| otel-collector  | -------------->| Backend của dự án |
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

**Dashboard options** (chọn một cho local dev):

| Stack | Khi nào dùng |
| ------ | ------------ |
| Full production-like backend (Elastic / Grafana) | Cần giống production; nặng RAM |
| Aspire Dashboard | Local dev nhẹ; structured logs + traces + metrics trong một UI |
| Jaeger / Tempo + Grafana | Trace-centric, gọn |

Cả hai expose standard OTLP ports (gRPC `:4317`, HTTP `:4318`). Switch bằng config `OpenTelemetry:OtlpEndpoint` trong `appsettings.Development.json`.

---

## Shared Observability Setup

Gom cấu hình observability vào **một chỗ duy nhất** để mọi service/API dùng chung. Hình thức phụ thuộc kiến trúc dự án:

- **Modular / microservices** (có shared library): tách thành project riêng, ví dụ `src/BuildingBlocks/{Company}.BuildingBlock.Observability/` hoặc `src/Shared/`.
- **Monolith** (một API duy nhất): KHÔNG cần project riêng. Đặt extension method trong thư mục `Infrastructure/Observability/` (hoặc `Common/`, `Shared/`) của chính solution - miễn là một điểm cấu hình duy nhất.

- **Key file**: `OpenTelemetryExtensions.cs`
- **NuGet packages**: `OpenTelemetry.Extensions.Hosting`, `OpenTelemetry.Exporter.OpenTelemetryProtocol`, instrumentation cho ASP.NET Core, HTTP, EF Core, cache client, Runtime

Mọi entry point gọi cùng extension methods lúc startup:

```csharp
// Program.cs
builder.ConfigureOtelLog();              // Logs -> OTLP
builder.AddOtelTracingAndMetrics();      // Traces + Metrics -> OTLP
```

**Exporter modes** (config qua `OpenTelemetry:Exporter` trong `appsettings.json`):

| Value | Behavior |
| ------ | ---------- |
| `"otlp"` | Full telemetry: ASP.NET Core, HttpClient, EF Core, cache, Runtime -> OTLP endpoint |
| `"console"` | Traces + metrics ra console; tiện debug local |
| `"none"` | Không exporter; tắt telemetry |

---

## DO

1. **Structured logging với `Microsoft.Extensions.Logging`** - `LoggingBehavior` pipeline là ví dụ chuẩn:

   ```csharp
   // LoggingBehavior.cs - active ở mọi service qua Mediator pipeline
   _logger.LogInformation("Handling {RequestName}", typeof(TRequest).Name);
   _logger.LogInformation("Handled {RequestName} in {ElapsedMs}ms", typeof(TRequest).Name, elapsedMs);
   ```

   Luôn dùng named placeholder (`{DocumentId}`, không phải `{0}`) để query structured ở backend observability.

2. **Log đúng level**:

   - `Debug` / `Trace` - diagnostic chi tiết; không ở hot path production
   - `Information` - business event quan trọng (document published, user logged in, workflow transitioned)
   - `Warning` - retry triggered, circuit breaker opened, degraded dependency, slow handler (>500 ms)
   - `Error` - chỉ unhandled exception (bắt ở `GlobalExceptionHandler`); không dùng cho business rule violation
   - `Critical` - data loss, infrastructure failure không phục hồi

3. **Include `traceId` trong mọi API error response**:

   ```csharp
   // Program.cs hoặc GlobalExceptionHandler.cs
   ctx.ProblemDetails.Extensions["traceId"] = ctx.HttpContext.TraceIdentifier;
   ctx.ProblemDetails.Extensions["timestamp"] = DateTime.UtcNow;
   ```

   Mọi service phải theo pattern này - `traceId` giúp user correlate error response với trace ở backend.

4. **Health checks live/ready split**:

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

   - `/health/live` - process đang chạy? (lightweight, không external dep)
   - `/health/ready` - service xử lý được request? (DB/cache phải reachable)

   Thêm health check package tương ứng với database/cache dự án dùng (ví dụ `AspNetCore.HealthChecks.NpgSql`, `AspNetCore.HealthChecks.Redis`, `AspNetCore.HealthChecks.SqlServer`).

5. **Tách audit log khỏi technical log**:

   - **Technical logs** (traces, metrics, handler duration) -> OTel pipeline -> backend observability
   - **Audit records** (ai làm gì, login attempt, data mutation) -> bảng trong database (`LoginAudit`, audit columns trên entity)

   Không trộn hai stream. Audit interceptor set audit columns; dữ liệu audit nằm trong DB, không trong log file.

6. **Enrich OTel `Resource` với service identity**:

   ```csharp
   ResourceBuilder.CreateDefault()
       .AddService(serviceName: serviceName, serviceVersion: serviceVersion)
       .AddAttributes(new Dictionary<string, object>
       {
           ["service.namespace"] = "{namespace}",           // ví dụ: tên team/sản phẩm
           ["deployment.environment"] = environment.EnvironmentName.ToLowerInvariant(),
           ["deployment.instance-id"] = Environment.MachineName,
       });
   ```

   Mỗi service set tên riêng qua `OpenTelemetry:ServiceName` trong `appsettings.json` (ví dụ `identity-api`, `{Company}.{Module}.Api`).

7. **Wire database provider OpenTelemetry**:

   Nếu dùng Npgsql:

   ```csharp
   var dataSourceBuilder = new NpgsqlDataSourceBuilder(connectionString);
   dataSourceBuilder.UseOpenTelemetry();   // từ package Npgsql.OpenTelemetry
   var dataSource = dataSourceBuilder.Build();
   builder.Services.AddSingleton<DbDataSource>(dataSource);
   ```

   Provider khác (SQL Server, MySQL) dùng instrumentation OTel tương ứng. Mọi service dùng shared persistence setup sẽ tự có command execution spans.

8. **Wire messaging OpenTelemetry khi bật messaging**:

   Khi messaging enabled, thêm instrumentation cho bus đang dùng, ví dụ MassTransit:

   ```csharp
   busConfig.UsingRabbitMq((ctx, cfg) =>
   {
       cfg.UseOpenTelemetry();  // instrument message send/consume
   });
   ```

   Thêm source name của bus vào trace sources trong `AddOtelTracingAndMetrics`.

---

## DON'T

1. **Không** dùng `Console.WriteLine` / `Debug.WriteLine` trong production code path. Mọi output qua `ILogger<T>` hoặc OTel API.

2. **Không** log sensitive data - password, JWT token, secret key, nội dung tài liệu, full payload file:

   ```csharp
   // WRONG
   _logger.LogInformation("User {UserId} authenticated with token {Token}", userId, accessToken);

   // CORRECT
   _logger.LogInformation("User {UserId} authenticated successfully", userId);
   ```

   Chi log metadata: `documentId`, `userId`, `action`, `correlationId` (+ `tenantId`/`workspaceId` chi khi du an co multi-tenant/workspace).

3. **Không** log level `Information` ở hot path (mỗi HTTP request, mỗi DB query). Dùng `Debug`/`Trace` cho event ồn.

4. **Không** để `/health/ready` fail khi non-critical dependency down. Dùng `HealthStatus.Degraded` cho optional dependency.

5. **Không** trộn audit log với technical log. Audit records nằm trong bảng database - không trong OTel/log pipeline.

6. **Không** dùng exception cho business rule violation - đi qua `Result` pattern (xem `09-error-handling.md`).

7. **Không** log `OperationCanceledException` như error - client disconnect là bình thường.

8. **Không** thêm nhiều logging framework song song. Chọn một (mặc định template: `Microsoft.Extensions.Logging` + OTel pipeline) và ghi rõ vào file core.

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
| `ServiceName` | Định danh service trong traces/logs/metrics | `"{ProjectName}-api"` |
| `OtlpEndpoint` | gRPC endpoint cho collector hoặc dashboard local | (rỗng -> OTLP exporter disabled) |
| `Exporter` | `"otlp"`, `"console"`, hoặc `"none"` | `"otlp"` |

Environment variable overrides: `OTEL_SERVICE_NAME`, `OTEL_EXPORTER_OTLP_ENDPOINT`.

### Collector Configuration

`otel-collector-config.yaml` định nghĩa pipeline:

- **Receivers**: OTLP gRPC `:4317` và HTTP `:4318`
- **Processors**: memory limiter, resource enrichment (`deployment.environment`, `service.namespace={namespace}`), batching
- **Exporters**: backend observability của dự án + debug (console) cho local
- **Health**: health check riêng của collector (`:13133`)

Ở production: bỏ `debug` exporter và bật TLS cho endpoint.

---

## Related Rules

- [05-resilience.md](05-resilience.md) - retry/circuit-breaker observability
- [09-error-handling.md](09-error-handling.md) - exception logging trong `GlobalExceptionHandler`
- [13-background-jobs.md](13-background-jobs.md) - outbox processing observability
