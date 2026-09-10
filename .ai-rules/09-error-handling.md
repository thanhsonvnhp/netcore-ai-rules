# 09 – Error Handling & Exception Strategy Rules

---

## Error Strategy: Result Pattern First (thực tế hiện tại)

Dự án dùng **Result Pattern** (từ SmartOffice.BuildingBlock.Domain.Shared.Common) làm primary error handling mechanism. Exception chỉ dùng cho unhandled/system errors.

```
✅ Command Handler → return Result<T>.Failure(error)   // hoặc implicit từ Error   // TẤT CẢ LỖI LOGIC TRONG Application CHỈ DÙNG `Error.Failure`
✅ Query Handler → return ProductErrors.NotFound
✅ Validator (FluentValidation) → ValidationBehavior trả Result.Failure(Error.Validation(...)).
✅ Domain Entity Factory → return Result<T>.Failure(domainError)
❌ KHÔNG dùng exception cho business rule violations
```

**GlobalExceptionHandler** (IExceptionHandler) chỉ catch:

- Unhandled exceptions (bugs, null refs, external failures)
- KHÔNG catch Result failures — chúng được handle ở Controller qua `result.ToApiResponse()` (hoặc error.ToApiResponse()).

Xem `GlobalExceptionHandler.cs` trong Api/Middleware.

---

## Result Pattern Types (thực tế BuildingBlock)

```
SmartOffice.BuildingBlock.Domain.Shared/Common/
├── Result.cs          # IsSuccess, IsFailure, Error ; có guard + implicit operator từ Error
├── ResultT.cs         # Result<T> : Value
├── Error.cs           # readonly record struct Error(string Code, string Description, ErrorType Type)
│                      # static: None, Failure(code,desc), Validation(...), NotFound(...), Conflict(...), Unauthorized(...)
└── ErrorType.cs       # enum Failure | Validation | NotFound | Conflict | Unauthorized (hiện chưa có Forbidden/ServiceUnavailable trong factories)
```

---

## DO

1. **Dùng Result Pattern** cho mọi handler:

   ```csharp
   public async ValueTask<Result> Handle(DeleteDocumentCommand cmd, CancellationToken ct)
   {
       if (result.IsFailure)
           return Result.Failure(DocumentErrors.NotFound);
       // ...
       return Result.Success();
   }
   ```

2. **Định nghĩa predefined errors** trong Domain:

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

3. **Map Error.Type sang HTTP status** trong `ResultExtensions` (Api layer):

   | ErrorType | HTTP Status (hiện tại) | Ghi chú |
   |---|---|---|
   | `NotFound` | 404 | |
   | `Validation` | 400 BadRequest (+ ValidationProblemDetails) | Business validation từ Result hoặc FV |
   | `Conflict` | 409 | |
   | `Unauthorized` | 401 | |
   | `Failure` (default) | 500 | |

   (Một số rule cũ ghi 422 cho business validation. Code thực tế map Validation → 400.)

   **Error code style**:
   - Current `Error.Code`: "Module.Entity.Reason" (ví dụ "Document.NotFound") — được đưa vào ProblemDetails `extensions["errorCode"]` + ValidationProblemDetails key.
   - Nguồn gốc xlsx khuyến nghị: UPPER_SNAKE_CASE có nghĩa (RESOURCE_NOT_FOUND, VALIDATION_ERROR, IDEMPOTENCY_KEY_CONFLICT, INCOMMING_DOC_MISSED_ATTACHMENT_FILE, TOKEN_EXPIRED...). File module nên có sheet tổng hợp mã lỗi. Ưu tiên dùng code rõ nghĩa từ sheet khi có thể; giữ consistency với Error factories trong Domain.
   - HttpCode sheet (bilingual) liệt kê đầy đủ status + custom messageCode tương ứng — dùng làm tham khảo khi định nghĩa Error static (09) và ResultExtensions.

   Body response ví dụ:

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

4. **GlobalExceptionHandler** chỉ catch thật sự exceptions (xem Middleware/GlobalExceptionHandler.cs):

   ```csharp
   public async ValueTask<bool> TryHandleAsync(HttpContext ctx, Exception ex, CancellationToken ct)
   {
       _logger.LogError(ex, "Unhandled exception occurred");
       // Trả 500 ProblemDetails (detail chỉ ở Development)
       ...
   }
   ```

5. **Validation failures (FluentValidation qua ValidationBehavior)** và business Result.Validation đều đi qua mapping trả 400.

## DON'T

1. **KHÔNG** dùng exception cho business rule violations:

   ```csharp
   // ❌ WRONG — dùng exception cho business rule
   if (!doc.CanPublish()) throw new DocumentAlreadyPublishedException(doc.Id);
   // ✅ CORRECT — dùng Result pattern
   var result = doc.Publish(publishedBy);
   if (result.IsFailure) return result;
   ```

2. **KHÔNG** throw generic `Exception` hay `ApplicationException`:

   ```csharp
   // ❌ WRONG
   throw new Exception("Document not found");
   // ✅ CORRECT
   return DocumentErrors.NotFound;
   ```

3. **KHÔNG** log exception nhiều lần trong cùng call stack (log once tại middleware).

4. **KHÔNG** expose stack trace, inner exception details ra response body ở production.

5. **KHÔNG** dùng exception để điều khiển control flow:

   ```csharp
   // ❌ WRONG
   try { var doc = _repo.GetById(id); }
   catch (NotFoundException) { return false; }
   // ✅ CORRECT
   var result = await _queryHandler.Handle(new GetDocumentByIdQuery(id), ct);
   ```

6. **KHÔNG** catch `OperationCanceledException` và log như Error — đây là hành vi bình thường khi client disconnect.

7. **KHÔNG** dùng Exception hierarchy (DomainException, NotFoundException) cho business errors — dùng `Error` static constants.

## Ví dụ minh họa

```csharp
// ── SmartOffice.BuildingBlock.Domain.Shared.Common.Error (thực tế)
namespace SmartOffice.BuildingBlock.Domain.Shared.Common;


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

// ── SmartOffice.BuildingBlock.Domain.Shared.Common.Result (thực tế, có guard)
namespace SmartOffice.BuildingBlock.Domain.Shared.Common;

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
// ── Domain aggregate
public sealed class Product : AggregateRoot<ProductId>
{
    public static Result<Product> Create(...) { ... return Result<Product>.Success(p); }
    public Result Update(...) { if (invalid) return ProductErrors.NameEmpty; ... return Result.Success(); }
}

// ── ResultExtensions (Api) — (Validation → 400)
public static class ResultExtensions
{
    public static IActionResult ToApiResponse<T>(this Result<T> result) { ... }
    // switch ErrorType → NotFoundObjectResult(404), BadRequestObjectResult + ValidationProblemDetails(400) cho Validation,
    // Conflict(409), Unauthorized(401), default 500 ProblemDetails
}

// ── Handler
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

// ── GlobalExceptionHandler (chỉ unhandled)
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
