# SmartOffice AI Coding Rules - Modular Structure


## Cấu trúc
```
.ai-rules/
├── core/                    # ← LUÔN LOAD ĐẦY ĐỦ (3 file nhỏ)
│   ├── 00-behavioral-guidelines.md
│   ├── 01-smartoffice-hard-rules.md
│   └── 02-spec-workflow.md
├── 01-clean-architecture.md
|── 02-constants-errors.md
├── 02-cqrs-pattern.md
├── 03-security-tenancy.md
├── 04-api-contract.md
├── 05-resilience.md
├── 06-observability.md
├── 07-testing.md
├── 08-ef-core.md
├── 09-error-handling.md
├── 10-dependency-injection.md
├── 11-configuration.md
├── 12-caching.md
├── 13-background-jobs.md
├── 14-database-rule.md
├── 15-commit-change-log.md
├── 16-code-comments.md
└── README.md
```

## Cách sử dụng cho Agent (QUAN TRỌNG)

**Mọi task mới:**
1. **Luôn load 3 file core** (`00-` đến `02-`) vào context.
2. Trong phase **Plan** và **Tasks**, ghi rõ các rule reference cần dùng (ví dụ: "Referenced: 08-efcore.md, 04-api-contract.md, vertical-slice-guide.md").
3. Khi cần chi tiết sâu (EF Core convention, API contract rules, testing pattern, changelog template...), dùng tool `read_file` để load file tương ứng trong `reference/`.
4. Tuân thủ nghiêm ngặt **Surgical Changes** + **Simplicity First** khi edit code.

## Ví dụ prompt khởi tạo cho agent
```
Bạn là AI coding assistant cho SmartOffice Backend (.NET 10 microservices).

Luôn tuân thủ 3 file core sau:
- .ai-rules/core/00-behavioral-guidelines.md
- .ai-rules/core/01-smartoffice-hard-rules.md
- .ai-rules/core/02-spec-workflow.md

Quy trình: Spec-Driven (Specify → Clarify → Checklist → Plan → Tasks → Implement → QA/Review)

Khi cần rule chi tiết, hãy đọc file trong .ai-rules/ bằng read_file.

Bắt đầu task: [mô tả task]
