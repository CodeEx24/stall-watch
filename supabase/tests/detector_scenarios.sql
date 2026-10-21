-- STW-36: detector scenario tests against a seed-shaped synthetic fixture.
-- Covers: first-run counts, immediate re-run (0 new), recovery then re-stall via
-- builder activity + backdating (exactly 1 new alert), failure injection (failed run,
-- no partial episodes / alerts), rejection of builder / anon / direct private calls,
-- and the Unit 7C trap (staff activity does not count as builder activity).
-- The two-session concurrency scenario lives in detector_concurrency.sh (it needs two
-- connections, which one psql transaction cannot provide).
--
-- Self-contained: own orgs / users / projects (ids ...36xx / ...37xx, emails
-- ds.*@example.test), never writes seed rows (section 8 only reads seed Unit 7C), and
-- everything is rolled back.
-- Independent of shared-DB state: a BASELINE run first gives every already-stalled
-- project its episode, so later counts are exactly this fixture's. The advisory lock
-- that baseline run takes is held until ROLLBACK, so no other detector run can
-- interleave with this file.
\set ON_ERROR_STOP on
begin;

-- run a scalar query as a user (null = anon); returns the text result or the SQLSTATE
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
  exception when others then
    r := 'ERR:' || sqlstate;
  end;
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  return r;
end $$;
grant execute on function pg_temp.as_user(uuid, text) to authenticated, anon;

-- baseline: absorb whatever the shared DB already has stalled, BEFORE the fixture
-- exists (not asserted on beyond success). From here on every new episode / alert
-- belongs to this fixture, and the lock this run took is held until ROLLBACK.
create temp table ds_state (k text primary key, v bigint);
do $$
declare
  v_run uuid := private.run_stall_detector('scheduled');
  r builder.stall_runs;
begin
  select * into r from builder.stall_runs where id = v_run;
  if r.status <> 'succeeded' then
    raise exception 'FAIL: baseline run did not succeed: %', r;
  end if;
  insert into ds_state values ('base_flagged', r.projects_flagged);
  raise notice 'PASS: baseline run absorbed % pre-existing stalled project(s) on this DB', r.projects_flagged;
end $$;

-- fixtures -------------------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email) values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000036a1', 'authenticated', 'authenticated', 'ds.staff@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000036a2', 'authenticated', 'authenticated', 'ds.ana@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000036a3', 'authenticated', 'authenticated', 'ds.mia@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000036a4', 'authenticated', 'authenticated', 'ds.bruno@example.test');
insert into public.orgs (id, name, org_type) values
  ('00000000-0000-0000-0000-0000000036f0', 'DS Staff', 'staff'),
  ('00000000-0000-0000-0000-0000000036a0', 'DS Builder A', 'builder'),
  ('00000000-0000-0000-0000-0000000036b0', 'DS Builder B', 'builder');
-- org A: exactly one admin (+ one member), org B: exactly one admin, staff: admin of the staff org
insert into public.memberships (user_id, org_id, role) values
  ('00000000-0000-0000-0000-0000000036a1', '00000000-0000-0000-0000-0000000036f0', 'admin'),
  ('00000000-0000-0000-0000-0000000036a2', '00000000-0000-0000-0000-0000000036a0', 'admin'),
  ('00000000-0000-0000-0000-0000000036a3', '00000000-0000-0000-0000-0000000036a0', 'member'),
  ('00000000-0000-0000-0000-0000000036a4', '00000000-0000-0000-0000-0000000036b0', 'admin');

