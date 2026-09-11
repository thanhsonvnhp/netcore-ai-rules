# 04 - API Contract Rules

## Scope

This document defines API contract rules for routing, request format, response format, errors, pagination, filtering, sorting, idempotency, and HTTP status codes.

---

## Protocol and Format

Use HTTP/HTTPS for API communication.

Use JSON as the default request and response format.

Use REST resource design.

Do not design API routes as actions.

---

## Route Rules

Use lowercase kebab-case resource names.

Use plural nouns for resource names.

Use nested resources only when the child resource depends on the parent resource.

Examples:

```http
GET /orders
GET /orders/{orderId}
POST /orders
PATCH /orders/{orderId}
DELETE /orders/{orderId}

GET /payment-methods
GET /shipping-addresses

GET /customers/{customerId}/orders
GET /orders/{orderId}/items
```

Do not use action-based routes:

```http
GET /getOrders
GET /getOrderById
POST /createOrder
POST /updateOrder
```

---

## API Versioning

Use URL-based API versioning when the API group is versioned.

Format:

```http
/api/v1/{resource}
```

Rules:

* Use URL versioning.
* Do not use query string versioning.
* Do not use header versioning.
* Configure OpenAPI document title and version explicitly.

---

## HTTP Methods

| Method   | Usage                                                     |
| -------- | --------------------------------------------------------- |
| `GET`    | Read data                                                 |
| `POST`   | Create resource or execute non-idempotent business action |
| `PUT`    | Replace full resource                                     |
| `PATCH`  | Update part of resource                                   |
| `DELETE` | Delete, cancel, or remove resource                        |

Examples:

```http
GET /orders/{orderId}
POST /orders
POST /orders/{orderId}/cancel
PUT /orders/{orderId}
PATCH /orders/{orderId}
DELETE /orders/{orderId}
```

---

## Request Headers

Use these headers consistently:

| Header            | Rule                                          |
| ----------------- | --------------------------------------------- |
| `Content-Type`    | Required for requests with body               |
| `Accept`          | Recommended for response format negotiation   |
| `Authorization`   | Required for authenticated APIs               |
| `Idempotency-Key` | Required for important mutating POST commands |
| `X-Trace-Id`      | Used for correlation when provided            |

Examples:

```http
Content-Type: application/json
Accept: application/json
Authorization: Bearer {access_token}
Idempotency-Key: {unique_request_id}
X-Trace-Id: {request_trace_id}
```

---

## Request Body

Request body uses JSON by default.

Use `multipart/form-data` only for upload APIs.

Use ISO 8601 UTC for date and time values.

Example:

```json
{
  "customerId": "cus_001",
  "createdAt": "2026-05-22T10:30:00Z",
  "items": [
    {
      "productId": "prd_001",
      "quantity": 2
    }
  ]
}
```

Rules:

* Use camelCase JSON property names.
* Use UTC datetime values.
* Do not send business context values that are resolved from token or trusted headers.
* Do not send tenant or workspace values in body when they are available from `ICurrentUser` (chi ap dung khi du an co multi-tenant/workspace).

---

## CancellationToken

Use `CancellationToken` from `HttpContext.RequestAborted` in every controller action.

Example:

```csharp
public async Task<IActionResult> GetById(
    Guid id,
    CancellationToken cancellationToken)
{
    var result = await sender.Send(
        new GetDocumentByIdQuery(id),
        cancellationToken);

    return result.ToApiResponse();
}
```

---

## Idempotency

Use `Idempotency-Key` for important mutating commands.

Examples:

* Create document
* Approve document
* Publish document
* Submit workflow action
* Create transaction

Controller example:

```csharp
public async Task<IActionResult> Create(
    [FromHeader(Name = "Idempotency-Key")] Guid? idempotencyKey,
    [FromBody] CreateDocumentRequest request,
    CancellationToken cancellationToken)
{
    var command = new CreateDocumentCommand(
        request.Title,
        request.Content,
        idempotencyKey);

    var result = await sender.Send(command, cancellationToken);

    return result.ToApiResponse();
}
```

Rules:

* Validate required idempotency key for important mutating POST commands.
* Return `409 Conflict` when the same idempotency key is reused with a different payload.
* Store idempotency records by key, request hash, response status, and response body when the feature is implemented.

---

## Success Response Format

Use native HTTP responses with direct DTO values.

Do not wrap successful responses in a top-level envelope.

Correct:

```json
{
  "id": "ord_001",
  "status": "created"
}
```

Correct paged response:

```json
{
  "items": [],
  "totalCount": 100,
  "page": 1,
  "pageSize": 20
}
```

Do not use this envelope:

```json
{
  "success": true,
  "code": 200,
  "messageCode": "SUCCESS",
  "message": "Operation completed successfully",
  "data": {},
  "pagination": {},
  "errors": []
}
```

