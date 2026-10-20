-- STW-20: builder core tables, composite FKs, checks
-- Every assertion raises on failure; the transaction is rolled back.
\set ON_ERROR_STOP on
begin;

create or replace function pg_temp.expect_error(stmt text, state text, label text)
returns void language plpgsql as $$
begin
  execute stmt;
  raise exception 'FAIL: % — statement succeeded', label;
exception
  when others then
    if sqlstate <> state then
      raise exception 'FAIL: % — expected SQLSTATE %, got % (%)', label, state, sqlstate, sqlerrm;
    end if;
end $$;

-- 1. structure
do $$
declare t text;
begin
  foreach t in array array['projects', 'project_slots', 'selections', 'selection_history'] loop
    if to_regclass('builder.' || t) is null then raise exception 'FAIL: builder.% missing', t; end if;
    if not (select relrowsecurity and relforcerowsecurity from pg_class where oid = ('builder.' || t)::regclass) then
      raise exception 'FAIL: builder.% must have RLS enabled and forced', t;
    end if;
    if has_table_privilege('anon', 'builder.' || t, 'select,insert,update,delete')
       or has_table_privilege('authenticated', 'builder.' || t, 'select,insert,update,delete') then
      raise exception 'FAIL: app roles hold privileges on builder.% before STW-21', t;
    end if;
  end loop;
  foreach t in array array['projects', 'project_slots', 'selections'] loop
    if (select count(*) from information_schema.columns where table_schema = 'builder' and table_name = t
        and column_name in ('created_at', 'updated_at', 'lock_version')) <> 3 then
      raise exception 'FAIL: builder.% missing audit columns', t;
    end if;
    if not exists (select 1 from pg_trigger where tgrelid = ('builder.' || t)::regclass
                   and tgname = 'trg_' || t || '_touch' and not tgisinternal) then
      raise exception 'FAIL: builder.% missing touch trigger', t;
    end if;
  end loop;
  if (select is_nullable from information_schema.columns where table_schema = 'builder'
      and table_name = 'selection_history' and column_name = 'product_name') <> 'YES' then
    raise exception 'FAIL: selection_history.product_name must be nullable';
  end if;
  if exists (select 1 from information_schema.columns where table_schema = 'builder'
             and column_name in ('status', 'action', 'actor_kind') and data_type <> 'text') then
    raise exception 'FAIL: statuses must be text';
  end if;
  raise notice 'PASS: 4 tables, RLS enabled+forced and locked, audit columns + touch triggers, nullable history product, text statuses';
end $$;

-- 2. composite keys exist as required
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'projects_id_org_key' and contype = 'u')
     or not exists (select 1 from pg_constraint where conname = 'project_slots_id_org_key' and contype = 'u')
     or not exists (select 1 from pg_constraint where conname = 'selections_slot_id_key' and contype = 'u') then
    raise exception 'FAIL: missing unique (id, org_id) on projects/slots or unique selections.slot_id';
  end if;
  if (select count(*) from pg_constraint where contype = 'f' and conname in
      ('project_slots_project_fk', 'selections_slot_fk', 'selection_history_slot_fk')
      and array_length(conkey, 1) = 2) <> 3 then
    raise exception 'FAIL: composite FKs (project_id, org_id) / (slot_id, org_id) missing';
  end if;
  raise notice 'PASS: unique (id, org_id) on projects and slots, unique selections.slot_id, 3 composite FKs';
end $$;

-- fixtures: two builder orgs, one project + slot each
insert into public.orgs (id, name, org_type) values
  ('00000000-0000-0000-0000-0000000002a0', 'T Builder A', 'builder'),
  ('00000000-0000-0000-0000-0000000002b0', 'T Builder B', 'builder');
insert into builder.projects (id, org_id, name, status, selection_phase_started_at) values
  ('00000000-0000-0000-0000-0000000002a1', '00000000-0000-0000-0000-0000000002a0', 'T Lot A', 'selection_phase', now()),
  ('00000000-0000-0000-0000-0000000002b1', '00000000-0000-0000-0000-0000000002b0', 'T Lot B', 'selection_phase', now());
