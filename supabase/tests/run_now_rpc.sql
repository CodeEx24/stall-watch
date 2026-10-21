-- STW-33: public.run_stall_detector_now() (staff-guarded "Run now" RPC)
-- Every assertion raises on failure; the transaction is rolled back, so the shared
-- DB keeps its runs / episodes / alerts unchanged.
\set ON_ERROR_STOP on
begin;

-- fixtures (synthetic) ---------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email) values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000033a1', 'authenticated', 'authenticated', 'rn.staff@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000033a2', 'authenticated', 'authenticated', 'rn.ana@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000033a3', 'authenticated', 'authenticated', 'rn.mia@example.test');
insert into public.orgs (id, name, org_type) values
  ('00000000-0000-0000-0000-0000000033f0', 'RN Staff', 'staff'),
  ('00000000-0000-0000-0000-0000000033a0', 'RN Builder A', 'builder');
insert into public.memberships (user_id, org_id, role) values
  ('00000000-0000-0000-0000-0000000033a1', '00000000-0000-0000-0000-0000000033f0', 'member'),
  ('00000000-0000-0000-0000-0000000033a2', '00000000-0000-0000-0000-0000000033a0', 'admin'),
  ('00000000-0000-0000-0000-0000000033a3', '00000000-0000-0000-0000-0000000033a0', 'member');

-- call the RPC as a user (null = anon); returns 'run:<id>' or the SQLSTATE raised
create or replace function pg_temp.call_as(uid uuid)
returns text language plpgsql as $$
declare
  r builder.stall_runs;
  res text;
begin
  if uid is null then
    perform set_config('request.jwt.claims', '', true);
    execute 'set local role anon';
  else
    perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
  end if;
  begin
    select * into r from public.run_stall_detector_now();
    res := 'run:' || r.id;
  exception when others then
    res := sqlstate || ':' || sqlerrm;
  end;
  execute 'reset role';
  return res;
end $$;
grant execute on function pg_temp.call_as(uuid) to authenticated, anon;

-- 1. hygiene ----------------------------------------------------------------------
do $$
declare
  fn constant regprocedure := 'public.run_stall_detector_now()'::regprocedure;
  p record;
  rl text;
begin
  select * into p from pg_proc where oid = fn;
  if not p.prosecdef then
    raise exception 'FAIL: run_stall_detector_now is not security definer';
  end if;
  if p.proconfig is distinct from array['search_path=""'] then
    raise exception 'FAIL: run_stall_detector_now search_path is %, expected ''''', p.proconfig;
  end if;
  if p.prorettype <> 'builder.stall_runs'::regtype or p.proretset then
    raise exception 'FAIL: run_stall_detector_now must return one builder.stall_runs row';
  end if;
  if (select lanname from pg_language where oid = p.prolang) <> 'plpgsql' then
    raise exception 'FAIL: run_stall_detector_now is not plpgsql';
  end if;
  -- the staff check is the first statement of the body
  if regexp_replace(p.prosrc, '\s+', ' ', 'g')
     not like ' declare % begin if not (select private.is_staff()) then raise exception ''forbidden'' using errcode = ''42501''; end if;%' then
    raise exception 'FAIL: body does not begin with the private.is_staff() check: %', p.prosrc;
  end if;
  foreach rl in array array['public', 'anon'] loop
    if has_function_privilege(rl, fn, 'execute') then
      raise exception 'FAIL: % can execute run_stall_detector_now', rl;
    end if;
  end loop;
  if exists (select 1 from aclexplode(p.proacl) a where a.grantee = 0) then
    raise exception 'FAIL: PUBLIC holds an execute grant on run_stall_detector_now';
  end if;
  if not has_function_privilege('authenticated', fn, 'execute') then
    raise exception 'FAIL: authenticated cannot execute run_stall_detector_now';
  end if;
  if has_function_privilege('authenticated', 'private.run_stall_detector(text)', 'execute') then
    raise exception 'FAIL: authenticated can call private.run_stall_detector directly';
  end if;
  raise notice 'PASS: security definer, search_path='''', plpgsql, returns builder.stall_runs, body starts with is_staff check; execute: public/anon no, authenticated yes';
