-- STW-31: stall_runs, stall_episodes, alerts.episode_id
-- Every assertion raises on failure; the transaction is rolled back.
\set ON_ERROR_STOP on
begin;

create or replace function pg_temp.expect_error(stmt text, state text, label text)
returns void language plpgsql as $$
begin
  execute stmt;
  raise exception 'FAIL: % — statement succeeded', label;
exception when others then
  if sqlstate <> state then
    raise exception 'FAIL: % — expected %, got % (%)', label, state, sqlstate, sqlerrm;
  end if;
end $$;

-- 1. catalog
do $$
declare t text;
begin
  if (select count(*) from information_schema.columns where table_schema = 'builder' and table_name = 'stall_runs'
      and column_name in ('started_at','finished_at','trigger','projects_flagged','alerts_created','status','error_message')) <> 7 then
    raise exception 'FAIL: stall_runs columns missing';
  end if;
  if not exists (select 1 from pg_constraint where conname = 'stall_episodes_project_quiet_key' and contype = 'u')
     or not exists (select 1 from pg_constraint where conname = 'alerts_episode_user_key' and contype = 'u') then
    raise exception 'FAIL: unique (project_id, quiet_since) or (episode_id, user_id) missing';
  end if;
  foreach t in array array['stall_runs', 'stall_episodes'] loop
    if not (select relrowsecurity and relforcerowsecurity from pg_class where oid = ('builder.' || t)::regclass) then
      raise exception 'FAIL: builder.% RLS not enabled+forced', t;
    end if;
    if (select array_agg(policyname || ':' || cmd) from pg_policies where schemaname = 'builder' and tablename = t)
       is distinct from array['p_' || t || '_select:SELECT'] then
      raise exception 'FAIL: builder.% must have exactly one select policy', t;
    end if;
    if not exists (select 1 from pg_policies where schemaname = 'builder' and tablename = t and qual like '%is_staff%') then
      raise exception 'FAIL: builder.% select policy must use private.is_staff()', t;
    end if;
    if has_table_privilege('authenticated', 'builder.' || t, 'insert')
       or has_table_privilege('authenticated', 'builder.' || t, 'update')
       or has_table_privilege('authenticated', 'builder.' || t, 'delete')
       or has_table_privilege('anon', 'builder.' || t, 'select,insert,update,delete') then
      raise exception 'FAIL: write or anon privileges on builder.%', t;
    end if;
  end loop;
  raise notice 'PASS: run columns, unique keys, forced RLS, staff-only select, no write grants';
end $$;

-- 2. constraints
select pg_temp.expect_error($q$insert into builder.stall_runs (trigger) values ('cron')$q$, '23514', 'trigger check');
select pg_temp.expect_error($q$insert into builder.stall_runs (trigger, status) values ('manual', 'succeeded')$q$, '23514', 'finished_at required when done');
select pg_temp.expect_error($q$insert into builder.stall_runs (trigger, status, finished_at) values ('manual', 'failed', now())$q$, '23514', 'failed needs error_message');
insert into builder.stall_runs (id, trigger) values ('00000000-0000-0000-0000-0000000006e1', 'scheduled');
update builder.stall_runs set status = 'succeeded', finished_at = now(), projects_flagged = 1, alerts_created = 1
  where id = '00000000-0000-0000-0000-0000000006e1';

insert into auth.users (instance_id, id, aud, role, email) values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000006a1', 'authenticated', 'authenticated', 'det.staff@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000006a2', 'authenticated', 'authenticated', 'det.ana@example.test');
insert into public.orgs (id, name, org_type) values
  ('00000000-0000-0000-0000-0000000006f0', 'DET Staff', 'staff'),
  ('00000000-0000-0000-0000-0000000006a0', 'DET Builder A', 'builder'),
  ('00000000-0000-0000-0000-0000000006b0', 'DET Builder B', 'builder');
insert into public.memberships (user_id, org_id, role) values
  ('00000000-0000-0000-0000-0000000006a1', '00000000-0000-0000-0000-0000000006f0', 'admin'),
  ('00000000-0000-0000-0000-0000000006a2', '00000000-0000-0000-0000-0000000006a0', 'admin');
