-- STW-25: tenant-isolation attack suite and forced-RLS catalog check
-- Ana (Builder A admin) attacks Builder B; anon attacks everything. Users are impersonated
-- exactly like PostgREST does it: request.jwt.claims + set local role authenticated/anon.
-- Synthetic fixtures only (no seed data, no real users); every assertion raises on failure
-- and the whole transaction is rolled back.
\set ON_ERROR_STOP on
begin;

-- 1. catalog: every ordinary/partitioned table in public and builder has RLS enabled AND forced.
--    Generic on purpose: a table added by a future migration is covered automatically.
create or replace function pg_temp.tables_missing_forced_rls()
returns setof text language sql stable as $$
  select n.nspname || '.' || c.relname
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname in ('public', 'builder') and c.relkind in ('r', 'p')
    and not (c.relrowsecurity and c.relforcerowsecurity)
  order by 1
$$;

do $$
declare
  missing text[];
  n_tables integer;
begin
  select count(*) into n_tables from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname in ('public', 'builder') and c.relkind in ('r', 'p');
  if n_tables < 8 then
    raise exception 'FAIL: expected at least 8 tables in public/builder, found %', n_tables;
  end if;
  select array_agg(t) into missing from pg_temp.tables_missing_forced_rls() t;
  if missing is not null then
    raise exception 'FAIL: tables lacking enable+force RLS: %', missing;
  end if;
  raise notice 'PASS: catalog check: 0 of % public/builder tables lack enable+force RLS', n_tables;
end $$;

-- 1b. negative control: the catalog query really does catch a table that is only enabled,
--     or not protected at all (the probe table is created and dropped inside the rollback)
do $$
begin
  create table public.stw25_probe (id integer);
  if not exists (select 1 from pg_temp.tables_missing_forced_rls() t where t = 'public.stw25_probe') then
    raise exception 'FAIL: catalog check missed a table without RLS';
  end if;
  alter table public.stw25_probe enable row level security;
  if not exists (select 1 from pg_temp.tables_missing_forced_rls() t where t = 'public.stw25_probe') then
    raise exception 'FAIL: catalog check missed a table with RLS enabled but not forced';
  end if;
  alter table public.stw25_probe force row level security;
  if exists (select 1 from pg_temp.tables_missing_forced_rls() t where t = 'public.stw25_probe') then
    raise exception 'FAIL: catalog check flagged a table with RLS enabled and forced';
  end if;
  drop table public.stw25_probe;
  raise notice 'PASS: catalog check flags no-RLS and enabled-but-not-forced tables (negative control)';
end $$;

-- fixtures ---------------------------------------------------------------------------------
-- staff org, Builder A (Ana admin, Mia member), Builder B (Bruno admin); B owns a project,
-- slots, a selection (history via trigger) and an alert addressed to Bruno.
insert into auth.users (instance_id, id, aud, role, email) values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000025a1', 'authenticated', 'authenticated', 'iso.ana@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000025a2', 'authenticated', 'authenticated', 'iso.mia@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000025b1', 'authenticated', 'authenticated', 'iso.bruno@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000025f1', 'authenticated', 'authenticated', 'iso.staff@example.test');
insert into public.orgs (id, name, org_type) values
  ('00000000-0000-0000-0000-0000000025f0', 'ISO Staff', 'staff'),
  ('00000000-0000-0000-0000-0000000025a0', 'ISO Builder A', 'builder'),
  ('00000000-0000-0000-0000-0000000025b0', 'ISO Builder B', 'builder');
insert into public.memberships (user_id, org_id, role) values
  ('00000000-0000-0000-0000-0000000025a1', '00000000-0000-0000-0000-0000000025a0', 'admin'),
  ('00000000-0000-0000-0000-0000000025a2', '00000000-0000-0000-0000-0000000025a0', 'member'),
  ('00000000-0000-0000-0000-0000000025b1', '00000000-0000-0000-0000-0000000025b0', 'admin'),
  ('00000000-0000-0000-0000-0000000025f1', '00000000-0000-0000-0000-0000000025f0', 'admin');