end $$;

-- 2. builder admin, builder member, anon: forbidden, nothing logged ------------------
do $$
declare
  runs_before bigint := (select count(*) from builder.stall_runs);
  res text;
begin
  res := pg_temp.call_as('00000000-0000-0000-0000-0000000033a2');
  if res <> '42501:forbidden' then
    raise exception 'FAIL: builder admin got %, expected 42501:forbidden', res;
  end if;
  res := pg_temp.call_as('00000000-0000-0000-0000-0000000033a3');
  if res <> '42501:forbidden' then
    raise exception 'FAIL: builder member got %, expected 42501:forbidden', res;
  end if;
  res := pg_temp.call_as(null);
  if res not like '42501:permission denied for function run_stall_detector_now%' then
    raise exception 'FAIL: anon got %, expected insufficient privilege on the function', res;
  end if;
  -- an authenticated JWT whose sub has no membership at all
  res := pg_temp.call_as('00000000-0000-0000-0000-0000000033ff');
  if res <> '42501:forbidden' then
    raise exception 'FAIL: user without membership got %, expected 42501:forbidden', res;
  end if;
  if (select count(*) from builder.stall_runs) <> runs_before then
    raise exception 'FAIL: a forbidden call logged a run';
  end if;
  raise notice 'PASS: builder admin / member / no-membership -> 42501 forbidden; anon -> permission denied (42501); no run logged';
end $$;

-- 3. staff: a manual run is logged and returned ----------------------------------------
do $$
declare
  staff constant uuid := '00000000-0000-0000-0000-0000000033a1';
  runs_before bigint := (select count(*) from builder.stall_runs);
  res text;
  v_id uuid;
  r builder.stall_runs;
  seen text;
begin
  res := pg_temp.call_as(staff);
  if res not like 'run:%' then
    raise exception 'FAIL: staff call failed: %', res;
  end if;
  v_id := substr(res, 5)::uuid;
  if (select count(*) from builder.stall_runs) <> runs_before + 1 then
    raise exception 'FAIL: staff call did not log exactly one run';
  end if;
  select * into r from builder.stall_runs where id = v_id;
  if r.trigger <> 'manual' or r.status <> 'succeeded' or r.finished_at is null
     or r.error_message is not null then
    raise exception 'FAIL: staff run row wrong: %', r;
  end if;
  -- the returned row is the logged row, and staff can read it back through RLS
  perform set_config('request.jwt.claims', json_build_object('sub', staff, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select status into seen from builder.stall_runs where id = v_id;
  reset role;
  if seen is distinct from 'succeeded' then
    raise exception 'FAIL: staff cannot read the run row through RLS (got %)', seen;
  end if;
  -- a builder admin cannot read it
  perform set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000033a2', 'role', 'authenticated')::text, true);
  set local role authenticated;
  select status into seen from builder.stall_runs where id = v_id;
  reset role;
  if seen is not null then
    raise exception 'FAIL: builder admin can read the run row';
  end if;
  raise notice 'PASS: staff -> run row returned (trigger manual, status succeeded), logged once, visible to staff, hidden from builders';
end $$;

-- 4. the RPC returns the full row (PostgREST JSON shape) -------------------------------
do $$
declare
  j jsonb;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000033a1', 'role', 'authenticated')::text, true);
  set local role authenticated;
  select to_jsonb(r) into j from public.run_stall_detector_now() r;
  reset role;
  if not (j ?& array['id', 'trigger', 'status', 'started_at', 'finished_at',
                     'projects_flagged', 'alerts_created', 'error_message']) then
    raise exception 'FAIL: returned row lacks run columns: %', j;
  end if;
  if j->>'trigger' <> 'manual' or j->>'status' <> 'succeeded' then
    raise exception 'FAIL: returned row wrong: %', j;
  end if;
  raise notice 'PASS: returned row carries every run column (id, trigger, status, timestamps, counts, error_message)';
end $$;

rollback;
