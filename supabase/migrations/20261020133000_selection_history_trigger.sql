-- WHY:  The stall rule counts only BUILDER activity, so who changed a selection
--       must come from the database, never from the client: a builder could
--       otherwise forge history, or staff edits could hide a stall (ADR-006/007).
-- WHAT: private.record_selection_history(): AFTER INSERT / UPDATE / DELETE on
--       builder.selections, writes one builder.selection_history row:
--         insert -> 'set'    (product_name = new value)
--         update -> 'change' (only when product_name actually changes)
--         delete -> 'clear'  (product_name null)
--       changed_by = auth.uid(); actor_kind = 'builder' when the caller is a
--       member of the selection's org (= the project's org, enforced by the
--       composite FKs), otherwise 'staff' — including when there is no auth.uid()
--       (SQL editor, scheduled jobs).
--       SECURITY DEFINER IS DELIBERATE: app roles have no INSERT on
--       selection_history (STW-21), so only this trigger can write it. It runs as
--       the owner (postgres, BYPASSRLS), takes no arguments, reads identity only
--       from auth.uid() and the row being changed, uses search_path = '' with
--       schema-qualified names, and execute is revoked from public, anon,
--       authenticated.
--       private.forbid_history_change(): BEFORE UPDATE OR DELETE on
--       selection_history raises for everyone, so history is append-only even for
--       privileged roles. Single exception: an update that only sets changed_by to
--       null, which is what `changed_by references public.users on delete set null`
--       does when a user is deleted. The history row survives, anonymised.
-- ROLLBACK: drop trigger if exists trg_selection_history on builder.selections;
--           drop trigger if exists trg_selection_history_immutable on builder.selection_history;
--           drop function if exists private.record_selection_history();
--           drop function if exists private.forbid_history_change();

create or replace function private.record_selection_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := (select auth.uid());
  v_row   builder.selections;
  v_kind  text;
begin
  if tg_op = 'DELETE' then
    v_row := old;
  else
    v_row := new;
  end if;

  if tg_op = 'UPDATE' and new.product_name is not distinct from old.product_name then
    return null;  -- nothing a builder chose changed; not activity
  end if;

  v_kind := case
    when v_uid is not null and exists (
      select 1 from public.memberships m
      where m.user_id = v_uid and m.org_id = v_row.org_id
    ) then 'builder'
    else 'staff'
  end;

  insert into builder.selection_history (org_id, slot_id, action, product_name, changed_by, actor_kind)
  values (
    v_row.org_id,
    v_row.slot_id,
    case tg_op when 'INSERT' then 'set' when 'UPDATE' then 'change' else 'clear' end,
    case when tg_op = 'DELETE' then null else new.product_name end,
    v_uid,
    v_kind
  );
  return null;
end;
$$;

comment on function private.record_selection_history() is
  'AFTER trigger on builder.selections: appends set/change/clear to selection_history with changed_by = auth.uid() and actor_kind computed from memberships. Deliberately SECURITY DEFINER.';
revoke execute on function private.record_selection_history() from public, anon, authenticated;

create trigger trg_selection_history
  after insert or update or delete on builder.selections
  for each row execute function private.record_selection_history();

create or replace function private.forbid_history_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- The one permitted change: the FK action `changed_by ... on delete set null`
  -- when a user is deleted. The row survives, anonymised; nothing else may differ.
  if tg_op = 'UPDATE'
     and old.changed_by is not null and new.changed_by is null
     and (new.id, new.org_id, new.slot_id, new.action, new.product_name, new.actor_kind, new.changed_at)
         is not distinct from
         (old.id, old.org_id, old.slot_id, old.action, old.product_name, old.actor_kind, old.changed_at) then
    return new;
  end if;
  raise exception 'builder.selection_history is append-only (% blocked)', tg_op
    using errcode = 'insufficient_privilege';
end;
$$;
comment on function private.forbid_history_change() is
  'Blocks UPDATE/DELETE on builder.selection_history for every role, except nulling changed_by alone (the users FK on delete set null).';
revoke execute on function private.forbid_history_change() from public, anon, authenticated;

create trigger trg_selection_history_immutable
  before update or delete on builder.selection_history
  for each row execute function private.forbid_history_change();
