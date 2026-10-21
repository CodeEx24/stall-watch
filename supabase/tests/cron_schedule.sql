-- STW-34: pg_cron daily schedule for the stall detector
-- Every assertion raises on failure. Everything runs in one transaction that is
-- rolled back, so the shared DB keeps its job list and gets no run rows from here.
\set ON_ERROR_STOP on
begin;

-- run a statement as an app role; returns 'OK' or 'DENIED' (42501)
create or replace function pg_temp.try_as(r text, q text)
returns text language plpgsql as $$
declare res text := 'OK';
begin
  if r = 'anon' then
    perform set_config('request.jwt.claims', '', true);
  else
    perform set_config('request.jwt.claims',
      json_build_object('sub', gen_random_uuid(), 'role', r)::text, true);
  end if;
  execute format('set local role %I', r);
  begin
    execute q;
  exception when insufficient_privilege then
    res := 'DENIED';
  end;
  execute 'reset role';
  return res;
end $$;
grant execute on function pg_temp.try_as(text, text) to anon, authenticated, service_role;

-- 1. extension and the one daily job
do $$
declare
  j record;
  n int;
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    raise exception 'FAIL: pg_cron extension is not installed';
  end if;

  select count(*) into n from cron.job where jobname = 'stall-detector-daily';
  if n <> 1 then
    raise exception 'FAIL: expected exactly 1 job stall-detector-daily, found %', n;
  end if;

  select * into j from cron.job where jobname = 'stall-detector-daily';
  -- daily: fixed minute and hour, every day of month / month / weekday
  if j.schedule !~ '^[0-5]?[0-9] (1?[0-9]|2[0-3]) \* \* \*$' then
    raise exception 'FAIL: schedule % is not once a day', j.schedule;
  end if;
  if j.schedule <> '0 18 * * *' then
    raise exception 'FAIL: schedule % is not the documented 0 18 * * * (02:00 Asia/Manila)', j.schedule;
  end if;
  if j.command <> 'select private.run_stall_detector(''scheduled'')' then
    raise exception 'FAIL: unexpected job command: %', j.command;
  end if;
  if j.command ~* '(key|secret|http|token|jwt|password|bearer)' then
    raise exception 'FAIL: job command contains a secret-like word: %', j.command;
  end if;
  if j.username <> 'postgres' or j.database <> 'postgres' or not j.active then
    raise exception 'FAIL: job must be active, run as postgres in db postgres (got %, %, %)',
      j.username, j.database, j.active;
  end if;
  if (select proowner::regrole::text from pg_proc
      where oid = 'private.run_stall_detector(text)'::regprocedure) <> 'postgres' then
    raise exception 'FAIL: private.run_stall_detector is not owned by the job role postgres';
  end if;

  -- no leftover helper jobs (e.g. a forgotten force-check) call the detector
  select count(*) into n from cron.job where command ilike '%run_stall_detector%';
  if n <> 1 then
    raise exception 'FAIL: % cron jobs call run_stall_detector, expected 1', n;
  end if;
  raise notice 'PASS: pg_cron installed; one active job stall-detector-daily, 0 18 * * * (UTC), exact command, no secret words, runs as postgres (detector owner)';
end $$;

-- 2. app roles cannot see or change cron jobs
do $$
declare
  r text;
  q text;
begin
  foreach r in array array['anon', 'authenticated', 'service_role'] loop
    if has_schema_privilege(r, 'cron', 'usage') then
      raise exception 'FAIL: % has usage on schema cron', r;
    end if;
    foreach q in array array[
      'select count(*) from cron.job',
      'select count(*) from cron.job_run_details',
      'select cron.schedule(''x-' || r || ''', ''* * * * *'', ''select 1'')',
      'select cron.unschedule(''stall-detector-daily'')',
      'select cron.alter_job(1, schedule := ''* * * * *'')',
      'update cron.job set active = false',
      'delete from cron.job_run_details'
    ] loop
      if pg_temp.try_as(r, q) <> 'DENIED' then
        raise exception 'FAIL: % was not denied: %', r, q;
      end if;
    end loop;
  end loop;
  if (select active from cron.job where jobname = 'stall-detector-daily') is not true then
    raise exception 'FAIL: the job changed during the denial checks';
  end if;
  raise notice 'PASS: anon / authenticated / service_role have no usage on schema cron; read, schedule, unschedule, alter, update, delete all denied (42501)';
end $$;

-- 3. the job's own command works and logs a scheduled run (rolled back)
do $$
declare
  cmd text;
  run_id uuid;
  st text;
begin
  select command into cmd from cron.job where jobname = 'stall-detector-daily';
  execute cmd into run_id;
  select status into st from builder.stall_runs where id = run_id and trigger = 'scheduled';
  if st is distinct from 'succeeded' then
    raise exception 'FAIL: executing the job command did not log a succeeded scheduled run (got %)', st;
  end if;
  raise notice 'PASS: executing the job command as postgres -> stall_runs row trigger=scheduled, status=succeeded';
end $$;

rollback;