insert into builder.projects (id, org_id, name, status, selection_phase_started_at) values
  ('00000000-0000-0000-0000-0000000025a5', '00000000-0000-0000-0000-0000000025a0', 'ISO Lot A', 'selection_phase', now()),
  ('00000000-0000-0000-0000-0000000025b5', '00000000-0000-0000-0000-0000000025b0', 'ISO Unit B', 'selection_phase', now());
insert into builder.project_slots (id, org_id, project_id, room, category) values
  ('00000000-0000-0000-0000-0000000025a6', '00000000-0000-0000-0000-0000000025a0', '00000000-0000-0000-0000-0000000025a5', 'Kitchen', 'Countertop'),
  ('00000000-0000-0000-0000-0000000025a7', '00000000-0000-0000-0000-0000000025a0', '00000000-0000-0000-0000-0000000025a5', 'Kitchen', 'Faucet'),
  ('00000000-0000-0000-0000-0000000025b6', '00000000-0000-0000-0000-0000000025b0', '00000000-0000-0000-0000-0000000025b5', 'Kitchen', 'Countertop'),
  ('00000000-0000-0000-0000-0000000025b7', '00000000-0000-0000-0000-0000000025b0', '00000000-0000-0000-0000-0000000025b5', 'Bath', 'Tile');
insert into builder.selections (org_id, slot_id, product_name) values
  ('00000000-0000-0000-0000-0000000025a0', '00000000-0000-0000-0000-0000000025a6', 'A Quartz'),
  ('00000000-0000-0000-0000-0000000025b0', '00000000-0000-0000-0000-0000000025b6', 'B Quartz');
-- 'late_change' needs no detector episode, so these fixtures do not depend on the detector tables
insert into builder.alerts (id, org_id, user_id, project_id, kind, message) values
  ('00000000-0000-0000-0000-0000000025a9', '00000000-0000-0000-0000-0000000025a0', '00000000-0000-0000-0000-0000000025a1',
   '00000000-0000-0000-0000-0000000025a5', 'late_change', 'ISO Lot A changed late'),
  ('00000000-0000-0000-0000-0000000025b9', '00000000-0000-0000-0000-0000000025b0', '00000000-0000-0000-0000-0000000025b1',
   '00000000-0000-0000-0000-0000000025b5', 'late_change', 'ISO Unit B changed late');

-- the attack is only meaningful if Builder B's rows really exist (owner bypasses RLS)
do $$
declare b constant uuid := '00000000-0000-0000-0000-0000000025b0';
begin
  if (select count(*) from builder.projects where org_id = b) <> 1
     or (select count(*) from builder.project_slots where org_id = b) <> 2
     or (select count(*) from builder.selections where org_id = b) <> 1
     or (select count(*) from builder.selection_history where org_id = b) <> 1
     or (select count(*) from builder.alerts where org_id = b) <> 1 then
    raise exception 'FAIL: Builder B fixtures missing';
  end if;
  raise notice 'PASS: Builder B fixtures present (1 project, 2 slots, 1 selection, 1 history row, 1 alert)';
end $$;

-- run a statement as a user, like PostgREST; returns visible/affected row count, -1 if denied
create or replace function pg_temp.as_user(uid uuid, stmt text)
returns integer language plpgsql as $$
declare n integer;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  begin
    if stmt ~* '^\s*select' then
      execute 'select count(*) from (' || stmt || ') q' into n;
    else
      execute stmt;
      get diagnostics n = row_count;
    end if;
  exception when insufficient_privilege then
    n := -1;
  end;
  execute 'reset role';
  return n;
end $$;
grant execute on function pg_temp.as_user(uuid, text) to authenticated;

-- same, but any error counts as "rejected" (-1); used where an FK or RLS error are both correct
create or replace function pg_temp.as_user_rejected(uid uuid, stmt text)
returns integer language plpgsql as $$
declare n integer;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  begin
    execute stmt;
    get diagnostics n = row_count;
  exception when others then
    n := -1;
  end;
  execute 'reset role';
  return n;
end $$;
grant execute on function pg_temp.as_user_rejected(uuid, text) to authenticated;

-- 2. reads: Ana selects Builder B rows -> zero rows everywhere
do $$
declare
  ana   constant uuid := '00000000-0000-0000-0000-0000000025a1';
  b     constant text := '00000000-0000-0000-0000-0000000025b0';
  bruno constant text := '00000000-0000-0000-0000-0000000025b1';
  t text;
  n integer;
  checked integer := 0;
