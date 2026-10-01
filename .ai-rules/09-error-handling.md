# 09 - Error Handling & Exception Strategy Rules

---

## Error Strategy: Result Pattern First

The project uses the **Result Pattern** (a `Common/` folder, or a shared library when modular - for example `{Company}.BuildingBlock.Domain.Shared`) as the primary error handling mechanism. Exceptions are only for unhandled/system errors.

```
[OK] Command Handler -> return Result<T>.Failure(error)   // or implicit from Error   // ALL LOGIC ERRORS IN Application USE `Error.Failure` ONLY
[OK] Query Handler -> return ProductErrors.NotFound
[OK] Validator (FluentValidation) -> ValidationBehavior returns Result.Failure(Error.Validation(...)).
[OK] Domain Entity Factory -> return Result<T>.Failure(domainError)
[FAIL] Do NOT use exceptions for business rule violations
```

**GlobalExceptionHandler** (`IExceptionHandler`) only catches:

- Unhandled exceptions (bugs, null refs, external failures)
- It does NOT catch Result failures - those are handled in the Controller via `result.ToApiResponse()` (or `error.ToApiResponse()`).

See `GlobalExceptionHandler.cs` in Api/Middleware.

---

## Result Pattern Types

```
Common/ (or `{Company}.BuildingBlock.Domain.Shared` when split into a shared library)
--- Result.cs          # IsSuccess, IsFailure, Error ; has a guard + an implicit operator from Error
--- ResultT.cs         # Result<T> : Value
--- Error.cs           # readonly record struct Error(string Code, string Description, ErrorType Type)
|                      # static: None, Failure(code,desc), Validation(...), NotFound(...), Conflict(...), Unauthorized(...)
--- ErrorType.cs       # enum Failure | Validation | NotFound | Conflict | Unauthorized (add Forbidden/ServiceUnavailable if the project needs them)
```

---

## DO

1. **Use the Result Pattern** in every handler:

   ```csharp
   public async ValueTask<Result> Handle(DeleteDocumentCommand cmd, CancellationToken ct)
   {
       if (result.IsFailure)
           return Result.Failure(DocumentErrors.NotFound);
       // ...
       return Result.Success();
   }
   ```

2. **Define predefined errors** in Domain:

   ```csharp
   public static class DocumentErrors
   {
       public static readonly Error NotFound = Error.NotFound(
           "Document.NotFound",
           "The document with the specified identifier was not found.");

       public static readonly Error AlreadyPublished = Error.Failure(
           "Document.AlreadyPublished",
           "The document has already been published and cannot be modified.");

       public static readonly Error ConcurrencyConflict = Error.Conflict(
           "Document.ConcurrencyConflict",
           "The document was modified by another user. Please refresh and retry.");
   }
   ```

3. **Map `Error.Type` to an HTTP status** in `ResultExtensions` (Api layer):

   | ErrorType | HTTP Status | Note |
   |---|---|---|
   | `NotFound` | 404 | |
   | `Validation` | 400 BadRequest (+ ValidationProblemDetails) | Business validation from Result or FluentValidation |
   | `Conflict` | 409 | |
   | `Unauthorized` | 401 | |
   | `Failure` (default) | 500 | |

   (Business validation maps to 400, not 422 - pick one and stay consistent across the whole project.)

   **Error code style**:
   - `Error.Code`: `"Module.Entity.Reason"` (for example `"Document.NotFound"`) - placed into the ProblemDetails `extensions["errorCode"]` + the ValidationProblemDetails key.
   - Public error code returned to the client: meaningful UPPER_SNAKE_CASE (`RESOURCE_NOT_FOUND`, `VALIDATION_ERROR`, `IDEMPOTENCY_KEY_CONFLICT`, `TOKEN_EXPIRED`...) - see `04-api-contract.md`. When the project has a centralized error code catalog (BA/API spec), prefer codes from that catalog and keep them consistent with the Error factories in Domain.

   Example response body:

   ```json
   {
      "success": false,
      "code": 400,
      "messageCode": "VALIDATION_ERROR",
      "message": "One or more validation errors occurred.",
      "errors": [
        {
          "field": "pageSize",
          "message": "PageSize must be between 1 and 250."
        }
      ]
   }
   ```

4. **GlobalExceptionHandler** only catches real exceptions (see Middleware/GlobalExceptionHandler.cs):

   ```csharp
   public async ValueTask<bool> TryHandleAsync(HttpContext ctx, Exception ex, CancellationToken ct)
   {
       _logger.LogError(ex, "Unhandled exception occurred");
       // Return a 500 ProblemDetails (detail only in Development)
       ...
   }
   ```

5. **Validation failures** (FluentValidation via ValidationBehavior) and business `Result.Validation` both go through the mapping that returns 400.

## DON'T

1. Do **NOT** use exceptions for business rule violations:

   ```csharp
   // [FAIL] WRONG - an exception for a business rule
   if (!doc.CanPublish()) throw new DocumentAlreadyPublishedException(doc.Id);
   // [OK] CORRECT - the Result pattern
   var result = doc.Publish(publishedBy);
   if (result.IsFailure) return result;
   ```

2. Do **NOT** throw a generic `Exception` or `ApplicationException`:

   ```csharp
   // [FAIL] WRONG
   throw new Exception("Document not found");
   // [OK] CORRECT
   return DocumentErrors.NotFound;
   ```

3. Do **NOT** log the same exception multiple times along the same call stack (log once, at the middleware).

4. Do **NOT** expose stack traces or inner exception details in the response body in production.

