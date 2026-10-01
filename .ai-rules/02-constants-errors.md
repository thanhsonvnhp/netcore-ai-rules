# 02 - Constants & Error Codes Centralization Rules

> **Root concept**: Every constant and error code must be declared centrally in **exactly 2 files per module** (`ErrorCodes.cs` and `Constants.cs`) in the Application layer. **NEVER** scatter magic numbers/strings through the code.

---

## Folder structure

Each module has **exactly 2 files** holding all error codes and constants for **every Aggregate** in that module:

```
src/Services/{Module}/
  {Company}.{Module}.Application/
    Constants/
      ErrorCodes.cs      <- namespace {Company}.{Module}.Application
      Constants.cs      <- namespace {Company}.{Module}.Application
```

Example (sample module `Acme.Catalog` - replace with the project's real module):

```
src/Services/Catalog/
  Acme.Catalog.Application/
    Constants/
      ErrorCodes.cs      <- namespace Acme.Catalog.Application.Constants
      Constants.cs      <- namespace Acme.Catalog.Application.Constants
```

---

## DO

1. **`ErrorCodes.cs` holds every error code in the module**, organized as a nested static class per Aggregate:

   ```csharp
   // src/Services/Catalog/Acme.Catalog.Application/Constants/ErrorCodes.cs
   namespace Acme.Catalog.Application;

   public static class ErrorCodes
   {
       public static class Product
       {
           public static readonly Error NAME_EMPTY      = Error.Failure("PRODUCT_NAME_EMPTY",      "Tên sản phẩm không được để trống.");
           public static readonly Error INVALID_PRICE   = Error.Failure("PRODUCT_INVALID_PRICE",   "Giá sản phẩm phải lớn hơn 0.");
           public static readonly Error NOT_FOUND       = Error.NotFound  ("PRODUCT_NOT_FOUND",       "Không tìm thấy sản phẩm.");
           public static readonly Error DUPLICATE_SKU   = Error.Failure  ("PRODUCT_DUPLICATE_SKU",   "SKU đã tồn tại trong hệ thống.");
       }

       public static class Order
       {
           public static readonly Error NOT_FOUND          = Error.NotFound ("ORDER_NOT_FOUND",          "Không tìm thấy đơn hàng.");
           public static readonly Error ALREADY_CANCELLED  = Error.Failure ("ORDER_ALREADY_CANCELLED",  "Đơn hàng đã bị huỷ.");
           public static readonly Error INSUFFICIENT_STOCK = Error.Failure ("ORDER_INSUFFICIENT_STOCK", "Số lượng tồn kho không đủ.");
       }
   }
   ```

   (The error messages above are in Vietnamese because that is this template's default output language - use the project's configured output language, see Language Policy in `core/01-project-hard-rules.md`.)

2. **`Constants.cs` holds every business constant in the module**, organized as a nested static class per Aggregate:

   ```csharp
   // src/Services/Catalog/Acme.Catalog.Application/Constants/Constants.cs
   namespace Acme.Catalog.Application;

   public static class Constants
   {
       public static class ProductConstants
       {
           public const int     NAME_MAX_LENGTH        = 200;
           public const int     DESCRIPTION_MAX_LENGTH = 2000;
           public const int     SKU_MAX_LENGTH         = 50;
           public const decimal MIN_PRICE             = 0.01m;
           public const decimal MAX_PRICE             = 1_000_000_000m;
       }

       public static class OrderConstants
       {
           public const int MAX_ITEMS_PER_ORDER   = 100;
           public const int MAX_QUANTITY_PER_ITEM = 9_999;
       }

       public static class CacheConstants
       {
           public const string PRODUCT_LIST_ALL        = "products:list:all";
           public static string ProductById(Guid id) => $"products:{id}";
       }

       public static class QueueConstants
       {
           public const string PRODUCT_CREATED = "catalog.product.created";
           public const string ORDER_PLACED    = "catalog.order.placed";
       }
   }
   ```

3. **Error codes use the format `"{AGGREGATE}_{UPPER_SNAKE_CASE_REASON}"`** - all uppercase, words separated by `_`:

   ```
   "PRODUCT_NOT_FOUND"
   "ORDER_ALREADY_CANCELLED"
   "INVOICE_AMOUNT_EXCEEDS_LIMIT"
   "USER_EMAIL_DUPLICATED"
   ```

**Constants use the format `"{AGGREGATE}_{UPPER_SNAKE_CASE}"`** - all uppercase, words separated by `_`:

   ```
   "NAME_MAX_LENGTH"
   "DESCRIPTION_MAX_LENGTH"
   "SKU_MAX_LENGTH"
   "MIN_PRICE"
   "MAX_PRICE"
   "MAX_ITEMS_PER_ORDER"
   "MAX_QUANTITY_PER_ITEM"
   ```

4. **A caller needs only one `using`** to reach every error and constant in the module:

   ```csharp
   using Acme.Catalog.Application;

   // Error codes:
   return ErrorCodes.Product.NotFound;
   return ErrorCodes.Order.AlreadyCancelled;

   // Constants:
   .MaximumLength(Constants.Product.NameMaxLength);
   ```

5. **Validators use the constants and error codes from the 2 centralized files**, never hardcoded values. **`.WithMessage()` and `.WithErrorCode()` must point to `ErrorCodes.*`, never a string literal:**

   ```csharp
   using Acme.Catalog.Application;

   // CORRECT
   RuleFor(x => x.Name)
       .NotEmpty().WithMessage(ErrorCodes.Product.NAME_EMPTY.Code)
       .MaximumLength(Constants.ProductConstants.NAME_MAX_LENGTH);
   RuleFor(x => x.Ids)
       .NotEmpty().WithMessage(ErrorCodes.FileSignature.ITEMS_EMPTY.Code);

   // WRONG - a hardcoded string in WithMessage
   RuleFor(x => x.Name).NotEmpty().WithMessage("Tên không được để trống.");
   RuleFor(x => x.Ids).NotEmpty().WithMessage("Danh sách không được rỗng.");

   // WRONG - a hardcoded number in MaximumLength
   RuleFor(x => x.Name).MaximumLength(200);
   ```

6. **An EF Fluent Configuration class uses constants**, never hardcoded values:

   ```csharp
   using Acme.Catalog.Application;

   // CORRECT
   builder.Property(p => p.Name)
          .HasColumnName("name")
          .HasMaxLength(Constants.ProductConstants.NameMaxLength)
          .IsRequired();

   // WRONG
   builder.Property(p => p.Name).HasMaxLength(200);
   ```

7. **A Domain entity uses constants when validating**, never hardcoded values:

   ```csharp
   using Acme.Catalog.Application;

   public static Result<Product> Create(string name, decimal price)
   {
       if (string.IsNullOrWhiteSpace(name))             return ErrorCodes.Product.NameEmpty;
       if (price < Constants.Product.MinPrice)          return ErrorCodes.Product.InvalidPrice;
       if (name.Length > Constants.Product.NameMaxLength) return ErrorCodes.Product.NameTooLong;
       // ...
   }
   ```

8. Use **`Error.Failure`** for logic errors in Application. The validation pipeline is the ONLY place that uses `Error.Validation`.

---

## DON'T

1. Do **NOT** inline an `Error` at the call site:

   ```csharp
   // WRONG
   return Error.NotFound("PRODUCT_NOT_FOUND", "Không tìm thấy.");
   return Result.Failure("ERR_001");
   ```

2. Do **NOT** create multiple scattered `*Errors.cs` or `*Constants.cs` files per Aggregate - each module has **exactly 2 files**:

   ```
   // WRONG - scattered per Aggregate
   Constants/
     ProductErrors.cs
     OrderErrors.cs
     ProductConstants.cs
     OrderConstants.cs

   // CORRECT - centralized in 2 files
   Constants/
     ErrorCodes.cs
     Constants.cs
   ```

3. Do **NOT** place `ErrorCodes.cs` / `Constants.cs` in the Domain or Infrastructure layer:

   ```
   // WRONG
   Acme.Catalog.Domain/Constants/ErrorCodes.cs
   Acme.Catalog.Infrastructure/Constants/ErrorCodes.cs

   // CORRECT
   Acme.Catalog.Application/Constants/ErrorCodes.cs
   ```

4. Do **NOT** use lowercase, PascalCase, or any mixed format for an error code string:

   ```csharp
   // WRONG
   "Product.NotFound"
   "product_not_found"
   "ProductNotFound"
   "ERR_001"

   // CORRECT
   "PRODUCT_NOT_FOUND"
   ```

5. Do **NOT** declare scattered `private const int X = 200;` inside a class - move it into `Constants.cs`.

6. Do **NOT** use a fully-qualified name at the call site - `using` the centralized namespace instead:

   ```csharp
   // WRONG
   return Acme.Catalog.Application.Constants.ErrorCodes.Product.NotFound;

   // CORRECT
   using Acme.Catalog.Application.Constants;
   return ErrorCodes.Product.NotFound;
   ```

7. Do **NOT** use a string literal as a message anywhere in the code - neither in a validator nor in business logic:

   ```csharp
   // WRONG - validator
   RuleFor(x => x.Ids).NotEmpty().WithMessage("Danh sách không được để trống.");

   // WRONG - business logic
   return Result.Failure(Error.Failure("ERR", "File không tìm thấy."));
   if (!isValid) throw new Exception("Dữ liệu không hợp lệ.");

   // CORRECT - every message goes through ErrorCodes.*
   RuleFor(x => x.Ids).NotEmpty().WithMessage(ErrorCodes.FileSignature.ITEMS_EMPTY.Code);
   return ErrorCodes.FileItem.NOT_FOUND;
   ```

---

## Checklist for the AI agent when generating code

- [ ] New error -> add to `{Company}.{Module}.Application/Constants/ErrorCodes.cs`, in the nested class for the right Aggregate
- [ ] New constant -> add to `{Company}.{Module}.Application/Constants/Constants.cs`, in the nested class for the right Aggregate
- [ ] Validator, EF Config, Domain method -> `using {Company}.{Module}.Application.Constants`, never hardcode
- [ ] Error code string -> must be `UPPER_SNAKE_CASE`, pattern `"{AGGREGATE}_{REASON}"`
- [ ] `.WithMessage()` in a validator -> must be `ErrorCodes.X.Y.Code`, never a string literal
- [ ] `Result.Failure(...)` in a handler/domain method -> must use a static constant from `ErrorCodes.*`, never inline `Error.Failure("...", "...")`
- [ ] No message string written directly in logic code - all of them go through `ErrorCodes.*`
- [ ] No new constants/errors file created outside the 2 designated files
