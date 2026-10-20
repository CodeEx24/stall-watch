-- STW-19: forced RLS + read-only policies on orgs, users, memberships
-- Every assertion raises on failure; the transaction is rolled back.
\set ON_ERROR_STOP on
begin;

-- 1. catalog: RLS enabled + forced, select policy per table, no write privileges
do $$
declare t text;
begin
  foreach t in array array['orgs', 'users', 'memberships'] loop
    if not (select relrowsecurity and relforcerowsecurity from pg_class where oid = ('public.' || t)::regclass) then
      raise exception 'FAIL: % RLS not enabled+forced', t;
    end if;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = t
                   and policyname = 'p_' || t || '_select' and cmd = 'SELECT') then
      raise exception 'FAIL: % has no p_%_select policy', t, t;
    end if;
    if exists (select 1 from pg_policies where schemaname = 'public' and tablename = t and cmd <> 'SELECT') then
      raise exception 'FAIL: % has a non-select policy', t;
    end if;
    if has_table_privilege('authenticated', 'public.' || t, 'insert')
       or has_table_privilege('authenticated', 'public.' || t, 'update')
       or has_table_privilege('authenticated', 'public.' || t, 'delete')
       or has_table_privilege('anon', 'public.' || t, 'insert')
       or has_table_privilege('anon', 'public.' || t, 'update')
       or has_table_privilege('anon', 'public.' || t, 'delete')
       or has_table_privilege('anon', 'public.' || t, 'select') then
      raise exception 'FAIL: write (or anon read) privilege present on %', t;
    end if;
    if not has_table_privilege('authenticated', 'public.' || t, 'select') then
      raise exception 'FAIL: authenticated cannot select %', t;
    end if;
  end loop;
  raise notice 'PASS: RLS enabled+forced, p_<table>_select only, no insert/update/delete for anon/authenticated';
end $$;

-- fixtures: staff org S, builder orgs A and B
insert into auth.users (instance_id, id, aud, role, email) values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000001a1', 'authenticated', 'authenticated', 'rls.staff@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000001a2', 'authenticated', 'authenticated', 'rls.a.admin@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000001a3', 'authenticated', 'authenticated', 'rls.a.member@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000001a4', 'authenticated', 'authenticated', 'rls.b.admin@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000001a5', 'authenticated', 'authenticated', 'rls.nobody@example.test');
insert into public.orgs (id, name, org_type) values
  ('00000000-0000-0000-0000-0000000001b1', 'RLS Staff', 'staff'),
  ('00000000-0000-0000-0000-0000000001b2', 'RLS Builder A', 'builder'),
  ('00000000-0000-0000-0000-0000000001b3', 'RLS Builder B', 'builder');
insert into public.memberships (user_id, org_id, role) values
  ('00000000-0000-0000-0000-0000000001a1', '00000000-0000-0000-0000-0000000001b1', 'member'),
  ('00000000-0000-0000-0000-0000000001a2', '00000000-0000-0000-0000-0000000001b2', 'admin'),
  ('00000000-0000-0000-0000-0000000001a3', '00000000-0000-0000-0000-0000000001b2', 'member'),
  ('00000000-0000-0000-0000-0000000001a4', '00000000-0000-0000-0000-0000000001b3', 'admin');

-- counts visible to a user, restricted to this test's fixtures
create or replace function pg_temp.visible(uid uuid)
returns table (orgs bigint, users bigint, memberships bigint)
language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  return query select
    (select count(*) from public.orgs where name like 'RLS %'),
    (select count(*) from public.users where email like 'rls.%@example.test'),
    (select count(*) from public.memberships m where m.org_id in (
       '00000000-0000-0000-0000-0000000001b1', '00000000-0000-0000-0000-0000000001b2', '00000000-0000-0000-0000-0000000001b3'));
  execute 'reset role';
end $$;
grant execute on function pg_temp.visible(uuid) to authenticated;

