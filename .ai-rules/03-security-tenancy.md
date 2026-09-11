# 03 - Security & Tenancy Rules

## Scope

This document defines security, authorization, tenant, workspace, and audit rules for application code.

---

## Current User Context

Use `ICurrentUser` (abstraction trong Application, implement o Infrastructure) for authenticated user, tenant, and workspace context.

`ICurrentUser` is implemented by `CurrentUser` / `CurrentUserBase`.

The implementation resolves user context from:

* JWT claims
* Trusted headers forwarded by Gateway or BFF
* Test or background context through `SetCurrentUser(...)`

Example:

```csharp
public interface ICurrentUser
{
    string Id { get; }

    string UserName { get; }

    Guid? TenantId { get; }

    string? WorkspaceSlug { get; }

    void SetCurrentUser(...);
}
```

Rules:

* Register `ICurrentUser` as scoped.
* Inject `ICurrentUser` into Application and Infrastructure layers.
* Do not inject `ICurrentUser` into Domain layer.
* Do not create a separate `ITenantContext` abstraction unless the architecture rule is updated.
* Use `ICurrentUser.TenantId` and workspace properties for tenant and workspace context.

---

## Tenant and Workspace Resolution

Tenant and workspace context must come from trusted sources only.

Allowed sources:

* JWT claim
* `X-Workspace-Id` header forwarded by Gateway or BFF
* `X-Workspace-Slug` header forwarded by Gateway or BFF
* Explicit test or background context configured through `ICurrentUser.SetCurrentUser(...)`

Rules:

* Do not read `TenantId`, `WorkspaceId`, or `WorkspaceSlug` from request body.
* Do not read `TenantId`, `WorkspaceId`, or `WorkspaceSlug` from query string.
* Do not trust tenant or workspace headers from public clients.
* Gateway or BFF validates and forwards trusted workspace headers.
* Token claims take precedence over request payload values.

---

## Entity Tenancy

The reference implementation uses tenant and workspace context through `ICurrentUser`.

The reference module does not apply mandatory tenant filtering to every entity.

The reference module applies global soft-delete filtering through base DbContext (vi du `BaseAppDbContext`).

Tenant filtering is module-specific.

Rules:

* Use tenant-aware entity interfaces only for entities that require tenant isolation.
* Configure tenant or workspace query filters in module-specific DbContext configuration.
* Keep tenant filtering centralized in EF Core model configuration.
* Do not duplicate tenant filtering logic across handlers.

---

## Global Query Filters

Base DbContext cua du an (vi du `BaseAppDbContext`) applies soft-delete filtering.

Example:

```csharp
if (isSoftDelete)
{
    modelBuilder.Entity(entityType.ClrType)
        .HasQueryFilter(e => !((ISoftDelete)e).IsDeleted);
}
```

Modules can extend query filters through `ConfigureEntityQueryFilter()`.

Rules:

* Keep soft-delete filters enabled by default.
* Add tenant or workspace filters in module DbContext configuration.
* Use `.IgnoreQueryFilters()` only with explicit authorization and audit justification.
* Do not bypass global filters in normal query handlers.

---

## Authorization

Use policy-based authorization for sensitive business actions.

Example:

```csharp
[Authorize(Policy = "document:publish")]
```

Rules:

* Use authorization policies instead of hardcoded role checks.
* Define business permissions as policies.
* Check permissions before executing sensitive use cases.
* Keep authorization logic outside Domain layer.

Correct:

```csharp
var result = await authorizationService.AuthorizeAsync(
    user,
    "document:delete");
```

Incorrect:

```csharp
if (user.IsInRole("Admin"))
{
    // ...
}
```

---

## Admin Cross-Tenant Access

Admin bypass and cross-tenant queries require explicit protection.

Rules:

* Mark admin bypass endpoints or handlers with `[RequireAdminScope]`.
* Require policy-based authorization for admin bypass actions.
* Write audit log entries for all cross-tenant access.
* Include who, what, when, where, why, tenant, workspace, and target resource in audit data.
* Do not use admin bypass in standard user workflows.

---

## Audit Logging

Audit logs record business-relevant actions.

Audit log examples:

* User created a document.
* User published a document.
* User deleted a record.
* Admin accessed cross-tenant data.
* User changed workflow state.

Technical logs record operational events.

Technical log examples:

* Exception
* Request latency
* Retry
* Timeout
* Dependency failure

Rules:

* Keep audit logs separate from technical logs.
* Use audit logs for accountability and compliance.
* Use technical logs for diagnostics and operations.
* Do not store sensitive content in technical logs.

---

## Sensitive Data Logging

Do not log sensitive data.

Restricted data:

* Access token
* Refresh token
* Password
* Client secret
* Authorization header
* Cookie value
* OTP
* MFA secret
* Private key
* Personal identifiable information
* Confidential document content
* Tenant-sensitive payloads

Rules:

* Mask sensitive fields before logging.
* Log identifiers instead of full payloads.
* Log document IDs instead of document content.
* Log user IDs instead of full user profiles.
* Log tenant IDs only when required for traceability.

---

## Domain Layer Rules

Domain layer stays independent from authentication, authorization, and tenant resolution.

Rules:

* Do not inject `ICurrentUser` into Domain entities.
* Do not inject tenant context into Domain entities.
* Do not access `HttpContext` from Domain layer.
* Pass required business values into domain methods explicitly.
* Keep authorization checks in Application or API layer.
* Keep audit enrichment in Infrastructure interceptors or Application services.

---

## Infrastructure Integration

`UpdateAuditableEntitiesInterceptor` uses scoped `ICurrentUser` resolution to populate auditable fields.

Typical audit fields:

* `CreatedBy`
* `CreatedAt`
* `UpdatedBy`
* `UpdatedAt`
* `DeletedBy`
* `DeletedAt`

Rules:

* Use infrastructure interceptors for audit metadata.
* Do not set audit metadata manually in Domain entities.
* Do not require Domain layer to know the authenticated user.

---

## Restrictions

Do not hardcode role strings in controllers or handlers.

Do not read tenant or workspace context from request body.

Do not read tenant or workspace context from query string.

Do not trust tenant or workspace headers from public clients.

Do not disable global query filters without authorization and audit justification.

Do not log tokens, passwords, secrets, OTP values, confidential content, or sensitive personal data.

Do not inject `ICurrentUser` into Domain layer.

Do not place authorization logic in Domain entities.

Do not mix audit logs with technical logs.

---

## Related Components

* `ICurrentUser` (vi du `{Company}.Application.Abstractions.ICurrentUser` - thay bang namespace thuc te)
* `CurrentUser` / `CurrentUserBase` (implement trong Infrastructure)
* Base DbContext cua du an (vi du `BaseAppDbContext`)
* `ConfigureEntityQueryFilter()`
* `UpdateAuditableEntitiesInterceptor`
* `[Authorize(Policy = "...")]`
* `[RequireAdminScope]`
