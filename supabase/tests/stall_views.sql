-- STW-26: live stall rule views builder.v_project_stall and builder.v_projects
-- Every assertion raises on failure; the transaction is rolled back.
\set ON_ERROR_STOP on
begin;

-- 1. catalog: security_invoker on both views, grants authenticated-only, one window
do $$
declare
  v text;
begin
  foreach v in array array['v_project_stall', 'v_projects'] loop
    if not coalesce((select 'security_invoker=true' = any (reloptions)
                     from pg_class where oid = ('builder.' || v)::regclass and relkind = 'v'), false) then
      raise exception 'FAIL: builder.% is not a view with security_invoker=true', v;
    end if;
    if has_table_privilege('anon', 'builder.' || v, 'select,insert,update,delete') then
      raise exception 'FAIL: anon has privileges on builder.%', v;
    end if;
    if not has_table_privilege('authenticated', 'builder.' || v, 'select')
       or has_table_privilege('authenticated', 'builder.' || v, 'insert,update,delete') then
      raise exception 'FAIL: authenticated must have select only on builder.%', v;
    end if;
  end loop;
  if private.stall_window() <> interval '7 days' then
    raise exception 'FAIL: stall window is %, expected 7 days', private.stall_window();
  end if;
  if (select provolatile from pg_proc where oid = 'private.stall_window()'::regprocedure) <> 'i'
     or has_function_privilege('anon', 'private.stall_window()', 'execute')
     or not has_function_privilege('authenticated', 'private.stall_window()', 'execute') then
    raise exception 'FAIL: private.stall_window() must be immutable, executable by authenticated only';
  end if;
  raise notice 'PASS: both views security_invoker=true, select for authenticated only, stall window 7 days in one immutable function';
end $$;

-- 2a. the provided seed, when loaded (skipped on a fresh DB)
do $$
declare
  seed_names constant text[] := array['Lot 12', 'Lot 14', 'Lot 15', 'Lot 9', 'Lot 3',
                                      'Unit 4B', 'Unit 5A', 'Unit 7C', 'Unit 2A'];
  stalled text[];
begin
  if not exists (select 1 from builder.projects where name = 'Lot 12') then
    raise notice 'SKIP: seed not loaded; seed-specific assertions skipped';
    return;
  end if;
  if (select count(*) from builder.v_projects where name = any (seed_names)) <> 9 then
    raise exception 'FAIL: expected 9 seeded projects in v_projects';
  end if;
  select array_agg(name order by name) into stalled
  from builder.v_projects where name = any (seed_names) and is_stalled;
  if stalled is distinct from array['Lot 12', 'Unit 4B', 'Unit 7C'] then
    raise exception 'FAIL: seeded stalled projects are %, expected {Lot 12, Unit 4B, Unit 7C}', stalled;
  end if;
  -- Unit 7C: staff touched a selection yesterday, yet quiet_since is the builder's 9 days ago
  if (select quiet_since > now() - interval '8 days' from builder.v_projects where name = 'Unit 7C') then
    raise exception 'FAIL: Unit 7C quiet_since moved with staff activity';
  end if;
  raise notice 'PASS: seed -> stalled exactly Lot 12, Unit 4B, Unit 7C; other six not; Unit 7C staff change ignored';
end $$;

-- fixtures ----------------------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email) values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000026a1', 'authenticated', 'authenticated', 'sv.staff@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000026a2', 'authenticated', 'authenticated', 'sv.ana@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000026a3', 'authenticated', 'authenticated', 'sv.bruno@example.test');
insert into public.orgs (id, name, org_type) values
  ('00000000-0000-0000-0000-0000000026f0', 'SV Staff', 'staff'),
  ('00000000-0000-0000-0000-0000000026a0', 'SV Builder A', 'builder'),
  ('00000000-0000-0000-0000-0000000026b0', 'SV Builder B', 'builder');
insert into public.memberships (user_id, org_id, role) values
  ('00000000-0000-0000-0000-0000000026a1', '00000000-0000-0000-0000-0000000026f0', 'admin'),
  ('00000000-0000-0000-0000-0000000026a2', '00000000-0000-0000-0000-0000000026a0', 'admin'),
  ('00000000-0000-0000-0000-0000000026a3', '00000000-0000-0000-0000-0000000026b0', 'admin');

insert into builder.projects (id, org_id, name, status, selection_phase_started_at, archived_at) values
  ('00000000-0000-0000-0000-000000002611', '00000000-0000-0000-0000-0000000026a0', 'SV Quiet 7d',    'selection_phase', now() - interval '20 days', null),
  ('00000000-0000-0000-0000-000000002612', '00000000-0000-0000-0000-0000000026a0', 'SV Quiet 6d23h', 'selection_phase', now() - interval '20 days', null),
  ('00000000-0000-0000-0000-000000002613', '00000000-0000-0000-0000-0000000026a0', 'SV Phase 8d',    'selection_phase', now() - interval '8 days',  null),
  ('00000000-0000-0000-0000-000000002614', '00000000-0000-0000-0000-0000000026a0', 'SV Phase 2d',    'selection_phase', now() - interval '2 days',  null),
  ('00000000-0000-0000-0000-000000002615', '00000000-0000-0000-0000-0000000026a0', 'SV Archived',    'selection_phase', now() - interval '30 days', now() - interval '1 day'),
  ('00000000-0000-0000-0000-000000002616', '00000000-0000-0000-0000-0000000026a0', 'SV Revision',    'revision',        now() - interval '30 days', null),
  ('00000000-0000-0000-0000-000000002621', '00000000-0000-0000-0000-0000000026b0', 'SV Trap',        'selection_phase', now() - interval '15 days', null),
  ('00000000-0000-0000-0000-000000002622', '00000000-0000-0000-0000-0000000026b0', 'SV Kickoff',     'pending_kickoff', null,                       null);