5. Do **NOT** use exceptions for control flow:

   ```csharp
   // [FAIL] WRONG
   try { var doc = _repo.GetById(id); }
   catch (NotFoundException) { return false; }
   // [OK] CORRECT
   var result = await _queryHandler.Handle(new GetDocumentByIdQuery(id), ct);
   ```

6. Do **NOT** catch `OperationCanceledException` and log it as an Error - that is normal behavior when a client disconnects.

7. Do **NOT** use an exception hierarchy (DomainException, NotFoundException) for business errors - use static `Error` constants.

## Illustrative example

```csharp
// -- {Company}.BuildingBlock.Domain.Shared.Common.Error (actual)
namespace Common;  // for example: {Company}.BuildingBlock.Domain.Shared.Common when split into shared


/// <summary>
/// Represents the type of an error.
/// </summary>
public enum ErrorType
{
    /// <summary>
    /// No error. for success Result
    /// </summary>
    None,
    /// <summary>
    /// For business logic errors.
    /// </summary>
    Failure,
    /// <summary>
    /// For validation errors on MediatR pipeline.
    /// </summary>
    Validation,
    /// <summary>
    /// For not found errors.
    /// </summary>
    NotFound,
    /// <summary>
    /// For conflict errors.
    /// </summary>
    Conflict,
    /// <summary>
    /// For unauthorized errors.
    /// </summary>
    Unauthorized,
    /// <summary>
    /// For forbidden errors.
    /// </summary>
    Forbidden,
    /// <summary>
    /// For unhandled errors.
    /// </summary>
    Unhandled
}

/// <summary>
/// Represents an error that can occur in the application.
/// </summary>
/// <param name="Code"></param>
/// <param name="Description"></param>
/// <param name="Type"></param>
/// <param name="Errors">Detailed error in Validation exception</param>
public readonly record struct Error(string Code, string Description, ErrorType Type, Dictionary<string, object>? Errors = null)
{
    public static readonly Error None = new(string.Empty, string.Empty, ErrorType.None);

    public static Error Failure(string code, string description) =>
        new(code, description, ErrorType.Failure);

    public static Error Validation(string code, string description, Dictionary<string, object> errors) =>
        new(code, description, ErrorType.Validation, errors);

    public static Error NotFound(string code, string description) =>
        new(code, description, ErrorType.NotFound);

    public static Error Conflict(string code, string description) =>
        new(code, description, ErrorType.Conflict);

    public static Error Unauthorized(string code, string description) =>
        new(code, description, ErrorType.Unauthorized);

    public static Error Forbidden(string code, string description) =>
        new(code, description, ErrorType.Forbidden);
}

// -- {Company}.BuildingBlock.Domain.Shared.Common.Result (actual, with a guard)
namespace Common;  // for example: {Company}.BuildingBlock.Domain.Shared.Common when split into shared

public class Result
{
    protected Result(bool isSuccess, Error error)
    {
        if (isSuccess && error != Error.None)
        {
            throw new InvalidOperationException("Success result cannot have an error.");
        }

        if (!isSuccess && error == Error.None)
        {
            throw new InvalidOperationException("Failure result must have an error.");
        }

        IsSuccess = isSuccess;
        Error = error;
    }

    public bool IsSuccess { get; }
    public bool IsFailure => !IsSuccess;

    public Error Error
    {
        get;
    }

    public static Result Success() => new(true, Error.None);

    public static Result Failure(Error error) => new(false, error);

    // public static implicit operator Result() => Success();

    public static implicit operator Result(Error error) => Failure(error);
}

public sealed class Result<T> : Result
{
    private readonly T _value;

    private Result(T value) : base(true, Common.Error.None)
    {
        _value = value;
    }

    private Result(Error error) : base(false, error)
    {
        _value = default!;
    }

    public T Data => _value;

    public static Result<T> Success(T value) => new(value);

    public static new Result<T> Failure(Error error) => new(error);

    public static implicit operator Result<T>(T value) => Success(value);

    public static implicit operator Result<T>(Error error) => Failure(error);
}

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

public class PaginationModel
{
    public long Page { get; set; }
    public long PageSize { get; set; }
    public long TotalItems { get; set; }
    public long TotalPages { get; set; }
}
```

```csharp
// -- Domain aggregate
public sealed class Product : AggregateRoot<ProductId>
{
    public static Result<Product> Create(...) { ... return Result<Product>.Success(p); }
    public Result Update(...) { if (invalid) return ProductErrors.NameEmpty; ... return Result.Success(); }
}

// -- ResultExtensions (Api) - (Validation -> 400)
public static class ResultExtensions
{
    public static IActionResult ToApiResponse<T>(this Result<T> result) { ... }
    // switch ErrorType -> NotFoundObjectResult(404), BadRequestObjectResult + ValidationProblemDetails(400) for Validation,
    // Conflict(409), Unauthorized(401), default 500 ProblemDetails
}

// -- Handler
internal sealed class CreateProductCommandHandler(...) : ICommandHandler<CreateProductCommand, ProductId>
{
    public async ValueTask<Result<ProductId>> Handle(...)
    {
        var r = Product.Create(...);
        if (r.IsFailure) return r;   // implicit or explicit
        ...
        return Result<ProductId>.Success(id);
    }
}

// -- GlobalExceptionHandler (unhandled only)
internal sealed class GlobalExceptionHandler(...) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext httpContext, Exception exception, CancellationToken ct)
    {
        _logger.LogError(exception, "Unhandled exception occurred");
        // 500 ProblemDetails (detail only in Development)
        ...
    }
}
```