-- the seed's nine shapes, as fixture copies
insert into builder.projects (id, org_id, name, status, selection_phase_started_at, selection_due_date, archived_at) values
  ('00000000-0000-0000-0000-000000003612', '00000000-0000-0000-0000-0000000036a0', 'DS Lot 12',   'selection_phase', now() - interval '20 days',  (now() + interval '10 days')::date, null),
  ('00000000-0000-0000-0000-000000003614', '00000000-0000-0000-0000-0000000036a0', 'DS Lot 14',   'selection_phase', now() - interval '10 days',  (now() + interval '2 days')::date,  null),
  ('00000000-0000-0000-0000-000000003615', '00000000-0000-0000-0000-0000000036a0', 'DS Lot 15',   'revision',        now() - interval '40 days',  (now() - interval '5 days')::date,  null),
  ('00000000-0000-0000-0000-000000003609', '00000000-0000-0000-0000-0000000036a0', 'DS Lot 9',    'complete',        now() - interval '90 days',  (now() - interval '60 days')::date, null),
  -- archived while still in selection_phase and long quiet: archived must win
  ('00000000-0000-0000-0000-000000003603', '00000000-0000-0000-0000-0000000036a0', 'DS Lot 3',    'selection_phase', now() - interval '200 days', (now() - interval '170 days')::date, now() - interval '100 days'),
  ('00000000-0000-0000-0000-00000000364b', '00000000-0000-0000-0000-0000000036b0', 'DS Unit 4B', 'selection_phase', now() - interval '8 days',   (now() + interval '20 days')::date, null),
  ('00000000-0000-0000-0000-00000000365a', '00000000-0000-0000-0000-0000000036b0', 'DS Unit 5A', 'selection_phase', now() - interval '2 days',   (now() + interval '25 days')::date, null),
  ('00000000-0000-0000-0000-00000000367c', '00000000-0000-0000-0000-0000000036b0', 'DS Unit 7C', 'selection_phase', now() - interval '15 days',  (now() + interval '6 days')::date,  null),
  ('00000000-0000-0000-0000-00000000362a', '00000000-0000-0000-0000-0000000036b0', 'DS Unit 2A', 'pending_kickoff', null,                         (now() + interval '45 days')::date, null);
insert into builder.project_slots (id, org_id, project_id, room, category) values
  ('00000000-0000-0000-0000-00000000371a', '00000000-0000-0000-0000-0000000036a0', '00000000-0000-0000-0000-000000003612', 'Kitchen', 'Countertop'),
  ('00000000-0000-0000-0000-00000000371b', '00000000-0000-0000-0000-0000000036a0', '00000000-0000-0000-0000-000000003612', 'Kitchen', 'Faucet'),
  ('00000000-0000-0000-0000-00000000374a', '00000000-0000-0000-0000-0000000036a0', '00000000-0000-0000-0000-000000003614', 'Kitchen', 'Countertop'),
  ('00000000-0000-0000-0000-0000000037ca', '00000000-0000-0000-0000-0000000036b0', '00000000-0000-0000-0000-00000000367c', 'Kitchen', 'Countertop'),
  ('00000000-0000-0000-0000-0000000037cb', '00000000-0000-0000-0000-0000000036b0', '00000000-0000-0000-0000-00000000367c', 'Bath', 'Vanity');
-- current selections (inserted without a JWT, so the trigger logs them as 'staff' at
-- now(): ignored by the rule, like any staff edit)
insert into builder.selections (org_id, slot_id, product_name) values
  ('00000000-0000-0000-0000-0000000036a0', '00000000-0000-0000-0000-00000000371a', 'Quartz'),
  ('00000000-0000-0000-0000-0000000036a0', '00000000-0000-0000-0000-00000000374a', 'Marble'),
  ('00000000-0000-0000-0000-0000000036b0', '00000000-0000-0000-0000-0000000037ca', 'Granite');