insert into builder.project_slots (id, org_id, project_id, room, category) values
  ('00000000-0000-0000-0000-000000002711', '00000000-0000-0000-0000-0000000026a0', '00000000-0000-0000-0000-000000002611', 'Kitchen', 'Countertop'),
  ('00000000-0000-0000-0000-000000002712', '00000000-0000-0000-0000-0000000026a0', '00000000-0000-0000-0000-000000002611', 'Kitchen', 'Faucet'),
  ('00000000-0000-0000-0000-000000002713', '00000000-0000-0000-0000-0000000026a0', '00000000-0000-0000-0000-000000002612', 'Kitchen', 'Countertop'),
  ('00000000-0000-0000-0000-000000002721', '00000000-0000-0000-0000-0000000026b0', '00000000-0000-0000-0000-000000002621', 'Kitchen', 'Countertop');

-- current selections: inserted here with no auth.uid(), so the trigger logs them as
-- 'staff' activity at now() -- which the rule must ignore.
insert into builder.selections (org_id, slot_id, product_name) values
  ('00000000-0000-0000-0000-0000000026a0', '00000000-0000-0000-0000-000000002711', 'Quartz'),
  ('00000000-0000-0000-0000-0000000026b0', '00000000-0000-0000-0000-000000002721', 'Concrete');
-- backdated builder activity (history is append-only but insertable by the owner)
insert into builder.selection_history (org_id, slot_id, action, product_name, actor_kind, changed_at) values
  ('00000000-0000-0000-0000-0000000026a0', '00000000-0000-0000-0000-000000002711', 'set', 'Quartz',   'builder', now() - interval '12 days'),
  ('00000000-0000-0000-0000-0000000026a0', '00000000-0000-0000-0000-000000002711', 'set', 'Quartz',   'builder', now() - interval '7 days'),
  ('00000000-0000-0000-0000-0000000026a0', '00000000-0000-0000-0000-000000002713', 'set', 'Granite',  'builder', now() - interval '6 days 23 hours'),
  ('00000000-0000-0000-0000-0000000026a0', '00000000-0000-0000-0000-000000002713', 'clear', null,     'builder', now() - interval '6 days 23 hours'),
  ('00000000-0000-0000-0000-0000000026b0', '00000000-0000-0000-0000-000000002721', 'set', 'Concrete', 'builder', now() - interval '9 days'),
  ('00000000-0000-0000-0000-0000000026b0', '00000000-0000-0000-0000-000000002721', 'change', 'Clay',  'staff',   now() - interval '1 day');

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

-- 2b. synthetic scenario (works on a fresh DB without the seed)
do $$
declare
  stalled text[];
  r record;
begin
  select array_agg(name order by name) into stalled
  from builder.v_projects where name like 'SV %' and is_stalled;
  if stalled is distinct from array['SV Phase 8d', 'SV Quiet 7d', 'SV Trap'] then
    raise exception 'FAIL: synthetic stalled set is %, expected {SV Phase 8d, SV Quiet 7d, SV Trap}', stalled;
  end if;
  if (select count(*) from builder.v_projects where name like 'SV %') <> 8
     or exists (select 1 from builder.v_projects where name like 'SV %' and is_stalled is null) then
    raise exception 'FAIL: expected 8 SV rows with non-null is_stalled';
  end if;
  -- quiet_since = greatest(phase start, last BUILDER history)
  select * into r from builder.v_projects where name = 'SV Quiet 7d';
  if r.quiet_since <> now() - interval '7 days' or r.org_name <> 'SV Builder A'
     or r.slot_count <> 2 or r.empty_slots <> 1 then
    raise exception 'FAIL: SV Quiet 7d row wrong: %', r;
  end if;
  if (select quiet_since from builder.v_projects where name = 'SV Phase 8d') <> now() - interval '8 days'
     or (select quiet_since from builder.v_projects where name = 'SV Quiet 6d23h') <> now() - interval '6 days 23 hours'
     or (select quiet_since from builder.v_projects where name = 'SV Kickoff') is not null then
    raise exception 'FAIL: quiet_since is not greatest(selection_phase_started_at, last builder history)';
  end if;
  if (select quiet_since from builder.v_projects where name = 'SV Trap') <> now() - interval '9 days' then
    raise exception 'FAIL: staff activity moved quiet_since on SV Trap';
  end if;
  if (select last_builder_activity_at from builder.v_project_stall
      where project_id = '00000000-0000-0000-0000-000000002611') <> now() - interval '7 days' then
    raise exception 'FAIL: v_project_stall.last_builder_activity_at wrong';
  end if;
  raise notice 'PASS: synthetic -> 7d boundary stalled, 6d23h not, phase 8d stalled, phase 2d / archived / revision / kickoff not; staff-only change ignored; slot counts right';
