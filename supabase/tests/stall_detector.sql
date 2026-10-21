-- STW-32: private.run_stall_detector (locking, episodes, alerts, failure logging)
-- Every assertion raises on failure; the transaction is rolled back, so the shared
-- DB keeps 0 runs / episodes / alerts.
\set ON_ERROR_STOP on
begin;

-- run a scalar query as a user and return its result as text ('DENIED' on 42501)
create or replace function pg_temp.as_user(uid uuid, q text)
returns text language plpgsql as $$
declare r text;
begin
  if uid is null then
    perform set_config('request.jwt.claims', '', true);
    execute 'set local role anon';
  else
    perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
  end if;
  begin
    execute q into r;
  exception when insufficient_privilege then
    r := 'DENIED';
  end;
  execute 'reset role';
  return r;
end $$;
grant execute on function pg_temp.as_user(uuid, text) to authenticated, anon;

-- 1. hygiene: definer, search_path, advisory lock, execute revoked from app roles
do $$
declare
  fn constant regprocedure := 'private.run_stall_detector(text)'::regprocedure;
  p record;
  rl text;
begin
  select * into p from pg_proc where oid = fn;
  if not p.prosecdef then
    raise exception 'FAIL: run_stall_detector is not security definer';
  end if;
  if p.proconfig is distinct from array['search_path=""'] then
    raise exception 'FAIL: run_stall_detector search_path is %, expected ''''', p.proconfig;
  end if;
  if p.prosrc not like '%pg_advisory_xact_lock(%' then
    raise exception 'FAIL: run_stall_detector does not take pg_advisory_xact_lock';
  end if;
  if p.prorettype <> 'uuid'::regtype then
    raise exception 'FAIL: run_stall_detector must return the run id (uuid)';
  end if;
  foreach rl in array array['public', 'anon', 'authenticated'] loop
    if has_function_privilege(rl, fn, 'execute') then
      raise exception 'FAIL: % can execute run_stall_detector', rl;
    end if;
  end loop;
  if not (select rolbypassrls from pg_roles where oid = p.proowner) then
    raise exception 'FAIL: owner of run_stall_detector cannot bypass RLS';
  end if;
  raise notice 'PASS: security definer, search_path='''', pg_advisory_xact_lock, returns uuid, execute revoked from public/anon/authenticated, owner bypasses RLS';
end $$;

-- 2. invalid trigger rejected, no run row written
do $$
declare
  before_runs bigint := (select count(*) from builder.stall_runs);
  t text;
begin
  foreach t in array array['cron', '', 'MANUAL'] loop
    begin
      perform private.run_stall_detector(t);
      raise exception 'FAIL: trigger % accepted', t;
    exception when invalid_parameter_value then
      null;
    end;
  end loop;
  begin
    perform private.run_stall_detector(null);
    raise exception 'FAIL: null trigger accepted';
  exception when invalid_parameter_value then
    null;
  end;
  if (select count(*) from builder.stall_runs) <> before_runs then
    raise exception 'FAIL: a rejected trigger wrote a run row';
  end if;
  raise notice 'PASS: triggers other than scheduled/manual raise 22023 and log nothing';
end $$;

-- 3. the provided seed with the linked test users (skipped on a fresh DB)
do $$
declare
  ana   uuid := (select id from public.users where email = 'ana@builder-a.test');
  mia   uuid := (select id from public.users where email = 'mia@builder-a.test');
  bruno uuid := (select id from public.users where email = 'bruno@builder-b.test');
  staff uuid := (select id from public.users where email = 'staff@stallwatch.test');
  run1 uuid;
  run2 uuid;
  r record;
  alerts_before bigint;
  v text;
  lot12_days integer;