-- builder history, backdated: Lot 12 last builder activity 10 days ago (stalled; the
-- exact 7-day boundary is covered by stall_views.sql), Lot 14 yesterday (due soon,
-- not stalled), Unit 7C 9 days ago
insert into builder.selection_history (org_id, slot_id, action, product_name, actor_kind, changed_at) values
  ('00000000-0000-0000-0000-0000000036a0', '00000000-0000-0000-0000-00000000371a', 'set', 'Quartz',  'builder', now() - interval '10 days'),
  ('00000000-0000-0000-0000-0000000036a0', '00000000-0000-0000-0000-00000000374a', 'set', 'Marble',  'builder', now() - interval '1 day'),
  ('00000000-0000-0000-0000-0000000036b0', '00000000-0000-0000-0000-0000000037ca', 'set', 'Granite', 'builder', now() - interval '9 days');

create temp table ds_ids (k text primary key, v uuid);
insert into ds_ids values
  ('staff',  '00000000-0000-0000-0000-0000000036a1'),
  ('ana',    '00000000-0000-0000-0000-0000000036a2'),
  ('mia',    '00000000-0000-0000-0000-0000000036a3'),
  ('bruno',  '00000000-0000-0000-0000-0000000036a4'),
  ('lot12',  '00000000-0000-0000-0000-000000003612'),
  ('unit7c', '00000000-0000-0000-0000-00000000367c');

-- fixture-scoped helpers: episodes / alerts on this file's projects only
create or replace function pg_temp.ds_episodes(p_run uuid default null)
returns text language sql as $$
  select coalesce(string_agg(p.name, ',' order by p.name), '')
  from builder.stall_episodes e join builder.projects p on p.id = e.project_id
  where p.org_id in ('00000000-0000-0000-0000-0000000036a0', '00000000-0000-0000-0000-0000000036b0')
    and (p_run is null or e.run_id = p_run);
$$;
create or replace function pg_temp.ds_alert_count(p_user uuid)
returns bigint language sql as $$
  select count(*) from builder.alerts where user_id = p_user;
$$;

-- 0. Unit 7C trap: a staff user really edits a 7C selection (RLS path, history trigger)
do $$
declare
  staff constant uuid := (select v from ds_ids where k = 'staff');
  res text;
begin
  res := pg_temp.as_user(staff,
    'with u as (update builder.selections set product_name = ''Quartzite''
                 where slot_id = ''00000000-0000-0000-0000-0000000037ca'' returning 1)
     select count(*)::text from u');
  if res <> '1' then
    raise exception 'FAIL: staff could not edit the Unit 7C selection (got %)', res;
  end if;
  if not exists (select 1 from builder.selection_history
                 where slot_id = '00000000-0000-0000-0000-0000000037ca' and action = 'change'
                   and actor_kind = 'staff' and changed_by = staff and changed_at = now()) then
    raise exception 'FAIL: staff edit not logged as actor_kind staff';
  end if;
  if (select updated_at from builder.selections where slot_id = '00000000-0000-0000-0000-0000000037ca') <> now() then
    raise exception 'FAIL: staff edit did not refresh selections.updated_at (trap not armed)';
  end if;
  if not (select is_stalled from builder.v_projects where name = 'DS Unit 7C')
     or (select quiet_since from builder.v_projects where name = 'DS Unit 7C') <> now() - interval '9 days' then
    raise exception 'FAIL: staff activity counted as builder activity on DS Unit 7C';
  end if;
  raise notice 'PASS: Unit 7C trap armed -> staff edit logged as staff, updated_at = now(), project still stalled (quiet 9 days)';
end $$;

-- 1. rejections: builder admin / member / anon cannot run the detector; nobody (staff
--    included) can call the private function directly; nothing is logged
do $$
declare
  runs_before bigint := (select count(*) from builder.stall_runs);
  res text;
  who text;
  uid uuid;
