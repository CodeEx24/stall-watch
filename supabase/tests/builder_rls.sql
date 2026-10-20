-- STW-21: builder RLS policies and grants
-- Every assertion raises on failure; the transaction is rolled back.
\set ON_ERROR_STOP on
begin;

-- 1. catalog: forced RLS, policy names and commands, grants
do $$
declare
  t text;
  expected text[] := array[
    'projects:p_projects_select:SELECT', 'projects:p_projects_update:UPDATE',
    'project_slots:p_project_slots_select:SELECT',
    'selections:p_selections_select:SELECT', 'selections:p_selections_insert:INSERT',
    'selections:p_selections_update:UPDATE', 'selections:p_selections_delete:DELETE',
    'selection_history:p_selection_history_select:SELECT'];
  actual text[];
begin
  select array_agg(tablename || ':' || policyname || ':' || cmd order by tablename || ':' || policyname || ':' || cmd) into actual
  from pg_policies where schemaname = 'builder'
    and tablename in ('projects', 'project_slots', 'selections', 'selection_history');
  if actual is distinct from (select array_agg(e order by e) from unnest(expected) e) then
    raise exception 'FAIL: builder policies are %, expected %', actual, expected;
  end if;
  foreach t in array array['projects', 'project_slots', 'selections', 'selection_history'] loop
    if not (select relrowsecurity and relforcerowsecurity from pg_class where oid = ('builder.' || t)::regclass) then
      raise exception 'FAIL: builder.% RLS not enabled+forced', t;
    end if;
    if has_table_privilege('anon', 'builder.' || t, 'select,insert,update,delete') then
      raise exception 'FAIL: anon has privileges on builder.%', t;
    end if;
    if not has_table_privilege('authenticated', 'builder.' || t, 'select') then
      raise exception 'FAIL: authenticated cannot select builder.%', t;
    end if;
  end loop;
  if has_schema_privilege('anon', 'builder', 'usage') or not has_schema_privilege('authenticated', 'builder', 'usage') then
    raise exception 'FAIL: schema usage must be authenticated only';
  end if;
  if has_table_privilege('authenticated', 'builder.project_slots', 'insert,update,delete')
     or has_table_privilege('authenticated', 'builder.selection_history', 'insert,update,delete')
     or has_table_privilege('authenticated', 'builder.projects', 'insert,delete') then
    raise exception 'FAIL: write privilege on slots/history or insert/delete on projects';
  end if;
  if has_column_privilege('authenticated', 'builder.selections', 'selected_by', 'insert')
     or has_column_privilege('authenticated', 'builder.selections', 'selected_by', 'update')
     or has_column_privilege('authenticated', 'builder.selections', 'org_id', 'update')
     or has_column_privilege('authenticated', 'builder.selections', 'slot_id', 'update')
     or has_column_privilege('authenticated', 'builder.projects', 'org_id', 'update') then
    raise exception 'FAIL: forgeable columns are grantable';
  end if;
  raise notice 'PASS: forced RLS, 8 p_<table>_<command> policies, grants authenticated-only, no slot/history writes, no forgeable columns';
end $$;

-- fixtures ------------------------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email) values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000003a1', 'authenticated', 'authenticated', 'brls.staff@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000003a2', 'authenticated', 'authenticated', 'brls.ana@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000003a3', 'authenticated', 'authenticated', 'brls.bruno@example.test');
insert into public.orgs (id, name, org_type) values
  ('00000000-0000-0000-0000-0000000003f0', 'BRLS Staff', 'staff'),
  ('00000000-0000-0000-0000-0000000003a0', 'BRLS Builder A', 'builder'),
  ('00000000-0000-0000-0000-0000000003b0', 'BRLS Builder B', 'builder');
insert into public.memberships (user_id, org_id, role) values
  ('00000000-0000-0000-0000-0000000003a1', '00000000-0000-0000-0000-0000000003f0', 'admin'),
  ('00000000-0000-0000-0000-0000000003a2', '00000000-0000-0000-0000-0000000003a0', 'admin'),
  ('00000000-0000-0000-0000-0000000003a3', '00000000-0000-0000-0000-0000000003b0', 'admin');
