# .NET Core Backend - AI Coding Agent Instructions

> **Template:** Bộ instructions generic cho backend .NET Core (Clean Architecture + CQRS + EF Core). Khi onboard dự án mới: thay `{ProjectName}` trong `core/01-project-hard-rules.md`, điền stack + business overview thực tế.

> **Nguyên tắc nguồn chân lý:** **`.ai-rules/` là gốc**. Mọi skill/agent/command khi kích hoạt phải đọc và tuân theo `.ai-rules/`, không định nghĩa rule chồng lấn. Skill chỉ là lớp điều phối - rule nằm ở `.ai-rules/`.

## Quick Start for Any AI Agent

**Always load these 3 core files first** (they contain everything essential):

1. `.ai-rules/core/00-behavioral-guidelines.md` - Mindset & thinking discipline (Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution)
2. `.ai-rules/core/01-project-hard-rules.md` - Non-negotiable rules (Clean Architecture, migration policy, changelog, testing, outbox-first messaging) + project map + stack của dự án
3. `.ai-rules/core/02-spec-workflow.md` - Artifact-first workflow: core constitution + gate + artifact sequence + primary commands (`/kit-clarify-plan`, `/kit-implement`, `/kit-status`)

## Stack Rules

See `.ai-rules/core/01-project-hard-rules.md` - authoritative source cho non-negotiable rules (Clean Architecture, migration tool, changelog, `Result<T>`, audit columns, soft delete, outbox-first, testing stack, paths) + business overview + repository map của dự án.

Chi tiết theo chủ đề: xem danh sách rule files trong `.ai-rules/README.md`.

## Safety Rules

Ask developer confirmation before:

- creating or running destructive migrations
- changing authentication, authorization, permissions, or security-sensitive code
- adding new production dependencies
- deleting files
- touching deployment, CI/CD, infrastructure, or secrets
- expanding scope beyond approved plan

## Workflow - Artifacts + Gate (khi dự án dùng spec-kit)

**Core rules + gate**: See `.ai-rules/core/02-spec-workflow.md` (always load).

The gate is **not** required for planning, proposal, host Plan mode, or small edits outside an active kit feature. It is only required right before actual production writes inside a tracked feature (when using kit artifact on `.specify/features/*`).

### Quick Reference

- Workspace: `.specify/features/<task-id>_<title>/` (never commit)
- Gate: `gates/implementation-approved.md` with `Decision: APPROVED` (token: `APPROVE_IMPLEMENTATION <feature-id>`) - only required when the intent is to apply/write
- Primary commands: `/kit-clarify-plan`, `/kit-implement`, `/kit-status`

## Change log

`change-logs` is required for every code change - nếu dự án bật changelog policy (mặc định template: bật). Xem `.ai-rules/15-commit-change-log.md`.
