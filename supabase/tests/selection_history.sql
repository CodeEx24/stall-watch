-- STW-23: selection history trigger with computed actor_kind
-- Every assertion raises on failure; the transaction is rolled back.
\set ON_ERROR_STOP on
begin;

-- 1. hygiene
do $$
declare fn record;
begin
  select p.prosecdef, p.proconfig into fn
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'private' and p.proname = 'record_selection_history';
  if not found or not fn.prosecdef then raise exception 'FAIL: record_selection_history must exist and be security definer'; end if;
  if fn.proconfig is null or not ('search_path=""' = any (fn.proconfig)) then raise exception 'FAIL: search_path not pinned'; end if;
  if has_function_privilege('public', 'private.record_selection_history()', 'execute')
     or has_function_privilege('anon', 'private.record_selection_history()', 'execute')
     or has_function_privilege('authenticated', 'private.record_selection_history()', 'execute') then
    raise exception 'FAIL: execute not revoked';
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'trg_selection_history' and tgrelid = 'builder.selections'::regclass)
     or not exists (select 1 from pg_trigger where tgname = 'trg_selection_history_immutable' and tgrelid = 'builder.selection_history'::regclass) then
    raise exception 'FAIL: triggers missing';
  end if;
  raise notice 'PASS: definer, search_path pinned, execute revoked, both triggers attached';
end $$;

-- fixtures: staff, Ana (Builder A admin), one project with two slots
insert into auth.users (instance_id, id, aud, role, email) values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000005a1', 'authenticated', 'authenticated', 'hist.ana@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000005a2', 'authenticated', 'authenticated', 'hist.staff@example.test');
insert into public.orgs (id, name, org_type) values
  ('00000000-0000-0000-0000-0000000005f0', 'HIST Staff', 'staff'),
  ('00000000-0000-0000-0000-0000000005a0', 'HIST Builder A', 'builder');
insert into public.memberships (user_id, org_id, role) values
  ('00000000-0000-0000-0000-0000000005a1', '00000000-0000-0000-0000-0000000005a0', 'admin'),
  ('00000000-0000-0000-0000-0000000005a2', '00000000-0000-0000-0000-0000000005f0', 'admin');
insert into builder.projects (id, org_id, name, status, selection_phase_started_at) values
  ('00000000-0000-0000-0000-0000000005a5', '00000000-0000-0000-0000-0000000005a0', 'HIST Lot', 'selection_phase', now());
insert into builder.project_slots (id, org_id, project_id, room, category) values
  ('00000000-0000-0000-0000-0000000005a6', '00000000-0000-0000-0000-0000000005a0', '00000000-0000-0000-0000-0000000005a5', 'Kitchen', 'Countertop'),
  ('00000000-0000-0000-0000-0000000005a7', '00000000-0000-0000-0000-0000000005a0', '00000000-0000-0000-0000-0000000005a5', 'Kitchen', 'Faucet');

create or replace function pg_temp.run_as(uid uuid, stmt text)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute stmt;
  execute 'reset role';
end $$;
grant execute on function pg_temp.run_as(uuid, text) to authenticated;

-- 2. Ana (builder): set -> change -> no-op update -> clear
select pg_temp.run_as('00000000-0000-0000-0000-0000000005a1', $q$insert into builder.selections (org_id, slot_id, product_name)
  values ('00000000-0000-0000-0000-0000000005a0', '00000000-0000-0000-0000-0000000005a6', 'Quartz')$q$);
select pg_temp.run_as('00000000-0000-0000-0000-0000000005a1', $q$update builder.selections set product_name = 'Granite'
  where slot_id = '00000000-0000-0000-0000-0000000005a6'$q$);
select pg_temp.run_as('00000000-0000-0000-0000-0000000005a1', $q$update builder.selections set product_name = 'Granite'
  where slot_id = '00000000-0000-0000-0000-0000000005a6'$q$);
select pg_temp.run_as('00000000-0000-0000-0000-0000000005a1', $q$delete from builder.selections
  where slot_id = '00000000-0000-0000-0000-0000000005a6'$q$);

