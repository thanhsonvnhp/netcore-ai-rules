# 16 - Quy tắc Comment Code

## Nguyên tắc chính

- **Ngôn ngữ**: Tiếng Việt cho tất cả comment giải thích nghiệp vụ.
- **Mục đích**: Comment giải thích **ý nghĩa nghiệp vụ** của hàm/block - không mô tả lại những gì code đã nói rõ bằng tên biến/hàm.
- **Mức độ**: Comment ở cấp hàm hoặc block logic quan trọng, không comment từng dòng.

## Khi nào cần comment

| Trường hợp | Ví dụ |
|---|---|
| Hàm xử lý nghiệp vụ phức tạp | Command handler, domain method có nhiều điều kiện |
| Business rule không hiển nhiên từ tên | Constraint, invariant ẩn, edge case đặc thù |
| Workaround / limitation kỹ thuật | EF Core quirk, outbox pattern, integration contract |
| Quyết định thiết kế cần giải thích | Tại sao không dùng cách A mà dùng cách B |

## Khi nào KHÔNG comment

- Tên hàm/property đã nói rõ mục đích (`GetStaffById`, `IsLocked`, `CreateStaff`).
- CRUD đơn giản không có logic nghiệp vụ đặc biệt.
- Code đã có test mô tả hành vi đầy đủ.
- Comment chỉ nhắc lại tên hàm theo cách khác.

## Format

```csharp
/// <summary>
/// Khóa tài khoản và thu hồi phiên đăng nhập hiện tại
/// </summary>
public Result Lock()
{
    if (IsLocked) return StaffErrors.AlreadyLocked;
    IsLocked = true;
    AddDomainEvent(new StaffLockedEvent(Id));
    return Result.Success();
}

// Chỉ lấy assignment mặc định để hiển thị tóm tắt trên danh sách.
// Assignment phụ được load riêng ở màn hình chi tiết.
var defaultAssignment = assignments.FirstOrDefault(a => a.IsDefault);
```

## Không viết

```csharp
// Hàm này set IsLocked = true   <- mô tả lại code, vô nghĩa
// TODO: fix later                <- không được để TODO không có ticket
/// <summary>
/// Gets the staff by identifier and returns the result.
/// </summary>                    <- XML doc dài không có thêm thông tin
```

## Tóm tắt

> Comment = **tại sao** hoặc **ý nghĩa nghiệp vụ**, không phải **làm gì**.  
> Một dòng rõ ràng đủ - không viết block comment nhiều đoạn.
