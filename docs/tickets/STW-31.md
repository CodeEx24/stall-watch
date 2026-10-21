# STW-31 — Detector tables: stall_runs, stall_episodes, alerts.episode_id

- **Jira:** https://stratyge.atlassian.net/browse/STW-31 (blueprint US-023)
- **Branch:** `feat/stw-31/detector-tables`

## Overview
A run log and a de-duplication record, so that every detector run is visible to staff and re-runs or overlapping runs can never duplicate alerts (ADR-004).

## Implementation details
Migration `20261020140000_detector_tables.sql`:
- `builder.stall_runs`: `trigger in ('scheduled','manual')`, `status in ('running','succeeded','failed')` (default `running`), `started_at`, `finished_at`, `projects_flagged`, `alerts_created`, `error_message` (≤ 2000 chars), plus `created_at` / `updated_at` / `lock_version` and the touch trigger.
  - Checks: `finished_at` is null exactly while running; `finished_at >= started_at`; `error_message` is set exactly when failed. A run row can't lie about its state.
- `builder.stall_episodes`: `org_id`, `project_id`, `quiet_since`, `run_id → stall_runs`, `created_at`. **`unique (project_id, quiet_since)`**: new builder activity moves `quiet_since`, so a re-stall is a new episode. Composite FK `(project_id, org_id)`; `unique (id, org_id)` so alerts can reference it the same way. Append-only (no update columns).
- `builder.alerts.episode_id`: composite FK `(episode_id, org_id) → stall_episodes`; **`unique (episode_id, user_id)`** (one alert per admin per episode); `stalled` alerts require an episode (`late_change` alerts from STW-42 don't).
- RLS enabled and forced on both tables. `p_stall_runs_select` / `p_stall_episodes_select` use `(select private.is_staff())`. Grants: select to authenticated only, no insert/update/delete, nothing for anon. Rows come only from `private.run_stall_detector` (STW-32, definer).
- `supabase/tests/alerts.sql` (STW-22): fixtures switched to `late_change` alerts, because `stalled` now needs an episode; the access rules tested are kind-independent.

## API changes
Staff can read `/rest/v1/stall_runs` and `/rest/v1/stall_episodes` (builder profile). Builders get empty results.

## Database changes
Two tables, one column plus three constraints on alerts, indexes and policies. Rollback is in the header and `MIGRATIONS.md`.

## Dependencies on other tickets
Code dependencies STW-21 and STW-22 are Done. Stacked on STW-24 only for migration order on the shared local DB. Blocks STW-32 (detector function).

## Known limitations
Runs have no org (the detector is global), so the run log is staff-only by design.

## Testing notes
`npm run test:db` → `supabase/tests/detector_tables.sql` (rolled back), full suite 46 PASS:
1. PASS: run columns, unique keys, forced RLS, exactly one staff-only select policy per table, no write grants.
2. PASS: trigger, finished and error checks; a duplicate `(project, quiet_since)` is rejected (23505); an episode's org must match its project's (23503); a re-stall with a new `quiet_since` is a new episode; one alert per `(episode, user)` (23505); a `stalled` alert without an episode is rejected (23514).
3. PASS: staff see runs and episodes; a builder admin sees none; staff can't insert runs directly.

## Follow-up tasks
STW-32 writes these tables from `private.run_stall_detector`.