insert into builder.projects (id, org_id, name, status, selection_phase_started_at) values
  ('00000000-0000-0000-0000-0000000003a5', '00000000-0000-0000-0000-0000000003a0', 'BRLS Lot A', 'selection_phase', now()),
  ('00000000-0000-0000-0000-0000000003b5', '00000000-0000-0000-0000-0000000003b0', 'BRLS Unit B', 'selection_phase', now());
insert into builder.project_slots (id, org_id, project_id, room, category) values
  ('00000000-0000-0000-0000-0000000003a6', '00000000-0000-0000-0000-0000000003a0', '00000000-0000-0000-0000-0000000003a5', 'Kitchen', 'Countertop'),
  ('00000000-0000-0000-0000-0000000003a7', '00000000-0000-0000-0000-0000000003a0', '00000000-0000-0000-0000-0000000003a5', 'Kitchen', 'Faucet'),
  ('00000000-0000-0000-0000-0000000003b6', '00000000-0000-0000-0000-0000000003b0', '00000000-0000-0000-0000-0000000003b5', 'Kitchen', 'Countertop');
insert into builder.selections (org_id, slot_id, product_name) values
  ('00000000-0000-0000-0000-0000000003b0', '00000000-0000-0000-0000-0000000003b6', 'B Quartz');
insert into builder.selection_history (org_id, slot_id, action, product_name, actor_kind) values
  ('00000000-0000-0000-0000-0000000003b0', '00000000-0000-0000-0000-0000000003b6', 'set', 'B Quartz', 'builder');

-- run a statement as a user; returns affected/visible row count, or -1 if denied
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

do $$
declare
  ana   constant uuid := '00000000-0000-0000-0000-0000000003a2';
  bruno constant uuid := '00000000-0000-0000-0000-0000000003a3';
  staff constant uuid := '00000000-0000-0000-0000-0000000003a1';
  n integer;
