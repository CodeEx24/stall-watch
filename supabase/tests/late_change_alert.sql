-- STW-42: late-change alert trigger (builder change on a 'revision' project -> one
-- 'late_change' alert per staff user, org_id = the builder org).
-- Every assertion raises on failure; the transaction is rolled back.
\set ON_ERROR_STOP on
begin;

-- 1. hygiene: definer, pinned search_path, execute revoked, trigger attached, schema
do $$
declare fn record;
begin
  select p.prosecdef, p.proconfig into fn
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'private' and p.proname = 'raise_late_change_alert';
  if not found or not fn.prosecdef then raise exception 'FAIL: raise_late_change_alert must exist and be security definer'; end if;
  if fn.proconfig is null or not ('search_path=""' = any (fn.proconfig)) then raise exception 'FAIL: search_path not pinned'; end if;
  if has_function_privilege('public', 'private.raise_late_change_alert()', 'execute')
     or has_function_privilege('anon', 'private.raise_late_change_alert()', 'execute')
     or has_function_privilege('authenticated', 'private.raise_late_change_alert()', 'execute') then
    raise exception 'FAIL: execute not revoked';
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'trg_late_change_alert'
                 and tgrelid = 'builder.selection_history'::regclass and not tgisinternal) then
    raise exception 'FAIL: trg_late_change_alert missing';
  end if;
  if (select is_nullable from information_schema.columns
      where table_schema = 'builder' and table_name = 'alerts' and column_name = 'history_id') is distinct from 'YES' then
    raise exception 'FAIL: alerts.history_id missing or not nullable';
  end if;
  if not exists (select 1 from pg_constraint where conname = 'alerts_history_user_key' and contype = 'u')
     or not exists (select 1 from pg_constraint where conname = 'alerts_history_fk' and contype = 'f' and array_length(conkey, 1) = 2)
     or not exists (select 1 from pg_constraint where conname = 'selection_history_id_org_key' and contype = 'u') then
    raise exception 'FAIL: de-dup key / composite FK missing';
  end if;
  if not (select relrowsecurity and relforcerowsecurity from pg_class where oid = 'builder.alerts'::regclass)
     or not (select relrowsecurity and relforcerowsecurity from pg_class where oid = 'builder.selection_history'::regclass) then
    raise exception 'FAIL: RLS not enabled+forced on alerts / selection_history';
  end if;
  if has_table_privilege('authenticated', 'builder.alerts', 'insert') then
    raise exception 'FAIL: authenticated can insert alerts';
  end if;
  raise notice 'PASS: definer, search_path pinned, execute revoked (public/anon/authenticated), trigger attached, history_id + unique (history_id, user_id), RLS forced';
end $$;

-- fixtures: a staff org with 2 staff users, a builder org (admin + member) with a
-- revision, a selection_phase and a complete project. Selections are pre-filled as
-- postgres (no auth.uid() -> actor 'staff', action 'set': no alert).
insert into auth.users (instance_id, id, aud, role, email) values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000042f1', 'authenticated', 'authenticated', 'lca.staff1@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000042f2', 'authenticated', 'authenticated', 'lca.staff2@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000042a1', 'authenticated', 'authenticated', 'lca.admin@example.test'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000042a2', 'authenticated', 'authenticated', 'lca.member@example.test');
insert into public.orgs (id, name, org_type) values
  ('00000000-0000-0000-0000-0000000042f0', 'LCA Staff', 'staff'),
  ('00000000-0000-0000-0000-0000000042a0', 'LCA Builder', 'builder');
insert into public.memberships (user_id, org_id, role) values
  ('00000000-0000-0000-0000-0000000042f1', '00000000-0000-0000-0000-0000000042f0', 'admin'),
  ('00000000-0000-0000-0000-0000000042f2', '00000000-0000-0000-0000-0000000042f0', 'member'),
  ('00000000-0000-0000-0000-0000000042a1', '00000000-0000-0000-0000-0000000042a0', 'admin'),
  ('00000000-0000-0000-0000-0000000042a2', '00000000-0000-0000-0000-0000000042a0', 'member');
insert into builder.projects (id, org_id, name, status, selection_phase_started_at) values
  ('00000000-0000-0000-0000-0000000042b1', '00000000-0000-0000-0000-0000000042a0', 'LCA Lot 15', 'revision', now() - interval '30 days'),
  ('00000000-0000-0000-0000-0000000042b2', '00000000-0000-0000-0000-0000000042a0', 'LCA Lot 14', 'selection_phase', now() - interval '3 days'),
  ('00000000-0000-0000-0000-0000000042b3', '00000000-0000-0000-0000-0000000042a0', 'LCA Lot 9', 'complete', now() - interval '60 days'),
  ('00000000-0000-0000-0000-0000000042b4', '00000000-0000-0000-0000-0000000042a0', repeat('N', 200), 'revision', now() - interval '30 days');