begin
  -- positive control: Ana does see her own org, so the zeros below are RLS, not broken fixtures
  if pg_temp.as_user(ana, $q$select 1 from builder.projects where org_id = '00000000-0000-0000-0000-0000000025a0'$q$) <> 1
     or pg_temp.as_user(ana, $q$select 1 from builder.project_slots where org_id = '00000000-0000-0000-0000-0000000025a0'$q$) <> 2
     or pg_temp.as_user(ana, $q$select 1 from builder.selections where org_id = '00000000-0000-0000-0000-0000000025a0'$q$) <> 1
     or pg_temp.as_user(ana, $q$select 1 from builder.selection_history where org_id = '00000000-0000-0000-0000-0000000025a0'$q$) <> 1
     or pg_temp.as_user(ana, $q$select 1 from builder.alerts where id = '00000000-0000-0000-0000-0000000025a9'$q$) <> 1 then
    raise exception 'FAIL: Ana cannot see her own Builder A rows (positive control)';
  end if;

  -- the AC tables, by org and by B's ids (no filter on the policy column alone)
  if pg_temp.as_user(ana, $q$select 1 from builder.projects where org_id = '00000000-0000-0000-0000-0000000025b0' or id = '00000000-0000-0000-0000-0000000025b5'$q$) <> 0
     or pg_temp.as_user(ana, $q$select 1 from builder.project_slots where org_id = '00000000-0000-0000-0000-0000000025b0' or project_id = '00000000-0000-0000-0000-0000000025b5'$q$) <> 0
     or pg_temp.as_user(ana, $q$select 1 from builder.selections where org_id = '00000000-0000-0000-0000-0000000025b0' or slot_id in ('00000000-0000-0000-0000-0000000025b6', '00000000-0000-0000-0000-0000000025b7')$q$) <> 0
     or pg_temp.as_user(ana, $q$select 1 from builder.selection_history where org_id = '00000000-0000-0000-0000-0000000025b0' or slot_id = '00000000-0000-0000-0000-0000000025b6'$q$) <> 0
     or pg_temp.as_user(ana, $q$select 1 from builder.alerts where org_id = '00000000-0000-0000-0000-0000000025b0' or user_id = '00000000-0000-0000-0000-0000000025b1' or id = '00000000-0000-0000-0000-0000000025b9'$q$) <> 0 then
    raise exception 'FAIL: Ana can see Builder B projects, slots, selections, history or alerts';
  end if;
  raise notice 'PASS: Ana sees 0 Builder B rows in projects, slots, selections, history and alerts (and sees her own)';

  -- identity tables: B's org, B's memberships, Bruno's user row
  if pg_temp.as_user(ana, $q$select 1 from public.orgs where id = '00000000-0000-0000-0000-0000000025b0'$q$) <> 0
     or pg_temp.as_user(ana, $q$select 1 from public.memberships where org_id = '00000000-0000-0000-0000-0000000025b0' or user_id = '00000000-0000-0000-0000-0000000025b1'$q$) <> 0
     or pg_temp.as_user(ana, $q$select 1 from public.users where id = '00000000-0000-0000-0000-0000000025b1'$q$) <> 0 then
    raise exception 'FAIL: Ana can see Builder B identity rows';
  end if;
  raise notice 'PASS: Ana sees 0 Builder B rows in orgs, memberships and users';

  -- generic sweep: every table or view in public/builder carrying org_id or user_id
  -- (future tables and views are covered automatically); 0 rows or denied are both fine
  for t in
    select format('%I.%I', c.table_schema, c.table_name) || ':' || string_agg(c.column_name::text, ',' order by c.column_name)
    from information_schema.columns c
    where c.table_schema in ('public', 'builder') and c.column_name in ('org_id', 'user_id')
    group by c.table_schema, c.table_name
  loop
    n := pg_temp.as_user(ana, format('select 1 from %s where %s', split_part(t, ':', 1),
           case split_part(t, ':', 2)
             when 'org_id' then format('org_id = %L', b)
             when 'user_id' then format('user_id = %L', bruno)
             else format('org_id = %L or user_id = %L', b, bruno) end));
    if n > 0 then
      raise exception 'FAIL: Ana sees % Builder B row(s) in %', n, split_part(t, ':', 1);
    end if;
    checked := checked + 1;
  end loop;
  raise notice 'PASS: generic sweep: Ana sees 0 Builder B rows in all % org_id/user_id relations', checked;
