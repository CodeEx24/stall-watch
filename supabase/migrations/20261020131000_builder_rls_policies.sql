-- WHY:  Builder A must only see and change Builder A's data; staff see everything.
--       Builders and staff share the `authenticated` role, so the policies are the
--       wall. Clients must not be able to forge who chose a product or move a row
--       to another org, so writes are narrowed with column grants as well.
-- WHAT: RLS stays ENABLED and FORCED on every builder table. Policies (all `to
--       authenticated`, tenant predicate = org_id = any (current_user_org_ids())
--       or is_staff(); helpers wrapped in (select ...) so they run once per query):
--         projects           p_projects_select (org-or-staff), p_projects_update (STAFF only, with check)
--         project_slots      p_project_slots_select            (no write policy)
--         selections         p_selections_select / _insert / _update / _delete (org-or-staff, with check)
--         selection_history  p_selection_history_select        (no write policy; rows come from the
--                                                               definer trigger in STW-23)
--       Grants (authenticated only; anon gets nothing):
--         usage on schema builder;
--         select on all four tables;
--         update (name, status, selection_phase_started_at, selection_due_date, archived_at) on projects;
--         insert (org_id, slot_id, product_name), update (product_name), delete on selections.
--       private.stamp_selected_by(): BEFORE INSERT OR UPDATE on selections sets
--       selected_by := auth.uid(), so the chooser is always the caller (seed.sql runs
--       with triggers off and keeps its null).
--       Hosted project: `builder` must be listed in Dashboard > Project Settings > Data API
--       > Exposed schemas (local: supabase/config.toml). Recorded in SETUP.md.
-- ROLLBACK: drop trigger if exists trg_selections_stamp_selected_by on builder.selections;
--           drop function if exists private.stamp_selected_by();
--           drop policy if exists p_projects_select on builder.projects;
--           drop policy if exists p_projects_update on builder.projects;
--           drop policy if exists p_project_slots_select on builder.project_slots;
--           drop policy if exists p_selections_select on builder.selections;
--           drop policy if exists p_selections_insert on builder.selections;
--           drop policy if exists p_selections_update on builder.selections;
--           drop policy if exists p_selections_delete on builder.selections;
--           drop policy if exists p_selection_history_select on builder.selection_history;
--           revoke all on all tables in schema builder from authenticated;
--           revoke usage on schema builder from authenticated;

alter table builder.projects          enable row level security;
alter table builder.projects          force row level security;
alter table builder.project_slots     enable row level security;
alter table builder.project_slots     force row level security;
alter table builder.selections        enable row level security;
alter table builder.selections        force row level security;
alter table builder.selection_history enable row level security;
alter table builder.selection_history force row level security;

-- projects -------------------------------------------------------------------
create policy p_projects_select on builder.projects
  for select to authenticated
  using (org_id = any ((select private.current_user_org_ids())::uuid[]) or (select private.is_staff()));

create policy p_projects_update on builder.projects
  for update to authenticated
  using ((select private.is_staff()))
  with check ((select private.is_staff()));

-- project_slots ----------------------------------------------------------------
create policy p_project_slots_select on builder.project_slots
  for select to authenticated
  using (org_id = any ((select private.current_user_org_ids())::uuid[]) or (select private.is_staff()));

-- selections --------------------------------------------------------------------
create policy p_selections_select on builder.selections
  for select to authenticated
  using (org_id = any ((select private.current_user_org_ids())::uuid[]) or (select private.is_staff()));

create policy p_selections_insert on builder.selections
  for insert to authenticated
  with check (org_id = any ((select private.current_user_org_ids())::uuid[]) or (select private.is_staff()));

create policy p_selections_update on builder.selections
  for update to authenticated
  using (org_id = any ((select private.current_user_org_ids())::uuid[]) or (select private.is_staff()))
  with check (org_id = any ((select private.current_user_org_ids())::uuid[]) or (select private.is_staff()));

create policy p_selections_delete on builder.selections
  for delete to authenticated
  using (org_id = any ((select private.current_user_org_ids())::uuid[]) or (select private.is_staff()));

-- selection_history ---------------------------------------------------------------
create policy p_selection_history_select on builder.selection_history
  for select to authenticated
  using (org_id = any ((select private.current_user_org_ids())::uuid[]) or (select private.is_staff()));

-- selected_by is always the caller ---------------------------------------------------
create or replace function private.stamp_selected_by()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.selected_by := (select auth.uid());
  return new;
end;
$$;
comment on function private.stamp_selected_by() is
  'BEFORE INSERT OR UPDATE on builder.selections: selected_by := auth.uid() (clients cannot forge it).';
revoke execute on function private.stamp_selected_by() from public, anon, authenticated;

create trigger trg_selections_stamp_selected_by
  before insert or update on builder.selections
  for each row execute function private.stamp_selected_by();

-- grants: authenticated only ------------------------------------------------------------
revoke all on table builder.projects, builder.project_slots, builder.selections, builder.selection_history
  from public, anon, authenticated;
revoke all on schema builder from public, anon;

grant usage on schema builder to authenticated;
grant select on table builder.projects, builder.project_slots, builder.selections, builder.selection_history
  to authenticated;
grant update (name, status, selection_phase_started_at, selection_due_date, archived_at)
  on table builder.projects to authenticated;
grant insert (org_id, slot_id, product_name), update (product_name), delete
  on table builder.selections to authenticated;
