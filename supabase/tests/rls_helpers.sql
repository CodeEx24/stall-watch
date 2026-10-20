-- STW-18: private.current_user_org_ids() and private.is_staff()
-- Every assertion raises on failure; the transaction is rolled back.
\set ON_ERROR_STOP on
begin;

-- 1. hygiene: definer, search_path, grants
do $$
declare
  f text;
  fn record;
begin
  foreach f in array array['current_user_org_ids', 'is_staff'] loop
    select p.prosecdef, p.proconfig, p.provolatile into fn
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = f;
    if not found then raise exception 'FAIL: private.%() missing', f; end if;
    if not fn.prosecdef then raise exception 'FAIL: % must be security definer', f; end if;
    if fn.proconfig is null or not ('search_path=""' = any (fn.proconfig)) then
      raise exception 'FAIL: % search_path not pinned: %', f, fn.proconfig;
    end if;
    if fn.provolatile <> 's' then raise exception 'FAIL: % should be STABLE', f; end if;
    if has_function_privilege('public', 'private.' || f || '()', 'execute')
       or has_function_privilege('anon', 'private.' || f || '()', 'execute') then
      raise exception 'FAIL: % executable by public/anon', f;
    end if;
    if not has_function_privilege('authenticated', 'private.' || f || '()', 'execute') then
      raise exception 'FAIL: % not executable by authenticated', f;
    end if;
  end loop;
  if not has_schema_privilege('authenticated', 'private', 'usage') then
    raise exception 'FAIL: authenticated lacks usage on private';
  end if;
  if has_schema_privilege('anon', 'private', 'usage') then
    raise exception 'FAIL: anon has usage on private';
  end if;
  raise notice 'PASS: definer, stable, search_path pinned; execute: authenticated only; usage on private: authenticated only';
end $$;

-- fixtures: staff org, two builder orgs; users: staff, two-org builder, no-membership
insert into auth.users (instance_id, id, aud, role, email) values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000000d1', 'authenticated', 'authenticated', 'staff.probe@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000000d2', 'authenticated', 'authenticated', 'builder.probe@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000000d3', 'authenticated', 'authenticated', 'lonely.probe@example.test');
insert into public.orgs (id, name, org_type) values
  ('00000000-0000-0000-0000-0000000000e1', 'Probe Staff', 'staff'),
  ('00000000-0000-0000-0000-0000000000e2', 'Probe Builder A', 'builder'),
  ('00000000-0000-0000-0000-0000000000e3', 'Probe Builder B', 'builder');
insert into public.memberships (user_id, org_id, role) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000e1', 'member'),
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000e2', 'admin'),
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000e3', 'member');

-- helper: run the two functions as a signed-in user (same claims GoTrue/PostgREST set)
create or replace function pg_temp.as_user(uid uuid)
returns table (org_ids uuid[], staff boolean)
language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  return query select private.current_user_org_ids(), private.is_staff();
  execute 'reset role';
end $$;
grant execute on function pg_temp.as_user(uuid) to authenticated;

do $$
declare r record;
begin
  -- builder in two orgs
  select * into r from pg_temp.as_user('00000000-0000-0000-0000-0000000000d2');
  if r.org_ids <> array['00000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-0000000000e3']::uuid[] then
    raise exception 'FAIL: builder org ids wrong: %', r.org_ids;
  end if;
  if r.staff then raise exception 'FAIL: builder reported as staff'; end if;

  -- user with no membership
  select * into r from pg_temp.as_user('00000000-0000-0000-0000-0000000000d3');
  if r.org_ids <> '{}'::uuid[] or r.org_ids is null then
    raise exception 'FAIL: no-membership user should get an empty array, got %', r.org_ids;
  end if;
  if r.staff then raise exception 'FAIL: no-membership user reported as staff'; end if;

  -- staff member
  select * into r from pg_temp.as_user('00000000-0000-0000-0000-0000000000d1');
  if not r.staff then raise exception 'FAIL: staff member not detected'; end if;
  if r.org_ids <> array['00000000-0000-0000-0000-0000000000e1']::uuid[] then
    raise exception 'FAIL: staff org ids wrong: %', r.org_ids;
  end if;

  -- not signed in (no sub claim)
  perform set_config('request.jwt.claims', '{"role":"authenticated"}', true);
  set local role authenticated;
  if private.current_user_org_ids() <> '{}'::uuid[] or private.is_staff() then
    raise exception 'FAIL: no auth.uid() must mean no orgs and not staff';
  end if;
  reset role;

  raise notice 'PASS: org ids per user, empty array without membership, staff only via a staff org';
end $$;

-- 2. helpers see memberships although RLS on memberships is forced and has no policy
do $$
begin
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d2","role":"authenticated"}', true);
  set local role authenticated;
  begin
    perform 1 from public.memberships;
    raise exception 'FAIL: authenticated can read memberships directly';
  exception when insufficient_privilege then null;
  end;
  if cardinality(private.current_user_org_ids()) <> 2 then
    raise exception 'FAIL: helper could not read memberships under forced RLS';
  end if;
  reset role;
  raise notice 'PASS: direct read denied, helper still works under forced RLS (owner BYPASSRLS)';
end $$;

-- 3. anon cannot call them
do $$
begin
  set local role anon;
  begin
    perform private.is_staff();
    raise exception 'FAIL: anon executed private.is_staff()';
  exception when insufficient_privilege then null;
  end;
  reset role;
  raise notice 'PASS: anon cannot execute the helpers';
end $$;

rollback;
