-- WHY:  When a builder changes or clears a selection on a project in 'revision'
--       (the set was signed off once, e.g. seed Lot 15), Reverie3D staff must hear
--       about it at once: orders and renders made against the finished set may be
--       wrong now. Only the database knows who made a change (actor_kind, STW-23),
--       so the alert is raised there, in the same transaction as the change.
-- WHAT: builder.selection_history gets unique (id, org_id), so alerts can reference
--       it with a composite FK (ADR-003).
--       builder.alerts.history_id uuid NULL (existing rows and 'stalled' alerts keep
--       null): composite FK (history_id, org_id) -> selection_history (id, org_id),
--       so an alert can't point at another org's history row, and
--       unique (history_id, user_id) = the de-dup key: one alert per staff user per
--       history row, however often the insert path runs (ON CONFLICT DO NOTHING).
--       private.raise_late_change_alert(): AFTER INSERT trigger fn on
--       builder.selection_history (trg_late_change_alert). It acts only when
--         new.actor_kind = 'builder' and new.action in ('change', 'clear')
--         and the slot's project has status = 'revision'
--       ('set' fills an empty slot, so it does not break the finished set; a clear
--       then re-set alerts once, on the clear). Then it inserts one 'late_change'
--       alert per staff user (a user with a membership in an org whose
--       org_type = 'staff', the same definition private.is_staff() uses), with
--       org_id = the project's (builder) org, project_id, history_id, and a message
--       built from project / room / category / new product, cut to 500 chars
--       (rendered as plain text by the app).
--       SECURITY DEFINER IS DELIBERATE: app roles have no INSERT on builder.alerts
--       (STW-22) and cannot read other orgs' memberships, so only a definer function
--       can address staff. It takes no arguments, reads only the new history row
--       (itself written by the definer history trigger, never by a client), uses
--       search_path = '' with schema-qualified names; execute revoked from public,
--       anon, authenticated. No policy or grant changes: alerts stay recipient-only
--       (p_alerts_select user_id = auth.uid()), so staff read their own late-change
--       alerts and builders never see them. RLS stays enabled and forced.
-- ROLLBACK: drop trigger if exists trg_late_change_alert on builder.selection_history;
--           drop function if exists private.raise_late_change_alert();
--           alter table builder.alerts drop constraint if exists alerts_history_user_key,
--             drop constraint if exists alerts_history_fk, drop column if exists history_id;
--           alter table builder.selection_history drop constraint if exists selection_history_id_org_key;

-- schema ----------------------------------------------------------------------------
alter table builder.selection_history
  add constraint selection_history_id_org_key unique (id, org_id);

alter table builder.alerts add column history_id uuid;
alter table builder.alerts
  add constraint alerts_history_fk foreign key (history_id, org_id)
    references builder.selection_history (id, org_id) on delete restrict,
  add constraint alerts_history_user_key unique (history_id, user_id);
comment on column builder.alerts.history_id is
  'late_change alerts: the selection_history row that caused it. unique (history_id, user_id) de-duplicates.';

-- trigger function --------------------------------------------------------------------
create or replace function private.raise_late_change_alert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_project  record;
  v_message  text;
begin
  if new.actor_kind <> 'builder' or new.action not in ('change', 'clear') then
    return null;
  end if;

  select p.id, p.org_id, p.name, p.status, s.room, s.category
    into v_project
  from builder.project_slots s
  join builder.projects p on p.id = s.project_id and p.org_id = s.org_id
  where s.id = new.slot_id and s.org_id = new.org_id;

  if not found or v_project.status <> 'revision' then
    return null;
  end if;

  v_message := left(
    case new.action
      when 'change' then pg_catalog.format(
        '%s: %s %s was changed to "%s" by the builder while the project is in revision.',
        v_project.name, v_project.room, v_project.category, new.product_name)
      else pg_catalog.format(
        '%s: %s %s was cleared by the builder while the project is in revision.',
        v_project.name, v_project.room, v_project.category)
    end,
    500);

  insert into builder.alerts (org_id, user_id, project_id, kind, message, history_id)
  select distinct v_project.org_id, m.user_id, v_project.id, 'late_change', v_message, new.id
  from public.memberships m
  join public.orgs o on o.id = m.org_id
  where o.org_type = 'staff'
  on conflict (history_id, user_id) do nothing;

  return null;
end;
$$;

comment on function private.raise_late_change_alert() is
  'AFTER INSERT trigger on builder.selection_history: a builder change/clear on a revision project -> one late_change alert per staff user (org_id = the builder org), de-duplicated on (history_id, user_id). Deliberately SECURITY DEFINER.';
revoke execute on function private.raise_late_change_alert() from public, anon, authenticated;

create trigger trg_late_change_alert
  after insert on builder.selection_history
  for each row execute function private.raise_late_change_alert();