begin
  if not exists (select 1 from builder.projects where name = 'Lot 12')
     or ana is null or mia is null or bruno is null or staff is null then
    raise notice 'SKIP: seed or linked test users absent; seed-specific assertions skipped';
    return;
  end if;
  if exists (select 1 from builder.stall_episodes) then
    raise notice 'SKIP: episodes already exist on this DB; a first-run scenario is not reproducible';
    return;
  end if;

  -- first run
  run1 := private.run_stall_detector('manual');
  select * into r from builder.stall_runs where id = run1;
  if r.status <> 'succeeded' or r.trigger <> 'manual' or r.finished_at is null
     or r.finished_at < r.started_at or r.error_message is not null then
    raise exception 'FAIL: seed run 1 row wrong: %', r;
  end if;
  if r.projects_flagged <> 3 or r.alerts_created <> 3 then
    raise exception 'FAIL: seed run 1 flagged %, alerts %; expected 3 and 3', r.projects_flagged, r.alerts_created;
  end if;
  v := (select string_agg(p.name, ',' order by p.name) from builder.stall_episodes e
        join builder.projects p on p.id = e.project_id where e.run_id = run1);
  if v <> 'Lot 12,Unit 4B,Unit 7C' then
    raise exception 'FAIL: seed run 1 episodes for %, expected Lot 12, Unit 4B, Unit 7C', v;
  end if;
  if (select count(*) from builder.alerts where user_id = ana) <> 1
     or (select count(*) from builder.alerts where user_id = bruno) <> 2
     or (select count(*) from builder.alerts where user_id = mia) <> 0
     or (select count(*) from builder.alerts where user_id = staff) <> 0 then
    raise exception 'FAIL: seed alerts per user wrong (expected Ana 1, Bruno 2, Mia 0, staff 0)';
  end if;
  if (select string_agg(p.name, ',' order by p.name) from builder.alerts a
      join builder.projects p on p.id = a.project_id where a.user_id = bruno) <> 'Unit 4B,Unit 7C'
     or (select p.name from builder.alerts a join builder.projects p on p.id = a.project_id
         where a.user_id = ana) <> 'Lot 12' then
    raise exception 'FAIL: seed alerts point at the wrong projects';
  end if;
  if exists (select 1 from builder.alerts a where a.kind <> 'stalled' or a.episode_id is null) then
    raise exception 'FAIL: seed alerts must be kind stalled with an episode';
  end if;
  -- the exact AC text (the seed is relative to load time; 7 whole days while loaded < 1 day ago)
  v := (select message from builder.alerts where user_id = ana);
  lot12_days := (select floor(extract(epoch from now() - quiet_since) / 86400)::integer
                 from builder.v_projects where name = 'Lot 12');
  if lot12_days = 7 then
    if v <> 'Lot 12 has had no builder activity for 7 days. 3 slots are still empty.' then
      raise exception 'FAIL: Lot 12 message is "%"', v;
    end if;
  elsif v <> format('Lot 12 has had no builder activity for %s days. 3 slots are still empty.', lot12_days) then
    raise exception 'FAIL: Lot 12 message is "%"', v;
  else
    raise notice 'NOTE: seed loaded more than a day ago (Lot 12 quiet % days); exact-7 text not checkable', lot12_days;
  end if;
  -- the advisory lock is held by this transaction until it ends
  if not exists (select 1 from pg_locks where locktype = 'advisory' and pid = pg_backend_pid()
                 and classid = 0 and objid = 2026032 and granted) then
    raise exception 'FAIL: advisory lock 2026032 not held after a run';
  end if;
  -- recipients read their alerts through RLS; others see nothing
  if pg_temp.as_user(ana, 'select count(*)::text from builder.alerts') <> '1'
     or pg_temp.as_user(ana, 'select message from builder.alerts') <> v
     or pg_temp.as_user(mia, 'select count(*)::text from builder.alerts') <> '0'
     or pg_temp.as_user(bruno, 'select count(*)::text from builder.alerts') <> '2'
     or pg_temp.as_user(staff, 'select count(*)::text from builder.alerts') <> '0' then
    raise exception 'FAIL: seed alerts not visible to exactly their recipients';
  end if;
  if pg_temp.as_user(ana, 'select count(*)::text from builder.stall_runs') <> '0'
     or pg_temp.as_user(staff, format('select count(*)::text from builder.stall_runs where id = %L', run1)) <> '1' then
    raise exception 'FAIL: run log must be staff-only';
  end if;
  raise notice 'PASS: seed run 1 -> succeeded, flagged 3, alerts Ana 1 (Lot 12), Bruno 2 (Unit 4B, Unit 7C), Mia 0, staff 0; exact Lot 12 text; lock held; RLS: Ana 1, Mia 0';

  -- second immediate run
  alerts_before := (select count(*) from builder.alerts);
  run2 := private.run_stall_detector('scheduled');
  select * into r from builder.stall_runs where id = run2;
  if r.status <> 'succeeded' or r.alerts_created <> 0 or r.projects_flagged <> 3 then
    raise exception 'FAIL: seed run 2 row wrong: %', r;
  end if;
  if exists (select 1 from builder.stall_episodes where run_id = run2)
     or (select count(*) from builder.alerts) <> alerts_before then
    raise exception 'FAIL: seed run 2 created episodes or alerts';
  end if;
  raise notice 'PASS: seed run 2 -> succeeded, 0 new episodes, 0 new alerts (still flags 3 stalled)';
