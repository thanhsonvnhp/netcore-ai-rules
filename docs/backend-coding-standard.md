Quy chuẩn Lập trình Hệ thống Thống nhất: C#.NET 10 và PostgreSQL
================================

Sự phối hợp hiệu quả giữa tầng ứng dụng sử dụng ngôn ngữ hướng đối tượng tĩnh như C#.NET 10 / C# 14 và hệ quản trị cơ sở dữ liệu quan hệ PostgreSQL đòi hỏi một hệ thống quy chuẩn lập trình chặt chẽ. Tài liệu này thiết lập các tiêu chuẩn thống nhất nhằm tối ưu hóa tính rõ ràng, hiệu năng thực thi và khả năng bảo trì mã nguồn cho toàn bộ đội ngũ phát triển. Việc tuân thủ nghiêm ngặt các quy chuẩn này giúp thu hẹp khoảng cách kiến trúc giữa hệ thống kiểu dữ liệu của C# (sử dụng PascalCase) và mô hình lưu trữ phi đại diện của PostgreSQL (sử dụng snake_case).

> Tài liệu này quy định chuẩn đặt tên, format, C# 14 và PostgreSQL/EF Core/Npgsql áp dụng cho mọi dự án .NET trong template.
> Đọc khi cần tra cứu naming, EF mapping, PL/pgSQL hoặc review code có đúng chuẩn hay không.