do $$
declare got text;
begin
  select string_agg(action || '|' || coalesce(product_name, '∅') || '|' || actor_kind || '|' || (changed_by = '00000000-0000-0000-0000-0000000005a1')::text,
                    ',' order by changed_at, case action when 'set' then 1 when 'change' then 2 else 3 end)
    into got
  from builder.selection_history where slot_id = '00000000-0000-0000-0000-0000000005a6';
  if got is distinct from 'set|Quartz|builder|true,change|Granite|builder|true,clear|∅|builder|true' then
    raise exception 'FAIL: builder history was %', got;
  end if;
  raise notice 'PASS: insert=set, update=change (no-op update skipped), delete=clear with null product; changed_by=Ana; actor=builder';
end $$;

-- 3. staff edit -> actor_kind staff; no auth.uid() -> staff
select pg_temp.run_as('00000000-0000-0000-0000-0000000005a2', $q$insert into builder.selections (org_id, slot_id, product_name)
  values ('00000000-0000-0000-0000-0000000005a0', '00000000-0000-0000-0000-0000000005a7', 'Chrome')$q$);
select set_config('request.jwt.claims', '', true);
update builder.selections set product_name = 'Matte Black' where slot_id = '00000000-0000-0000-0000-0000000005a7';
do $$
declare got text;
begin
  select string_agg(action || '|' || actor_kind || '|' || coalesce(changed_by::text, 'null'), ',' order by case action when 'set' then 1 else 2 end)
    into got
  from builder.selection_history where slot_id = '00000000-0000-0000-0000-0000000005a7';
  if got is distinct from 'set|staff|00000000-0000-0000-0000-0000000005a2,change|staff|null' then
    raise exception 'FAIL: staff / no-uid history was %', got;
  end if;
  raise notice 'PASS: staff caller -> staff; no auth.uid() -> staff with changed_by null';
end $$;

-- 4. clients cannot forge history; history is append-only for everyone
do $$
begin
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000005a1","role":"authenticated"}', true);
  set local role authenticated;
  begin
    insert into builder.selection_history (org_id, slot_id, action, product_name, actor_kind)
    values ('00000000-0000-0000-0000-0000000005a0', '00000000-0000-0000-0000-0000000005a6', 'set', 'Forged', 'builder');
    raise exception 'FAIL: authenticated inserted history directly';
  exception when insufficient_privilege then null;
  end;
  reset role;

  begin
    update builder.selection_history set actor_kind = 'builder' where slot_id = '00000000-0000-0000-0000-0000000005a7';
    raise exception 'FAIL: history update allowed for postgres';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from builder.selection_history where slot_id = '00000000-0000-0000-0000-0000000005a7';
    raise exception 'FAIL: history delete allowed for postgres';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS: no direct history inserts by app roles; UPDATE and DELETE blocked even for the owner';
end $$;

-- 5. deleting a user with history works: the FK nulls changed_by, the row survives
do $$
declare n_before int; n_after int;
begin
  select count(*) into n_before from builder.selection_history where changed_by = '00000000-0000-0000-0000-0000000005a1';
  if n_before = 0 then raise exception 'FAIL: fixture has no history for Ana'; end if;
  delete from auth.users where id = '00000000-0000-0000-0000-0000000005a1';  -- cascades to public.users
  select count(*) into n_after from builder.selection_history
   where slot_id = '00000000-0000-0000-0000-0000000005a6' and changed_by is null and actor_kind = 'builder';
  if n_after <> n_before then
    raise exception 'FAIL: expected % anonymised rows, got %', n_before, n_after;
  end if;
  -- nulling changed_by together with any other change is still blocked
  begin
    update builder.selection_history set changed_by = null, actor_kind = 'builder'   -- row is 'staff': a real second change
     where slot_id = '00000000-0000-0000-0000-0000000005a7' and changed_by is not null;
    raise exception 'FAIL: changed_by=null plus another change was allowed';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS: deleting a user anonymises their history (changed_by null, row kept); combined edits still blocked';
end $$;

rollback;
