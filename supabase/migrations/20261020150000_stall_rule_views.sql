-- WHY:  The stall badge must be live: it reflects the rule right now, not the last
--       detector run (ADR-006). Activity is measured from selection_history rows
--       with actor_kind = 'builder' -- never selections.updated_at, which a staff
--       edit refreshes (the Unit 7C trap). The views run with the CALLER's rights
--       (security_invoker), so the builder-table RLS still decides which rows a
--       user sees; a definer view in an exposed schema would bypass it.
-- WHAT: private.stall_window() -> interval '7 days': the ONE place the stall
--       window (STALL_DAYS = 7) is defined. Immutable; execute for authenticated
--       only (the invoker views call it). The detector (STW-32) reuses it.
--       builder.v_project_stall: one row per visible project with
--         last_builder_activity_at = max(selection_history.changed_at) where
--                                    actor_kind = 'builder' (via the project's slots)
--         quiet_since = greatest(selection_phase_started_at, last_builder_activity_at)
--         is_stalled  = status = 'selection_phase' and archived_at is null
--                       and quiet_since <= now() - private.stall_window()
--                       (never null; false when quiet_since is null)
--       builder.v_projects: one row per visible project for /projects:
--         id, org_id, org_name (public.orgs), name, status,
--         selection_phase_started_at, selection_due_date, archived_at,
--         slot_count, empty_slots (slots without a current selection),
--         quiet_since, is_stalled (from v_project_stall).
--       Both views: with (security_invoker = true), set again with ALTER VIEW
--       after creation (re-apply after ANY create or replace). Grants: select to
--       authenticated only; nothing to public / anon.
-- ROLLBACK: drop view if exists builder.v_projects;
--           drop view if exists builder.v_project_stall;
--           drop function if exists private.stall_window();

-- the stall window, defined once ------------------------------------------------
create or replace function private.stall_window()
returns interval
language sql
immutable
parallel safe
set search_path = ''
as $$
  select interval '7 days';
$$;
comment on function private.stall_window() is
  'Stall window (STALL_DAYS = 7): a selection_phase project is stalled when quiet for at least this long. Single source for the views and the detector.';
revoke execute on function private.stall_window() from public, anon;
grant execute on function private.stall_window() to authenticated;

-- v_project_stall ------------------------------------------------------------------
create or replace view builder.v_project_stall
with (security_invoker = true)
as
select
  p.id                                   as project_id,
  p.org_id,
  p.status,
  p.archived_at,
  p.selection_phase_started_at,
  h.last_builder_activity_at,
  greatest(p.selection_phase_started_at, h.last_builder_activity_at) as quiet_since,
  coalesce(
    p.status = 'selection_phase'
    and p.archived_at is null
    and greatest(p.selection_phase_started_at, h.last_builder_activity_at)
        <= now() - private.stall_window(),
    false
  )                                      as is_stalled
from builder.projects p
left join lateral (
  select max(sh.changed_at) as last_builder_activity_at
  from builder.project_slots s
  join builder.selection_history sh
    on sh.slot_id = s.id and sh.org_id = s.org_id
  where s.project_id = p.id
    and s.org_id = p.org_id
    and sh.actor_kind = 'builder'
) h on true;

alter view builder.v_project_stall set (security_invoker = true);
comment on view builder.v_project_stall is
  'Live stall rule per project. quiet_since = greatest(selection_phase_started_at, last builder history); staff activity ignored. security_invoker: caller RLS applies.';

-- v_projects -----------------------------------------------------------------------
create or replace view builder.v_projects
with (security_invoker = true)
as
select
  p.id,
  p.org_id,
  o.name                       as org_name,
  p.name,
  p.status,
  p.selection_phase_started_at,
  p.selection_due_date,
  p.archived_at,
  c.slot_count,
  c.empty_slots,
  st.quiet_since,
  st.is_stalled
from builder.projects p
join public.orgs o
  on o.id = p.org_id
join builder.v_project_stall st
  on st.project_id = p.id
cross join lateral (
  select
    count(*)::integer                                  as slot_count,
    (count(*) filter (where sel.id is null))::integer  as empty_slots
  from builder.project_slots s
  left join builder.selections sel
    on sel.slot_id = s.id
  where s.project_id = p.id
    and s.org_id = p.org_id
) c;

alter view builder.v_projects set (security_invoker = true);
comment on view builder.v_projects is
  'One row per project for /projects: org_name, slot_count, empty_slots, quiet_since, is_stalled. security_invoker: caller RLS applies.';

-- grants: authenticated only ---------------------------------------------------------
revoke all on table builder.v_project_stall, builder.v_projects from public, anon, authenticated;
grant select on table builder.v_project_stall, builder.v_projects to authenticated;
