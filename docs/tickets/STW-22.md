# STW-22 — Alerts table with recipient-only policies and column grant

- **Jira:** https://stratyge.atlassian.net/browse/STW-22 (blueprint US-014)
- **Branch:** `feat/stw-22/alerts-table`

## Overview
In-app alerts that only the recipient can read and mark read. Other org members can't see them, and neither can staff.

## Implementation details
Migration `20261020132000_alerts_table.sql`:
- `builder.alerts`: `org_id`, `user_id → public.users on delete cascade`, `project_id`, `kind text check in ('stalled','late_change')`, `message` (1–500 chars), `read_at`, `created_at`, plus `updated_at` / `lock_version` (mutable-table rule) with `trg_alerts_touch`.
- Composite FK `(project_id, org_id) → builder.projects (id, org_id)`: an alert can't point at another org's project.
- Check `read_at is null or read_at >= created_at`.
- Indexes: `(user_id, created_at desc)` for the inbox, plus `org_id` and `project_id`.
- RLS enabled and forced. `p_alerts_select` and `p_alerts_update` use `user_id = (select auth.uid())` (update has both using and with check).
- Grants (ADR-008): `select`; table-level `update` revoked, then `grant update (read_at)` only; no insert or delete for `authenticated`; nothing for `anon`. Rows come only from the detector (definer rights, STW-31/32).

## API changes
`GET /rest/v1/alerts` (builder profile) returns only the caller's alerts. `PATCH … read_at` is the only allowed write.

## Database changes
One table, three indexes, one trigger, two policies, grants. Rollback: `drop table if exists builder.alerts;`.

## Dependencies on other tickets
Blocked by STW-21. Blocks STW-24 (seed/users), STW-30 (/alerts inbox) and STW-31 (adds `episode_id` and the `(episode_id, user_id)` unique key).

## Known limitations
A recipient can set `read_at` to any value at or after `created_at`, including clearing it back to null (mark unread). That's acceptable for an inbox.

## Testing notes
`npm run test:db` → `supabase/tests/alerts.sql` (rolled back):
1. PASS: columns, composite FK, forced RLS, exactly 2 recipient policies, grants = select + update(read_at).
2. PASS: an alert's org must match its project's org (FK violation otherwise).
3. PASS: only the recipient sees the alert; a co-member and staff see 0.
4. PASS (AC3): Ana updating `message` → **permission denied (42501)**; updating `read_at` succeeds and bumps `lock_version`.
5. PASS: non-recipients can't mark it read; nobody can insert, delete or reassign.
6. PASS: `read_at >= created_at` enforced.

## Follow-up tasks
STW-31 adds `episode_id`.
