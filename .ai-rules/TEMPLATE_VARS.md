# Template Variables

When onboarding `netcore-ai-rules` into a new project, replace the placeholders below. Find leftover auto placeholders with:

```bash
grep -rnE "\{(ProjectName|Company|database|schema|namespace)\}" .ai-rules .agents CLAUDE.md AGENTS.md --exclude=TEMPLATE_VARS.md
```

Other `{...}` tokens in the rules are not onboarding placeholders - for example `{orderId}` is a route parameter and `{UseCase}` is a naming pattern.

The installers never modify this file, so its placeholder names stay readable after install.

## Convention

| Form | Meaning | Auto-replaced by the installer |
|---|---|---|
| `{Placeholder}` | One fixed value for the whole project, replaced once at onboarding | Yes (global ones) |
| `<placeholder>` | Varies per usage/module/script - the agent fills it in per case | **Never** - leave as-is |

Example: `.dbup/Scripts/{database}/<schema>/` - `{database}` is the one project database, while `<schema>` differs per module.

## Placeholders

| Placeholder | Meaning | Installer | Example A — Internal monolith | Example B — SaaS microservices |
|---|---|---|---|---|
| `{ProjectName}` | Solution / repo name, PascalCase | Auto | `CRM` | `AcmePlatform` |
| `{Company}` | Namespace prefix, short PascalCase | Auto | `CRM` | `Acme` |
| `{database}` | Real database name, snake_case | Auto | `crm` | `acme_db` |
| `{schema}` | **Default** DB schema, snake_case; never `public` for business tables | Auto | `app` | `catalog` |
| `{namespace}` | OTel `service.namespace`, lowercase/kebab | Auto | `crm` | `acme` |
| `{Module}` | Bounded context / microservice | **Manual** | `Identity`, `Sales`, `MasterData` | `Catalog`, `Ordering`, `Billing` |
| `{ServiceName}` | Service name in traces/logs, kebab-case | **Manual** | `identity-api`, `sales-worker` | `catalog-api`, `ordering-worker` |
| `{Aggregate}` | Main entity name in code examples | **Manual** | `Customer`, `Contact`, `Deal` | `Product`, `Order`, `Invoice` |

**Manual placeholders are never bulk-replaced.** `{Module}`, `{ServiceName}`, and `{Aggregate}` appear in examples that differ per module/service/aggregate - replacing them all with one value would make every other module wrong. They are left in the rules as generic references; the agent substitutes the right value per case.

## Install commands

**Example A** (PowerShell):

```powershell
./install.ps1 -Target ../CRM -Company CRM -ProjectName CRM -Database crm -Schema app -Namespace crm -Force
```

**Example B** (PowerShell):

```powershell
./install.ps1 -Target ../AcmePlatform -Company Acme -ProjectName AcmePlatform -Database acme_db -Schema catalog -Namespace acme -Force
```

**Example B** (bash - env vars):

```bash
COMPANY=Acme PROJECT_NAME=AcmePlatform DATABASE=acme_db SCHEMA=catalog NAMESPACE=acme ./install.sh ../AcmePlatform
```

To re-apply placeholders to an existing install, re-run the same command with `-Force` (PowerShell) or `FORCE=1` (bash).

## After installing - fill in `core/01-project-hard-rules.md`

- **Business Overview** — 2–5 bullets describing the real domain (for example: "Customer, contact, and sales opportunity management").
- **Frameworks & Architecture** — the real stack: .NET version, Postgres/SQL Server, Redis/Valkey, MassTransit/RabbitMQ...
- **Migration tool** — pick one: DbUp (`.dbup/Scripts/{database}/<schema>/`) or EF Migrations (`Infrastructure/Migrations/`).
- **Language Policy** — the output language (template default: Vietnamese).
- **Changelog policy** — enabled or disabled.
- **Frontend stack** (if any) — for example: React + Vite + Tailwind + TanStack Query.

## Notes

- Files with a `> **Template:**` note at the top contain project-specific sections to fill in.
- After onboarding, you may delete this file or keep it as a reference.