insert into builder.project_slots (id, org_id, project_id, room, category) values
  ('00000000-0000-0000-0000-0000000042c1', '00000000-0000-0000-0000-0000000042a0', '00000000-0000-0000-0000-0000000042b1', 'Kitchen', 'Countertop'),
  ('00000000-0000-0000-0000-0000000042c2', '00000000-0000-0000-0000-0000000042a0', '00000000-0000-0000-0000-0000000042b1', 'Kitchen', 'Faucet'),
  ('00000000-0000-0000-0000-0000000042c3', '00000000-0000-0000-0000-0000000042a0', '00000000-0000-0000-0000-0000000042b1', 'Bath', 'Tile'),
  ('00000000-0000-0000-0000-0000000042c4', '00000000-0000-0000-0000-0000000042a0', '00000000-0000-0000-0000-0000000042b2', 'Kitchen', 'Countertop'),
  ('00000000-0000-0000-0000-0000000042c5', '00000000-0000-0000-0000-0000000042a0', '00000000-0000-0000-0000-0000000042b3', 'Kitchen', 'Countertop'),
  ('00000000-0000-0000-0000-0000000042c6', '00000000-0000-0000-0000-0000000042a0', '00000000-0000-0000-0000-0000000042b4', repeat('R', 100), repeat('C', 100));
select set_config('request.jwt.claims', '', true);
insert into builder.selections (org_id, slot_id, product_name) values
  ('00000000-0000-0000-0000-0000000042a0', '00000000-0000-0000-0000-0000000042c1', 'Absolute Black Granite'),
  ('00000000-0000-0000-0000-0000000042a0', '00000000-0000-0000-0000-0000000042c2', 'Chrome'),
  ('00000000-0000-0000-0000-0000000042a0', '00000000-0000-0000-0000-0000000042c4', 'Quartz'),
  ('00000000-0000-0000-0000-0000000042a0', '00000000-0000-0000-0000-0000000042c5', 'Marble'),
  ('00000000-0000-0000-0000-0000000042a0', '00000000-0000-0000-0000-0000000042c6', 'Oak');

create or replace function pg_temp.run_as(uid uuid, stmt text)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute stmt;
  execute 'reset role';
end $$;
grant execute on function pg_temp.run_as(uuid, text) to authenticated;

create or replace function pg_temp.count_as(uid uuid, stmt text)
returns bigint language plpgsql as $$
declare n bigint;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute format('select count(*) from (%s) q', stmt) into n;
  execute 'reset role';
  return n;
end $$;
grant execute on function pg_temp.count_as(uuid, text) to authenticated;

-- every staff user on this DB (fixture staff + any seed staff), the same rule as private.is_staff()
create temp table lca_staff on commit drop as
  select distinct m.user_id from public.memberships m join public.orgs o on o.id = m.org_id where o.org_type = 'staff';
grant select on lca_staff to authenticated;

do $$
begin
  if exists (select 1 from builder.alerts where project_id::text like '00000000-0000-0000-0000-0000000042b%') then
    raise exception 'FAIL: fixture setup (staff-actor sets) created alerts';
  end if;
  if (select count(*) from lca_staff) < 2 then raise exception 'FAIL: fixture needs >= 2 staff users'; end if;
  raise notice 'PASS: fixture: % staff user(s) on this DB; pre-filling selections (staff/set) created no alert', (select count(*) from lca_staff);
end $$;

-- 2. builder admin changes a slot on the revision project -> one alert per staff user
select pg_temp.run_as('00000000-0000-0000-0000-0000000042a1', $q$update builder.selections set product_name = 'Calacatta Quartz'
  where slot_id = '00000000-0000-0000-0000-0000000042c1'$q$);
do $$
declare h uuid; n_staff int; n int; bad int;
begin
  select id into h from builder.selection_history
   where slot_id = '00000000-0000-0000-0000-0000000042c1' and action = 'change' and actor_kind = 'builder';
  if h is null then raise exception 'FAIL: no builder change history row'; end if;
  select count(*) into n_staff from lca_staff;
  select count(*) into n from builder.alerts where history_id = h;
  if n <> n_staff then raise exception 'FAIL: expected % alerts (one per staff user), got %', n_staff, n; end if;
  if exists (select user_id from lca_staff except select user_id from builder.alerts where history_id = h)
     or exists (select user_id from builder.alerts where history_id = h except select user_id from lca_staff)
     or exists (select 1 from builder.alerts where history_id = h group by user_id having count(*) > 1) then
    raise exception 'FAIL: recipients are not exactly the staff users, once each';
  end if;
  select count(*) into bad from builder.alerts where history_id = h
   and not (kind = 'late_change' and org_id = '00000000-0000-0000-0000-0000000042a0'
            and project_id = '00000000-0000-0000-0000-0000000042b1' and episode_id is null
            and read_at is null
            and message = 'LCA Lot 15: Kitchen Countertop was changed to "Calacatta Quartz" by the builder while the project is in revision.');
  if bad > 0 then raise exception 'FAIL: % alert(s) with wrong kind / org_id / project / message', bad; end if;
  raise notice 'PASS: builder admin change on revision project -> % late_change alert(s), one per staff user, org_id = builder org, message names project + slot + new product', n;
