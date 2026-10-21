-- STW-28: /projects reads builder.v_projects live; one builder selection clears the badge.
-- Every assertion raises on failure; the transaction is rolled back, so the shared
-- seed (Lot 12 stalled) is left exactly as it was.
\set ON_ERROR_STOP on
begin;

-- 1. the columns the page selects exist on the view (keeps queries.ts honest)
do $$
declare
  needed constant text[] := array['id', 'org_id', 'org_name', 'name', 'status', 'selection_due_date',
                                  'archived_at', 'slot_count', 'empty_slots', 'is_stalled'];
  missing text[];
begin
  select array_agg(c order by c) into missing
  from unnest(needed) as c
  where not exists (select 1 from information_schema.columns
                    where table_schema = 'builder' and table_name = 'v_projects' and column_name = c);
  if missing is not null then
    raise exception 'FAIL: builder.v_projects lacks columns %', missing;
  end if;
  raise notice 'PASS: builder.v_projects exposes every column the /projects list reads';
end $$;

-- 2. AC3 on the seed: Ana makes one selection on Lot 12 -> the badge is gone
do $$
declare
  ana uuid;
  lot12 uuid;
  slot uuid;
  stalled_before boolean;
  stalled_after boolean;
  empty_before int;
  empty_after int;
  kind text;
begin
  select id into ana from public.users where email = 'ana@builder-a.test';
  select id into lot12 from builder.projects where name = 'Lot 12';
  if ana is null or lot12 is null then
    raise notice 'SKIP: seed or ana@builder-a.test not loaded; AC3 seed check skipped';
    return;
  end if;

  perform set_config('request.jwt.claims', json_build_object('sub', ana, 'role', 'authenticated')::text, true);
  set local role authenticated;

  select is_stalled, empty_slots into stalled_before, empty_before from builder.v_projects where id = lot12;
  if stalled_before is distinct from true then
    raise exception 'FAIL: Lot 12 should be stalled for Ana before any selection (got %)', stalled_before;
  end if;

  select s.id into slot
  from builder.project_slots s
  where s.project_id = lot12
    and not exists (select 1 from builder.selections x where x.slot_id = s.id)
  order by s.room, s.category
  limit 1;
  if slot is null then
    raise exception 'FAIL: Lot 12 has no empty slot to select';
  end if;

  insert into builder.selections (org_id, slot_id, product_name)
  select org_id, id, 'STW-28 probe' from builder.project_slots where id = slot;

  select is_stalled, empty_slots into stalled_after, empty_after from builder.v_projects where id = lot12;
  select actor_kind into kind from builder.selection_history
  where slot_id = slot order by changed_at desc limit 1;

  reset role;
  perform set_config('request.jwt.claims', '', true);

  if stalled_after is distinct from false then
    raise exception 'FAIL: Lot 12 still stalled after Ana''s selection';
  end if;
  if empty_after <> empty_before - 1 then
    raise exception 'FAIL: empty_slots went % -> %, expected one fewer', empty_before, empty_after;
  end if;
  if kind is distinct from 'builder' then
    raise exception 'FAIL: history recorded actor_kind %, expected builder', kind;
  end if;
  raise notice 'PASS: Ana sets one Lot 12 slot -> is_stalled true -> false, empty_slots % -> %, history actor_kind builder', empty_before, empty_after;
end $$;

rollback;