end $$;

-- 3. writes: Ana attacks Builder B selections
do $$
declare
  ana constant uuid := '00000000-0000-0000-0000-0000000025a1';
begin
  -- cross-org insert into B's empty slot, claiming B's org: RLS with check rejects it (42501)
  if pg_temp.as_user(ana, $q$insert into builder.selections (org_id, slot_id, product_name)
       values ('00000000-0000-0000-0000-0000000025b0', '00000000-0000-0000-0000-0000000025b7', 'Hijack')$q$) <> -1 then
    raise exception 'FAIL: cross-org selection insert was not rejected by RLS';
  end if;
  -- same slot, but lying about the org (A): the composite FK (slot_id, org_id) rejects it
  if pg_temp.as_user_rejected(ana, $q$insert into builder.selections (org_id, slot_id, product_name)
       values ('00000000-0000-0000-0000-0000000025a0', '00000000-0000-0000-0000-0000000025b7', 'Hijack')$q$) <> -1 then
    raise exception 'FAIL: selection into a Builder B slot under Builder A org was accepted';
  end if;
  raise notice 'PASS: cross-org selection insert rejected (RLS 42501; org-mismatch blocked by composite FK)';

  -- update / delete of B's selection: zero rows affected
  if pg_temp.as_user(ana, $q$update builder.selections set product_name = 'Hacked' where slot_id = '00000000-0000-0000-0000-0000000025b6'$q$) <> 0
     or pg_temp.as_user(ana, $q$update builder.selections set product_name = 'Hacked' where org_id = '00000000-0000-0000-0000-0000000025b0'$q$) <> 0
     or pg_temp.as_user(ana, $q$delete from builder.selections where slot_id = '00000000-0000-0000-0000-0000000025b6'$q$) <> 0
     or pg_temp.as_user(ana, $q$delete from builder.selections where org_id = '00000000-0000-0000-0000-0000000025b0'$q$) <> 0 then
    raise exception 'FAIL: Ana changed or deleted a Builder B selection';
  end if;
  -- retargeting her own selection into Builder B: org_id and slot_id are not updatable
  if pg_temp.as_user(ana, $q$update builder.selections set org_id = '00000000-0000-0000-0000-0000000025b0' where slot_id = '00000000-0000-0000-0000-0000000025a6'$q$) <> -1
     or pg_temp.as_user(ana, $q$update builder.selections set slot_id = '00000000-0000-0000-0000-0000000025b7' where slot_id = '00000000-0000-0000-0000-0000000025a6'$q$) <> -1
     or pg_temp.as_user(ana, $q$update builder.selections set org_id = '00000000-0000-0000-0000-0000000025b0', slot_id = '00000000-0000-0000-0000-0000000025b7' where slot_id = '00000000-0000-0000-0000-0000000025a6'$q$) <> -1 then
    raise exception 'FAIL: Ana could retarget her selection to Builder B';
  end if;
  -- B's data is untouched and A's selection did not move
  if (select product_name from builder.selections where slot_id = '00000000-0000-0000-0000-0000000025b6') <> 'B Quartz'
     or exists (select 1 from builder.selections where slot_id = '00000000-0000-0000-0000-0000000025b7')
     or (select org_id from builder.selections where slot_id = '00000000-0000-0000-0000-0000000025a6') <> '00000000-0000-0000-0000-0000000025a0'
     or (select count(*) from builder.selection_history where org_id = '00000000-0000-0000-0000-0000000025b0') <> 1 then
    raise exception 'FAIL: Builder B data changed after the attack';
  end if;
  raise notice 'PASS: update/delete of B selections affect 0 rows; retargeting to B slot/org denied; B unchanged';

  -- other B tables: projects update, alerts mark-read, history forge
  if pg_temp.as_user(ana, $q$update builder.projects set name = 'Hacked' where id = '00000000-0000-0000-0000-0000000025b5'$q$) > 0
     or pg_temp.as_user(ana, $q$update builder.alerts set read_at = now() where id = '00000000-0000-0000-0000-0000000025b9'$q$) <> 0
     or pg_temp.as_user(ana, $q$insert into builder.selection_history (org_id, slot_id, action, product_name, actor_kind)
          values ('00000000-0000-0000-0000-0000000025b0', '00000000-0000-0000-0000-0000000025b6', 'set', 'Forged', 'builder')$q$) <> -1
     or pg_temp.as_user(ana, $q$insert into builder.alerts (org_id, user_id, project_id, kind, message)
          values ('00000000-0000-0000-0000-0000000025b0', '00000000-0000-0000-0000-0000000025b1', '00000000-0000-0000-0000-0000000025b5', 'late_change', 'Forged')$q$) <> -1 then
    raise exception 'FAIL: Ana wrote to a Builder B project, alert or history';
  end if;
  if (select read_at from builder.alerts where id = '00000000-0000-0000-0000-0000000025b9') is not null then
    raise exception 'FAIL: Builder B alert was marked read';
  end if;
  raise notice 'PASS: Ana cannot update B projects, mark B alerts read, or forge B history/alerts';