end $$;

-- 3. builder member clears a slot on the revision project -> alerts too ('clear' counts)
select pg_temp.run_as('00000000-0000-0000-0000-0000000042a2', $q$delete from builder.selections
  where slot_id = '00000000-0000-0000-0000-0000000042c2'$q$);
do $$
declare h uuid; n int;
begin
  select id into h from builder.selection_history
   where slot_id = '00000000-0000-0000-0000-0000000042c2' and action = 'clear' and actor_kind = 'builder';
  select count(*) into n from builder.alerts
   where history_id = h and message = 'LCA Lot 15: Kitchen Faucet was cleared by the builder while the project is in revision.';
  if n <> (select count(*) from lca_staff) then raise exception 'FAIL: builder clear -> % alerts', n; end if;
  raise notice 'PASS: builder member clear on revision project -> one alert per staff user';
end $$;

-- 4. no alert: builder 'set' of an empty slot, staff change, non-revision projects
select pg_temp.run_as('00000000-0000-0000-0000-0000000042a1', $q$insert into builder.selections (org_id, slot_id, product_name)
  values ('00000000-0000-0000-0000-0000000042a0', '00000000-0000-0000-0000-0000000042c3', 'Subway White')$q$);
select pg_temp.run_as('00000000-0000-0000-0000-0000000042f1', $q$update builder.selections set product_name = 'Nero Marquina'
  where slot_id = '00000000-0000-0000-0000-0000000042c1'$q$);
select pg_temp.run_as('00000000-0000-0000-0000-0000000042f2', $q$delete from builder.selections
  where slot_id = '00000000-0000-0000-0000-0000000042c1'$q$);
select pg_temp.run_as('00000000-0000-0000-0000-0000000042a1', $q$update builder.selections set product_name = 'Granite'
  where slot_id = '00000000-0000-0000-0000-0000000042c4'$q$);
select pg_temp.run_as('00000000-0000-0000-0000-0000000042a1', $q$delete from builder.selections
  where slot_id = '00000000-0000-0000-0000-0000000042c5'$q$);
do $$
declare n_hist int; n_alerted int;
begin
  -- the five statements above all wrote history ...
  select count(*) into n_hist from builder.selection_history
   where (slot_id = '00000000-0000-0000-0000-0000000042c3' and action = 'set' and actor_kind = 'builder')
      or (slot_id = '00000000-0000-0000-0000-0000000042c1' and actor_kind = 'staff' and action in ('change', 'clear'))
      or (slot_id in ('00000000-0000-0000-0000-0000000042c4', '00000000-0000-0000-0000-0000000042c5') and actor_kind = 'builder');
  if n_hist <> 5 then raise exception 'FAIL: expected 5 history rows for the no-alert cases, got %', n_hist; end if;
  -- ... but none of them raised an alert
  select count(*) into n_alerted from builder.alerts a
  join builder.selection_history h on h.id = a.history_id
  where (h.slot_id = '00000000-0000-0000-0000-0000000042c3')
     or (h.slot_id = '00000000-0000-0000-0000-0000000042c1' and h.actor_kind = 'staff')
     or (h.slot_id in ('00000000-0000-0000-0000-0000000042c4', '00000000-0000-0000-0000-0000000042c5'));
  if n_alerted <> 0 then raise exception 'FAIL: % alert(s) from set / staff / non-revision changes', n_alerted; end if;
  if exists (select 1 from builder.alerts where project_id in ('00000000-0000-0000-0000-0000000042b2', '00000000-0000-0000-0000-0000000042b3')) then
    raise exception 'FAIL: alert on a selection_phase / complete project';
  end if;
  raise notice 'PASS: no alert for builder set of an empty slot, staff change / clear on the revision project, builder change on selection_phase or clear on complete project';
end $$;

-- 5. retries cannot duplicate: a throw-away second trigger runs the same function again
--    for the same history row (the "retry"); the de-dup key keeps one alert per staff user.
create trigger trg_test_late_change_replay after insert on builder.selection_history
  for each row execute function private.raise_late_change_alert();
select pg_temp.run_as('00000000-0000-0000-0000-0000000042a1', $q$update builder.selections set product_name = 'Herringbone'
  where slot_id = '00000000-0000-0000-0000-0000000042c3'$q$);
