# CLAUDE.md — Stall Watch Engineering Guide

Working memory for the Stall Watch codebase. Read before writing code.
> PM project: Jira space Stallwatch (key STW, stratyge.atlassian.net). Every branch, commit and PR references the Jira key STW-nnn. Blueprint story US-nnn maps to STW-(nnn+8), e.g. US-003 = STW-11.

## 1. Product (one paragraph)
Stall Watch is a small multi-tenant web app where home builders pick finishes (slots such as "Kitchen – Countertop") for their projects. A scheduled stall detector finds projects that went quiet and creates in-app alerts for the builder's admins. Reverie3D staff see every builder and the detector's run history. The core constraint: the database is the security wall. Builder A must never read or write Builder B's data, and no code path may use the service-role key.

## 2. Tech stack (locked — no swaps without an ADR in docs/architecture.md)
- Next.js (App Router) + TypeScript (strict), deployed on Vercel
- Supabase: Postgres + Auth (email and password only), `@supabase/ssr`, publishable key only
- Scheduler: `pg_cron` calling a `security definer` function (Option A)
- UI: Tailwind CSS v4 + shadcn/ui (Radix, customised) + `motion` (ADR-010); tokens in `src/app/globals.css`, rules in `docs/design-system.md`
- CI: GitHub Actions (lint, typecheck, build, plus a database job running seed and SQL tests)
- Migrations: Supabase CLI; SQL tests in `supabase/tests/`

## 3. Folder structure
```
stall-watch/
  CLAUDE.md  AGENTS.md  README.md  SETUP.md  DESIGN.md  MIGRATIONS.md  .env.example
  docs/
    architecture.md            ADRs and component notes
    tickets/                   one file per ticket: STW-nnn.md (see _TEMPLATE.md)
  supabase/
    config.toml                exposed API schemas: public, builder
    migrations/                YYYYMMDDHHMMSS_what_it_does.sql
    seed.sql  link-test-users.sql   (provided; do not edit casually)
    tests/                     SQL assertions: isolation, detector, forced RLS
  src/
    app/                       routes: / (landing), login, (app)/ projects, projects/[id], alerts, detector (thin)
    components/                shared UI: ui/ (shadcn primitives), app-shell/, brand/, motion/, PageHeader, EmptyState, StatTile
    features/                  projects/, selections/, alerts/, detector/, auth/, landing/ (components, actions, queries)
    lib/                       supabase/ (server.ts, client.ts, proxy), format.ts, motion.ts, utils.ts (cn)
    types/database.types.ts    generated, committed
  .github/workflows/ci.yml
```
Rules: routes stay thin; all data access goes through feature `queries.ts` / `actions.ts` using the per-request Supabase client; server-only code is never imported by client components; the database enforces authorization, the UI never does.

## 4. Coding standards & naming conventions
| Thing | Convention | Example |
| --- | --- | --- |
| Component files | PascalCase .tsx | SlotRow.tsx |
| Hooks/utils/actions files | kebab-case | set-selection.ts, use-alerts.ts |
| Components | PascalCase | ProjectTable |
| Hooks | camelCase use-prefix | useAlerts() |
| Functions | camelCase verb-first | setSelection() |
| Variables | camelCase | activeProject |
| Booleans | is/has/should/can | isStalled |
| Constants | UPPER_SNAKE_CASE | STALL_DAYS |
| Types/interfaces | PascalCase, no I-prefix | ProjectRow |
| Schemas | camelCase + Schema | selectionInputSchema |
| Env vars | UPPER_SNAKE_CASE | NEXT_PUBLIC_SUPABASE_URL |
| SQL tables/columns | snake_case | project_slots, org_id |
| Policies | p_<table>_<command> | p_selections_update |
| Triggers | trg_<what> | trg_selection_history |
| Views | v_<name> | v_project_stall |
| Functions (SQL) | snake_case verb-first, schema-qualified | private.run_stall_detector |
| Migrations | YYYYMMDDHHMMSS_what_it_does.sql | 20261021101500_identity_tables.sql |
| Routes | kebab-case | /projects/[id] |
| Tests | *.test.ts(x) or tests/*.sql | isolation.sql |

General: strict types, no `any`; validate external input at the boundary; prefer Server Components and Server Actions; no secrets client-side; small single-purpose functions.
Database invariants on every change: RLS enabled **and forced**; every INSERT/UPDATE policy has `with check`; statuses are `text` + `check` (no enums); mutable tables carry `created_at`, `updated_at`, `lock_version`; no hard deletes of business records except clearing a selection (history records the clear); primary keys `uuid default gen_random_uuid()`.
Reuse-first: before creating a component, utility or pattern, check whether it should be a shared component, a helper, or an existing pattern to follow. Do not create a second way to do the same thing.

## 5. Git: branches, commits, PRs
Branch: `<type>/stw-<nnn>/<short-kebab-title>` (feat, fix, chore, refactor, docs, test, perf, build, ci), e.g. `feat/stw-32/stall-detector-function`.
Commit (Conventional Commits): `feat(stall): record every detector run (STW-32)`.
Flow: short branch, PR, green CI, then **merge commit or rebase — never squash** (reviewers read history). The PR description states what changed, why, and how it was verified, and restates the acceptance criteria. Commit `DESIGN.md` before the code it describes. No secrets in git, ever; `git log -p` must stay clean.

## 6. Best-practice skills (consult when building features)
Install: `npx skills add supabase/agent-skills` (Supabase security and development guidance).
Also load a Next.js / React best-practices skill of your choice if one is installed in your environment (verify it exists first).
When developing any feature, follow these as the authority for language and framework practice. If a skill and a ticket's acceptance criteria conflict: the AC wins for behavior, the skill wins for how it is coded.

## 7. Definition of Ready / Done (short)
Ready: AC written and testable; prerequisites Done; sized at 8 points or less; security and tenant-isolation implications noted.
Done: AC met and demonstrated; PR merged with green CI; unit, integration and SQL isolation tests pass; RLS still enabled and forced on touched tables; no secrets; MIGRATIONS.md and ticket doc updated; migrations have a rollback.

## 8. Documentation & knowledge management
CLAUDE.md is **not** updated per ticket or feature. Update it only for durable, project-wide knowledge: best practices, architectural patterns and decisions, validation standards, coding conventions, shared workflows, reusable UI/API patterns, anti-duplication rules.
Cadence: update only when an Epic completes or a decision becomes stable and reusable.
Reuse-first: evaluate reuse before building (shared component? utility? existing pattern? should it be standardized?).
Per-ticket detail lives in `docs/tickets/STW-nnn.md`, never in CLAUDE.md.
Ticket doc template: Overview · Implementation details · API changes · Database changes · Dependencies on other tickets · Known limitations · Testing notes · Follow-up tasks.

## 9. Commands
```
npm run dev | lint | typecheck | build      # web app
supabase start                              # local stack
supabase db reset                           # apply migrations + seed.sql locally
supabase db push                            # apply migrations to the linked project
supabase gen types typescript --linked --schema public --schema builder > src/types/database.types.ts
psql "<local db url from supabase status>" -f supabase/tests/<file>.sql
```
> Keep CLAUDE.md canonical; critical rules are mirrored in AGENTS.md.