begin
  -- reads: Ana sees only Builder A
  if pg_temp.as_user(ana, $q$select 1 from builder.projects where name like 'BRLS %'$q$) <> 1
     or pg_temp.as_user(ana, $q$select 1 from builder.project_slots where org_id in ('00000000-0000-0000-0000-0000000003a0','00000000-0000-0000-0000-0000000003b0')$q$) <> 2
     or pg_temp.as_user(ana, $q$select 1 from builder.selections where org_id = '00000000-0000-0000-0000-0000000003b0'$q$) <> 0
     or pg_temp.as_user(ana, $q$select 1 from builder.selection_history where org_id = '00000000-0000-0000-0000-0000000003b0'$q$) <> 0 then
    raise exception 'FAIL: Ana can see Builder B rows';
  end if;
  if pg_temp.as_user(staff, $q$select 1 from builder.projects where name like 'BRLS %'$q$) <> 2 then
    raise exception 'FAIL: staff should see both builders';
  end if;
  raise notice 'PASS: Ana sees only Builder A; staff sees both';

  -- selections: insert own ok (selected_by forced to Ana), cross-org insert rejected
  if pg_temp.as_user(ana, $q$insert into builder.selections (org_id, slot_id, product_name)
       values ('00000000-0000-0000-0000-0000000003a0', '00000000-0000-0000-0000-0000000003a6', 'A Quartz')$q$) <> 1 then
    raise exception 'FAIL: Ana could not insert into her own slot';
  end if;
  if (select selected_by from builder.selections where slot_id = '00000000-0000-0000-0000-0000000003a6') <> ana then
    raise exception 'FAIL: selected_by not stamped with the caller';
  end if;
  -- RLS with check rejects the row (42501) before any unique check runs
  if pg_temp.as_user(ana, $q$insert into builder.selections (org_id, slot_id, product_name)
       values ('00000000-0000-0000-0000-0000000003b0', '00000000-0000-0000-0000-0000000003b6', 'Hijack')$q$) <> -1 then
    raise exception 'FAIL: Ana inserted into Builder B';
  end if;
  if pg_temp.as_user(ana, $q$insert into builder.selections (org_id, slot_id, product_name, selected_by)
       values ('00000000-0000-0000-0000-0000000003a0', '00000000-0000-0000-0000-0000000003a7', 'X', '00000000-0000-0000-0000-0000000003a3')$q$) <> -1 then
    raise exception 'FAIL: Ana could supply selected_by';
  end if;
  raise notice 'PASS: own insert ok with selected_by = caller; cross-org insert and forged selected_by rejected';

  -- selections: update / delete only own
  if pg_temp.as_user(ana, $q$update builder.selections set product_name = 'Hacked' where slot_id = '00000000-0000-0000-0000-0000000003b6'$q$) <> 0
     or pg_temp.as_user(ana, $q$delete from builder.selections where slot_id = '00000000-0000-0000-0000-0000000003b6'$q$) <> 0 then
    raise exception 'FAIL: Ana changed Builder B selection';
  end if;
  if pg_temp.as_user(ana, $q$update builder.selections set org_id = '00000000-0000-0000-0000-0000000003b0' where slot_id = '00000000-0000-0000-0000-0000000003a6'$q$) <> -1 then
    raise exception 'FAIL: Ana could move a selection to another org';
  end if;
  if pg_temp.as_user(ana, $q$update builder.selections set product_name = 'A Granite' where slot_id = '00000000-0000-0000-0000-0000000003a6'$q$) <> 1 then
    raise exception 'FAIL: Ana could not update her own selection';
  end if;
  if pg_temp.as_user(bruno, $q$delete from builder.selections where slot_id = '00000000-0000-0000-0000-0000000003a6'$q$) <> 0 then
    raise exception 'FAIL: Bruno deleted Builder A selection';
  end if;
  if pg_temp.as_user(staff, $q$update builder.selections set product_name = 'Staff pick' where slot_id = '00000000-0000-0000-0000-0000000003b6'$q$) <> 1 then
    raise exception 'FAIL: staff could not update a selection';
  end if;
  raise notice 'PASS: update/delete limited to own org (staff any); org_id cannot be changed';

  -- projects: update staff only
  if pg_temp.as_user(ana, $q$update builder.projects set status = 'complete' where id = '00000000-0000-0000-0000-0000000003a5'$q$) <> 0 then
    raise exception 'FAIL: builder updated a project';
  end if;
  if pg_temp.as_user(staff, $q$update builder.projects set selection_due_date = current_date + 7 where id = '00000000-0000-0000-0000-0000000003b5'$q$) <> 1 then
    raise exception 'FAIL: staff could not update a project';
  end if;
  if pg_temp.as_user(staff, $q$insert into builder.projects (org_id, name) values ('00000000-0000-0000-0000-0000000003a0', 'New')$q$) <> -1 then
    raise exception 'FAIL: projects insert should be denied';
  end if;
  raise notice 'PASS: projects update is staff only; no project inserts';

  -- slots and history: no writes for anyone in the app
  if pg_temp.as_user(staff, $q$insert into builder.project_slots (org_id, project_id, room, category) values ('00000000-0000-0000-0000-0000000003a0', '00000000-0000-0000-0000-0000000003a5', 'Bath', 'Tile')$q$) <> -1
     or pg_temp.as_user(ana, $q$insert into builder.selection_history (org_id, slot_id, action, product_name, actor_kind) values ('00000000-0000-0000-0000-0000000003a0', '00000000-0000-0000-0000-0000000003a6', 'set', 'Forged', 'builder')$q$) <> -1
     or pg_temp.as_user(ana, $q$delete from builder.selection_history where org_id = '00000000-0000-0000-0000-0000000003a0'$q$) <> -1 then
    raise exception 'FAIL: slot/history write allowed';
  end if;
  raise notice 'PASS: no slot or history writes from the app';
end $$;

-- anon
do $$
begin
  set local role anon;
  begin
    perform 1 from builder.projects;
    raise exception 'FAIL: anon can read builder.projects';
  exception when insufficient_privilege then null;
  end;
  reset role;
  raise notice 'PASS: anon denied';
end $$;

rollback;