drop trigger trg_test_late_change_replay on builder.selection_history;
do $$
declare h uuid; n int; r record;
begin
  select id into h from builder.selection_history
   where slot_id = '00000000-0000-0000-0000-0000000042c3' and action = 'change';
  select count(*) into n from builder.alerts where history_id = h;
  if n <> (select count(*) from lca_staff) then raise exception 'FAIL: replayed insert path -> % alerts, expected one per staff user', n; end if;
  -- and a direct duplicate (same history row, same user) is rejected by the key
  select * into r from builder.alerts where history_id = h limit 1;
  begin
    insert into builder.alerts (org_id, user_id, project_id, kind, message, history_id)
    values (r.org_id, r.user_id, r.project_id, 'late_change', 'dup', h);
    raise exception 'FAIL: duplicate (history_id, user_id) accepted';
  exception when unique_violation then null;
  end;
  raise notice 'PASS: insert path run twice for one history row -> still one alert per staff user; duplicate (history_id, user_id) -> unique_violation';
end $$;

-- 6. message is capped at 500 chars (200-char name, 100-char room / category, 200-char product)
select pg_temp.run_as('00000000-0000-0000-0000-0000000042a1', format($q$update builder.selections set product_name = %L
  where slot_id = '00000000-0000-0000-0000-0000000042c6'$q$, repeat('P', 200)));
do $$
declare n int;
begin
  select count(*) into n from builder.alerts
   where project_id = '00000000-0000-0000-0000-0000000042b4' and length(message) = 500;
  if n <> (select count(*) from lca_staff) then raise exception 'FAIL: long message not capped to 500 (% rows)', n; end if;
  raise notice 'PASS: oversized project / slot / product names -> message cut to 500 chars, alert still created';
end $$;

-- 7. RLS: staff read their own alert; builder users and other staff cannot see it
do $$
declare
  h uuid;
  s1 constant uuid := '00000000-0000-0000-0000-0000000042f1';
  s2 constant uuid := '00000000-0000-0000-0000-0000000042f2';
  admin constant uuid := '00000000-0000-0000-0000-0000000042a1';
  member constant uuid := '00000000-0000-0000-0000-0000000042a2';
  n bigint;
begin
  select id into h from builder.selection_history
   where slot_id = '00000000-0000-0000-0000-0000000042c1' and action = 'change' and actor_kind = 'builder';
  n := pg_temp.count_as(s1, format('select 1 from builder.alerts where history_id = %L', h));
  if n <> 1 then raise exception 'FAIL: staff1 sees % of the alerts for the change, expected 1 (own)', n; end if;
  n := pg_temp.count_as(s1, format('select 1 from builder.alerts where history_id = %L and user_id = %L', h, s2));
  if n <> 0 then raise exception 'FAIL: staff1 sees staff2''s alert'; end if;
  n := pg_temp.count_as(s2, format('select 1 from builder.alerts a join builder.projects p on p.id = a.project_id
                                    where a.history_id = %L and a.user_id = %L and p.name = ''LCA Lot 15''', h, s2));
  if n <> 1 then raise exception 'FAIL: staff2 cannot read own alert with its project'; end if;
  n := pg_temp.count_as(admin, 'select 1 from builder.alerts where kind = ''late_change'' and org_id = ''00000000-0000-0000-0000-0000000042a0''');
  if n <> 0 then raise exception 'FAIL: builder admin sees % late_change alert(s) of their org', n; end if;
  n := pg_temp.count_as(member, 'select 1 from builder.alerts where kind = ''late_change''');
  if n <> 0 then raise exception 'FAIL: builder member sees % late_change alert(s)', n; end if;
  -- staff can mark it read (read_at only), builder cannot touch it
  perform pg_temp.run_as(s1, format('update builder.alerts set read_at = now() where history_id = %L', h));
  perform pg_temp.run_as(admin, format('update builder.alerts set read_at = now() where history_id = %L', h));
  if (select count(*) from builder.alerts where history_id = h and read_at is not null) <> 1
     or not exists (select 1 from builder.alerts where history_id = h and user_id = s1 and read_at is not null) then
    raise exception 'FAIL: read_at update scope wrong';
  end if;
  raise notice 'PASS: RLS -> each staff user reads only their own alert (with project name); builder admin / member see none and cannot mark it read';
end $$;

-- 8. the trigger cannot be invoked by an app role directly
do $$
begin
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000042a1","role":"authenticated"}', true);
  set local role authenticated;
  begin
    perform private.raise_late_change_alert();
    raise exception 'FAIL: authenticated called the trigger function';
  exception when insufficient_privilege then null;  -- 42501 only: the execute check, not "only callable as trigger"
  end;
  reset role;
  raise notice 'PASS: authenticated cannot call private.raise_late_change_alert()';
end $$;

rollback;
