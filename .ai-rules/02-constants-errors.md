# 02 – Constants & Error Codes Centralization Rules

> **Root concept**: Mọi hằng số và mã lỗi phải được khai báo tập trung trong **2 file duy nhất mỗi module** (`ErrorCode.cs` và `Constants.cs`) tại Application layer. **KHÔNG** dùng magic number/string rải rác trong code.

---

## Cấu trúc thư mục

Mỗi module có **đúng 2 file** chứa toàn bộ error codes và constants của **tất cả Aggregate** trong module đó:

```
src/Services/{Module}/
  SmartOffice.{Module}.Domain/
    Constants/
      ErrorCodes.cs      ← namespace SmartOffice.{Module}.Domain
      Constants.cs      ← namespace SmartOffice.{Module}.Domain
```

Ví dụ thực tế (module Organization):

```
src/Services/Organization/
  SmartOffice.OrganizationManagement.Domain/
    Constants/
      ErrorCodes.cs      ← namespace SmartOffice.OrganizationManagement.Domain.Constants
      Constants.cs      ← namespace SmartOffice.OrganizationManagement.Domain.Constants
```

---

## DO

1. **`ErrorCodes.cs` chứa toàn bộ error codes của module**, tổ chức thành nested static class theo từng Aggregate:

   ```csharp
   // src/Services/Organization/SmartOffice.OrganizationManagement.Domain/Constants/ErrorCodes.cs
   namespace SmartOffice.OrganizationManagement.Domain;

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

2. **`Constants.cs` chứa toàn bộ business constants của module**, tổ chức thành nested static class theo từng Aggregate:

   ```csharp
   // src/Services/Organization/SmartOffice.OrganizationManagement.Domain/Constants/Constants.cs
   namespace SmartOffice.OrganizationManagement.Domain;

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
           public const string PRODUCT_CREATED = "organization.product.created";
           public const string ORDER_PLACED    = "organization.order.placed";
       }
   }
   ```

3. **Error code theo định dạng `"{AGGREGATE}_{UPPER_SNAKE_CASE_REASON}"`** — bắt buộc viết hoa toàn bộ, từ phân cách bằng `_`:

   ```
   "PRODUCT_NOT_FOUND"
   "ORDER_ALREADY_CANCELLED"
   "INVOICE_AMOUNT_EXCEEDS_LIMIT"
   "USER_EMAIL_DUPLICATED"
   ```
**Constant theo định dạng `"{AGGREGATE}_{UPPER_SNAKE_CASE}"`** - bắt buộc viết hoa toàn bộ, từ phân cách bằng `_`.:

   ```
   "NAME_MAX_LENGTH"
   "DESCRIPTION_MAX_LENGTH"
   "SKU_MAX_LENGTH"
   "MIN_PRICE"
   "MAX_PRICE"
   "MAX_ITEMS_PER_ORDER"
   "MAX_QUANTITY_PER_ITEM"
   ```

4. **Caller chỉ cần một `using` duy nhất** để truy cập toàn bộ errors và constants của module:

   ```csharp
   using SmartOffice.OrganizationManagement.Domain;

   // Error codes:
   return ErrorCodes.Product.NotFound;
   return ErrorCodes.Order.AlreadyCancelled;

   // Constants:
   .MaximumLength(Constants.Product.NameMaxLength);
   ```

5. **Validator dùng constants và error codes từ 2 file tập trung**, không hardcode giá trị trực tiếp. **`.WithMessage()` và `.WithErrorCode()` phải trỏ vào `ErrorCodes.*`, tuyệt đối không được là string literal:**

   ```csharp
   using SmartOffice.OrganizationManagement.Domain;

   // CORRECT
   RuleFor(x => x.Name)
       .NotEmpty().WithMessage(ErrorCodes.Product.NAME_EMPTY.Code)
       .MaximumLength(Constants.ProductConstants.NAME_MAX_LENGTH);
   RuleFor(x => x.Ids)
       .NotEmpty().WithMessage(ErrorCodes.FileSignature.ITEMS_EMPTY.Code);

   // WRONG — hardcode string trong WithMessage
   RuleFor(x => x.Name).NotEmpty().WithMessage("Tên không được để trống.");
   RuleFor(x => x.Ids).NotEmpty().WithMessage("Danh sách không được rỗng.");

   // WRONG — hardcode số trong MaximumLength
   RuleFor(x => x.Name).MaximumLength(200);
   ```

6. **EF Fluent Configuration Class dùng constants**, không hardcode:

   ```csharp
   using SmartOffice.OrganizationManagement.Domain;

   // CORRECT
   builder.Property(p => p.Name)
          .HasColumnName("name")
          .HasMaxLength(Constants.ProductConstants.NameMaxLength)
          .IsRequired();

   // WRONG
   builder.Property(p => p.Name).HasMaxLength(200);
   ```

7. **Domain entity dùng constants khi validate**, không hardcode:

   ```csharp
   using SmartOffice.OrganizationManagement.Domain;

   public static Result<Product> Create(string name, decimal price)
   {
       if (string.IsNullOrWhiteSpace(name))             return ErrorCodes.Product.NameEmpty;
       if (price < Constants.Product.MinPrice)          return ErrorCodes.Product.InvalidPrice;
       if (name.Length > Constants.Product.NameMaxLength) return ErrorCodes.Product.NameTooLong;
       // ...
   }
   ```

8. Dùng **Error.Failure** khi lỗi logic trong Application. CHỈ DUY NHẤT Validation Pipeline dùng `Error.Validation`
---

## DON'T

1. **KHÔNG** inline `Error` tại nơi dùng:

   ```csharp
   // WRONG
   return Error.NotFound("PRODUCT_NOT_FOUND", "Không tìm thấy.");
   return Result.Failure("ERR_001");
   ```

2. **KHÔNG** tạo nhiều file `*Errors.cs` hay `*Constants.cs` rải rác theo từng Aggregate — mỗi module chỉ có **đúng 2 file**:

   ```
   // WRONG — rải rác theo Aggregate
   Constants/
     ProductErrors.cs
     OrderErrors.cs
     ProductConstants.cs
     OrderConstants.cs

   // CORRECT — tập trung 2 file
   Constants/
     ErrorCode.cs
     Constants.cs
   ```

3. **KHÔNG** đặt file `ErrorCode.cs` / `Constants.cs` ở layer Domain hay Infrastructure:

   ```
   // WRONG
   SmartOffice.OrganizationManagement.Domain/Constants/ErrorCode.cs
   SmartOffice.OrganizationManagement.Infrastructure/Constants/ErrorCode.cs

   // CORRECT
   SmartOffice.OrganizationManagement.Application/Constants/ErrorCode.cs
   ```

4. **KHÔNG** dùng lowercase, PascalCase hay mixed format cho error code string:

   ```csharp
   // WRONG
   "Product.NotFound"
   "product_not_found"
   "ProductNotFound"
   "ERR_001"

   // CORRECT
   "PRODUCT_NOT_FOUND"
   ```

5. **KHÔNG** khai báo `private const int X = 200;` tản mạn trong class — phải gom về `Constants.cs`.

6. **KHÔNG** dùng fully-qualified name tại nơi gọi — phải `using` namespace tập trung:

   ```csharp
   // WRONG
   return SmartOffice.OrganizationManagement.Application.Constants.ErrorCode.Product.NotFound;

   // CORRECT
   using SmartOffice.OrganizationManagement.Application.Constants;
   return ErrorCode.Product.NotFound;
   ```

7. **KHÔNG** dùng string literal làm message ở bất kỳ đâu trong code — kể cả validator lẫn logic nghiệp vụ:

   ```csharp
   // WRONG — validator
   RuleFor(x => x.Ids).NotEmpty().WithMessage("Danh sách không được để trống.");

   // WRONG — business logic
   return Result.Failure(Error.Failure("ERR", "File không tìm thấy."));
   if (!isValid) throw new Exception("Dữ liệu không hợp lệ.");

   // CORRECT — tất cả message đều qua ErrorCodes.*
   RuleFor(x => x.Ids).NotEmpty().WithMessage(ErrorCodes.FileSignature.ITEMS_EMPTY.Code);
   return ErrorCodes.FileItem.NOT_FOUND;
   ```

---

## Checklist AI agent khi sinh code

- [ ] Thêm error mới → vào `SmartOffice.{Module}.Application/Constants/ErrorCode.cs`, nested class đúng Aggregate
- [ ] Thêm constant mới → vào `SmartOffice.{Module}.Application/Constants/Constants.cs`, nested class đúng Aggregate
- [ ] Validator, EF Config, Domain method → `using SmartOffice.{Module}.Application.Constants`, không hardcode
- [ ] Error code string → bắt buộc `UPPER_SNAKE_CASE`, pattern `"{AGGREGATE}_{REASON}"`
- [ ] `.WithMessage()` trong validator → phải là `ErrorCodes.X.Y.Code`, không phải string literal
- [ ] `Result.Failure(...)` trong handler/domain → phải dùng static constant từ `ErrorCodes.*`, không inline `Error.Failure("...", "...")`
- [ ] Không có string message nào viết trực tiếp trong code logic — tất cả qua `ErrorCodes.*`
- [ ] Không tạo file constants/errors mới ngoài 2 file quy định
