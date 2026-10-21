# STW-34 — pg_cron daily schedule

- **Jira:** https://stratyge.atlassian.net/browse/STW-34
- **Branch:** `feat/stw-34/pg-cron-schedule`

## Overview
As a staff user, I want the detector to run nightly without anyone pressing anything so that stalls are found automatically.

Acceptance criteria:
- Extension pg_cron enabled; job stall-detector-daily calls private.run_stall_detector('scheduled') once a day.
- The cron.schedule command contains no secret; the migration is its own file with a NOT SELF-CONTAINED note.
- After forcing the job once, cron.job_run_details shows success and a scheduled stall_runs row exists.

## Implementation details
Migration `20261020171000_stall_detector_cron_schedule.sql` (its own file, header WHY / WHAT / NOT SELF-CONTAINED / ROLLBACK):
1. `create extension if not exists pg_cron with schema pg_catalog;` — pg_cron 1.6.4 on the local image; already enabled from the dashboard on the hosted project, so a no-op there.
2. Idempotent: `select cron.unschedule(jobid) from cron.job where jobname = 'stall-detector-daily';`, then `cron.schedule('stall-detector-daily', '0 18 * * *', $$select private.run_stall_detector('scheduled')$$)`.
3. **Time:** pg_cron evaluates schedules in `cron.timezone`, GMT/UTC on Supabase. `0 18 * * *` = 18:00 UTC = **02:00 Asia/Manila** (UTC+8, no DST), the quietest hour for Philippine builders, and the run is visible to staff at the start of their day.
4. **Role:** the job row stores `username = current_user` of the migration (`postgres`, also what `supabase db push` uses). `postgres` owns `private.run_stall_detector` (execute revoked from app roles), so the job can call it; nothing is granted.
5. **No secret:** the command is a single SQL function call — no URL, no HTTP (`pg_net` not used), no key (ADR-001).

Who can see or change cron jobs (checked on the local stack, asserted in the test):
- schema `cron` is owned by `supabase_admin`; `USAGE` is granted to `postgres` only. `public`, `anon`, `authenticated`, `service_role` have none, so reading `cron.job` / `cron.job_run_details` and calling `cron.schedule` / `unschedule` / `alter_job` fail with 42501 for them, even though the extension's own object ACLs grant `public` read/execute.
- pg_cron's RLS policies on both tables (`username = current_user`) apply on top.
- `cron` is not an exposed Data API schema (`config.toml`: public, builder, graphql_public).
- The migration does not revoke anything itself: those ACLs belong to `supabase_admin`, and `postgres` cannot revoke grants it did not make; schema usage is the wall.

## API changes
None. No new route, RPC or exposed object.

## Database changes
- Extension `pg_cron` (schema `cron`), job `stall-detector-daily`.
- Rollback: `select cron.unschedule('stall-detector-daily');` (keep the extension; remove it only from the dashboard if no other job uses it).

## Dependencies on other tickets
Blocked by STW-32 (`private.run_stall_detector`), merged. Independent of STW-33 (staff Run now RPC), which calls the same function with `'manual'`; the advisory lock in STW-32 serializes the two.

## Known limitations
- NOT SELF-CONTAINED: depends on pg_cron being available and preloaded (`shared_preload_libraries`, `cron.database_name = postgres`) and, on hosted, enabled in Database → Extensions before `db push`.
- If a project's `cron.timezone` were not UTC, the job would fire at a different local hour.
- pg_cron cannot trigger a job by name on demand; staff use Run now (STW-33) for an immediate run.
- A missed night (database paused / down at 18:00 UTC) is not caught up; the next night's run finds the same stalls (episodes are idempotent).
- Free-plan hosted projects pause after inactivity; a paused project runs no cron jobs.

## Testing notes
- Migration applied to the shared local stack with `docker exec -i supabase_db_stall-watch psql -U postgres -v ON_ERROR_STOP=1 -f - < <file>`, **twice** (idempotency): second run unscheduled the old job and left exactly one `stall-detector-daily` (`0 18 * * *`, command `select private.run_stall_detector('scheduled')`, username `postgres`, active). Not recorded in `supabase_migrations.schema_migrations` (parallel tickets share the DB).
- **Forcing the job:** pg_cron 1.6 accepts interval schedules, so a temporary job `stall-detector-force-check` with schedule `'10 seconds'` and the SAME command was scheduled, then unscheduled. `cron.job_run_details` showed every run `succeeded`, `return_message = '1 row'`, and `builder.stall_runs` gained rows `trigger = 'scheduled'`, `status = 'succeeded'`, `projects_flagged = 3`, `alerts_created = 0` (the episodes already existed, so no duplicate alerts). Because the unschedule call was delayed, the temp job fired 13 times (03:29:45–03:31:45 UTC on 2026-10-21) — 13 real scheduled run rows remain on the shared local stack; no alerts or episodes were added.
- `supabase/tests/cron_schedule.sql` (one rolled-back transaction):
  1. pg_cron installed; exactly one `stall-detector-daily`; schedule matches a once-a-day pattern and equals `0 18 * * *`; command is exactly the scheduled call and has no `key|secret|http|token|jwt|password|bearer`; active, username/database `postgres`; detector owned by `postgres`; exactly one cron job calls `run_stall_detector` (catches a forgotten force-check job).
  2. `anon`, `authenticated`, `service_role`: no usage on schema `cron`; select on both tables, `cron.schedule`, `cron.unschedule`, `cron.alter_job`, update/delete all denied (42501); the job is unchanged afterwards.
  3. Executing the job's own command as `postgres` logs a `scheduled`, `succeeded` run (rolled back).
- `npm run test:db`: all files pass. `npm ci && npm run ci`: lint, typecheck, build green.

## Follow-up tasks
- CI has no database job yet; when it gets one (`supabase start` + `db reset`), `cron_schedule.sql` runs there too (pg_cron is preloaded in the CLI image).
- Optional: surface the next scheduled run time on `/detector` (STW-35) via a staff-only security definer read of `cron.job`.
