# STW-21 — Builder RLS policies, grants and API exposure

- **Jira:** https://stratyge.atlassian.net/browse/STW-21 (blueprint US-013)
- **Branch:** `feat/stw-21/builder-rls-policies`

## Overview
Org-scoped policies on every builder table, so a Builder A admin sees and changes only Builder A data. Staff see everything; anon sees nothing.

## Implementation details
Migration `20261020131000_builder_rls_policies.sql`. The tenant predicate is `org_id = any ((select private.current_user_org_ids())::uuid[]) or (select private.is_staff())`, evaluated once per statement.

| Table | Policies | Grants to `authenticated` |
|---|---|---|
| projects | `p_projects_select` (org-or-staff), `p_projects_update` (**staff only**, with check) | select; update (name, status, selection_phase_started_at, selection_due_date, archived_at) |
| project_slots | `p_project_slots_select` | select (**no write**) |
| selections | `p_selections_select` / `_insert` / `_update` / `_delete` (org-or-staff, **with check** on insert/update) | select; insert (org_id, slot_id, product_name); update (product_name); delete |
| selection_history | `p_selection_history_select` | select (**no write**; rows come from the STW-23 definer trigger) |

- `grant usage on schema builder to authenticated` only; `anon` has no schema usage and no table privileges.
- **Anti-forgery, beyond the AC:** column grants mean a client can't change `org_id`, `slot_id` or `selected_by`, or a project's `org_id`. `private.stamp_selected_by()` (BEFORE INSERT OR UPDATE on selections) always sets `selected_by := auth.uid()`. `seed.sql` runs with triggers off and keeps its nulls.
- `supabase/tests/builder_core_tables.sql` (STW-20): its "no app-role privileges" assertion is narrowed to anon only, because grants exist from this ticket on and `builder_rls.sql` asserts them exactly.
- AC4: `builder` is exposed locally through `config.toml` (STW-12). The hosted dashboard step is recorded in SETUP.md §2.5 and is a person action (`docs/actions/hosted-database.md`).
- Also in this PR: the STW-12 link is recorded (`docs/tickets/STW-12.md`), and the seed-files and STW-12 action guides are marked done.

## API changes
`/rest/v1/*` with `Accept-Profile: builder` now returns org-scoped rows to signed-in users. Selection writes go through RLS; everything else is read-only.

## Database changes
8 policies, 1 trigger and function, grants. Rollback is in the header and `MIGRATIONS.md`. STW-22 and STW-23 depend on it.

## Dependencies on other tickets
Blocked by STW-20. Blocks STW-22 (alerts), STW-23 (history trigger), STW-24 (seed and users), STW-25 (isolation tests).

## Known limitations
- The hosted exposed-schema change and `db push` are pending the person action.
- Projects have no insert policy: they come from seed/setup only, per the brief.

## Testing notes
`npm run test:db` → `supabase/tests/builder_rls.sql` (rolled back, JWT claims set like PostgREST):
1. PASS: forced RLS; exactly 8 `p_<table>_<command>` policies; grants for authenticated only; no slot/history writes; no forgeable columns grantable.
2. PASS: Ana sees only Builder A; staff sees both.
3. PASS: an insert into her own slot works with `selected_by` = Ana; inserting into Builder B's slot is rejected (42501); supplying `selected_by` is denied.
4. PASS: update/delete only within her own org (staff any); `org_id` can't be changed.
5. PASS: projects update is staff only; no project inserts.
6. PASS: no slot or history writes from the app.
7. PASS: anon is denied.

## Follow-up tasks
STW-25 adds the catalog-wide forced-RLS check and the full isolation attack suite.