end $$;

-- fixtures (synthetic, works without the seed) ------------------------------------------
insert into auth.users (instance_id, id, aud, role, email) values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000032a1', 'authenticated', 'authenticated', 'sd.staff@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000032a2', 'authenticated', 'authenticated', 'sd.ana@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000032a3', 'authenticated', 'authenticated', 'sd.mia@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000032a4', 'authenticated', 'authenticated', 'sd.bruno@example.test');
insert into public.orgs (id, name, org_type) values
  ('00000000-0000-0000-0000-0000000032f0', 'SD Staff', 'staff'),
  ('00000000-0000-0000-0000-0000000032a0', 'SD Builder A', 'builder'),
  ('00000000-0000-0000-0000-0000000032b0', 'SD Builder B', 'builder');
insert into public.memberships (user_id, org_id, role) values
  ('00000000-0000-0000-0000-0000000032a1', '00000000-0000-0000-0000-0000000032f0', 'admin'),
  ('00000000-0000-0000-0000-0000000032a2', '00000000-0000-0000-0000-0000000032a0', 'admin'),
  ('00000000-0000-0000-0000-0000000032a3', '00000000-0000-0000-0000-0000000032a0', 'member'),
  ('00000000-0000-0000-0000-0000000032a4', '00000000-0000-0000-0000-0000000032b0', 'admin');

