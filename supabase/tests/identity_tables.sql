-- STW-16: identity tables (orgs, users, memberships)
-- Every assertion raises on failure; the transaction is rolled back.
\set ON_ERROR_STOP on
begin;

-- helper: expect a statement to fail with a given SQLSTATE
create or replace function pg_temp.expect_error(stmt text, state text, label text)
returns void language plpgsql as $$
begin
  execute stmt;
  raise exception 'FAIL: % — statement succeeded: %', label, stmt;
exception
  when others then
    if sqlstate <> state then
      raise exception 'FAIL: % — expected SQLSTATE %, got % (%)', label, state, sqlstate, sqlerrm;
    end if;
end $$;

-- 1. structure: uuid defaults, audit columns, checks
do $$
declare t text;
begin
  foreach t in array array['orgs', 'users', 'memberships'] loop
    if (select count(*) from information_schema.columns
        where table_schema = 'public' and table_name = t
          and column_name in ('created_at', 'updated_at', 'lock_version')) <> 3 then
      raise exception 'FAIL: % missing created_at/updated_at/lock_version', t;
    end if;
    if not exists (select 1 from pg_trigger where tgrelid = ('public.' || t)::regclass
                   and tgname = 'trg_' || t || '_touch' and not tgisinternal) then
      raise exception 'FAIL: % has no touch trigger', t;
    end if;
  end loop;
  if (select column_default from information_schema.columns
      where table_schema = 'public' and table_name = 'orgs' and column_name = 'id') <> 'gen_random_uuid()'
     or (select column_default from information_schema.columns
      where table_schema = 'public' and table_name = 'memberships' and column_name = 'id') <> 'gen_random_uuid()' then
    raise exception 'FAIL: uuid keys must default to gen_random_uuid()';
  end if;
  if (select data_type from information_schema.columns
      where table_schema = 'public' and table_name = 'orgs' and column_name = 'org_type') <> 'text' then
    raise exception 'FAIL: org_type must be text (no enums)';
  end if;
  raise notice 'PASS: uuid keys, audit columns, touch triggers, text statuses';
end $$;

-- 2. no public table references a builder table
do $$
begin
  if exists (
    select 1 from pg_constraint c
    join pg_class src on src.oid = c.conrelid join pg_namespace sn on sn.oid = src.relnamespace
    join pg_class dst on dst.oid = c.confrelid join pg_namespace dn on dn.oid = dst.relnamespace
    where c.contype = 'f' and sn.nspname = 'public' and dn.nspname = 'builder'
  ) then
    raise exception 'FAIL: a public table references a builder table';
  end if;
  raise notice 'PASS: public tables do not reference builder tables';
end $$;

-- 3. constraints reject bad data
insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000000a1', 'probe-a@example.test', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000a2', 'probe-b@example.test', 'authenticated', 'authenticated');
-- STW-17's mirror trigger may already have created these rows; make sure they exist either way.
insert into public.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'probe-a@example.test'),
  ('00000000-0000-0000-0000-0000000000a2', 'probe-b@example.test')
on conflict (id) do nothing;
insert into public.orgs (id, name, org_type) values
  ('00000000-0000-0000-0000-0000000000b1', 'Probe Builder', 'builder');

select pg_temp.expect_error($q$insert into public.orgs (name, org_type) values ('x', 'vendor')$q$, '23514', 'org_type check');
select pg_temp.expect_error($q$insert into public.orgs (name, org_type) values ('   ', 'builder')$q$, '23514', 'org name not blank');
select pg_temp.expect_error($q$insert into public.memberships (user_id, org_id, role) values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1', 'owner')$q$, '23514', 'role check');
insert into public.memberships (user_id, org_id, role) values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1', 'admin');
select pg_temp.expect_error($q$insert into public.memberships (user_id, org_id, role) values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1', 'member')$q$, '23505', 'unique (user_id, org_id)');
select pg_temp.expect_error($q$update public.users set email = 'probe-a@example.test' where id = '00000000-0000-0000-0000-0000000000a2'$q$, '23505', 'unique email');
select pg_temp.expect_error($q$update public.users set email = 'Probe-B@Example.test' where id = '00000000-0000-0000-0000-0000000000a2'$q$, '23514', 'lower-case email');
select pg_temp.expect_error($q$insert into public.users (id, email) values (gen_random_uuid(), 'nobody@example.test')$q$, '23503', 'users.id must exist in auth.users');
select pg_temp.expect_error($q$delete from public.orgs where id = '00000000-0000-0000-0000-0000000000b1'$q$, '23503', 'org with members cannot be deleted');
do $$ begin raise notice 'PASS: checks, unique keys and foreign keys reject bad data'; end $$;

-- 4. locked: RLS enabled + forced, no privileges for app roles
do $$
declare t text;
begin
  foreach t in array array['orgs', 'users', 'memberships'] loop
    if not (select relrowsecurity and relforcerowsecurity from pg_class where oid = ('public.' || t)::regclass) then
      raise exception 'FAIL: % must have RLS enabled and forced', t;
    end if;
    if has_table_privilege('anon', 'public.' || t, 'select,insert,update,delete')
       or has_table_privilege('authenticated', 'public.' || t, 'insert,update,delete') then
      raise exception 'FAIL: app roles hold privileges on %', t;
    end if;
  end loop;
  raise notice 'PASS: RLS enabled and forced; no app-role write privileges';
end $$;

rollback;
