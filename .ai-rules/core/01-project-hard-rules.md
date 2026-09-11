# 01 - Project Hard Rules & Project Map (Core - Always Load)

> **Template:** File này là template generic cho mọi dự án .NET Core. Thay các placeholder `{ProjectName}`, `{Company}`, `{Module}`, `{schema}`, `{database}` bằng giá trị dự án thực tế khi onboard (xem `.ai-rules/TEMPLATE_VARS.md`). Stack mặc định bên dưới có thể đổi theo dự án - ghi rõ stack thực tế vào section "Frameworks & Architecture" khi onboard.

## Business Overview

> Điền mô tả ngắn domain nghiệp vụ của dự án tại đây (2-5 bullet). Không có sẵn - mỗi dự án tự khai báo.

- {Mô tả bounded context / nghiệp vụ chính}

The platform is built as a **modular system**. All services follow **strict Clean Architecture**.

## Repository Map (Must-Know Locations)

### Documentation & Rules

- `docs/` - Các guide kiến trúc của dự án (vertical slice, domain events, outbox...). Thêm đường dẫn thực tế khi onboard.
- `.ai-rules/` - Hard rules and guidelines (architecture, CQRS, security, API contract, testing, EF Core, error handling, etc.). Bộ rule files là unified source cho naming (C# + DB), REST contract, HttpCode + error codes, data types, SQL conventions, EF registration, C# conventions, editorconfig, response format.

### Source Code Structure (template - điều chỉnh theo repo thực tế)

- `{ProjectName}.sln` (hoặc `.slnx`)
- `src/BuildingBlocks/**` hoặc `src/Shared/**` - Shared libraries (chỉ khi modular/microservices - monolith đặt shared code trong `Infrastructure/Common`, `Shared/` hoặc ngay trong layer) (zero business logic): Authentication, Caching, Domain.Shared, Application.Shared, Persistence, EventBus, Observability.
- `src/Services/**` - Microservices / modules:
  - `{Module}/{Company}.{Module}.*` (Api/Application/Domain/Infrastructure + Unit/IntegrationTests) - mỗi module là một bounded context.
- Database scripts: `.dbup/Scripts/{database}/<schema>/<Schema|Static>/` (DbUp) **hoặc** `Migrations/` trong Infrastructure project (EF Core Migrations) - chọn 1 cơ chế duy nhất cho dự án và ghi rõ ở section Database bên dưới.
- Database documentation per schema: `docs/database/{database}.<schema>.md`.
- `change-logs/YYYY/MM/YYYY-MM-DD.md` - daily changelog entries (fenced YAML) for every commit that has API/contract/DB/shared impact. **Mandatory** (nếu dự án bật changelog policy).

### Database & DevOps

- Mọi database change đi qua migration tool của dự án (DbUp scripts hoặc EF Migrations). **No direct SQL in code** hoặc ad-hoc changes.
- `change-logs/` - Changelog guide + template (fenced YAML) + daily change log data files (**REQUIRED** cho mọi commit có API/contract/DB/shared impact).
- `docker-compose.yml` - Quick start: API services + database + cache (nếu dự án dùng).

**Key governance and implementation guides (in .ai-rules/):**

- [01-clean-architecture.md](../01-clean-architecture.md) - Clean Architecture rules and guidelines
- [02-constants-errors.md](../02-constants-errors.md) - Error codes and constants
- [02-cqrs-pattern.md](../02-cqrs-pattern.md) - CQRS pattern and handler conventions
- [03-security-tenancy.md](../03-security-tenancy.md) - Security, multi-tenancy (optional) and auth rules
- [04-api-contract.md](../04-api-contract.md) - API/contract change rules and versioning
- [05-resilience.md](../05-resilience.md) - Resilience and retry policies
- [06-observability.md](../06-observability.md) - Logging, tracing and metrics
- [07-testing.md](../07-testing.md) - Unit and integration testing guidelines
- [08-ef-core.md](../08-ef-core.md) - EF Core usage and conventions
- [09-error-handling.md](../09-error-handling.md) - Error handling and problem details
- [10-dependency-injection.md](../10-dependency-injection.md) - DI and composition rules
- [11-configuration.md](../11-configuration.md) - Configuration structure and secrets
- [12-caching.md](../12-caching.md) - Caching strategies and patterns
- [13-background-jobs.md](../13-background-jobs.md) - Background job, outbox and reliable messaging
- [14-database-rule.md](../14-database-rule.md) - Database rules and migration policies
- [15-commit-change-log.md](../15-commit-change-log.md) - Commit changelog template and requirements
- [16-code-comments.md](../16-code-comments.md) - Code comment conventions

## Frameworks & Architecture

- **Clean Architecture**: Dependency direction strictly `Domain <- Application <- Infrastructure <- API`. No violations.
- **Frameworks** (mặc định template - thay theo dự án): .NET 8+, EF Core, ASP.NET Core Web API.
- **Domain**: Zero external dependencies, zero NuGet packages, pure C# only.
- **Application**: Owns commands/queries/handlers/validators + all `I*` abstractions.
- **Infrastructure**: EF Core, cache (Redis/Valkey nếu cần), auth, outbox, external services.
- **API**: Controllers, middleware, OpenAPI, health checks, auth, telemetry.

## Database & Migration (Mandatory)

- Chọn **một** cơ chế migration và ghi rõ vào file này khi onboard:
  - DbUp: mỗi schema/static data change **requires** a script trong `.dbup/Scripts/{database}/<schema>/<Schema|Static>/`.
  - EF Core Migrations: mỗi change **requires** một migration trong `{Company}.{Module}.Infrastructure/Migrations/`.
- **No direct SQL in code** hoặc ad-hoc changes ngoài migration tool.
- Audit columns bat buoc tren moi bang nghiep vu: 8 cot `created_at`, `created_by`, `updated_at`, `updated_by`, `is_deleted`, `deleted_at`, `deleted_by`, `row_version`; them `tenant_id` / `workspace_id` chi khi du an co multi-tenant / workspace sharding (OPTIONAL ADD-ON, xem `03-security-tenancy.md`). Mac dinh single-tenant thi khong co.
- Soft delete: set `is_deleted = true` - tránh `DELETE FROM`, `DROP TABLE`, `DROP COLUMN`, `RENAME COLUMN` trên dữ liệu production (soft delete via EF Core Interceptor hoặc query filter trên DbContext).
- All tables: snake_case names (table_name, column_name, index_name). Column comments theo ngôn ngữ dự án (mặc định template: tiếng Việt).

## Changelog Requirement (Mandatory nếu dự án bật policy)

- API/contract/DB/shared impact changes **require** a daily changelog entry trong `change-logs/`.
- Dùng task ID (ví dụ `#JIRA-123`) trong title. Commit log cùng code.
- Follow `.ai-rules/15-commit-change-log.md` và `change-logs/README.md`.

## Testing

- Unit tests cho Domain và Application layers: xUnit + NSubstitute (hoặc Moq) + FluentAssertions.
- Integration tests cho API layer: WebApplicationFactory + Testcontainers (database/cache thực).
- Không có UI test nếu dự án backend-only.

## Messaging (Outbox-First)

- Dùng **transactional Outbox** cho reliable "publish after commit" khi dự án có messaging.
- Code chỉ depend vào `IMessagePublisher` (abstraction trong Application) - implementation (MassTransit, RabbitMQ client, Azure Service Bus...) nằm ở Infrastructure và **thay thế được**.
- Integration Event publish ở cuối Mediator pipeline (xem `13-background-jobs.md`).

## Language Preference

- Mặc định template: **tiếng Việt** cho user-facing message text, code comments giải thích logic, và log messages. Đổi theo team dự án khi onboard.
- English acceptable cho technical identifiers và internal exception messages.

## Common Commands

**Build and run solution** (thay `{ProjectName}` / `{Module}`):

```powershell
# Format code (required before commit)
dotnet format {ProjectName}.sln
dotnet format {ProjectName}.sln --verify-no-changes

# Build toàn solution
dotnet build {ProjectName}.sln
# Run all unit and integration tests
dotnet test {ProjectName}.sln
# Run unit tests cho 1 module
dotnet test src/Services/{Module}/{Company}.{Module}.UnitTests/{Company}.{Module}.UnitTests.csproj
# Run integration tests cho 1 module
dotnet test src/Services/{Module}/{Company}.{Module}.IntegrationTests/{Company}.{Module}.IntegrationTests.csproj

# Docker infrastructure cho local dev (nếu dự án dùng)
docker compose up -d
# Run 1 API project
dotnet run --project src/Services/{Module}/{Company}.{Module}.Api/{Company}.{Module}.Api.csproj
```

**Migration example** - DbUp (nếu dự án dùng DbUp):

```powershell
cd .dbup
dotnet run -- "Host=localhost;Port=5432;Database={database};Username=postgres;Password=postgres" {database} {schema} {schema}
```

Hoặc EF Core Migrations:

```powershell
dotnet ef migrations add <Name> --project src/Services/{Module}/{Company}.{Module}.Infrastructure
dotnet ef database update --project src/Services/{Module}/{Company}.{Module}.Infrastructure
```

**Change log**
Mọi change phải được document trong `change-logs/YYYY/MM/YYYY-MM-DD.md` (append cuối file) nếu dự án bật changelog policy.

**Code comment**:
MUST follow `16-code-comments.md` và mục Code comment trong `01-clean-architecture.md`.

## Error Handling

- Handlers trả `Result<T>` / `Result` / `ResultPaged<T>` - không throw exception cho expected errors. Có thể throw `AppErrorFailureException` (hoặc exception tương đương của dự án) trong business logic nếu pattern dự án cho phép.
- API map errors qua `ResultExtensions` -> `ProblemDetails` với user messages theo ngôn ngữ dự án (dùng `ToApiResponse` để convert `Result<T>` / `Result` / `ResultPaged<T>` sang API response).
- Không lộ stack traces trong `ProblemDetails` ở non-dev environments.

## Observability

- Inject `ILogger<>` -> Console -> OTel Collector -> backend observability của dự án (Elastic APM, Grafana, Jaeger, Azure Monitor, Aspire Dashboard...). Chú ý Log Level: Debug, Info, Warning, Error (xem `06-observability.md`).

## Frontend Stack (chỉ điền nếu dự án có frontend)

- Mặc định template để trống. Ví dụ phổ biến: React + Vite + Tailwind CSS + component library (Mantine/shadcn) + TanStack Query.
- No business logic in UI components.
- Vitest + Testing Library (frontend tests).

## Paths Reference (template - điều chỉnh theo repo thực tế)

| Resource            | Path |
|---------------------|------|
| Feature workspace   | `.specify/features/<task-id>_<title>/` (nếu dùng spec-kit) |
| Changelog           | `change-logs/YYYY/MM/YYYY-MM-DD.md` |
| Database docs       | `docs/database/{database}.<schema>.md` |
| DbUp scripts        | `.dbup/Scripts/{database}/<schema>/<Schema\|Static>/` |
| AI rules (core)     | `.ai-rules/core/` (always load first 3 files) |
| AI rules (detailed) | `.ai-rules/` |