do $$
declare r record;
begin
  -- AC3: signed-in user with no membership sees zero orgs (and only themself)
  select * into r from pg_temp.visible('00000000-0000-0000-0000-0000000001a5');
  if r.orgs <> 0 or r.memberships <> 0 or r.users <> 1 then
    raise exception 'FAIL: no-membership user saw orgs=% users=% memberships=% (want 0/1/0)', r.orgs, r.users, r.memberships;
  end if;

  -- builder A member: own org only, A's two users, A's two memberships; nothing of B or staff
  select * into r from pg_temp.visible('00000000-0000-0000-0000-0000000001a3');
  if r.orgs <> 1 or r.users <> 2 or r.memberships <> 2 then
    raise exception 'FAIL: builder A saw orgs=% users=% memberships=% (want 1/2/2)', r.orgs, r.users, r.memberships;
  end if;

  -- builder B admin: isolated from A
  select * into r from pg_temp.visible('00000000-0000-0000-0000-0000000001a4');
  if r.orgs <> 1 or r.users <> 1 or r.memberships <> 1 then
    raise exception 'FAIL: builder B saw orgs=% users=% memberships=% (want 1/1/1)', r.orgs, r.users, r.memberships;
  end if;

  -- staff: everything
  select * into r from pg_temp.visible('00000000-0000-0000-0000-0000000001a1');
  if r.orgs <> 3 or r.users <> 5 or r.memberships <> 4 then
    raise exception 'FAIL: staff saw orgs=% users=% memberships=% (want 3/5/4)', r.orgs, r.users, r.memberships;
  end if;
  raise notice 'PASS: no membership -> 0 orgs; builder A and B isolated; staff sees all';
end $$;

-- 2. writes are rejected for a signed-in builder admin and for staff
create or replace function pg_temp.expect_denied(uid uuid, stmt text, label text)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  begin
    execute stmt;
    execute 'reset role';
    raise exception 'FAIL: % succeeded', label;
  exception when insufficient_privilege then
    execute 'reset role';
  end;
end $$;
grant execute on function pg_temp.expect_denied(uuid, text, text) to authenticated;

select pg_temp.expect_denied('00000000-0000-0000-0000-0000000001a2', $q$insert into public.orgs (name, org_type) values ('Evil', 'staff')$q$, 'builder creates staff org');
select pg_temp.expect_denied('00000000-0000-0000-0000-0000000001a2', $q$insert into public.memberships (user_id, org_id, role) values ('00000000-0000-0000-0000-0000000001a2', '00000000-0000-0000-0000-0000000001b1', 'admin')$q$, 'builder joins staff org');
select pg_temp.expect_denied('00000000-0000-0000-0000-0000000001a2', $q$update public.memberships set role = 'admin' where user_id = '00000000-0000-0000-0000-0000000001a3'$q$, 'builder promotes member');
select pg_temp.expect_denied('00000000-0000-0000-0000-0000000001a2', $q$update public.orgs set org_type = 'staff' where id = '00000000-0000-0000-0000-0000000001b2'$q$, 'builder turns own org into staff');
select pg_temp.expect_denied('00000000-0000-0000-0000-0000000001a2', $q$delete from public.users where id = '00000000-0000-0000-0000-0000000001a3'$q$, 'builder deletes user');
select pg_temp.expect_denied('00000000-0000-0000-0000-0000000001a1', $q$update public.users set email = 'x@example.test' where id = '00000000-0000-0000-0000-0000000001a2'$q$, 'staff edits user');
do $$ begin raise notice 'PASS: insert/update/delete denied for builders and staff'; end $$;

-- 3. anon reads nothing
do $$
begin
  set local role anon;
  begin
    perform 1 from public.orgs;
    raise exception 'FAIL: anon can select orgs';
  exception when insufficient_privilege then null;
  end;
  reset role;
  raise notice 'PASS: anon cannot read identity tables';
end $$;

rollback;
