-- STW-17: auth.users -> public.users mirror trigger
-- Every assertion raises on failure; the transaction is rolled back.
\set ON_ERROR_STOP on
begin;

-- 1. function hygiene
do $$
declare
  fn record;
begin
  select p.prosecdef, p.proconfig into fn
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'private' and p.proname = 'mirror_auth_user';
  if not found then
    raise exception 'FAIL: private.mirror_auth_user() missing';
  end if;
  if not fn.prosecdef then
    raise exception 'FAIL: mirror_auth_user must be security definer';
  end if;
  if fn.proconfig is null or not ('search_path=""' = any (fn.proconfig)) then
    raise exception 'FAIL: search_path not pinned to empty: %', fn.proconfig;
  end if;
  if has_function_privilege('public', 'private.mirror_auth_user()', 'execute')
     or has_function_privilege('anon', 'private.mirror_auth_user()', 'execute')
     or has_function_privilege('authenticated', 'private.mirror_auth_user()', 'execute') then
    raise exception 'FAIL: execute not revoked from public/anon/authenticated';
  end if;
  if not exists (select 1 from pg_trigger
                 where tgrelid = 'auth.users'::regclass and tgname = 'trg_auth_users_mirror' and not tgisinternal) then
    raise exception 'FAIL: trigger trg_auth_users_mirror missing on auth.users';
  end if;
  raise notice 'PASS: security definer, search_path pinned, execute revoked, trigger attached';
end $$;

-- 2. insert into auth.users -> mirrored with same id and email
--    (the real GoTrue path, role supabase_auth_admin, is exercised end-to-end in the PR via /auth/v1/signup)
insert into auth.users (instance_id, id, aud, role, email)
values ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000000c1',
        'authenticated', 'authenticated', 'Mirror.Probe@Example.test');
do $$
begin
  if not exists (select 1 from public.users
                 where id = '00000000-0000-0000-0000-0000000000c1' and email = 'mirror.probe@example.test') then
    raise exception 'FAIL: new auth user not mirrored into public.users';
  end if;
  raise notice 'PASS: auth insert mirrored (same id, lower-cased email)';
end $$;

-- 3. email change is mirrored; delete cascades
update auth.users set email = 'renamed.probe@example.test' where id = '00000000-0000-0000-0000-0000000000c1';
do $$
begin
  if (select email from public.users where id = '00000000-0000-0000-0000-0000000000c1') <> 'renamed.probe@example.test' then
    raise exception 'FAIL: email change not mirrored';
  end if;
  raise notice 'PASS: email change mirrored';
end $$;
delete from auth.users where id = '00000000-0000-0000-0000-0000000000c1';
do $$
begin
  if exists (select 1 from public.users where id = '00000000-0000-0000-0000-0000000000c1') then
    raise exception 'FAIL: deleting the auth user did not remove public.users row';
  end if;
  raise notice 'PASS: auth delete cascades';
end $$;

-- 4. backfill invariant: every auth user with an email has a mirror row
do $$
begin
  if exists (select 1 from auth.users a
             left join public.users u on u.id = a.id
             where a.email is not null and u.id is null) then
    raise exception 'FAIL: auth users without a public.users mirror row';
  end if;
  raise notice 'PASS: every auth user with an email is mirrored';
end $$;

-- 5. app roles still cannot write public.users directly
set local role authenticated;
do $$
begin
  begin
    insert into public.users (id, email) values (gen_random_uuid(), 'forge@example.test');
    raise exception 'FAIL: authenticated inserted into public.users';
  exception when insufficient_privilege then
    raise notice 'PASS: authenticated cannot insert into public.users';
  end;
end $$;
reset role;

rollback;