end $$;

-- 4. anon is denied on every table and view in public and builder (generic over the catalog)
do $$
declare
  r record;
  checked integer := 0;
begin
  for r in
    select n.nspname, c.relname, c.relkind
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public', 'builder') and c.relkind in ('r', 'p', 'v', 'm', 'f')
    order by 1, 2
  loop
    if has_table_privilege('anon', format('%I.%I', r.nspname, r.relname), 'select,insert,update,delete,truncate,references,trigger') then
      raise exception 'FAIL: anon holds a privilege on %.%', r.nspname, r.relname;
    end if;
    perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
    set local role anon;
    begin
      execute format('select 1 from %I.%I limit 1', r.nspname, r.relname);
      raise exception 'FAIL: anon can select %.%', r.nspname, r.relname;
    exception when insufficient_privilege then null;
    end;
    begin
      execute format('insert into %I.%I default values', r.nspname, r.relname);
      raise exception 'FAIL: anon can insert into %.%', r.nspname, r.relname;
    exception when insufficient_privilege then null;
    end;
    begin
      execute format('update %I.%I set %I = %I', r.nspname, r.relname,
        (select attname from pg_attribute where attrelid = format('%I.%I', r.nspname, r.relname)::regclass and attnum > 0 and not attisdropped order by attnum limit 1),
        (select attname from pg_attribute where attrelid = format('%I.%I', r.nspname, r.relname)::regclass and attnum > 0 and not attisdropped order by attnum limit 1));
      raise exception 'FAIL: anon can update %.%', r.nspname, r.relname;
    exception when insufficient_privilege then null;
    end;
    begin
      execute format('delete from %I.%I', r.nspname, r.relname);
      raise exception 'FAIL: anon can delete from %.%', r.nspname, r.relname;
    exception when insufficient_privilege then null;
    end;
    reset role;
    checked := checked + 1;
  end loop;
  if checked < 8 then
    raise exception 'FAIL: anon sweep covered only % relations', checked;
  end if;
  raise notice 'PASS: anon denied select/insert/update/delete (42501) on all % public/builder relations', checked;
end $$;

-- 5. extra: anon cannot use schema private or execute any function in it
do $$
declare
  f record;
  checked integer := 0;
begin
  if has_schema_privilege('anon', 'private', 'usage') then
    raise exception 'FAIL: anon has usage on schema private';
  end if;
  for f in select p.oid, p.proname from pg_proc p where p.pronamespace = 'private'::regnamespace loop
    if has_function_privilege('anon', f.oid, 'execute') then
      raise exception 'FAIL: anon can execute private.%', f.proname;
    end if;
    checked := checked + 1;
  end loop;
  if checked = 0 then
    raise exception 'FAIL: no functions found in private';
  end if;
  set local role anon;
  begin
    perform private.is_staff();
    raise exception 'FAIL: anon called private.is_staff()';
  exception when insufficient_privilege then null;
  end;
  begin
    perform private.current_user_org_ids();
    raise exception 'FAIL: anon called private.current_user_org_ids()';
  exception when insufficient_privilege then null;
  end;
  reset role;
  raise notice 'PASS: anon has no usage on private and cannot execute any of its % functions', checked;
end $$;

rollback;