insert into builder.projects (id, org_id, name, status, selection_phase_started_at) values
  ('00000000-0000-0000-0000-000000003211', '00000000-0000-0000-0000-0000000032a0', 'SD Quiet A', 'selection_phase', now() - interval '20 days'),
  ('00000000-0000-0000-0000-000000003212', '00000000-0000-0000-0000-0000000032a0', 'SD Fresh A', 'selection_phase', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000003221', '00000000-0000-0000-0000-0000000032b0', 'SD Phase B', 'selection_phase', now() - interval '7 days');
insert into builder.project_slots (id, org_id, project_id, room, category) values
  ('00000000-0000-0000-0000-000000003311', '00000000-0000-0000-0000-0000000032a0', '00000000-0000-0000-0000-000000003211', 'Kitchen', 'Countertop'),
  ('00000000-0000-0000-0000-000000003312', '00000000-0000-0000-0000-0000000032a0', '00000000-0000-0000-0000-000000003211', 'Kitchen', 'Faucet'),
  ('00000000-0000-0000-0000-000000003321', '00000000-0000-0000-0000-0000000032b0', '00000000-0000-0000-0000-000000003221', 'Kitchen', 'Countertop'),
  ('00000000-0000-0000-0000-000000003322', '00000000-0000-0000-0000-0000000032b0', '00000000-0000-0000-0000-000000003221', 'Kitchen', 'Faucet'),
  ('00000000-0000-0000-0000-000000003323', '00000000-0000-0000-0000-0000000032b0', '00000000-0000-0000-0000-000000003221', 'Bath', 'Vanity');
-- SD Quiet A: one of two slots filled (the insert logs 'staff' at now(), ignored by the
-- rule); last builder activity 10 days ago -> quiet 10 days, 1 empty slot.
-- SD Phase B: phase started exactly 7 days ago, no activity -> quiet 7 days, 3 empty.
insert into builder.selections (org_id, slot_id, product_name) values
  ('00000000-0000-0000-0000-0000000032a0', '00000000-0000-0000-0000-000000003311', 'Quartz');
insert into builder.selection_history (org_id, slot_id, action, product_name, actor_kind, changed_at) values
  ('00000000-0000-0000-0000-0000000032a0', '00000000-0000-0000-0000-000000003311', 'set', 'Quartz', 'builder', now() - interval '10 days');

-- 4. forced error inside the work block: a throw-away trigger (this transaction only)
--    makes the alert insert fail AFTER the episodes were inserted
create function private.sd_force_detector_error() returns trigger
language plpgsql as $$
begin
  raise exception 'forced detector failure %', repeat('x', 3000);
end $$;
create trigger trg_sd_force_detector_error before insert on builder.alerts
  for each row execute function private.sd_force_detector_error();

do $$
declare
  v_run uuid;
  r record;
begin
  v_run := private.run_stall_detector('manual');  -- returns, does not raise
  select * into r from builder.stall_runs where id = v_run;
  if r.status <> 'failed' or r.finished_at is null or r.error_message is null then
    raise exception 'FAIL: forced-error run row wrong: %', r;
  end if;
  if r.error_message not like 'forced detector failure x%' or length(r.error_message) <> 2000 then
    raise exception 'FAIL: error_message not the truncated sqlerrm (length %)', length(r.error_message);
  end if;
  if r.projects_flagged <> 0 or r.alerts_created <> 0 then
    raise exception 'FAIL: failed run reports counts';
  end if;
  if exists (select 1 from builder.stall_episodes where run_id = r.id)
     or exists (select 1 from builder.alerts where project_id in
                ('00000000-0000-0000-0000-000000003211', '00000000-0000-0000-0000-000000003221')) then
    raise exception 'FAIL: partial episodes or alerts survived the failed run';
  end if;
  raise notice 'PASS: forced error -> run row failed with error_message (sqlerrm cut to 2000), finished_at set; 0 episodes / alerts from that run';
end $$;

drop trigger trg_sd_force_detector_error on builder.alerts;
drop function private.sd_force_detector_error();

-- 5. synthetic success, re-run, re-stall
do $$
declare
  admin_a  constant uuid := '00000000-0000-0000-0000-0000000032a2';
  member_a constant uuid := '00000000-0000-0000-0000-0000000032a3';
  admin_b  constant uuid := '00000000-0000-0000-0000-0000000032a4';
  staff    constant uuid := '00000000-0000-0000-0000-0000000032a1';
  sd_projects constant uuid[] := array['00000000-0000-0000-0000-000000003211',
                                       '00000000-0000-0000-0000-000000003212',
                                       '00000000-0000-0000-0000-000000003221']::uuid[];
  v_run uuid;
  r record;
begin
  v_run := private.run_stall_detector('scheduled');
  select * into r from builder.stall_runs where id = v_run;
  if r.status <> 'succeeded' or r.trigger <> 'scheduled'
     or r.projects_flagged <> (select count(*) from builder.v_projects where is_stalled) then
    raise exception 'FAIL: synthetic run row wrong: %', r;
  end if;
  if (select string_agg(p.name, ',' order by p.name) from builder.stall_episodes e
      join builder.projects p on p.id = e.project_id
      where e.run_id = r.id and e.project_id = any (sd_projects)) <> 'SD Phase B,SD Quiet A' then
    raise exception 'FAIL: synthetic episodes wrong (expected SD Phase B, SD Quiet A; not SD Fresh A)';
  end if;
  if (select quiet_since from builder.stall_episodes where project_id = sd_projects[1]) <> now() - interval '10 days' then
    raise exception 'FAIL: episode quiet_since is not the view''s quiet_since';
  end if;
  if (select message from builder.alerts where user_id = admin_a)
       <> 'SD Quiet A has had no builder activity for 10 days. 1 slot is still empty.'
     or (select message from builder.alerts where user_id = admin_b)
       <> 'SD Phase B has had no builder activity for 7 days. 3 slots are still empty.' then
    raise exception 'FAIL: synthetic messages wrong: % / %',
      (select message from builder.alerts where user_id = admin_a),
      (select message from builder.alerts where user_id = admin_b);
  end if;
  if exists (select 1 from builder.alerts where user_id in (member_a, staff)) then
    raise exception 'FAIL: a member or staff got an alert';
  end if;
  if (select count(*) from builder.alerts a where a.project_id = any (sd_projects)) <> 2
     or exists (select 1 from builder.alerts a join builder.stall_episodes e on e.id = a.episode_id
                where a.project_id = any (sd_projects)
                  and (e.run_id <> r.id or a.org_id <> e.org_id or a.kind <> 'stalled')) then
    raise exception 'FAIL: synthetic alerts not one per admin per new episode of this run';
  end if;
  if r.alerts_created <> (select count(*) from builder.alerts a join builder.stall_episodes e
                          on e.id = a.episode_id where e.run_id = r.id) then
    raise exception 'FAIL: alerts_created % does not match alerts inserted', r.alerts_created;
  end if;
  raise notice 'PASS: synthetic run -> episodes for the 2 stalled projects only; one alert per org admin, none for member/staff; plural/singular text; counts match';

  -- recipients through RLS
  if pg_temp.as_user(admin_a, 'select count(*)::text from builder.alerts') <> '1'
     or pg_temp.as_user(member_a, 'select count(*)::text from builder.alerts') <> '0'
     or pg_temp.as_user(admin_b, 'select count(*)::text from builder.alerts') <> '1'
     or pg_temp.as_user(staff, 'select count(*)::text from builder.alerts where project_id in
          (''00000000-0000-0000-0000-000000003211'', ''00000000-0000-0000-0000-000000003221'')') <> '0' then
    raise exception 'FAIL: synthetic alerts not visible to exactly their recipients';
  end if;
  if pg_temp.as_user(admin_a, 'select count(*)::text from builder.stall_runs') <> '0'
     or pg_temp.as_user(staff, format('select status from builder.stall_runs where id = %L', r.id)) <> 'succeeded' then
    raise exception 'FAIL: run log must be staff-only';
  end if;
  raise notice 'PASS: RLS -> admin sees own alert, member 0, other org admin only theirs, staff none; run log staff-only';

  -- immediate re-run: nothing new
  v_run := private.run_stall_detector('manual');
  select * into r from builder.stall_runs where id = v_run;
  if r.status <> 'succeeded' or r.alerts_created <> 0
     or exists (select 1 from builder.stall_episodes e where e.run_id = r.id)
     or (select count(*) from builder.alerts a where a.project_id = any (sd_projects)) <> 2 then
    raise exception 'FAIL: re-run created episodes or alerts: %', r;
  end if;
  raise notice 'PASS: immediate re-run -> succeeded, 0 new episodes, 0 new alerts';

  -- re-stall: builder activity 8 days ago moves quiet_since -> a new episode and a new alert
  insert into builder.selection_history (org_id, slot_id, action, product_name, actor_kind, changed_at) values
    ('00000000-0000-0000-0000-0000000032a0', '00000000-0000-0000-0000-000000003311', 'change', 'Granite', 'builder', now() - interval '8 days');
  v_run := private.run_stall_detector('scheduled');
  select * into r from builder.stall_runs where id = v_run;
  if r.status <> 'succeeded' or r.alerts_created <> 1
     or (select count(*) from builder.stall_episodes where project_id = sd_projects[1]) <> 2
     or (select message from builder.alerts a join builder.stall_episodes e on e.id = a.episode_id
         where e.run_id = r.id and a.user_id = admin_a)
        <> 'SD Quiet A has had no builder activity for 8 days. 1 slot is still empty.' then
    raise exception 'FAIL: re-stall did not produce exactly one new episode and alert: %', r;
  end if;
  raise notice 'PASS: re-stall (quiet_since moved) -> new episode, one new alert for the admin';
end $$;

rollback;
