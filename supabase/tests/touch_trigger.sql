-- STW-15: private schema + private.touch_updated_at()
-- Run: docker exec -i supabase_db_stall-watch psql -U postgres -v ON_ERROR_STOP=1 -f - < supabase/tests/touch_trigger.sql
-- Every assertion raises on failure; the transaction is rolled back, so nothing persists.
\set ON_ERROR_STOP on
begin;

-- 1. private exists and is not exposed over the Data API
do $$
begin
  if not exists (select 1 from pg_namespace where nspname = 'private') then
    raise exception 'FAIL: schema private does not exist';
  end if;
  if exists (
    select 1
    from pg_db_role_setting s
    cross join lateral unnest(s.setconfig) as c(cfg)
    where c.cfg like 'pgrst.db_schemas=%' and c.cfg ~ '(^|[=,\s])private([,\s]|$)'
  ) then
    raise exception 'FAIL: private is listed in pgrst.db_schemas';
  end if;
  if has_schema_privilege('anon', 'private', 'usage') then
    raise exception 'FAIL: anon has usage on private';
  end if;
  raise notice 'PASS: private exists, not exposed, no anon usage';
end $$;

-- 2. function hygiene: search_path pinned, not executable by app roles
do $$
declare
  cfg text[];
begin
  select p.proconfig into cfg
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'private' and p.proname = 'touch_updated_at';
  if cfg is null or not ('search_path=""' = any (cfg)) then
    raise exception 'FAIL: touch_updated_at search_path not pinned to empty, got %', cfg;
  end if;
  if has_function_privilege('anon', 'private.touch_updated_at()', 'execute')
     or has_function_privilege('authenticated', 'private.touch_updated_at()', 'execute') then
    raise exception 'FAIL: app roles can execute touch_updated_at';
  end if;
  raise notice 'PASS: search_path pinned, execute revoked from anon/authenticated';
end $$;

-- 3. behaviour on a scratch table
create table public._touch_probe (
  id int primary key,
  note text,
  updated_at timestamptz not null default '2000-01-01',
  lock_version integer not null default 0
);
create trigger trg_touch_probe before update on public._touch_probe
  for each row execute function private.touch_updated_at();

insert into public._touch_probe (id, note) values (1, 'a');

do $$
declare
  r record;
begin
  -- client tries to forge both columns; trigger must win
  update public._touch_probe set note = 'b', lock_version = 99, updated_at = '1999-01-01' where id = 1;
  select * into r from public._touch_probe where id = 1;
  if r.lock_version <> 1 then
    raise exception 'FAIL: lock_version expected 1, got %', r.lock_version;
  end if;
  if r.updated_at <> now() then
    raise exception 'FAIL: updated_at expected now() (%), got %', now(), r.updated_at;
  end if;

  update public._touch_probe set note = 'c' where id = 1;
  select * into r from public._touch_probe where id = 1;
  if r.lock_version <> 2 then
    raise exception 'FAIL: lock_version expected 2 after second update, got %', r.lock_version;
  end if;
  raise notice 'PASS: updated_at = now(), lock_version bumps by 1 and ignores client values';
end $$;

-- 4. the trigger fires for an app role that has no rights on schema private
grant select, update on public._touch_probe to authenticated;
set local role authenticated;
update public._touch_probe set note = 'd' where id = 1;
reset role;
do $$
begin
  if (select lock_version from public._touch_probe where id = 1) <> 3 then
    raise exception 'FAIL: trigger did not fire for authenticated';
  end if;
  raise notice 'PASS: trigger fires for authenticated without usage on private';
end $$;

rollback;