begin
  foreach who in array array['ana', 'mia', 'bruno', 'anon'] loop
    uid := (select v from ds_ids where k = who);
    res := pg_temp.as_user(uid, 'select r.id::text from public.run_stall_detector_now() r');
    if res <> 'ERR:42501' then
      raise exception 'FAIL: % calling run_stall_detector_now got %, expected ERR:42501', who, res;
    end if;
  end loop;
  foreach who in array array['ana', 'mia', 'staff', 'anon'] loop
    uid := (select v from ds_ids where k = who);
    res := pg_temp.as_user(uid, 'select private.run_stall_detector(''manual'')::text');
    if res <> 'ERR:42501' then
      raise exception 'FAIL: % calling private.run_stall_detector directly got %, expected ERR:42501', who, res;
    end if;
    res := pg_temp.as_user(uid, 'select private.run_stall_detector(''scheduled'')::text');
    if res <> 'ERR:42501' then
      raise exception 'FAIL: % calling private.run_stall_detector(scheduled) got %, expected ERR:42501', who, res;
    end if;
  end loop;
  if (select count(*) from builder.stall_runs) <> runs_before then
    raise exception 'FAIL: a rejected call logged a run';
  end if;
  raise notice 'PASS: builder admin / member / other-org admin / anon -> RPC 42501; direct private.run_stall_detector as admin / member / staff / anon -> 42501; no run logged';
end $$;


-- 2. failure injection: a throw-away trigger (this transaction only) makes the alert
--    insert fail AFTER this run inserted its episodes
create function private.ds_force_detector_error() returns trigger
language plpgsql as $$
begin
  raise exception 'ds injected failure';
end $$;
create trigger trg_ds_force_detector_error before insert on builder.alerts
  for each row execute function private.ds_force_detector_error();

do $$
declare
  alerts_before bigint := (select count(*) from builder.alerts);
  episodes_before bigint := (select count(*) from builder.stall_episodes);
  v_run uuid;
  r builder.stall_runs;
begin
  v_run := private.run_stall_detector('scheduled');  -- returns the run id, does not raise
  select * into r from builder.stall_runs where id = v_run;
  if r.status <> 'failed' or r.trigger <> 'scheduled' or r.finished_at is null
     or r.error_message <> 'ds injected failure'
     or r.projects_flagged <> 0 or r.alerts_created <> 0 then
    raise exception 'FAIL: injected-failure run row wrong: %', r;
  end if;
  if (select count(*) from builder.alerts) <> alerts_before
     or (select count(*) from builder.stall_episodes) <> episodes_before
     or exists (select 1 from builder.stall_episodes where run_id = v_run)
     or pg_temp.ds_episodes() <> '' then
    raise exception 'FAIL: the failed run left partial episodes or alerts';
  end if;
  raise notice 'PASS: injected failure -> run logged as failed with error_message, counts 0; no episode or alert left behind';
end $$;

drop trigger trg_ds_force_detector_error on builder.alerts;
drop function private.ds_force_detector_error();

-- 3. first run (scheduled): exactly the three stalled shapes, one alert per org admin
do $$
declare
  ana   constant uuid := (select v from ds_ids where k = 'ana');
  mia   constant uuid := (select v from ds_ids where k = 'mia');
  bruno constant uuid := (select v from ds_ids where k = 'bruno');
  staff constant uuid := (select v from ds_ids where k = 'staff');
  base  constant bigint := (select v from ds_state where k = 'base_flagged');
  v_run uuid;
  r builder.stall_runs;
  v text;
