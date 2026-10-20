-- STW-22: builder.alerts recipient-only policies and the read_at column grant
-- Every assertion raises on failure; the transaction is rolled back.
\set ON_ERROR_STOP on
begin;

-- 1. catalog
do $$
declare cols text[];
begin
  select array_agg(column_name::text order by column_name::text) into cols
  from information_schema.columns where table_schema = 'builder' and table_name = 'alerts'
    and column_name in ('org_id', 'user_id', 'project_id', 'kind', 'message', 'read_at', 'created_at');
  if cardinality(cols) <> 7 then raise exception 'FAIL: alerts columns missing: %', cols; end if;
  if not exists (select 1 from pg_constraint where conname = 'alerts_project_fk' and array_length(conkey, 1) = 2) then
    raise exception 'FAIL: composite FK (project_id, org_id) missing';
  end if;
  if not (select relrowsecurity and relforcerowsecurity from pg_class where oid = 'builder.alerts'::regclass) then
    raise exception 'FAIL: RLS not enabled+forced';
  end if;
  if (select array_agg(policyname || ':' || cmd order by policyname || ':' || cmd) from pg_policies
      where schemaname = 'builder' and tablename = 'alerts')
     is distinct from array['p_alerts_select:SELECT', 'p_alerts_update:UPDATE'] then
    raise exception 'FAIL: alerts policies wrong';
  end if;
  if exists (select 1 from pg_policies where schemaname = 'builder' and tablename = 'alerts'
             and (qual not like '%auth.uid()%' or (cmd = 'UPDATE' and with_check not like '%auth.uid()%'))) then
    raise exception 'FAIL: alerts policies must use user_id = auth.uid()';
  end if;
  if has_table_privilege('authenticated', 'builder.alerts', 'insert')
     or has_table_privilege('authenticated', 'builder.alerts', 'delete')
     or has_table_privilege('authenticated', 'builder.alerts', 'update')   -- table-level update must be gone
     or not has_column_privilege('authenticated', 'builder.alerts', 'read_at', 'update')
     or has_column_privilege('authenticated', 'builder.alerts', 'message', 'update')
     or has_column_privilege('authenticated', 'builder.alerts', 'user_id', 'update')
     or has_table_privilege('anon', 'builder.alerts', 'select,insert,update,delete') then
    raise exception 'FAIL: alerts grants wrong';
  end if;
  raise notice 'PASS: columns, composite FK, forced RLS, 2 recipient policies, grants = select + update(read_at)';
end $$;

-- fixtures: Ana and Mia (Builder A), staff
insert into auth.users (instance_id, id, aud, role, email) values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000004a1', 'authenticated', 'authenticated', 'alrt.ana@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000004a2', 'authenticated', 'authenticated', 'alrt.mia@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000004a3', 'authenticated', 'authenticated', 'alrt.staff@example.test');
insert into public.orgs (id, name, org_type) values
  ('00000000-0000-0000-0000-0000000004f0', 'ALRT Staff', 'staff'),
  ('00000000-0000-0000-0000-0000000004a0', 'ALRT Builder A', 'builder');
insert into public.memberships (user_id, org_id, role) values
  ('00000000-0000-0000-0000-0000000004a1', '00000000-0000-0000-0000-0000000004a0', 'admin'),
  ('00000000-0000-0000-0000-0000000004a2', '00000000-0000-0000-0000-0000000004a0', 'member'),
  ('00000000-0000-0000-0000-0000000004a3', '00000000-0000-0000-0000-0000000004f0', 'admin');
insert into builder.projects (id, org_id, name, status, selection_phase_started_at) values
  ('00000000-0000-0000-0000-0000000004a5', '00000000-0000-0000-0000-0000000004a0', 'ALRT Lot', 'selection_phase', now() - interval '9 days');
insert into builder.alerts (id, org_id, user_id, project_id, kind, message) values
  ('00000000-0000-0000-0000-0000000004a9', '00000000-0000-0000-0000-0000000004a0', '00000000-0000-0000-0000-0000000004a1',
   '00000000-0000-0000-0000-0000000004a5', 'stalled', 'ALRT Lot has had no builder activity for 7 days');

