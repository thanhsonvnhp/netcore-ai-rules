# 01 - SmartOffice Hard Rules & Project Map (Core - Always Load)

## Business Overview

SmartOffice Backend Core is a **modular backend in a microservices platform** supporting digital office operations for enterprises and institutions, including:

- Organizational management and structure
- Internal product/service catalogs (e.g., desk booking, office resources)
- Reliable event-driven workflows and notifications
- Document handling(Incoming Documents, Outgoing Documents, Submission Documents), access control, and automation
- Meeting / Vehicle / Personal Task / Schedule management
- Internal LMS (Learning Management System) and training management

The platform is built as a **modular system**. All services follow **strict Clean Architecture**.

## Repository Map (Must-Know Locations)

### Documentation & Rules

- `docs/Apply Vertical Slice in Clean Architecture .NET API.md` — **Mandatory** detailed guide for vertical slice implementation in the API layer (handler structure, validation, response formatting). Focus from `## 7. The Hybrid Approach — Vertical Slice in Clean Architecture` to `## 11. Design Checklists`.
- `docs/Entity-Domain-And-OutboxEvent.md` — Authoritative design for Domain Events + Integration Events + transactional Outbox.
- `.ai-rules/` — Hard rules and guidelines (architecture, CQRS, security, API contract, testing, EF Core, error handling, etc.). 15 rule files are the unified source for naming (C# + DB), REST contract, HttpCode + error codes, data types, PL/pgSQL, EF registration, C#14, editorconfig, response format.

### Source Code Structure

- `SmartOffice.slnx`
- `src/BuildingBlocks/**` — Shared libraries only (zero business logic): Authentication, Caching, Domain.Shared, Application.Shared, Persistence, EventBus.MassTransit, Observability.
- `src/Services/**` — Microservices:
  - `Organization/SmartOffice.OrganizationManagement.*` (Api/Application/Domain/Infrastructure + Unit/IntegrationTests) — current reference full CA implementation.
  - `OfficeManage/SmartOffice.OfficeManage.*` — full CA split.
  - `Identity/SmartOffice.Identity.Api` — single project (non-split), contains OIDC/identity logic.
  - `BFF/SmartOffice.Bff.WebApi` — single project API.
  - Other modules follow the same split pattern once implemented.
- DbUp scripts per schema under `.dbup/Scripts/smart_office/<schema>/<Schema|Static>`.
- Database documentation per schema under `docs/database/smart_office.<schema>.md`.
- `change-logs/YYYY/MM/YYYY-MM-DD.md` — daily changelog entries (fenced YAML) for every commit that has API/contract/DB/shared impact. **Mandatory**.

### Database & DevOps

- `.dbup/Scripts/smart_office/<schema>/` — **All** database changes (DbUp). No direct SQL in code.
- `change-logs/` — Changelog guide + template (fenced YAML) + daily change log data files (**REQUIRED** for every commit that has API/contract/DB/shared impact).
- `docker-compose.yml` — Quick start: APIs services + postgres + redis/valkey.

**Key governance and implementation guides (in .ai-rules/):**

- [01-clean-architecture.md](.ai-rules/01-clean-architecture.md) — Clean Architecture rules and guidelines
- [02-constants-errors.md](.ai-rules/02-constants-errors.md) — Error codes and constants
- [02-cqrs-pattern.md](.ai-rules/02-cqrs-pattern.md) — CQRS pattern and handler conventions
- [03-security-tenancy.md](.ai-rules/03-security-tenancy.md) — Security, multi-tenancy and auth rules
- [04-api-contract.md](.ai-rules/04-api-contract.md) — API/contract change rules and versioning
- [05-resilience.md](.ai-rules/05-resilience.md) — Resilience and retry policies
- [06-observability.md](.ai-rules/06-observability.md) — Logging, tracing and metrics
- [07-testing.md](.ai-rules/07-testing.md) — Unit and integration testing guidelines
- [08-ef-core.md](.ai-rules/08-ef-core.md) — EF Core usage and conventions
- [09-error-handling.md](.ai-rules/09-error-handling.md) — Error handling and problem details
- [10-dependency-injection.md](.ai-rules/10-dependency-injection.md) — DI and composition rules
- [11-configuration.md](.ai-rules/11-configuration.md) — Configuration structure and secrets
- [12-caching.md](.ai-rules/12-caching.md) — Caching strategies and patterns
- [13-background-jobs.md](.ai-rules/13-background-jobs.md) — Background job and scheduler rules
- [14-database-rule.md](.ai-rules/14-database-rule.md) — Database rules and migration policies
- [15-commit-change-log.md](.ai-rules/15-commit-change-log.md) — Commit changelog template and requirements

## Frameworks & Architecture

- **Clean Architecture**: Dependency direction strictly `Domain <- Application <- Infrastructure <- API`. No violations.
- **Frameworks**: .NET 10, EF Core, ASP.NET Core Web API.
- **Domain**: Zero external dependencies, zero NuGet packages, pure C# only.
- **Application**: Owns commands/queries/handlers/validators + all `I*` abstractions.
- **Infrastructure**: EF Core, Redis, JWT, outbox, external services.
- **API**: Controllers, middleware, Scalar/OpenAPI, health checks, auth via SSO, telemetry.

## Database & Migration (Mandatory)

- Every schema/static data change **requires** a script in `.dbup/Scripts/smart_office/<schema>/<Schema|Static>`.
- Use the `database-migration-creator` skill. **No direct SQL in code** or ad-hoc changes.
- 9 mandatory audit columns on every table: `tenant_id`, `created_at`, `created_by`, `updated_at`, `updated_by`, `deleted_at`, `deleted_by`, `is_deleted`, `row_version`.
- Soft delete: set `is_deleted = true` — no `DELETE FROM`, `DROP TABLE`, `DROP COLUMN`, `RENAME COLUMN` ever.(Soft delete via EF Core Interceptor or `IsDeleted` filter on DbContext).
- All tables: snake_case names(table_name, column_name, index_name), Vietnamese column comments.

## Changelog Requirement (Mandatory)

- API/contract/DB/shared impact changes **require** a daily changelog entry in `change-logs/`.
- Use task ID (e.g. `#JA-123`) in title. Commit the log with the code.
- Follow `.ai-rules/15-commit-change-log.md` and `change-logs/README.md`. (`change-log-documentation` skill is available to generate the changelog entry).

## Testing

- Unit tests for Domain and Application layers: xUnit v3 + NSubstitute + FluentAssertions.
- Integration tests for API layer: WebApplicationFactory + Testcontainers (PostgreSQL/Redis).
- No UI tests (BFF is API-only).

## Messaging (Outbox-First)

- Use **transactional Outbox** for reliable "publish after commit".
- Code must depend only on `IMessagePublisher`.
- Integration Event will be publish at the end of Mediator pipeline.
- Full design: see `docs/Entity-Domain-And-OutboxEvent.md`.

## Language Preference

- Prefer **Vietnamese** for user-facing message text, code comments explaining logic, and log messages (where visible to developers/users).
- English is acceptable for technical identifiers and internal exception messages.

## Common Commands

**Build and run solution:**

```powershell

# Run format code (required before commit code)
dotnet format SmartOffice.slnx
dotnet format SmartOffice.slnx --verify-no-changes

# Build All solution
dotnet build SmartOffice.slnx
# Run all unit and integration tests
dotnet test SmartOffice.slnx
# Run unit tests for a specific module
dotnet test src/Services/<Module>/SmartOffice.<Module>.UnitTests/SmartOffice.<Module>.UnitTests.csproj
# Run integration tests for a specific module
dotnet test src/Services/<Module>/SmartOffice.<Module>.IntegrationTests/SmartOffice.<Module>.IntegrationTests.csproj

# Run docker infrastructure for local development (Postgres + Redis)
docker compose up -d postgres redis
# Run a specific API project (replace <Module> with the module name)
dotnet run --project src/Services/<Module>/SmartOffice.<Module>.Api/SmartOffice.<Module>.Api.csproj -lp http
```

**DbUp migration example**:

```powershell
cd .dbup
dotnet run -- "Host=localhost;Port=5432;Database=smart_office;Username=postgres;Password=postgres" smart_office organization organization
```
Or: 
```sh
cd .dbup
./wait-for-it.sh 127.0.0.1:5432 -- "dotnet" "run" "Host=127.0.0.1:5432;Database=smart_office;Username=postgres;Password=postgres;port=5432;" "smart_office" "<schema>" "<schema>"
```

**Change log**
EVERY CHANGE MUST BE DOCUMENTED in `change-logs/YYYY/MM/YYYY-MM-DD.md` (append at the end). Use `change-log-documentation` skill and see `change-logs/README.md` for details.

**Code comment**: 
 MUST Flow **Code comment** on `01-clean-architecture.md`.

## Error Handling

- Handlers return `Result<T>` or `Result` or `ResultPaged<T>` — never throw exceptions for expected errors. Allow throw `AppErrorFailureException` while processing business logic.
- API maps errors via `ResultExtensions` → `ProblemDetails` with Vietnamese user messages (use `ToApiResponse` to convert `Result<T>` or `Result` or `ResultPaged<T>` to API responses).
- No stack traces in `ProblemDetails` responses in non-dev environments.

## Observability

- Inject ILogger<> to log to Console -> Otel Collector -> ELK stack (Chú ý Rule Log Level: Debug, Infor, Warn, Error)

## Frontend Stack (this repo is backend-only, but the frontend stack is defined for consistency)

- React + Vite + Tailwind CSS + Mantine UI components + Mantine Form ( based on React Hook Form ) + TanStack Query.
- No business logic in UI components.
- Vitest + Testing Library (frontend tests).

## Paths Reference

| Resource            | Path |
|---------------------|------|
| Feature workspace/Working tree   | `.specify/features/<jira>_<title>/` |
| Changelog           | `change-logs/YYYY/MM/YYYY-MM-DD.md` |
| Database docs       | `docs/database/smart_office.<schema>.md` |
| DbUp scripts        | `.dbup/Scripts/smart_office/<schema>/<Schema\|Static>/` |
| AI rules (core)     | `.ai-rules/core/` (always load first 3 files) |
| AI rules (detailed) | `.ai-rules/` (15+ files) |
| Skills              | `.agents/skills/<name>/SKILL.md` |
