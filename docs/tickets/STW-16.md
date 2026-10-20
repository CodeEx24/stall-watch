# STW-16 — Identity tables: orgs, users, memberships

- **Jira:** https://stratyge.atlassian.net/browse/STW-16 (blueprint US-008)
- **Branch:** `feat/stw-16/identity-tables`

## Overview
Identity data that every RLS decision reads: orgs (staff or builder), users (mirror of Supabase Auth), and memberships (who belongs to which org, as admin or member). The client cannot influence any of it.

## Implementation details
Migration `20261020121000_identity_tables.sql`:
- `public.orgs`: `org_type text check in ('staff','builder')`; `name` 1–200 chars, not blank.
- `public.users`: `id` references `auth.users(id) on delete cascade` (1:1 mirror, filled by STW-17); `email` unique, lower-case, shape-checked, ≤ 320 chars.
- `public.memberships`: `role text check in ('admin','member')`; `unique (user_id, org_id)`; `org_id` index; `org_id … on delete restrict` (an org with members can't vanish); `user_id … on delete cascade`.
- All three: uuid PK (`gen_random_uuid()` for orgs and memberships; users take the auth id), `created_at`, `updated_at`, `lock_version`, and `trg_<table>_touch` using `private.touch_updated_at()`.
- **Locked by default.** Supabase's default privileges grant `anon` and `authenticated` ALL on new `public` tables, so RLS is enabled **and forced** with no policies, and all privileges are revoked from `public`, `anon` and `authenticated`. STW-19 opens read-only access (`p_<table>_select`). Writes stay closed for app roles.
- No `public` → `builder` references (tested).

## API changes
Tables exist but are unreadable over the API until STW-19.

## Database changes
Three tables, one index, three triggers. Rollback: `drop table if exists public.memberships, public.users, public.orgs;`.

## Dependencies on other tickets
Blocked by STW-15. Blocks STW-17 (auth mirror) and STW-18 (RLS helpers), which can run in parallel.

## Known limitations
Column names follow the ticket ACs and `docs/architecture.md`. The provided `seed.sql` / `link-test-users.sql` aren't in the repo yet (`docs/actions/seed-files.md`). If they need extra columns (e.g. a display name), a follow-up migration adds them.

## Testing notes
`npm run test:db` → `supabase/tests/identity_tables.sql` (rolled back):
1. PASS: uuid keys, audit columns, touch triggers, text statuses.
2. PASS: no public table references a builder table.
3. PASS: rejects a bad `org_type`, a blank name, a bad role, a duplicate membership, a duplicate or upper-case email, a user without an auth user, and deleting an org that still has members.
4. PASS: RLS enabled and forced; no app-role privileges.

## Follow-up tasks
Reconcile columns with the provided seed files when they land (STW-24).
