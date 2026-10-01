# 16 - Code Comment Rules

## Main Principles

- **Language**: comments that explain business logic use the project's output language (see Language Policy in `core/01-project-hard-rules.md` - the template default is Vietnamese).
- **Purpose**: a comment explains the **business meaning** of a function/block - it does not restate what the code already says through variable/function names.
- **Granularity**: comment at the function or significant-logic-block level, not line by line.

## When to comment

| Case | Example |
|---|---|
| A function implements complex business logic | Command handler, a domain method with many conditions |
| A business rule is not obvious from the name | A constraint, a hidden invariant, a specific edge case |
| A technical workaround / limitation | An EF Core quirk, the outbox pattern, an integration contract |
| A design decision needs explaining | Why approach B was chosen over approach A |

## When NOT to comment

- The function/property name already states its purpose (`GetStaffById`, `IsLocked`, `CreateStaff`).
- Simple CRUD with no special business logic.
- The behavior is already fully described by a test.
- The comment only restates the function name in different words.

## Format

The example below uses Vietnamese because that is this template's default output language - replace it with the project's configured output language.

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

## Do not write

```csharp
// Hàm này set IsLocked = true   <- restates the code, adds nothing
// TODO: fix later                <- a TODO without a ticket is not allowed
/// <summary>
/// Gets the staff by identifier and returns the result.
/// </summary>                    <- a long XML doc that adds no information
```

## Summary

> A comment states **why** or the **business meaning**, not **what the code does**.
> One clear line is enough - do not write multi-paragraph block comments.