begin
  v_run := private.run_stall_detector('scheduled');
  select * into r from builder.stall_runs where id = v_run;
  if r.status <> 'succeeded' or r.trigger <> 'scheduled' or r.error_message is not null then
    raise exception 'FAIL: first run row wrong: %', r;
  end if;
  if r.projects_flagged <> base + 3 or r.alerts_created <> 3 then
    raise exception 'FAIL: first run flagged % (expected %), alerts % (expected 3)',
      r.projects_flagged, base + 3, r.alerts_created;
  end if;
  v := pg_temp.ds_episodes(v_run);
  if v <> 'DS Lot 12,DS Unit 4B,DS Unit 7C' then
    raise exception 'FAIL: first-run episodes for "%", expected DS Lot 12, DS Unit 4B, DS Unit 7C', v;
  end if;
  if exists (select 1 from builder.stall_episodes where run_id = v_run
             and org_id not in ('00000000-0000-0000-0000-0000000036a0', '00000000-0000-0000-0000-0000000036b0')) then
    raise exception 'FAIL: first run created episodes outside the fixture (baseline did not absorb)';
  end if;
  -- the 7C episode starts at the last BUILDER activity, not at the staff edit
  if (select e.quiet_since from builder.stall_episodes e
      where e.project_id = (select d.v from ds_ids d where d.k = 'unit7c')) <> now() - interval '9 days' then
    raise exception 'FAIL: DS Unit 7C episode quiet_since is not the last builder activity';
  end if;
  if pg_temp.ds_alert_count(ana) <> 1 or pg_temp.ds_alert_count(bruno) <> 2
     or pg_temp.ds_alert_count(mia) <> 0 or pg_temp.ds_alert_count(staff) <> 0 then
    raise exception 'FAIL: alerts per user: ana %, bruno %, mia %, staff % (expected 1, 2, 0, 0)',
      pg_temp.ds_alert_count(ana), pg_temp.ds_alert_count(bruno),
      pg_temp.ds_alert_count(mia), pg_temp.ds_alert_count(staff);
  end if;
  if (select string_agg(p.name, ',' order by p.name) from builder.alerts a
      join builder.projects p on p.id = a.project_id where a.user_id in (ana, bruno))
     <> 'DS Lot 12,DS Unit 4B,DS Unit 7C' then
    raise exception 'FAIL: alerts point at the wrong projects';
  end if;
  -- not flagged: due soon but active (Lot 14), revision (Lot 15), complete (Lot 9),
  -- archived (Lot 3), recently entered phase (Unit 5A), pending kickoff (Unit 2A)
  if exists (select 1 from builder.stall_episodes e join builder.projects p on p.id = e.project_id
             where p.name in ('DS Lot 14', 'DS Lot 15', 'DS Lot 9', 'DS Lot 3', 'DS Unit 5A', 'DS Unit 2A'))
     or exists (select 1 from builder.alerts a join builder.projects p on p.id = a.project_id
             where p.name in ('DS Lot 14', 'DS Lot 15', 'DS Lot 9', 'DS Lot 3', 'DS Unit 5A', 'DS Unit 2A')) then
    raise exception 'FAIL: a non-stalled shape got an episode or alert';
  end if;
  -- recipients see them through RLS
  if pg_temp.as_user(ana, 'select count(*)::text from builder.alerts') <> '1'
     or pg_temp.as_user(mia, 'select count(*)::text from builder.alerts') <> '0'
     or pg_temp.as_user(bruno, 'select count(*)::text from builder.alerts') <> '2' then
    raise exception 'FAIL: fixture alerts not visible to exactly their recipients';
  end if;
  raise notice 'PASS: first run -> flagged base+3, 3 alerts: DS Lot 12 (ana), DS Unit 4B + DS Unit 7C (bruno); mia/staff 0; Lot 14/15/9/3, Unit 5A/2A untouched; 7C episode at last builder activity';
end $$;

-- 4. immediate re-run, MANUAL via the staff RPC: 0 new episodes, 0 new alerts
do $$
declare
  staff constant uuid := (select v from ds_ids where k = 'staff');
  base  constant bigint := (select v from ds_state where k = 'base_flagged');
  alerts_before bigint := (select count(*) from builder.alerts);
  res text;
  r builder.stall_runs;
