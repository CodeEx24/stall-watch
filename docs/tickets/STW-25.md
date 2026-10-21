# STW-25 — Isolation tests and forced-RLS catalog check

- **Jira:** https://stratyge.atlassian.net/browse/STW-25 (blueprint US-017)
- **Branch:** `test/stw-25/isolation-attack-tests`

## Overview
A SQL attack suite that proves tenant isolation instead of assuming it: Ana (Builder A admin) tries to read and write Builder B's data, anon tries every table, and a catalog query checks that every table in `public` and `builder` has RLS enabled **and** forced.

## Implementation details
New file `supabase/tests/isolation.sql`. Everything runs in one transaction that is rolled back. It uses its own synthetic fixtures (ids `…25xx`, emails `iso.*@example.test`), so it doesn't touch seed data and passes on a fresh database.

Users are impersonated the same way PostgREST does it: `set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true)` followed by `set local role authenticated` (the `pg_temp.as_user` helper, same as in `builder_rls.sql` / `alerts.sql`).

1. **Catalog check:** `pg_temp.tables_missing_forced_rls()` lists every `relkind in ('r','p')` table in `public`/`builder` where `not (relrowsecurity and relforcerowsecurity)`. It must return zero rows. Nothing is hard-coded, so new tables are covered automatically.
2. **Negative control:** a probe table is created inside the transaction. The check must flag it with no RLS, flag it again with RLS enabled but not forced, and stop flagging it once RLS is forced. This proves the query actually detects a gap.
3. **Fixtures:** a staff org, Builder A (Ana admin, Mia member) and Builder B (Bruno admin). Each builder gets a project, slots and a selection (history is written by the trigger) plus an alert. Alerts use kind `late_change` so they don't need a detector episode. As owner, the test first asserts that B's rows exist.
4. **Reads:** As a positive control, Ana sees her own rows. She then sees 0 of B's rows in projects, slots, selections, history and alerts, querying both by `org_id` and by B's ids, and 0 in orgs, memberships and users. A generic sweep covers every table or view in `public`/`builder` that has an `org_id` or `user_id` column, so future tables and views are included.
5. **Writes:** A cross-org selection insert is rejected by RLS (42501). Inserting into B's slot while claiming org A is rejected by the composite FK. Updating or deleting B's selections affects 0 rows. Retargeting her own selection to B's `org_id`/`slot_id` is denied (42501, column grants). She can't update B's projects, mark B's alert read, or forge B history or alerts. The test then confirms B's data is unchanged.
6. **Anon:** for every table, view, matview and foreign table in `public`/`builder`, anon holds no privilege. As `anon`, `select`, `insert … default values`, `update` and `delete` all raise `insufficient_privilege`.
7. **Extra:** anon has no `usage` on `private` and no `execute` on any function in it. Calling `private.is_staff()` / `private.current_user_org_ids()` as anon raises 42501.

## API changes
None.

## Database changes
None (tests only, no migration).

## Dependencies on other tickets
Uses STW-18…STW-23 (identity tables, helpers, builder tables and policies, alerts, history trigger). It runs alongside STW-31's detector tables but doesn't depend on them.

## Known limitations
- Isolation is tested directly at the SQL level, not through HTTP and PostgREST. The JWT-claims impersonation matches what PostgREST sets per request.
- The anon sweep checks that the privilege is denied (42501). It doesn't test anon rows through policies, because anon has no grants or schema usage to reach them.

## Testing notes
`npm run test:db` → `supabase/tests/isolation.sql`:
- PASS: catalog check: 0 of 10 public/builder tables lack enable+force RLS
- PASS: catalog check flags no-RLS and enabled-but-not-forced tables (negative control)
- PASS: Builder B fixtures present (1 project, 2 slots, 1 selection, 1 history row, 1 alert)
- PASS: Ana sees 0 Builder B rows in projects, slots, selections, history and alerts (and sees her own)
- PASS: Ana sees 0 Builder B rows in orgs, memberships and users
- PASS: generic sweep: Ana sees 0 Builder B rows in all 9 org_id/user_id relations
- PASS: cross-org selection insert rejected (RLS 42501; org-mismatch blocked by composite FK)
- PASS: update/delete of B selections affect 0 rows; retargeting to B slot/org denied; B unchanged
- PASS: Ana cannot update B projects, mark B alerts read, or forge B history/alerts
- PASS: anon denied select/insert/update/delete (42501) on all 12 public/builder relations
- PASS: anon has no usage on private and cannot execute any of its 8 functions

Mutation checks were run locally on throwaway copies and not committed. Each injected weakness made the suite fail as expected:
- `p_selections_select using (true)` → "FAIL: Ana can see Builder B …"
- `grant select … to anon` → "FAIL: anon holds a privilege on …"
- `alter table builder.alerts no force row level security` → "FAIL: tables lacking enable+force RLS: {builder.alerts}"

## Follow-up tasks
None. New tables and views are picked up by the generic sweeps automatically.