insert into builder.projects (id, org_id, name, status, selection_phase_started_at) values
  ('00000000-0000-0000-0000-0000000006a5', '00000000-0000-0000-0000-0000000006a0', 'DET Lot', 'selection_phase', now() - interval '20 days');
insert into builder.stall_episodes (id, org_id, project_id, quiet_since, run_id) values
  ('00000000-0000-0000-0000-0000000006e5', '00000000-0000-0000-0000-0000000006a0', '00000000-0000-0000-0000-0000000006a5',
   '2026-10-01 00:00+00', '00000000-0000-0000-0000-0000000006e1');

select pg_temp.expect_error($q$insert into builder.stall_episodes (org_id, project_id, quiet_since, run_id)
  values ('00000000-0000-0000-0000-0000000006a0', '00000000-0000-0000-0000-0000000006a5', '2026-10-01 00:00+00', '00000000-0000-0000-0000-0000000006e1')$q$,
  '23505', 'same (project, quiet_since) twice');
select pg_temp.expect_error($q$insert into builder.stall_episodes (org_id, project_id, quiet_since, run_id)
  values ('00000000-0000-0000-0000-0000000006b0', '00000000-0000-0000-0000-0000000006a5', '2026-10-05 00:00+00', '00000000-0000-0000-0000-0000000006e1')$q$,
  '23503', 'episode org must match project org');
-- a re-stall (new quiet_since) is a new episode
insert into builder.stall_episodes (org_id, project_id, quiet_since, run_id)
  values ('00000000-0000-0000-0000-0000000006a0', '00000000-0000-0000-0000-0000000006a5', '2026-10-09 00:00+00', '00000000-0000-0000-0000-0000000006e1');

insert into builder.alerts (org_id, user_id, project_id, kind, message, episode_id) values
  ('00000000-0000-0000-0000-0000000006a0', '00000000-0000-0000-0000-0000000006a2', '00000000-0000-0000-0000-0000000006a5',
   'stalled', 'DET Lot stalled', '00000000-0000-0000-0000-0000000006e5');
select pg_temp.expect_error($q$insert into builder.alerts (org_id, user_id, project_id, kind, message, episode_id)
  values ('00000000-0000-0000-0000-0000000006a0', '00000000-0000-0000-0000-0000000006a2', '00000000-0000-0000-0000-0000000006a5', 'stalled', 'dup', '00000000-0000-0000-0000-0000000006e5')$q$,
  '23505', 'one alert per (episode, user)');
select pg_temp.expect_error($q$insert into builder.alerts (org_id, user_id, project_id, kind, message)
  values ('00000000-0000-0000-0000-0000000006a0', '00000000-0000-0000-0000-0000000006a2', '00000000-0000-0000-0000-0000000006a5', 'stalled', 'no episode')$q$,
  '23514', 'stalled alert needs an episode');
do $$ begin raise notice 'PASS: run status/finished/error checks, unique episode per (project, quiet_since), re-stall = new episode, one alert per (episode, user)'; end $$;

-- 3. staff-only visibility; builders see nothing
create or replace function pg_temp.visible(uid uuid)
returns table (runs bigint, episodes bigint) language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  return query select (select count(*) from builder.stall_runs where id = '00000000-0000-0000-0000-0000000006e1'),
                      (select count(*) from builder.stall_episodes where org_id = '00000000-0000-0000-0000-0000000006a0');
  execute 'reset role';
end $$;
grant execute on function pg_temp.visible(uuid) to authenticated;
do $$
declare r record;
begin
  select * into r from pg_temp.visible('00000000-0000-0000-0000-0000000006a1');
  if r.runs <> 1 or r.episodes <> 2 then raise exception 'FAIL: staff should see runs=1 episodes=2, got %/%', r.runs, r.episodes; end if;
  select * into r from pg_temp.visible('00000000-0000-0000-0000-0000000006a2');
  if r.runs <> 0 or r.episodes <> 0 then raise exception 'FAIL: builder sees detector rows %/%', r.runs, r.episodes; end if;
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000006a1","role":"authenticated"}', true);
  set local role authenticated;
  begin
    insert into builder.stall_runs (trigger) values ('manual');
    raise exception 'FAIL: staff inserted a run directly';
  exception when insufficient_privilege then null;
  end;
  reset role;
  raise notice 'PASS: staff sees runs and episodes; builder sees none; no direct writes even for staff';
end $$;

rollback;