---

## Success HTTP Status Codes

| Scenario                                |           Status |
| --------------------------------------- | ---------------: |
| Successful `GET`                        |         `200 OK` |
| Successful resource creation            |    `201 Created` |
| Accepted asynchronous request           |   `202 Accepted` |
| Successful update with no response body | `204 No Content` |
| Successful delete with no response body | `204 No Content` |

Rules:

* Return `201 Created` for POST resource creation.
* Include `Location` header for created resources.
* Return `204 No Content` for successful PUT, PATCH, or DELETE without response body.
* Do not return `200 OK` for every successful operation.

Example:

```csharp
return CreatedAtAction(
    nameof(GetById),
    new { id = response.Id },
    response);
```

---

## Error Response Format

Use `ProblemDetails` or `ValidationProblemDetails` for all error responses.

The project uses:

* `AddProblemDetails`
* `GlobalExceptionHandler`
* `ResultExtensions`
* `Result.ToApiResponse()`

Example:

```json
{
  "type": "https://httpstatuses.com/400",
  "title": "Validation Failed",
  "status": 400,
  "traceId": "00-abc123-def456-00",
  "errors": {
    "title": [
      "Title is required."
    ]
  }
}
```

Project extensions:

```json
{
  "type": "https://httpstatuses.com/409",
  "title": "Conflict",
  "status": 409,
  "traceId": "00-abc123-def456-00",
  "errorCode": "DOCUMENT_ALREADY_PUBLISHED",
  "errorDescription": "The document has already been published."
}
```

Rules:

* Return `ProblemDetails` for non-validation errors.
* Return `ValidationProblemDetails` for input validation errors.
* Include `traceId` in error responses.
* Include project error code in `ProblemDetails.Extensions`.
* Do not return custom error envelopes.

General error response example( already includes project extensions):

```json
{
    // problem details
    "type": "https://httpstatuses.com/422",
    "title": "Validation Failed",
    "status": 400,
    "traceId": "00-abc123-def456-00",
    
    // project extensions
    "success": false, 
    "code": 400, 
    "messageCode": "VALIDATION_ERROR",
    "message": "Lỗi tham số", 
    "data": null, 
    "errors": [
        { "key": "value" }, 
        { "field": "field", "message": "message"  }, 
    ]
}
```

---

## Error Code Naming

Use uppercase snake_case for business error codes.

Examples:

```text
VALIDATION_ERROR
RESOURCE_NOT_FOUND
DOCUMENT_ALREADY_PUBLISHED
IDEMPOTENCY_KEY_CONFLICT
RATE_LIMIT_EXCEEDED
```

Rules:

* Keep error codes meaningful.
* Store error code constants in one module-level location.
* Keep business error codes separate from HTTP status code names.
* Use localized user messages outside the error code itself.

---

## ErrorType to HTTP Status Mapping

| Error Type     |                 HTTP Status | Usage                                                           |
| -------------- | --------------------------: | --------------------------------------------------------------- |
| `NotFound`     |             `404 Not Found` | Resource does not exist                                         |
| `Validation`   |           `400 Bad Request` | Input or business validation failed                             |
| `Conflict`     |              `409 Conflict` | Duplicate data, concurrency conflict, or invalid state conflict |
| `Unauthorized` |          `401 Unauthorized` | Authentication required or invalid token                        |
| `Forbidden`    |             `403 Forbidden` | Authenticated user has insufficient permission                  |
| `Failure`      | `400 Bad Request`           | Business logic failure                                          |

Rules:

* FluentValidation errors return `400 Bad Request`.
* `Result.Validation` returns `400 Bad Request`.
* Do not map project validation errors to `422` in controllers.
* Keep status mapping centralized in `ResultExtensions`.

---

## Standard HTTP Codes

| Status | Code                     | Meaning                                                 |
| -----: | ------------------------ | ------------------------------------------------------- |
|  `200` | `OK`                     | Success                                                 |
|  `201` | `CREATED`                | Resource created                                        |
|  `202` | `ACCEPTED`               | Request accepted for asynchronous processing            |
|  `204` | `NO_CONTENT`             | Success without response body                           |
|  `400` | `BAD_REQUEST`            | Invalid request syntax or validation failure            |
|  `401` | `UNAUTHORIZED`           | Authentication required or invalid                      |
|  `403` | `FORBIDDEN`              | Permission denied                                       |
|  `404` | `RESOURCE_NOT_FOUND`     | Resource not found                                      |
|  `405` | `METHOD_NOT_ALLOWED`     | HTTP method not supported                               |
|  `409` | `CONFLICT`               | State conflict, duplicate data, or concurrency conflict |
|  `415` | `UNSUPPORTED_MEDIA_TYPE` | Unsupported request content type                        |
|  `429` | `RATE_LIMIT_EXCEEDED`    | Rate limit exceeded                                     |
|  `500` | `INTERNAL_ERROR`         | Internal server error                                   |
|  `502` | `BAD_GATEWAY`            | Gateway received invalid backend response               |
|  `503` | `SERVICE_UNAVAILABLE`    | Service unavailable                                     |
|  `504` | `GATEWAY_TIMEOUT`        | Gateway timeout                                         |