begin
  res := pg_temp.as_user(staff, 'select r.id::text from public.run_stall_detector_now() r');
  if res like 'ERR:%' then
    raise exception 'FAIL: staff RPC failed: %', res;
  end if;
  select * into r from builder.stall_runs where id = res::uuid;
  if r.trigger <> 'manual' or r.status <> 'succeeded' or r.alerts_created <> 0
     or r.projects_flagged <> base + 3 then
    raise exception 'FAIL: immediate re-run row wrong: %', r;
  end if;
  if exists (select 1 from builder.stall_episodes where run_id = r.id)
     or (select count(*) from builder.alerts) <> alerts_before
     or pg_temp.ds_episodes() <> 'DS Lot 12,DS Unit 4B,DS Unit 7C' then
    raise exception 'FAIL: immediate re-run created episodes or alerts';
  end if;
  raise notice 'PASS: immediate re-run (manual, staff RPC) -> succeeded, still flags base+3, 0 new episodes, 0 new alerts';
end $$;

-- 5. recovery: the builder admin really edits a DS Lot 12 selection (RLS path) ->
--    builder activity now -> no longer stalled; a run flags it no more
do $$
declare
  ana  constant uuid := (select v from ds_ids where k = 'ana');
  base constant bigint := (select v from ds_state where k = 'base_flagged');
  res text;
  v_run uuid;
  r builder.stall_runs;
begin
  res := pg_temp.as_user(ana,
    'with u as (update builder.selections set product_name = ''Soapstone''
                 where slot_id = ''00000000-0000-0000-0000-00000000371a'' returning 1)
     select count(*)::text from u');
  if res <> '1' then
    raise exception 'FAIL: builder admin could not edit DS Lot 12 (got %)', res;
  end if;
  if not exists (select 1 from builder.selection_history where slot_id = '00000000-0000-0000-0000-00000000371a'
                 and actor_kind = 'builder' and changed_by = ana and changed_at = now()) then
    raise exception 'FAIL: builder edit not logged as builder activity';
  end if;
  if (select is_stalled from builder.v_projects where name = 'DS Lot 12') then
    raise exception 'FAIL: DS Lot 12 still stalled after builder activity';
  end if;
  v_run := private.run_stall_detector('scheduled');
  select * into r from builder.stall_runs where id = v_run;
  if r.status <> 'succeeded' or r.alerts_created <> 0 or r.projects_flagged <> base + 2
     or exists (select 1 from builder.stall_episodes where run_id = v_run) then
    raise exception 'FAIL: run after recovery wrong: %', r;
  end if;
  raise notice 'PASS: recovery -> builder edit logged as builder, DS Lot 12 not stalled, next run flags base+2 and creates nothing (the old episode is no longer current)';
end $$;

-- 6. re-stall: backdate that builder activity to 8 days ago (time travel on the
--    fixture's own history row; history is append-only, so the immutability trigger is
--    disabled for this one update inside this rolled-back transaction) -> a NEW
--    episode and exactly 1 new alert (org A has one admin), via the staff RPC
alter table builder.selection_history disable trigger trg_selection_history_immutable;
update builder.selection_history
   set changed_at = now() - interval '8 days'
 where slot_id = '00000000-0000-0000-0000-00000000371a'
   and actor_kind = 'builder' and changed_at = now();
alter table builder.selection_history enable trigger trg_selection_history_immutable;

do $$
declare
  ana   constant uuid := (select v from ds_ids where k = 'ana');
  mia   constant uuid := (select v from ds_ids where k = 'mia');
  staff constant uuid := (select v from ds_ids where k = 'staff');
  lot12 constant uuid := (select v from ds_ids where k = 'lot12');
  base  constant bigint := (select v from ds_state where k = 'base_flagged');
  res text;
  r builder.stall_runs;
  v text;
