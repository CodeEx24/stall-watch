# STW-26 — Stall rule views (v_project_stall, v_projects)

- **Jira:** https://stratyge.atlassian.net/browse/STW-26 (blueprint US-018)
- **Branch:** `feat/stw-26/stall-rule-views`

## Overview
A live stall rule, so the badge on `/projects` is always current (ADR-006), independent of when the detector last ran.

Acceptance criteria:
- Views are security_invoker = true (reloptions checked) and set again after any create or replace.
- Given the seed, is_stalled is true for Lot 12, Unit 4B and Unit 7C and false for the other six projects.
- Quiet since = greatest(selection_phase_started_at, last builder history); staff activity is ignored (Unit 7C).
- Given Ana, then only Builder A rows are visible; v_projects exposes org_name, empty_slots, quiet_since, is_stalled.

## Implementation details
Migration `20261020150000_stall_rule_views.sql`:
- **`private.stall_window()`** returns `interval '7 days'` (STALL_DAYS = 7). The single definition of the window; immutable, `search_path = ''`, execute for `authenticated` only. Derived from the seed scenarios: Lot 12 (builder quiet 7 days) and Unit 4B (phase 8 days, no events) stall, Unit 5A (2 days) and Lot 14 (yesterday) don't. The boundary is inclusive: quiet for exactly 7 days is stalled.
- **`builder.v_project_stall`**: per project, `last_builder_activity_at` = max `selection_history.changed_at` with `actor_kind = 'builder'` over the project's slots; `quiet_since = greatest(selection_phase_started_at, last_builder_activity_at)` (greatest ignores nulls); `is_stalled = status = 'selection_phase' and archived_at is null and quiet_since <= now() - private.stall_window()`, coalesced to `false` (never null). `selections.updated_at` is never read (Unit 7C trap).
- **`builder.v_projects`**: one row per project with `id, org_id, org_name, name, status, selection_phase_started_at, selection_due_date, archived_at, slot_count, empty_slots, quiet_since, is_stalled`. `empty_slots` = slots with no current selection.
- Both views `with (security_invoker = true)` and re-set with `alter view ... set (security_invoker = true)` right after creation. The caller's RLS on projects, slots, history, selections and orgs decides visibility. Grants: `select` to `authenticated` only; nothing for `public` / `anon`.

Rejected: a constant inlined in the view (the detector would need a second copy); a `security definer` view or function (would bypass tenant RLS in an exposed schema).

## API changes
`GET /rest/v1/v_projects` and `/rest/v1/v_project_stall` with `Accept-Profile: builder` (authenticated). Anon gets `42501`.

## Database changes
One function, two views, grants. Rollback (header + `MIGRATIONS.md`):
`drop view if exists builder.v_projects; drop view if exists builder.v_project_stall; drop function if exists private.stall_window();`
Any later `create or replace view` must repeat `alter view ... set (security_invoker = true)`.

## Dependencies on other tickets
Uses STW-20/21 (tables, RLS) and STW-23 (actor_kind from the history trigger), all Done. Stacked on STW-31 (#19) only for migration order on the shared local DB. Blocks STW-32 (detector reuses `private.stall_window()` / `v_project_stall`) and the `/projects` page.

## Known limitations
- `quiet_since` is also computed for projects that can't stall (revision, complete); only `is_stalled` is gated on status and archive.
- No `src/types/database.types.ts` exists yet; types will be generated when the web feature consumes the views.

## Testing notes
`supabase/tests/stall_views.sql` (rolled back; synthetic fixtures `...26xx`):
1. reloptions contain `security_invoker=true` on both views; select-only for authenticated, nothing for anon; window is 7 days in one immutable function.
2. Seed (skipped with a NOTICE when Lot 12 is absent): stalled = exactly {Lot 12, Unit 4B, Unit 7C}, other six false. Synthetic: 7-day boundary stalled, 6d23h not, phase 8d stalled, phase 2d / archived / revision / pending_kickoff not; slot_count / empty_slots right.
3. Staff change after builder quiet keeps quiet_since and the stall (logged `staff`); a builder change resets quiet_since to now and clears it.
4. Synthetic Ana sees only her org, Bruno only his, staff all; seeded `ana@builder-a.test` (looked up by email, unchanged) sees exactly Lot 12/14/15/9/3 with only Lot 12 stalled.
5. Anon denied on both views.

`npm run test:db`: all files pass (54 PASS). REST as Ana: `GET /rest/v1/v_projects?select=name,org_name,is_stalled,empty_slots` → 5 Builder A rows, Lot 12 `is_stalled: true`; anon → `42501 permission denied for schema builder`.

## Follow-up tasks
- STW-32: `private.run_stall_detector` selects stalled projects from `builder.v_project_stall` / uses `private.stall_window()`.
- `/projects` page reads `builder.v_projects`.
