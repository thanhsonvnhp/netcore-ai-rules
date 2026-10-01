# 01 - Project Hard Rules & Project Map (Core - Always Load)

> **Template:** This file is a generic template for any .NET Core project. Replace every `{Placeholder}` with real project values during onboarding (see `.ai-rules/TEMPLATE_VARS.md`). The default stack below may change per project - record the actual stack in the "Frameworks & Architecture" section during onboarding.

## Business Overview

> Fill in a short description of this project's business domain here (2-5 bullets). Nothing is pre-filled - every project declares its own.

- {Describe the main bounded context / business domain}

The platform is built as a **modular system**. All services follow **strict Clean Architecture**.

## Repository Map (Must-Know Locations)

### Documentation & Rules

- `docs/` - Project architecture guides (vertical slice, domain events, outbox...). Add the real paths during onboarding.
- `.ai-rules/` - Hard rules and guidelines (architecture, CQRS, security, API contract, testing, EF Core, error handling, etc.). The rule files are the unified source for naming (C# + DB), REST contract, HTTP status + error codes, data types, SQL conventions, EF registration, C# conventions, editorconfig, and response format.

### Source Code Structure (template - adjust to the real repo)

- `{ProjectName}.sln` (or `.slnx`)
- `src/BuildingBlocks/**` or `src/Shared/**` - Shared libraries (only when modular/microservices - a monolith keeps shared code in `Infrastructure/Common`, `Shared/`, or inside the layer itself) with zero business logic: Authentication, Caching, Domain.Shared, Application.Shared, Persistence, EventBus, Observability.
- `src/Services/**` - Microservices / modules:
  - `{Module}/{Company}.{Module}.*` (Api/Application/Domain/Infrastructure + Unit/IntegrationTests) - each module is one bounded context.
- Database scripts: `.dbup/Scripts/{database}/<schema>/<Schema|Static>/` (DbUp) **or** `Migrations/` inside the Infrastructure project (EF Core Migrations) - pick exactly one mechanism for the project and record it in the Database section below.
- Database documentation per schema: `docs/database/{database}.<schema>.md`.
- `change-logs/YYYY/MM/YYYY-MM-DD.md` - daily changelog entries (fenced YAML) for every commit with API/contract/DB/shared impact. **Mandatory** when the project enables the changelog policy.
- `.plans/<task-id>.md` - personal working plan per task. Local only, never committed.

### Database & DevOps

- Every database change goes through the project's migration tool (DbUp scripts or EF Migrations). **No direct SQL in code** and no ad-hoc changes.
- `change-logs/` - Daily change log data files (fenced YAML, template in `15-commit-change-log.md`) - **REQUIRED** for every commit with API/contract/DB/shared impact.
- `docker-compose.yml` - Quick start: API services + database + cache (when the project uses it).

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
- **Frameworks** (template default - change per project): .NET 8+, EF Core, ASP.NET Core Web API.
- **Domain**: Zero external dependencies, zero NuGet packages, pure C# only.
- **Application**: Owns commands/queries/handlers/validators + all `I*` abstractions.
- **Infrastructure**: EF Core, cache (Redis/Valkey when needed), auth, outbox, external services.
- **API**: Controllers, middleware, OpenAPI, health checks, auth, telemetry.

## Database & Migration (Mandatory)

- Pick **one** migration mechanism and record it in this file during onboarding:
  - DbUp: every schema/static data change **requires** a script in `.dbup/Scripts/{database}/<schema>/<Schema|Static>/`.
  - EF Core Migrations: every change **requires** a migration in `{Company}.{Module}.Infrastructure/Migrations/`.
- **No direct SQL in code** and no ad-hoc changes outside the migration tool.
- Audit columns are mandatory on every business table: the 8 columns `created_at`, `created_by`, `updated_at`, `updated_by`, `is_deleted`, `deleted_at`, `deleted_by`, `row_version`. Add `tenant_id` / `workspace_id` **only** when the project has multi-tenant / workspace sharding (OPTIONAL ADD-ON, see `03-security-tenancy.md`). Single-tenant is the default and has neither.
- Soft delete: set `is_deleted = true`. Avoid `DELETE FROM`, `DROP TABLE`, `DROP COLUMN`, `RENAME COLUMN` on production data (soft delete via an EF Core interceptor or a query filter on the DbContext).
- All tables: snake_case names (table_name, column_name, index_name). Column comments use the project's output language (see Language Policy below).

## Changelog Requirement (Mandatory when the policy is enabled)

- API/contract/DB/shared impact changes **require** a daily changelog entry in `change-logs/`.
- Use the task ID (for example `#JIRA-123`) in the title. Commit the log together with the code.
- Follow `.ai-rules/15-commit-change-log.md`.

## Testing

- Unit tests for the Domain and Application layers: xUnit + NSubstitute (or Moq) + FluentAssertions.
- Integration tests for the API layer: WebApplicationFactory + Testcontainers (real database/cache).
- No UI tests for a backend-only project.

## Messaging (Outbox-First)

- Use a **transactional Outbox** for reliable "publish after commit" when the project has messaging.
- Code depends only on `IMessagePublisher` (an abstraction in Application). The implementation (MassTransit, RabbitMQ client, Azure Service Bus...) lives in Infrastructure and **must be replaceable**.
- Integration Events are published at the end of the Mediator pipeline (see `13-background-jobs.md`).

## Language Policy

Two different things - do not conflate them:

| | Language | Applies to |
|---|---|---|
| **Rule language** | English | `.ai-rules/**` - instructions the AI agent reads |
| **Output language** | **Vietnamese** (template default) | Code comments explaining logic, user-facing messages, log messages, chat replies |

- Change the output language above during onboarding if the team uses another language. This is the single place that defines it - other rule files refer here.
- English is always used for technical identifiers, type names, and internal exception messages, regardless of the output language.
- Rules are written in English because identifiers are English and it costs fewer tokens. This does **not** change the output language - an English rule still produces Vietnamese comments when that is the configured output language.

## Common Commands

**Build and run the solution**:

```powershell
# Format code (required before commit)
dotnet format {ProjectName}.sln
dotnet format {ProjectName}.sln --verify-no-changes

# Build the whole solution
dotnet build {ProjectName}.sln
# Run all unit and integration tests
dotnet test {ProjectName}.sln
# Run unit tests for one module
dotnet test src/Services/{Module}/{Company}.{Module}.UnitTests/{Company}.{Module}.UnitTests.csproj
# Run integration tests for one module
dotnet test src/Services/{Module}/{Company}.{Module}.IntegrationTests/{Company}.{Module}.IntegrationTests.csproj

# Docker infrastructure for local dev (when the project uses it)
docker compose up -d
# Run one API project
dotnet run --project src/Services/{Module}/{Company}.{Module}.Api/{Company}.{Module}.Api.csproj
```

**Migration example** - DbUp (when the project uses DbUp):

```powershell
cd .dbup
dotnet run -- "Host=localhost;Port=5432;Database={database};Username=postgres;Password=postgres" {database} {schema} {schema}
```

Or EF Core Migrations:

```powershell
dotnet ef migrations add <Name> --project src/Services/{Module}/{Company}.{Module}.Infrastructure
dotnet ef database update --project src/Services/{Module}/{Company}.{Module}.Infrastructure
```

**Change log**
Every change must be documented in `change-logs/YYYY/MM/YYYY-MM-DD.md` (append at the end of the file) when the project enables the changelog policy.

**Code comments**
MUST follow `16-code-comments.md` and the Code comment section in `01-clean-architecture.md`.

## Error Handling

- Handlers return `Result<T>` / `Result` / `ResultPaged<T>` - do not throw exceptions for expected errors. Throwing `AppErrorFailureException` (or the project's equivalent) inside business logic is acceptable when the project's pattern allows it.
- The API maps errors through `ResultExtensions` -> `ProblemDetails` with user messages in the project's output language (use `ToApiResponse` to convert `Result<T>` / `Result` / `ResultPaged<T>` into an API response).
- Never expose stack traces in `ProblemDetails` outside development environments.

## Observability

- Inject `ILogger<>` -> Console -> OTel Collector -> the project's observability backend (Elastic APM, Grafana, Jaeger, Azure Monitor, Aspire Dashboard...). Mind the log levels: Debug, Info, Warning, Error (see `06-observability.md`).

## Frontend Stack (fill in only when the project has a frontend)

- Empty by default in the template. Common example: React + Vite + Tailwind CSS + a component library (Mantine/shadcn) + TanStack Query.
- No business logic in UI components.
- Vitest + Testing Library (frontend tests).

## Paths Reference (template - adjust to the real repo)

| Resource            | Path |
|---------------------|------|
| Personal task plan  | `.plans/<task-id>.md` (local only, never committed) |
| Changelog           | `change-logs/YYYY/MM/YYYY-MM-DD.md` |
| Database docs       | `docs/database/{database}.<schema>.md` |
| DbUp scripts        | `.dbup/Scripts/{database}/<schema>/<Schema\|Static>/` |
| AI rules (core)     | `.ai-rules/core/` (always load all 3 files first) |
| AI rules (detailed) | `.ai-rules/` |

## Placeholders in these rules

- `<placeholder>` (angle brackets) varies per case - for example `<schema>` differs per module. Substitute the right value each time; never treat it as fixed.
- A `{Placeholder}` still present after onboarding (typically `{Module}`, `{ServiceName}`, `{Aggregate}`) is a generic reference: substitute the module/service/aggregate you are working on.
- Full list and meanings: `.ai-rules/TEMPLATE_VARS.md`.
