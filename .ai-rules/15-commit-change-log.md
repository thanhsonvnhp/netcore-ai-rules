# 15 - Commit Change Log Rules

> **Template:** When the project enables the changelog policy, every commit with API/contract/DB/shared impact needs a changelog entry. Disable the policy by recording that explicitly in `core/01-project-hard-rules.md`.

## When it is required

Any change affecting:

- API endpoint / request / response contract
- Validation behavior
- Database script / schema / migration
- Shared library / Infrastructure
- Auth / security behavior
- Configuration / deployment behavior
- Background job / event flow

## Format

- Path: `change-logs/YYYY/MM/YYYY-MM-DD.md` (append at the end of the file, never overwrite).
- The title contains the task ID (for example `#JIRA-123`).
- Commit the changelog **in the same commit** as the code.

## Entry template (fenced YAML)

```yaml
---
date: YYYY-MM-DD
task: "#JIRA-123"
scope: api | db | contract | infra | shared
summary: >
  Short description of the change, in the project's output language.
files:
  - path/to/changed/file.cs
breaking: false
---
```

## Checklist

- [ ] Is there an entry in `change-logs/YYYY/MM/YYYY-MM-DD.md` for this commit?
- [ ] Does the task ID appear in the title?
- [ ] `breaking: true` set when the contract/DB change is not backward-compatible?
- [ ] Is the changelog committed together with the code (not in a later commit)?
