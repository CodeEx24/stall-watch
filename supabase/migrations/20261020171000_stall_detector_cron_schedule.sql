-- WHY:  Stalls must be found every night without anyone pressing a button (ADR-001,
--       Option A). pg_cron runs inside Postgres and calls the security definer
--       detector directly, so there is no HTTP route, no shared secret and no
--       service-role key to protect or leak.
-- WHAT: 1. create extension if not exists pg_cron (schema pg_catalog; the extension
--          creates its own schema "cron"). On the hosted project the owner already
--          enabled it in the dashboard, so this is a no-op there.
--       2. Idempotent schedule: unschedule any existing job named
--          'stall-detector-daily', then
--            cron.schedule('stall-detector-daily', '0 18 * * *',
--                          'select private.run_stall_detector(''scheduled'')')
--          pg_cron evaluates the expression in cron.timezone, which is GMT/UTC on
--          Supabase: 18:00 UTC = 02:00 Asia/Manila (UTC+8, no DST), once a day.
--          The command text is a single function call: no secret, no URL, no key.
--       3. The job row records username = current_user = postgres (the migration
--          role), so the nightly run executes as postgres, which owns
--          private.run_stall_detector (execute is revoked from public/anon/
--          authenticated; the owner keeps it).
--       Who can see or change cron jobs: schema "cron" is owned by supabase_admin
--       and USAGE on it is granted to postgres only -- not to public, anon,
--       authenticated or service_role -- so app roles cannot read cron.job /
--       cron.job_run_details or call cron.schedule/unschedule/alter_job (42501), even
--       though the extension's own object ACLs grant public read/execute. pg_cron's
--       RLS policies on both tables add username = current_user on top. "cron" is not
--       an exposed Data API schema (config.toml: public, builder, graphql_public).
--       This migration grants nothing. supabase/tests/cron_schedule.sql asserts all
--       of the above.
-- NOT SELF-CONTAINED: this migration depends on things outside supabase/migrations/:
--       * the pg_cron extension must be available and preloaded on the server
--         (shared_preload_libraries, cron.database_name = postgres). Supabase local
--         and hosted both ship it; on hosted it is enabled in the dashboard,
--         Database -> Extensions -> pg_cron (SETUP.md section 2, step 3).
--       * the job runs as the role that applied the migration (postgres), which must
--         own (or be able to execute) private.run_stall_detector (STW-32).
--       * the schedule fires in cron.timezone (UTC on Supabase); a project with a
--         different cron.timezone would run at a different local hour.
-- ROLLBACK: select cron.unschedule('stall-detector-daily');
--       (leave the extension in place; drop it only from the dashboard, and only if
--       no other job uses it.)

create extension if not exists pg_cron with schema pg_catalog;

select cron.unschedule(jobid)
from cron.job
where jobname = 'stall-detector-daily';

select cron.schedule(
  'stall-detector-daily',
  '0 18 * * *',
  $$select private.run_stall_detector('scheduled')$$
);