insert into builder.project_slots (id, org_id, project_id, room, category) values
  ('00000000-0000-0000-0000-0000000002a2', '00000000-0000-0000-0000-0000000002a0', '00000000-0000-0000-0000-0000000002a1', 'Kitchen', 'Countertop'),
  ('00000000-0000-0000-0000-0000000002b2', '00000000-0000-0000-0000-0000000002b0', '00000000-0000-0000-0000-0000000002b1', 'Kitchen', 'Countertop');

-- 3. AC4: a selection whose org_id differs from its slot's org -> FK violation
select pg_temp.expect_error($q$insert into builder.selections (org_id, slot_id, product_name)
  values ('00000000-0000-0000-0000-0000000002a0', '00000000-0000-0000-0000-0000000002b2', 'Cross-org quartz')$q$,
  '23503', 'cross-org selection');
select pg_temp.expect_error($q$insert into builder.project_slots (org_id, project_id, room, category)
  values ('00000000-0000-0000-0000-0000000002a0', '00000000-0000-0000-0000-0000000002b1', 'Bath', 'Tile')$q$,
  '23503', 'cross-org slot');
select pg_temp.expect_error($q$insert into builder.selection_history (org_id, slot_id, action, product_name, actor_kind)
  values ('00000000-0000-0000-0000-0000000002a0', '00000000-0000-0000-0000-0000000002b2', 'set', 'X', 'builder')$q$,
  '23503', 'cross-org history');
do $$ begin raise notice 'PASS: cross-org selection / slot / history rows raise foreign key violations'; end $$;

-- 4. checks and uniques
select pg_temp.expect_error($q$insert into builder.projects (org_id, name, status)
  values ('00000000-0000-0000-0000-0000000002a0', 'No start', 'selection_phase')$q$, '23514', 'selection_phase needs start');
select pg_temp.expect_error($q$insert into builder.projects (org_id, name, status)
  values ('00000000-0000-0000-0000-0000000002a0', 'Bad', 'stalled')$q$, '23514', 'project status check');
insert into builder.selections (org_id, slot_id, product_name)
  values ('00000000-0000-0000-0000-0000000002a0', '00000000-0000-0000-0000-0000000002a2', 'Quartz');
select pg_temp.expect_error($q$insert into builder.selections (org_id, slot_id, product_name)
  values ('00000000-0000-0000-0000-0000000002a0', '00000000-0000-0000-0000-0000000002a2', 'Granite')$q$, '23505', 'one selection per slot');
select pg_temp.expect_error($q$insert into builder.project_slots (org_id, project_id, room, category)
  values ('00000000-0000-0000-0000-0000000002a0', '00000000-0000-0000-0000-0000000002a1', 'Kitchen', 'Countertop')$q$, '23505', 'duplicate slot');
select pg_temp.expect_error($q$insert into builder.selection_history (org_id, slot_id, action, product_name, actor_kind)
  values ('00000000-0000-0000-0000-0000000002a0', '00000000-0000-0000-0000-0000000002a2', 'clear', 'Quartz', 'builder')$q$, '23514', 'clear must have no product');
select pg_temp.expect_error($q$insert into builder.selection_history (org_id, slot_id, action, product_name, actor_kind)
  values ('00000000-0000-0000-0000-0000000002a0', '00000000-0000-0000-0000-0000000002a2', 'set', null, 'builder')$q$, '23514', 'set needs a product');
select pg_temp.expect_error($q$insert into builder.selection_history (org_id, slot_id, action, product_name, actor_kind)
  values ('00000000-0000-0000-0000-0000000002a0', '00000000-0000-0000-0000-0000000002a2', 'set', 'X', 'robot')$q$, '23514', 'actor_kind check');
insert into builder.selection_history (org_id, slot_id, action, product_name, actor_kind)
  values ('00000000-0000-0000-0000-0000000002a0', '00000000-0000-0000-0000-0000000002a2', 'clear', null, 'builder');
do $$ begin raise notice 'PASS: status/phase/action/actor checks, one selection per slot, unique slots, clear has null product'; end $$;

rollback;