-- composite FK: alert org must match the project's org
do $$
begin
  begin
    insert into builder.alerts (org_id, user_id, project_id, kind, message)
    values ('00000000-0000-0000-0000-0000000004f0', '00000000-0000-0000-0000-0000000004a3',
            '00000000-0000-0000-0000-0000000004a5', 'stalled', 'x');
    raise exception 'FAIL: alert with mismatched org accepted';
  exception when foreign_key_violation then null;
  end;
  raise notice 'PASS: alert org must match project org';
end $$;

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
  ana   constant uuid := '00000000-0000-0000-0000-0000000004a1';
  mia   constant uuid := '00000000-0000-0000-0000-0000000004a2';
  staff constant uuid := '00000000-0000-0000-0000-0000000004a3';
  q_mine constant text := $q$select 1 from builder.alerts where id = '00000000-0000-0000-0000-0000000004a9'$q$;
begin
  -- visibility: recipient only (not a co-member, not staff)
  if pg_temp.as_user(ana, q_mine) <> 1 or pg_temp.as_user(mia, q_mine) <> 0 or pg_temp.as_user(staff, q_mine) <> 0 then
    raise exception 'FAIL: alert visible to someone other than the recipient';
  end if;
  raise notice 'PASS: only the recipient sees the alert (co-member and staff see 0)';

  -- AC3: Ana changes message -> permission denied; read_at -> succeeds
  if pg_temp.as_user(ana, $q$update builder.alerts set message = 'edited' where id = '00000000-0000-0000-0000-0000000004a9'$q$) <> -1 then
    raise exception 'FAIL: Ana could change message';
  end if;
  if pg_temp.as_user(ana, $q$update builder.alerts set read_at = now() where id = '00000000-0000-0000-0000-0000000004a9'$q$) <> 1 then
    raise exception 'FAIL: Ana could not mark her alert read';
  end if;
  if (select read_at from builder.alerts where id = '00000000-0000-0000-0000-0000000004a9') is null
     or (select lock_version from builder.alerts where id = '00000000-0000-0000-0000-0000000004a9') <> 1 then
    raise exception 'FAIL: read_at not stored or touch trigger not fired';
  end if;
  raise notice 'PASS: message update denied (42501); read_at update succeeds and bumps lock_version';

  -- others cannot mark it read; nobody can insert, delete or reassign
  if pg_temp.as_user(mia, $q$update builder.alerts set read_at = now() where id = '00000000-0000-0000-0000-0000000004a9'$q$) <> 0
     or pg_temp.as_user(staff, $q$update builder.alerts set read_at = now() where id = '00000000-0000-0000-0000-0000000004a9'$q$) <> 0 then
    raise exception 'FAIL: non-recipient marked the alert read';
  end if;
  if pg_temp.as_user(ana, $q$update builder.alerts set user_id = '00000000-0000-0000-0000-0000000004a2' where id = '00000000-0000-0000-0000-0000000004a9'$q$) <> -1
     or pg_temp.as_user(ana, $q$delete from builder.alerts where id = '00000000-0000-0000-0000-0000000004a9'$q$) <> -1
     or pg_temp.as_user(staff, $q$insert into builder.alerts (org_id, user_id, project_id, kind, message)
          values ('00000000-0000-0000-0000-0000000004a0', '00000000-0000-0000-0000-0000000004a2', '00000000-0000-0000-0000-0000000004a5', 'stalled', 'forged')$q$) <> -1 then
    raise exception 'FAIL: insert/delete/reassign allowed';
  end if;
  raise notice 'PASS: non-recipients cannot mark read; no insert, delete or reassign';
end $$;

-- read_at cannot predate the alert
do $$
begin
  begin
    update builder.alerts set read_at = created_at - interval '1 day' where id = '00000000-0000-0000-0000-0000000004a9';
    raise exception 'FAIL: read_at before created_at accepted';
  exception when check_violation then null;
  end;
  raise notice 'PASS: read_at >= created_at enforced';
end $$;

rollback;