end $$;

-- 3. a staff change does not reset quiet_since; a builder change does
do $$
declare
  staff constant uuid := '00000000-0000-0000-0000-0000000026a1';
  ana   constant uuid := '00000000-0000-0000-0000-0000000026a2';
  q constant text := $q$select quiet_since::text || '|' || is_stalled from builder.v_projects where name = 'SV Quiet 7d'$q$;
begin
  if pg_temp.as_user(staff, $s$with u as (update builder.selections set product_name = 'Staff pick'
       where slot_id = '00000000-0000-0000-0000-000000002711' returning 1) select count(*)::text from u$s$) <> '1' then
    raise exception 'FAIL: staff could not change the selection';
  end if;
  if (select actor_kind from builder.selection_history
      where slot_id = '00000000-0000-0000-0000-000000002711' and product_name = 'Staff pick') <> 'staff' then
    raise exception 'FAIL: staff change not logged as staff';
  end if;
  if pg_temp.as_user(staff, q) <> (now() - interval '7 days')::text || '|true' then
    raise exception 'FAIL: staff change reset quiet_since: %', pg_temp.as_user(staff, q);
  end if;
  if pg_temp.as_user(ana, $s$with u as (update builder.selections set product_name = 'Builder pick'
       where slot_id = '00000000-0000-0000-0000-000000002711' returning 1) select count(*)::text from u$s$) <> '1' then
    raise exception 'FAIL: Ana could not change her selection';
  end if;
  if pg_temp.as_user(ana, q) <> now()::text || '|false' then
    raise exception 'FAIL: builder change did not reset quiet_since: %', pg_temp.as_user(ana, q);
  end if;
  raise notice 'PASS: staff change keeps quiet_since and the stall; builder change resets quiet_since to now and clears it';
end $$;

-- 4. tenant isolation through the invoker views
do $$
declare
  staff constant uuid := '00000000-0000-0000-0000-0000000026a1';
  ana   constant uuid := '00000000-0000-0000-0000-0000000026a2';
  bruno constant uuid := '00000000-0000-0000-0000-0000000026a3';
  seeded_ana uuid;
  v text;
begin
  if pg_temp.as_user(ana, $q$select string_agg(distinct org_name, ',') from builder.v_projects where name like 'SV %'$q$) <> 'SV Builder A'
     or pg_temp.as_user(ana, $q$select count(*)::text from builder.v_projects where name like 'SV %'$q$) <> '6'
     or pg_temp.as_user(ana, $q$select count(*)::text from builder.v_project_stall where org_id = '00000000-0000-0000-0000-0000000026b0'$q$) <> '0' then
    raise exception 'FAIL: SV Ana sees rows outside SV Builder A';
  end if;
  if pg_temp.as_user(bruno, $q$select string_agg(name, ',' order by name) from builder.v_projects where name like 'SV %'$q$) <> 'SV Kickoff,SV Trap' then
    raise exception 'FAIL: SV Bruno should see only SV Builder B';
  end if;
  if pg_temp.as_user(staff, $q$select count(*)::text from builder.v_projects where name like 'SV %'$q$) <> '8' then
    raise exception 'FAIL: staff should see every builder';
  end if;
  raise notice 'PASS: synthetic Ana sees only her org, Bruno only his, staff all (v_projects and v_project_stall)';

  -- the seeded Ana (read only; skipped when the seed / test users are absent)
  select id into seeded_ana from public.users where email = 'ana@builder-a.test';
  if seeded_ana is null or not exists (select 1 from builder.projects where name = 'Lot 12') then
    raise notice 'SKIP: seeded ana@builder-a.test not present';
    return;
  end if;
  v := pg_temp.as_user(seeded_ana, $q$select string_agg(name || ':' || is_stalled, ',' order by name) from builder.v_projects$q$);
  if v <> 'Lot 12:true,Lot 14:false,Lot 15:false,Lot 3:false,Lot 9:false' then
    raise exception 'FAIL: seeded Ana sees %', v;
  end if;
  if pg_temp.as_user(seeded_ana, $q$select string_agg(distinct org_name, ',') from builder.v_projects$q$) <> 'Builder A' then
    raise exception 'FAIL: seeded Ana sees another org';
  end if;
  raise notice 'PASS: seeded Ana sees exactly the 5 Builder A projects, Lot 12 stalled';
end $$;

-- 5. anon denied
do $$
begin
  if pg_temp.as_user(null, 'select count(*)::text from builder.v_projects') <> 'DENIED'
     or pg_temp.as_user(null, 'select count(*)::text from builder.v_project_stall') <> 'DENIED' then
    raise exception 'FAIL: anon can read the stall views';
  end if;
  raise notice 'PASS: anon denied on both views';
end $$;

rollback;
