# AGENTS.md — Stall Watch

Rules for all coding agents. CLAUDE.md is canonical; this mirrors the must-follow rules.

## Non-negotiables
- Follow the folder structure and naming conventions in CLAUDE.md.
- **Never use the Supabase service-role key** (code, `.env.example`, Vercel). Never put a secret in git, a migration, a function body or a `cron.schedule` command.
- Every table in `public` and `builder`: `enable` **and** `force` row level security, plus real policies named `p_<table>_<command>`; every INSERT/UPDATE policy has `with check` in the same scope.
- Tenant scope is `org_id = any (private.current_user_org_ids()) or private.is_staff()`; alerts are `user_id = auth.uid()`; detector tables are staff-only. Child rows use composite FKs `(parent_id, org_id)`.
- Every `security definer` function: `set search_path = ''`, schema-qualified names, `revoke execute ... from public, anon`; if `authenticated` can call it, check the caller in the first lines; if only the scheduler calls it, revoke from `authenticated` too. Authority comes from `public.memberships`, never from user metadata, `auth.role()` or caller-passed ids.
- Every view in an exposed schema is `security_invoker`; set it again after every `create or replace`.
- Compute builder activity from `selection_history.actor_kind = 'builder'`, never from `selections.updated_at`.
- The detector must be idempotent (episode record + unique keys), record every run, mark failed runs `failed` with the error (log row outside the inner block), and be unreachable by builders and anon.
- Schema changes only through migration files (`YYYYMMDDHHMMSS_what.sql`, header with WHY / WHAT / ROLLBACK, row in MIGRATIONS.md). Never edit an applied migration; never change schema in the dashboard.
- Statuses are `text` + `check`, never enums. Mutable tables carry `created_at`, `updated_at`, `lock_version`.
- Conventional Commits; branches `<type>/sw-<nnn>/<title>`; merge commit or rebase, never squash; CI green before merge.
- **Reuse-first:** check for a shared component, helper or existing pattern before creating a new one.
- **Do not bloat CLAUDE.md:** it holds durable project-wide knowledge only, updated at epic completion or when a decision becomes stable. Ticket detail goes to `docs/tickets/SW-nnn.md`.
- Verify, don't assume: query the catalog for RLS, policies and grants; test in a real browser for UI; when docs and the database disagree, the database is right.

## Definition of Done (short)
AC met and demonstrated; PR merged with green CI; tests pass (SQL isolation tests where relevant); RLS still enabled and forced on touched tables; no secrets; docs and ledger updated; migrations reversible.
