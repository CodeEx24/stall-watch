-- WHY:  Stall alerts are personal: only the recipient may read them or mark them
--       read, not other org members and not staff. RLS cannot restrict columns, so
--       a column grant makes "mark as read changes nothing else" mechanical
--       (ADR-008). Alerts are created only by the detector (definer rights, STW-24+).
-- WHAT: builder.alerts (org_id, user_id, project_id, kind, message, read_at,
--       created_at, plus updated_at / lock_version with the shared touch trigger).
--       Composite FK (project_id, org_id) -> projects; user_id -> public.users.
--       kind is text + check: 'stalled' (detector) or 'late_change' (Part 3 bonus).
--       read_at cannot precede created_at.
--       RLS enabled + forced. Policies for authenticated:
--         p_alerts_select  user_id = auth.uid()
--         p_alerts_update  user_id = auth.uid()  (using + with check)
--       Grants: select; UPDATE revoked then update (read_at) only; no insert or
--       delete for authenticated; nothing for anon.
--       STW-31 adds episode_id and the (episode_id, user_id) unique key.
-- ROLLBACK: drop table if exists builder.alerts;

create table builder.alerts (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null,
  user_id       uuid not null references public.users (id) on delete cascade,
  project_id    uuid not null,
  kind          text not null check (kind in ('stalled', 'late_change')),
  message       text not null check (length(btrim(message)) between 1 and 500),
  read_at       timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  lock_version  integer not null default 0 check (lock_version >= 0),
  constraint alerts_project_fk foreign key (project_id, org_id)
    references builder.projects (id, org_id) on delete restrict,
  constraint alerts_read_after_created check (read_at is null or read_at >= created_at)
);
comment on table builder.alerts is 'In-app alerts. Recipient-only (user_id = auth.uid()); only read_at is writable by the app; rows come from the detector.';

-- the inbox query: my alerts, newest first, unread first
create index alerts_user_created_idx on builder.alerts (user_id, created_at desc);
create index alerts_org_id_idx on builder.alerts (org_id);
create index alerts_project_id_idx on builder.alerts (project_id);

create trigger trg_alerts_touch before update on builder.alerts
  for each row execute function private.touch_updated_at();

alter table builder.alerts enable row level security;
alter table builder.alerts force row level security;

create policy p_alerts_select on builder.alerts
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy p_alerts_update on builder.alerts
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

revoke all on table builder.alerts from public, anon, authenticated;
grant select on table builder.alerts to authenticated;
revoke update on table builder.alerts from authenticated;
grant update (read_at) on table builder.alerts to authenticated;