---

## Pagination

Use pagination for list APIs when the result set can grow.

Request query parameters:

| Parameter  | Rule                                          |
| ---------- | --------------------------------------------- |
| `page`     | 1-based page number; default `1`; minimum `1` |
| `pageSize` | Default `20`; minimum `1`; maximum `250`      |

Example:

```http
GET /orders?page=1&pageSize=20
```

Query example:

```csharp
public sealed record GetDocumentListQuery(
    int Page = 1,
    int PageSize = 20,
    string? Keyword = null)
    : IQuery<ResultPaged<DocumentSummaryDto>>;
```

Validation example:

```csharp
RuleFor(x => x.Page)
    .GreaterThanOrEqualTo(1);

RuleFor(x => x.PageSize)
    .InclusiveBetween(1, 250);
```

Response model:

```csharp
public sealed class ResultPaged<T> : Result
{
    public ResultPaged(bool isSuccess, Error error) : base(isSuccess, error)
    {
    }

    public ResultPaged(IEnumerable<T> data, PaginationModel paginationModel) : base(true, Error.None)
    {
        _paginationModel = paginationModel;
        _data = data;
    }

    public IEnumerable<T> Data { get { return _data; } set { _data = value; } }
    private IEnumerable<T> _data = Array.Empty<T>();
    public PaginationModel Pagination { get { return _paginationModel; } set { _paginationModel = value; } }
    private PaginationModel _paginationModel = new();

    public static ResultPaged<T> Success(IEnumerable<T> value, PaginationModel pagination) => new(value, pagination);
    public static new ResultPaged<T> Failure(Error error) => new(false, error);
    public static implicit operator ResultPaged<T>(Error error) => Failure(error);
}
```

Rules:

* Always include `totalCount` in paged responses.
* Use `page` and `pageSize` consistently.
* Do not allow unbounded `pageSize`.
* Use `ResultPaged<T>` when the project CQRS abstraction requires it.

---

## Filtering

Use query string parameters for filters.

Examples:

```http
GET /orders?status=1
GET /orders?status=1&departmentId=HANH_CHINH&search=so%20lon
GET /orders?status[0]=1&status[1]=4
GET /orders?incomeDocumentDate=2026-05-22T10:30:00Z
```

Rules:

* Use simple query parameters for scalar filters.
* Use indexed query parameters for array filters.
* Use ISO 8601 UTC for date filters.
* Do not expose tenant or workspace filters to standard client APIs when they are resolved from `ICurrentUser` (chi ap dung khi du an co multi-tenant/workspace).

---

## Sorting

Use `sort` query parameter.

Format:

```text
field:direction
```

Use comma-separated values for multiple fields.

Examples:

```http
GET /orders?sort=status:desc
GET /orders?sort=status:asc,createdAt:desc
```

Rules:

* Use `asc` for ascending order.
* Use `desc` for descending order.
* Validate sortable field names.
* Reject unknown sort fields.
* Do not pass raw sort values directly into SQL.

---

## OpenAPI

Configure OpenAPI metadata explicitly.

Rules:

* Set document title.
* Set document version.
* Describe request body and response status codes.
* Describe `ProblemDetails` responses.
* Describe pagination, filtering, and sorting query parameters.
* Describe `Idempotency-Key` header for idempotent commands.

---

## Restrictions

Do not return custom error objects instead of `ProblemDetails`.

Do not use mixed response envelopes for successful responses.

Do not omit `totalCount` from paged responses.

Do not use `200 OK` for every successful response.

Do not put tenant or workspace context in route path when it is resolved from `ICurrentUser` (chi ap dung khi du an co multi-tenant/workspace).

Do not accept unlimited `pageSize`.

Do not use action names in REST resource routes.

Do not use query parameter or header API versioning.

Do not trust client-supplied tenant or workspace values (chi ap dung khi du an co multi-tenant/workspace).

Do not concatenate raw filter or sort values into SQL.

---

## Related Components

* `AddProblemDetails`
* `GlobalExceptionHandler`
* `ResultExtensions`
* `Result.ToApiResponse()`
* `PagedResult<T>`
* `ResultPaged<T>`
* `ValidationBehavior`
* `HttpContext.RequestAborted`
* `Idempotency-Key`
* `X-Trace-Id`
