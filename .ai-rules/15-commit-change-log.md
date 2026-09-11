# 15 - Commit Change Log Rules

> **Template:** Nếu dự án bật changelog policy, mọi commit có API/contract/DB/shared impact phải có changelog entry. Tắt policy bằng cách ghi rõ trong `core/01-project-hard-rules.md`.

## Khi nào bắt buộc

Mọi thay đổi ảnh hưởng tới:

- API endpoint / request / response contract
- Validation behavior
- Database script / schema / migration
- Shared library / Infrastructure
- Auth / security behavior
- Configuration / deployment behavior
- Background job / event flow

## Format

- Đường dẫn: `change-logs/YYYY/MM/YYYY-MM-DD.md` (append cuối file, không ghi đè).
- Title chứa task ID (ví dụ `#JIRA-123`).
- Commit changelog **cùng commit** với code.

## Template entry (fenced YAML)

```yaml
---
date: YYYY-MM-DD
task: "#JIRA-123"
scope: api | db | contract | infra | shared
summary: >
  Mô tả ngắn gọn thay đổi.
files:
  - path/to/changed/file.cs
breaking: false
---
```

## Checklist

- [ ] Có entry trong `change-logs/YYYY/MM/YYYY-MM-DD.md` cho commit này?
- [ ] Task ID xuất hiện trong title?
- [ ] `breaking: true` nếu contract/DB change không backward-compatible?
- [ ] Changelog commit cùng code (không để commit sau)?