**Tài liêu tham khảo**
 * [C# identifier naming rules and conventions](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/coding-style/identifier-names)
 * [Common C# code conventions](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/coding-style/coding-conventions)
 * [Npgsql](https://www.npgsql.org/doc/index.html)
 * [Npgsql Entity Framework Core Provider](https://www.npgsql.org/efcore/index.html)

### 1. Quy chuẩn Đặt tên trong C# (.NET 10 / C# 14)

Việc định danh nhất quán là bước đầu tiên để duy trì một cơ sở mã nguồn dễ đọc và dễ mở rộng. Các quy ước dưới đây được kế thừa trực tiếp từ chuẩn thiết kế của Microsoft kết hợp với các thực tế vận hành hệ thống lớn.

**1.1. Quy tắc Đặt tên Cơ bản cho Định danh**

Mọi định danh trong mã nguồn C# phải bắt đầu bằng một chữ cái hoặc ký tự gạch dưới (_). Định danh cần ưu tiên tính rõ ràng và khả năng đọc hiểu tiếng Anh tự nhiên hơn là sự ngắn gọn. Việc sử dụng các từ viết tắt không phổ biến hoặc các ký tự viết tắt tùy tiện bị loại bỏ hoàn toàn nhằm tránh gây hiểu lầm.

```csharp
// ❌ SAI: Đặt tên viết tắt khó hiểu, không rõ nghĩa
var getWin = GetWin();
var edOrg = new EducationOrganization();

// ✔️ ĐÚNG: Ưu tiên rõ nghĩa hơn ngắn gọn, dùng thuật ngữ đầy đủ
var activeWindow = GetWindow();
var educationOrganization = new EducationOrganization();
```

**1.2. Quản lý Quy tắc Casing, Tiền tố và Hậu tố**

Mã nguồn C# áp dụng nhất quán hai phong cách viết hoa chính là PascalCase và camelCase. Bảng dưới đây tóm tắt quy tắc áp dụng cho các thành phần phổ biến:

| Thành phần | Kiểu Casing | Tiền tố / Hậu tố | Ví dụ thực tế |
|---|---|---|---|
| Namespace | PascalCase | Không có | Enterprise.BillingService.Core |
| Class, Record, Struct, Enum | PascalCase | Không có | InvoiceProcessor, PaymentStatus |
| Interface | PascalCase | Tiền tố `I` | InvoiceRepository |
| Abstract Class | PascalCase | Hậu tố `Base` | ControllerRepositoryBase |
| Extension Class | PascalCase | Hậu tố `Extensions` | ByteArrayExtensions |
| Method | PascalCase | Động từ hoặc cặp động từ-danh từ | CalculateDiscount, SaveInvoiceAsync |
| Property & Constant | PascalCase | Không có | CreatedAtUtc, MaxRetryAttempts |
| Local Variable & Argument | camelCase | Không có | invoiceTotal, customerId |
| Private / Internal Field | camelCase | Tiền tố `_` (ví dụ `_logger`) hoặc `__` cho tiền tố nội bộ | `__dbContext`, `_logger` |
| Static Field/Constant | PascalCase / UPPER_SNAKE_CASE | Tiền tố `s_` (nếu cần phân biệt) | CacheInterval |

**1.3. Quy chuẩn Đặt tên trong Primary Constructor (C# 12+)**

Cách đặt tên tham số trong Primary Constructor phụ thuộc trực tiếp vào bản chất của kiểu khai báo :

Đối với Record: Các tham số tự động được trình biên dịch chuyển đổi thành các thuộc tính công khai (public properties). Do đó, bắt buộc sử dụng kiểu PascalCase.

Đối với Class và Struct: Các tham số đóng vai trò như các biến trong phạm vi lớp. Bắt buộc sử dụng kiểu camelCase (như tham số hàm thông thường).

```csharp
// ❌ SAI: Dùng camelCase cho record hoặc PascalCase cho class
public record Customer(string firstName, string lastName);

public class UserService(IUserRepository UserRepository)
{
    public async Task GetUserAsync() => await UserRepository.GetByIdAsync(Guid.NewGuid());
}

// ✔️ ĐÚNG: Record dùng PascalCase, Class dùng camelCase chuẩn xác
public record Customer(string FirstName, string LastName);

public class UserService(IUserRepository userRepository)
{
    public async Task GetUserAsync() => await userRepository.GetByIdAsync(Guid.NewGuid());
}
```

**1.4. Quy chuẩn cho Generic và Phiên bản hóa API**

Khi thiết kế các thành phần generic, tham số kiểu dữ liệu phải được đặt tên rõ ràng, bắt đầu bằng ký tự T kết hợp với tên mô tả ý nghĩa (ví dụ: TInput, TOutput). Đối với việc nâng cấp các API hiện có, sử dụng hậu tố số nguyên tăng dần (ví dụ: IOrderService2) thay vì hậu tố Ex mơ hồ.

### 2. Quy chuẩn Định dạng, Bố cục và Tài liệu hóa Mã nguồn

Định dạng mã nguồn đồng nhất giúp tối ưu hóa khả năng đọc hiểu trên các công cụ xem mã và giảm thiểu xung đột dòng lệnh khi trộn mã trên hệ thống Git.

**2.1. Định dạng Dấu ngoặc nhọn và Thụt lề**

Mã nguồn C# bắt buộc sử dụng phong cách định dạng Allman. Cả dấu mở ngoặc nhọn { và dấu đóng ngoặc nhọn } đều phải bắt đầu trên một dòng mới độc lập, căn lề thẳng hàng với mức thụt lề của câu lệnh quản lý khối tương ứng. Hệ thống bắt buộc sử dụng thụt lề bằng 4 khoảng trắng (spaces), không sử dụng ký tự Tab.

```csharp
// ❌ SAI: Đặt dấu ngoặc nhọn tùy tiện, viết gộp dòng, thụt lề bằng Tab
if (id == Guid.Empty) {
    	throw new ArgumentException("Mã hóa đơn không hợp lệ."); }

// ✔️ ĐÚNG: Định dạng Allman chuẩn mực, thẳng hàng, dùng 4 khoảng trắng
if (id == Guid.Empty)
{
    throw new ArgumentException("Mã hóa đơn không hợp lệ.", nameof(id));
}
```

**2.2. Khoảng trắng và Quản lý Ngoại lệ**

Mỗi dòng mã chỉ được phép chứa tối đa một câu lệnh. Chỉ thực hiện bắt (catch) các ngoại lệ cụ thể mà hệ thống thực sự có khả năng xử lý hoặc phục hồi an toàn. Nghiêm cấm việc bắt ngoại lệ chung System.Exception mà không đi kèm bộ lọc ngoại lệ hoặc ghi nhật ký hệ thống.

```csharp
// ❌ SAI: Bắt Exception quá chung chung không xử lý gì
try
{
    var data = File.ReadAllText("config.json");
}
catch (Exception)
{
    // Nuốt lỗi, làm mất dấu vết hệ thống
}

// ✔️ ĐÚNG: Bắt ngoại lệ cụ thể, ghi nhật ký rõ ràng và bẫy lỗi có chủ đích
try
{
    var data = File.ReadAllText("config.json");
}
catch (FileNotFoundException ex)
{
    _logger.LogWarning(ex, "Tệp cấu hình config.json không tồn tại. Sử dụng cấu hình mặc định.");
    LoadDefaultConfig();
}
```

**2.3. Chú thích Dòng đơn và Tài liệu hóa XML**

Chú thích dòng đơn (//) phải được đặt trên một dòng riêng biệt phía trên đoạn mã cần giải thích, bắt đầu bằng chữ cái viết hoa và kết thúc bằng dấu chấm. Phải có một khoảng trắng phân tách giữa ký tự // và nội dung chú thích. Bắt buộc sử dụng chú thích định dạng XML (///) cho tất cả các public/protected members.

```csharp
// ❌ SAI: Viết chú thích ở cuối dòng code, không viết hoa, không dấu chấm
var discount = 0.1m; // ap dung giam gia 10%

// ✔️ ĐÚNG: Chú thích dòng riêng biệt, viết hoa, kết thúc bằng dấu chấm và có khoảng trắng
// Áp dụng chương trình khuyến mãi giảm giá 10% cho thành viên VIP.
var discount = 0.1m;
```

### 3. Cấu hình Phong cách Lập trình Hiện đại (C# 14 /.NET 10)

Sự phát triển của.NET 10 mang đến nhiều cải tiến cú pháp giúp tối giản mã nguồn, tăng hiệu năng và ngăn ngừa lỗi runtime.

**3.1. Tính năng Field-Backed Properties (Từ khóa field trong C# 14)**

Khi cần thực hiện kiểm tra điều kiện (validation) hoặc xử lý logic trong các thuộc tính tự động, sử dụng từ khóa field của C# 14 để truy cập trực tiếp vào trường sao lưu tự động sinh ra bởi trình biên dịch, tránh khai báo thủ công các trường private dư thừa.

```csharp
// Cú pháp trước C# 14: Khai báo trường private thủ công gây dài dòng, dư thừa mã nguồn
private string _email = string.Empty;
public string Email
{
    get => _email;
    set => _email = value?? throw new ArgumentNullException(nameof(value));
}

// ✔️ ĐÚNG: Sử dụng từ khóa 'field' của C# 14 tối giản hóa cú pháp, an toàn và rõ ràng
public string Email
{
    get;
    set => field = value?? throw new ArgumentNullException(nameof(value));
}
```

**3.2. C# 14 Property Extensions (Extension Members)**

Sử dụng cú pháp mở rộng thành viên (Extension Members) của C# 14 để gắn thêm các thuộc tính mở rộng trực tiếp vào các kiểu dữ liệu có sẵn (như ClaimsPrincipal trong bảo mật) thay vì viết các lớp static helper rườm rà.

```csharp
// Cú pháp trước C# 14: Viết class static Helper bắt buộc gọi qua phương thức tĩnh rườm rà
public static class ClaimsPrincipalExtensions
{
    public static string? GetSubjectId(this ClaimsPrincipal principal)
    {
        return principal.FindFirst("sub")?.Value;
    }
}
// Cách dùng cũ: User.GetSubjectId();

// ✔️ ĐÚNG: Khai báo Extension Property của C# 14 trực quan và có tính đóng gói cao
public static class ClaimsPrincipalExtensions
{
    extension(ClaimsPrincipal principal)
    {
        public string? SubjectId => principal.FindFirst("sub")?.Value;
        public string? Email => principal.FindFirst(ClaimTypes.Email)?.Value;
    }
}
// Cách dùng mới cực kỳ tự nhiên: if (User.SubjectId is null) {... }
```

**3.3. Sử dụng var và So sánh Chuỗi**

Sử dụng từ khóa var khi và chỉ khi kiểu dữ liệu trả về của biểu thức bên phải là hoàn toàn rõ ràng từ cú pháp khai báo. Sử dụng string.Empty thay vì "" khi so sánh hoặc gán chuỗi rỗng.

```csharp
// ❌ SAI: Dùng var khi kiểu dữ liệu không rõ ràng, dùng chuỗi rỗng "" để so sánh
var data = GetConfigurationValue(); 
if (data == "")
{
    data = "default";
}

// ✔️ ĐÚNG: Khai báo tường minh khi kiểu dữ liệu mập mờ, dùng string.Empty rõ ràng
string data = GetConfigurationValue();
if (data == string.Empty)
{
    data = "default";
}
```

**3.4 Tệp cấu hình quy tắc đính trong project**
```ini
// .editorconfig
# tệp tin cấu hình gốc.editorconfig dành cho dự án C#.NET 10 
root = true

[*.cs]
# Ràng buộc định dạng cơ bản: Thụt lề bằng khoảng trắng, độ dài 4 
indent_style = space
indent_size = 4
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

# Ràng buộc dấu ngoặc nhọn kiểu Allman: Đưa ngoặc nhọn về dòng mới 
csharp_new_line_before_open_brace = all
csharp_new_line_before_else = true
csharp_new_line_before_catch = true
csharp_new_line_before_finally = true

# Ràng buộc quy định viết câu lệnh và khai báo trên một dòng độc lập 
csharp_preserve_single_line_statements = false
csharp_preserve_single_line_blocks = false

# -----------------------------------------------------------------------------
# QUY TẮC ĐẶT TÊN BIỂU TƯỢNG (NAMING CONVENTIONS) 
# -----------------------------------------------------------------------------

# Lớp, cấu trúc, bản ghi, enum: PascalCase 
dotnet_naming_rule.types_should_be_pascal_case.severity = error
dotnet_naming_rule.types_should_be_pascal_case.symbols = all_types
dotnet_naming_rule.types_should_be_pascal_case.style = pascal_case_style

dotnet_naming_symbols.all_types.applicable_kinds = class, struct, interface, enum, delegate
dotnet_naming_symbols.all_types.applicable_accessibilities = *
dotnet_naming_style.pascal_case_style.capitalization = pascal_case

# Interfaces: PascalCase có tiền tố 'I' bắt buộc 
dotnet_naming_rule.interfaces_should_be_i_pascal_case.severity = error
dotnet_naming_rule.interfaces_should_be_i_pascal_case.symbols = interface_symbols
dotnet_naming_rule.interfaces_should_be_i_pascal_case.style = i_pascal_case_style

dotnet_naming_symbols.interface_symbols.applicable_kinds = interface
dotnet_naming_symbols.interface_symbols.applicable_accessibilities = *
dotnet_naming_style.i_pascal_case_style.capitalization = pascal_case
dotnet_naming_style.i_pascal_case_style.required_prefix = I

# Private instance fields: camelCase và tiền tố dấu gạch dưới (_) 
dotnet_naming_rule.private_instance_fields_should_be_underscore_camel_case.severity = error
dotnet_naming_rule.private_instance_fields_should_be_underscore_camel_case.symbols = private_instance_fields
dotnet_naming_rule.private_instance_fields_should_be_underscore_camel_case.style = underscore_camel_case_style

dotnet_naming_symbols.private_instance_fields.applicable_kinds = field
dotnet_naming_symbols.private_instance_fields.applicable_accessibilities = private
dotnet_naming_symbols.private_instance_fields.required_modifiers =!static
dotnet_naming_style.underscore_camel_case_style.capitalization = camel_case
dotnet_naming_style.underscore_camel_case_style.required_prefix = _

# Private static fields: ưu tiên PascalCase; UPPER_SNAKE_CASE (`MY_CONST`) cũng được chấp nhận cho static nếu cần phân biệt
dotnet_naming_rule.private_static_fields_should_be_pascal_case.severity = warning
dotnet_naming_rule.private_static_fields_should_be_pascal_case.symbols = private_static_fields
dotnet_naming_rule.private_static_fields_should_be_pascal_case.style = s_pascal_case_style

dotnet_naming_symbols.private_static_fields.applicable_kinds = field
dotnet_naming_symbols.private_static_fields.applicable_accessibilities = private
dotnet_naming_symbols.private_static_fields.required_modifiers = static
dotnet_naming_style.s_pascal_case_style.capitalization = pascal_case

# Hằng số (Constants): UPPER_SNAKE_CASE bắt buộc
dotnet_naming_rule.constants_should_be_upper_snake_case.severity = error
dotnet_naming_rule.constants_should_be_upper_snake_case.symbols = constants_symbols
dotnet_naming_rule.constants_should_be_upper_snake_case.style = upper_snake_style

dotnet_naming_symbols.constants_symbols.applicable_kinds = field
dotnet_naming_symbols.constants_symbols.required_modifiers = const
dotnet_naming_style.upper_snake_style.capitalization = all_upper
dotnet_naming_style.upper_snake_style.word_separator = _

# -----------------------------------------------------------------------------
# QUY TẮC PHONG CÁCH LẬP TRÌNH (STYLE & LANGUAGE PREFERENCES) [2]
# -----------------------------------------------------------------------------

# Ràng buộc sử dụng var [3, 2]
csharp_style_var_for_built_in_types = false:error
csharp_style_var_when_type_is_apparent = true:error
csharp_style_var_elsewhere = false:suggestion

# So khớp mẫu (Pattern Matching) và tối giản hóa logic [2]
csharp_style_pattern_matching_over_as_with_null_check = true:error
csharp_style_pattern_matching_over_is_with_cast_check = true:error
dotnet_style_prefer_is_null_check_over_reference_equality_method = true:error

# Ràng buộc sử dụng dấu ngoặc nhọn trong câu lệnh rẽ nhánh [4, 2]
csharp_prefer_braces = true:error

# Ép buộc sắp xếp đúng thứ tự bộ sửa đổi (modifiers: public private static readonly) [2]
csharp_preferred_modifier_order = public,private,protected,internal,file,static,extern,new,virtual,abstract,sealed,readonly,unsafe,volatile,async:error
```

### 4. Quy chuẩn Thiết kế và Đặt tên Cơ sở Dữ liệu PostgreSQL

Để tránh các lỗi runtime liên quan đến cơ chế tự động chuyển đổi định danh viết hoa thành viết thường của PostgreSQL, toàn bộ cơ sở dữ liệu PostgreSQL bắt buộc phải áp dụng quy chuẩn chữ viết thường kết hợp dấu gạch dưới (snake_case) một cách nhất quán.

**4.1 Quy chuẩn Đặt tên Đối tượng Cơ sở Dữ liệu (Bảng, Cột, Ràng buộc và Chỉ mục)**

Để tối ưu hóa tính rõ ràng, nhất quán và đảm bảo an toàn vận hành, toàn bộ các đối tượng cơ sở dữ liệu trong PostgreSQL phải tuân thủ quy chuẩn đặt tên sau:

| Loại đối tượng | Kiểu Casing | Định dạng / Cú pháp đặt tên | Ví dụ thực tế | Ghi chú & Quy tắc thiết kế |
|---|---|---|---|---|
| Bảng (Tables) | snake_case | Danh từ số nhiều | products, categories | Tuyệt đối không dùng tiền tố dư thừa như `tbl_` hoặc `t_`. Có thể thêm prefix cho module trong trường hợp nhiều mobile trong một schema. Khuyến nghị tách mỗi module một schema |
| Cột (Columns) | snake_case | Danh từ số ít | name, price | Khóa chính của bảng luôn đặt tên nhất quán là `id`. |
| Khóa chính (PK) | snake_case | `pk_{table_name}` | `pk_categories` | Định danh ràng buộc khóa chính của bảng. |
| Cột khóa ngoại | snake_case | `{referenced_table_singular}_id` | `category_id` | Thể hiện tường minh cột liên kết khóa ngoại. |
| Ràng buộc khóa ngoại (FK) | snake_case | `fk_{table_name}_{referenced_table}_{column_name}` | `fk_products_categories_category_id` | Tạo bằng `ALTER TABLE` sau khi toàn bộ bảng đã được khởi tạo để tránh phụ thuộc vòng. |
| Ràng buộc duy nhất (UQ) | snake_case | `uq_{table_name}_{column_name}` | `uq_categories_code` | Định danh ràng buộc giá trị cột không trùng lặp. |
| Ràng buộc kiểm tra (CK) | snake_case | `ck_{table_name}_{constraint_name}` | `ck_orders_positive_total_price` | Định danh ràng buộc kiểm tra logic nghiệp vụ. |
| Chỉ mục thường (Index) | snake_case | `idx_{table_name}_{column_name}` | `idx_products_category_id` | Tăng hiệu năng cho các cột thường xuyên được lọc. |
| Chỉ mục một phần (Partial Index) | snake_case | `idx_{table_name}_{column_name}_partial` | `idx_products_created_at_partial` | Thêm hậu tố `_partial` khi chỉ mục có điều kiện `WHERE`. |
| Chỉ mục đính kèm (Covering Index) | snake_case | `idx_{table_name}_{column_name}_includes` | `idx_users_display_name_includes` | Dùng hậu tố `_includes` để chỉ các cột thêm vào covering index. |

```sql
-- ❌ SAI: Đặt tên hỗn hợp PascalCase, dùng danh từ số ít cho bảng, tiền tố tbl_ dư thừa, nhúng khóa ngoại trực tiếp gây lỗi phụ thuộc vòng
CREATE TABLE "tbl_Product" (
    "ProductId" UUID PRIMARY KEY,
    "CategoryId" UUID REFERENCES "Category"("Id"),
    "ProductName" TEXT NOT NULL,
    "Price" NUMERIC
);

-- ✔️ ĐÚNG: Sử dụng snake_case nhất quán, bảng số nhiều, cột số ít.
-- Khởi tạo cấu trúc bảng sạch trước, thêm ràng buộc FK và Index bổ trợ sau.

-- Bước 1: Tạo tất cả các bảng liên quan (chỉ bao gồm cột, PK nội tuyến và UQ/CK cơ bản)
CREATE TABLE categories (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    code VARCHAR(50) NOT NULL,
    CONSTRAINT uq_categories_code UNIQUE (code)
);

CREATE TABLE products (
    id UUID PRIMARY KEY,
    category_id UUID NOT NULL,
    name TEXT NOT NULL,
    price NUMERIC(18,2) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,  -- BOOLEAN LUÔN LUÔN NOT NULL  VÀ CÓ DEFAULT
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Bước 2: Thiết lập ràng buộc khóa ngoại (FK) bằng ALTER TABLE sau khi tạo xong toàn bộ bảng
ALTER TABLE products 
ADD CONSTRAINT fk_products_categories_category_id 
FOREIGN KEY (category_id) REFERENCES categories(id);

-- Bước 3: Thiết lập các chỉ mục (Indexes) để tối ưu hóa hiệu năng truy vấn
CREATE INDEX idx_products_category_id ON products(category_id);
CREATE INDEX idx_products_created_at_partial ON products(created_at) WHERE is_active = TRUE;
```

**4.3. Khuyến nghị Chọn Kiểu Dữ liệu Tối ưu và Ánh xạ sang C# (.NET 10)**
Để đảm bảo tính toàn vẹn dữ liệu, tối ưu dung lượng lưu trữ và đồng bộ hóa chặt chẽ giữa tầng ứng dụng và cơ sở dữ liệu, toàn bộ đội ngũ bắt buộc phải tuân thủ bảng quy chuẩn ánh xạ kiểu dữ liệu sau đây:

| Loại dữ liệu | Kiểu PostgreSQL | Kiểu C# (.NET 10) | Bản chất kỹ thuật & khuyến nghị thiết kế |
|---|---|---|---|
| UUID | `uuid` | `System.Guid` | Lưu dạng nhị phân 128-bit; hiệu năng và dung lượng tốt hơn so với lưu GUID dưới dạng chuỗi. Dùng cho cột định danh `id`. |
| Chuỗi văn bản | `text` | `System.String` (`string`) | Khuyên dùng thay cho `varchar(N)` để tránh cần migration khi thay đổi độ dài; PostgreSQL xử lý `text` hiệu năng tương đương. |
| Số nguyên | `integer` / `bigint` | `int` / `long` | `integer` (4 bytes) cho hầu hết các cột số; `bigint` (8 bytes) cho counters lớn hoặc PK tự tăng ở quy mô lớn. |
| Số thập phân | `decimal(18,2)` | `System.Decimal` (`decimal`) | Dùng cho tính toán tài chính; đảm bảo độ chính xác tuyệt đối, tránh sai số của float/double. |
| Logic | `boolean` | `System.Boolean` (`bool`) | Lưu giá trị true/false; không dùng số (0/1) hay ký tự (Y/N) để biểu thị trạng thái. |
| Ngày giờ | `timestamptz` | `System.DateTime` | "timestamp with time zone" — lưu dưới UTC, tránh lệch múi giờ trong môi trường phân tán. |
| Mảng | `type[]` (ví dụ: `text[]`) | `T[]` hoặc `List<T>` | PostgreSQL hỗ trợ cột mảng; dùng khi tập giá trị nhỏ và cố định; cân nhắc normalisation nếu mối quan hệ phức tạp. |
| Bán cấu trúc (JSON) | `jsonb` | `System.Text.Json.JsonDocument` hoặc POCO class hoặc `string` | Lưu JSON dạng nhị phân đã phân tích cú pháp; tận dụng chỉ mục GIN; ánh xạ qua Complex Types/JSON mapping trong EF Core cho truy vấn & cập nhật hiệu năng. |

Nếu cần, đưa thêm ví dụ cột/định danh tương ứng (ví dụ: `id UUID`, `name TEXT`, `price NUMERIC(18,2)`) vào cột Ghi chú.

### 5. Tích hợp Thực thể với EF Core 10 và Npgsql

**5.1 Tích hợp DBContext vào DI**

```csharp
// ❌ SAI: EF Core tự quản lý pool kết nối độc lập, cấu hình phân mảnh và kém hiệu năng
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection"))
          .UseSnakeCaseNamingConvention());

// ✔️ ĐÚNG: Khởi tạo NpgsqlDataSource tập trung và cấu hình DI hợp nhất

// 00. Cài đặt một số cờ ứng dụng
AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true); // khi dùng kiểu timestampz  map với DateTime c#

// Bước 1: Khởi tạo NpgsqlDataSourceBuilder để cấu hình ADO.NET Driver
var dataSourceBuilder = new NpgsqlDataSourceBuilder(builder.Configuration.GetConnectionString("DefaultConnection"));

// Thêm các cấu hình nâng cao cấp hệ thống tại đây (ví dụ: MapEnum, UseJsonNet, Logging, Plugins) 
var dataSource = dataSourceBuilder.Build();

// Bước 2: Đăng ký DataSource dưới dạng Singleton vào DI Container
builder.Services.AddSingleton<DbDataSource>(dataSource);
builder.Services.AddSingleton<NpgsqlDataSource>(dataSource);

// Bước 3: Đăng ký DbContext sử dụng DataSource được lấy từ DI
builder.Services.AddDbContext<AppDbContext>((services, options) =>
{
    var dbDataSource = services.GetRequiredService<NpgsqlDataSource>();
    options.UseNpgsql(dbDataSource) // Đăng ký DbContext sử dụng nguồn kết nối hợp nhất
          .UseSnakeCaseNamingConvention();
});
```


**5.2. Tự động hóa snake_case thông qua Naming Conventions**

Để bảo toàn phong cách viết PascalCase trong mã nguồn C# nhưng lưu trữ dưới dạng snake_case trong PostgreSQL, dự án sử dụng thư viện EFCore.NamingConventions đăng ký trong cấu hình DbContext.

```csharp
// ❌ SAI: Thực hiện thủ công bằng cách viết đè chuỗi cấu hình bảng từng dòng rườm rà
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    modelBuilder.Entity<Customer>().ToTable("customers");
    modelBuilder.Entity<Customer>().Property(c => c.FirstName).HasColumnName("first_name");
    // Dễ sai sót và cực kỳ tốn thời gian bảo trì
}

// ✔️ ĐÚNG: Tự động hóa hoàn toàn ở tầng cấu hình DbContext
protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
{
    optionsBuilder
       .UseNpgsql(connectionString)
       .UseSnakeCaseNamingConvention(); // Chuyển đổi tự động toàn bộ sang snake_case
}
```

**5.2. Ánh xạ JSONB bằng Complex Types (Tính năng đột phá .NET 10)**

Trong.NET 10, để ánh xạ các trường dữ liệu bán cấu trúc JSONB của PostgreSQL, bắt buộc dùng Complex Types thông qua API ComplexProperty thay thế hoàn toàn cho giải pháp "Owned Entities" cũ nhằm tối ưu hiệu năng và cho phép cập nhật hàng loạt.

```csharp
// Định nghĩa cấu trúc dữ liệu lưu trữ
public class Product
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public ProductSpecification Specs { get; set; } = new(); // Complex Type
}

public class ProductSpecification
{
    public string Brand { get; set; } = string.Empty;
    public int RamGigabytes { get; set; }
}

// ❌ SAI (Cơ chế cũ - Owned Entities): Gây ra tracking rườm rà, không hỗ trợ ExecuteUpdate
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    modelBuilder.Entity<Product>().OwnsOne(p => p.Specs, builder => { builder.ToJson(); });
}

// ✔️ ĐÚNG (Cơ chế.NET 10 - Complex Types): Tối giản, không shadow primary keys, cho phép ExecuteUpdate
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    modelBuilder.Entity<Product>().ComplexProperty(p => p.Specs, builder => builder.ToJson());
}
```

Nhờ sử dụng Complex Types trong.NET 10, thao tác cập nhật hàng loạt đạt hiệu năng vượt trội :

```csharp
// KHI CHỈ CÓ MỘT CÂU LỆNH UPDATE 
// ✔️ ĐÚNG: Cập nhật hàng loạt trực tiếp mà không cần tải dữ liệu lên bộ nhớ RAM ứng dụng
await context.Products
   .Where(p => p.Specs.Brand == "Apple")
   .ExecuteUpdateAsync(s => s.SetProperty(
        p => p.Specs.RamGigabytes,
        p => p.Specs.RamGigabytes + 4)); // Thực thi đúng 1 câu lệnh SQL duy nhất

// KHI CÓ NHIỀU
await using var transaction = await context.Database.BeginTransactionAsync();
try
{
    // Lệnh 1
    var updatedCount1 = await context.Products
        .Where(p => p.Specs.Brand == "Apple")
        .ExecuteUpdateAsync(s => s.SetProperty(
            p => p.Specs.RamGigabytes,
            p => p.Specs.RamGigabytes + 4));

    // Lệnh 2 (ví dụ)
    await context.Products
        .Where(p => p.Category == "Laptop" && p.Price > 1000)
        .ExecuteUpdateAsync(s => s.SetProperty(p => p.IsActive, false));

    // Có thể kết hợp với Insert, Delete, hoặc các lệnh SQL thuần
    // await context.Database.ExecuteSqlRawAsync("...");

    await transaction.CommitAsync();
}
catch (Exception)
{
    await transaction.RollbackAsync();
    throw;
}

// KẾT HỢP SaveChange
await using var transaction = await context.Database.BeginTransactionAsync();

try
{
    // Bulk update
    await context.Products
        .Where(p => p.Specs.Brand == "Apple")
        .ExecuteUpdateAsync(...);

    // Thay đổi tracked entities
    var product = await context.Products.FindAsync(123);
    product.LastUpdated = DateTime.UtcNow;

    await context.SaveChangesAsync();   // vẫn cần transaction rõ ràng

    await transaction.CommitAsync();
}
catch
{
    await transaction.RollbackAsync();
    throw;
}

// KHUYẾN NGHị: Custom DBContext tạo transaction chung cho mỗi request.
```

### 6. Khai báo và Truy vấn Hàm (Functions) và Thủ tục (Procedures) trong PL/pgSQL

Nhóm phát triển cần nắm rõ sự khác biệt bản chất giữa Hàm (Function) và Thủ tục (Procedure) để đưa ra thiết kế chuẩn xác.

**6.1. Nguyên tắc sử dụng**

Hàm (Function): Thiết kế để tính toán và trả về dữ liệu (Scalar, Table, hoặc JSON). Gọi bằng câu lệnh SELECT. Không được phép bắt đầu hoặc kết thúc giao dịch (COMMIT/ROLLBACK) bên trong hàm.

Thủ tục (Procedure): Thiết kế để thực thi các tác vụ thay đổi trạng thái dữ liệu. Gọi bằng câu lệnh CALL. Cho phép quản lý giao dịch độc lập một cách tường minh bên trong thân thủ tục.

**6.2. Thiết kế khối lệnh PL/pgSQL chuẩn hóa**

Mọi tham số truyền vào PL/pgSQL phải bắt đầu bằng tiền tố p_ và biến cục bộ phải bắt đầu bằng v_ để tránh xung đột tên cột trong bảng cơ sở dữ liệu.

```sql
-- ✔️ ĐÚNG: Cấu trúc Thủ tục chuẩn có xử lý khóa bi quan, kiểm tra logic và bẫy lỗi cụ thể
CREATE OR REPLACE PROCEDURE ticketing.adjust_ticket_quota(
    p_ticket_type_id UUID,
    p_quantity_delta NUMERIC,
    OUT p_is_success BOOLEAN
)
LANGUAGE plpgsql AS $$
DECLARE
    v_avail NUMERIC;
    v_qty NUMERIC;
    v_new_avail NUMERIC;
BEGIN
    -- Khóa dòng dữ liệu bằng FOR UPDATE để chống tranh chấp đồng thời (race condition)
    SELECT quantity, available_quantity 
    INTO v_qty, v_avail 
    FROM ticketing.ticket_types 
    WHERE id = p_ticket_type_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Mã loại vé % không tồn tại trong hệ thống', p_ticket_type_id;
    END IF;

    v_new_avail := v_avail + p_quantity_delta;

    -- Kiểm tra ràng buộc logic nghiệp vụ
    IF v_new_avail < 0 THEN
        RAISE EXCEPTION 'Không thể giảm số lượng khả dụng xuống dưới mức 0';
    END IF;

    -- Cập nhật dữ liệu
    UPDATE ticketing.ticket_types
    SET available_quantity = v_new_avail
    WHERE id = p_ticket_type_id;

    p_is_success := TRUE;

EXCEPTION
    -- Bẫy lỗi và hoàn trả trạng thái an toàn
    WHEN OTHERS THEN
        p_is_success := FALSE;
        RAISE WARNING 'Đã xảy ra lỗi trong quá trình điều chỉnh hạn ngạch vé: %', SQLERRM;
END;
$$;
```

**6.3. Truy vấn từ C# an toàn hiệu năng cao (Npgsql / ADO.NET)**

Ngăn chặn SQL Injection: Tuyệt đối không cộng chuỗi SQL thủ công. Sử dụng nội suy chuỗi an toàn (FormattableString) trong EF Core hoặc tham số hóa an toàn trong ADO.NET.

Tối ưu hóa tham số: Trình điều khiển Npgsql tối ưu nhất khi sử dụng tham số vị trí dạng $1, $2 thay vì tham số đặt tên dạng @parameterName.

```csharp
// ❌ SAI: Nguy cơ SQL Injection cực cao do cộng chuỗi trực tiếp
var cmdText = "SELECT * FROM products WHERE name = '" + userInput + "'";

// ❌ SAI: Sử dụng câu lệnh gọi thủ tục bằng cách nhúng trực tiếp giá trị biến
await dbContext.Database.ExecuteSqlRawAsync($"CALL adjust_ticket_quota('{ticketTypeId}', {quantity}, false)");

// ✔️ ĐÚNG: Sử dụng string interpolation của EF Core (Tự động biên dịch thành SQL tham số hóa an toàn)
await dbContext.Database.ExecuteSqlAsync($"CALL ticketing.adjust_ticket_quota({ticketTypeId}, {quantity})");

// ✔️ ĐÚNG: Sử dụng tham số vị trí hiệu năng cao với ADO.NET Npgsql trực tiếp
await using var dataSource = NpgsqlDataSource.Create(connectionString);
await using var cmd = dataSource.CreateCommand("CALL ticketing.adjust_ticket_quota($1, $2, $3)");
cmd.Parameters.AddWithValue(ticketTypeId);
cmd.Parameters.AddWithValue(quantity);
cmd.Parameters.AddWithValue(false); // Tham số OUT

await cmd.ExecuteNonQueryAsync();
```

### 7. Quy tắc Bảo mật và Phân tích Hiệu năng Truy vấn

**7.1. Chẩn đoán hiệu năng bằng auto_explain cho PL/pgSQL**

Khi cần tối ưu hóa các hàm và thủ tục chứa logic phức tạp, lập trình viên không được dùng lệnh EXPLAIN thông thường từ bên ngoài (vì nó không thể phân tích các câu lệnh SQL chạy lồng bên trong thân hàm). Bắt buộc cấu hình và phân tích qua mô-đun auto_explain trong môi trường Staging/Development :

```sql
-- ✔️ ĐÚNG: Thiết lập phân tích chi tiết các câu lệnh nội bộ của hàm PL/pgSQL
SET auto_explain.log_min_duration = 0;
SET auto_explain.log_analyze = true;
SET auto_explain.log_nested_statements = ON;
SET auto_explain.log_level = INFO;

-- Thực thi hàm cần đo lường hiệu năng
SELECT * FROM ticketing.customer_order_summary('d3b07384-d113-4e4e-a548-18e001800115');

-- Toàn bộ sơ đồ thực thi của từng câu lệnh SELECT/UPDATE con trong hàm 
-- sẽ được in ra đầy đủ trong thẻ "Messages" của pgAdmin hoặc DBeaver.
```

**7.2. Tối ưu hóa Chỉ mục Tổ hợp (Composite Index)**

Khi thiết lập chỉ mục trên nhiều cột (A, B), thứ tự khai báo các cột là yếu tố quyết định. Cột có tần suất xuất hiện cao nhất trong điều kiện lọc hoặc có độ chọn lọc (selectivity) cao nhất phải được xếp lên trước.

```sql
-- Giả định ứng dụng có hai mẫu câu truy vấn lọc sau:
-- Truy vấn 1: WHERE customer_id = X AND status = Y
-- Truy vấn 2: WHERE status = Y (Chỉ lọc theo status)

-- ❌ SAI: Tạo chỉ mục tổ hợp idx_orders_status_customer_id (status xếp trước)
-- Chỉ mục này vô tác dụng với các truy vấn chỉ lọc theo customer_id vì status có độ chọn lọc rất thấp.
CREATE INDEX idx_orders_status_customer_id ON orders(status, customer_id);

-- ✔️ ĐÚNG: Đặt cột có độ chọn lọc cao (customer_id) lên trước trong cấu hình chỉ mục tổ hợp
-- Chỉ mục này hỗ trợ tối đa cho cả hai trường hợp: lọc theo (customer_id, status) và lọc theo riêng (customer_id).
CREATE INDEX idx_orders_customer_id_status ON orders(customer_id, status);
```