begin
  if not (select is_stalled from builder.v_projects where id = lot12)
     or (select quiet_since from builder.v_projects where id = lot12) <> now() - interval '8 days' then
    raise exception 'FAIL: backdating did not re-stall DS Lot 12';
  end if;
  res := pg_temp.as_user(staff, 'select r.id::text from public.run_stall_detector_now() r');
  if res like 'ERR:%' then
    raise exception 'FAIL: staff RPC failed: %', res;
  end if;
  select * into r from builder.stall_runs where id = res::uuid;
  if r.trigger <> 'manual' or r.status <> 'succeeded' or r.alerts_created <> 1
     or r.projects_flagged <> base + 3 then
    raise exception 'FAIL: re-stall run row wrong: %', r;
  end if;
  if pg_temp.ds_episodes(r.id) <> 'DS Lot 12'
     or (select count(*) from builder.stall_episodes where project_id = lot12) <> 2
     or (select quiet_since from builder.stall_episodes where run_id = r.id) <> now() - interval '8 days' then
    raise exception 'FAIL: re-stall did not open exactly one new DS Lot 12 episode';
  end if;
  if (select count(*) from builder.alerts a join builder.stall_episodes e on e.id = a.episode_id
      where e.run_id = r.id) <> 1
     or (select a.user_id from builder.alerts a join builder.stall_episodes e on e.id = a.episode_id
         where e.run_id = r.id) <> ana
     or pg_temp.ds_alert_count(ana) <> 2 or pg_temp.ds_alert_count(mia) <> 0 then
    raise exception 'FAIL: re-stall alerts wrong (expected one new alert, for ana only)';
  end if;
  v := (select a.message from builder.alerts a join builder.stall_episodes e on e.id = a.episode_id
        where e.run_id = r.id);
  if v <> 'DS Lot 12 has had no builder activity for 8 days. 1 slot is still empty.' then
    raise exception 'FAIL: re-stall message is "%"', v;
  end if;
  raise notice 'PASS: re-stall (backdated builder activity) -> manual run opens a 2nd DS Lot 12 episode and exactly 1 new alert (ana), member none';
end $$;

-- 7. both triggers are in the run log, and staff (only) can read it
do $$
declare
  staff constant uuid := (select v from ds_ids where k = 'staff');
  ana   constant uuid := (select v from ds_ids where k = 'ana');
  n_sched bigint;
  n_manual bigint;
begin
  -- runs of this transaction: started_at = now() (the transaction clock)
  n_sched  := (select count(*) from builder.stall_runs where started_at = now() and trigger = 'scheduled');
  n_manual := (select count(*) from builder.stall_runs where started_at = now() and trigger = 'manual');
  -- baseline + failed + first + recovery = 4 scheduled; re-run + re-stall = 2 manual
  if n_sched <> 4 or n_manual <> 2 then
    raise exception 'FAIL: run log has % scheduled / % manual runs from this test, expected 4 / 2', n_sched, n_manual;
  end if;
  if (select count(*) from builder.stall_runs where started_at = now() and status = 'failed') <> 1 then
    raise exception 'FAIL: expected exactly one failed run from this test';
  end if;
  if pg_temp.as_user(staff, 'select count(*)::text from builder.stall_runs where started_at = now()') <> '6'
     or pg_temp.as_user(ana, 'select count(*)::text from builder.stall_runs') <> '0' then
    raise exception 'FAIL: run log must be readable by staff only';
  end if;
  raise notice 'PASS: stall_runs logs 4 scheduled (1 failed) + 2 manual runs from this test; staff reads all 6, builder admin 0';
end $$;

-- 8. the seed's own Unit 7C, read-only (skipped without the seed): still stalled even
--    though staff touched it yesterday
do $$
begin
  if not exists (select 1 from builder.projects where id = '00000000-0000-0000-0000-00000000b07c') then
    raise notice 'SKIP: seed Unit 7C absent';
    return;
  end if;
  if not (select is_stalled from builder.v_projects where id = '00000000-0000-0000-0000-00000000b07c') then
    raise exception 'FAIL: seed Unit 7C is not stalled (staff activity counted?)';
  end if;
  raise notice 'PASS: seed Unit 7C (read-only) -> stalled despite the recent staff edit';
end $$;

rollback;
