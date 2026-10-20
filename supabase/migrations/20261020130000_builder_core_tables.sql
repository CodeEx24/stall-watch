-- WHY:  Projects, slots, selections and their history are the business data each
--       builder org owns. A child row must never be able to disagree with its
--       parent's org (ADR-003): with org_id-only checks a user could attach a row
--       to another org's parent while tagging it with their own org.
-- WHAT: builder.projects, builder.project_slots, builder.selections,
--       builder.selection_history, shaped to the provided supabase/seed.sql.
--       - unique (id, org_id) on projects and slots, so children reference
--         (parent_id, org_id) with composite foreign keys.
--       - statuses / actions / actor kinds are text + check (no enums).
--       - projects in 'selection_phase' must have selection_phase_started_at.
--       - one current selection per slot (selections.slot_id unique).
--       - history.product_name is nullable (a 'clear' has no product) and must be
--         null exactly when action = 'clear'.
--       - projects, slots, selections carry created_at / updated_at / lock_version
--         with private.touch_updated_at(); history is append-only (no update
--         columns; STW-23 blocks update/delete).
--       Locked by default like the identity tables: RLS enabled AND forced with
--       no policies, all privileges revoked from app roles (Supabase default
--       privileges would grant ALL). STW-21 adds org-scoped policies and grants.
-- ROLLBACK: drop table if exists builder.selection_history, builder.selections,
--                                builder.project_slots, builder.projects;

-- projects -------------------------------------------------------------------
create table builder.projects (
  id                          uuid primary key default gen_random_uuid(),
  org_id                      uuid not null references public.orgs (id) on delete restrict,
  name                        text not null check (length(btrim(name)) between 1 and 200),
  status                      text not null default 'pending_kickoff'
                              check (status in ('pending_kickoff', 'selection_phase', 'revision', 'complete')),
  selection_phase_started_at  timestamptz,
  selection_due_date          date,
  archived_at                 timestamptz,
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now(),
  lock_version                integer not null default 0 check (lock_version >= 0),
  constraint projects_id_org_key unique (id, org_id),
  constraint projects_selection_phase_started
    check (status <> 'selection_phase' or selection_phase_started_at is not null)
);
comment on table builder.projects is 'A builder project (lot/unit). status drives the stall rule; only selection_phase projects can stall.';
create index projects_org_id_idx on builder.projects (org_id);

-- project_slots ---------------------------------------------------------------
create table builder.project_slots (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null,
  project_id    uuid not null,
  room          text not null check (length(btrim(room)) between 1 and 100),
  category      text not null check (length(btrim(category)) between 1 and 100),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  lock_version  integer not null default 0 check (lock_version >= 0),
  constraint project_slots_id_org_key unique (id, org_id),
  constraint project_slots_project_room_category_key unique (project_id, room, category),
  constraint project_slots_project_fk foreign key (project_id, org_id)
    references builder.projects (id, org_id) on delete restrict
);
comment on table builder.project_slots is 'A finish to choose on a project, e.g. Kitchen / Countertop.';
create index project_slots_org_id_idx on builder.project_slots (org_id);

-- selections -------------------------------------------------------------------
create table builder.selections (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null,
  slot_id       uuid not null,
  product_name  text not null check (length(btrim(product_name)) between 1 and 200),
  selected_by   uuid references public.users (id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  lock_version  integer not null default 0 check (lock_version >= 0),
  constraint selections_slot_id_key unique (slot_id),
  constraint selections_slot_fk foreign key (slot_id, org_id)
    references builder.project_slots (id, org_id) on delete restrict
);
comment on table builder.selections is 'Current choice per slot (at most one). Clearing deletes the row; history keeps the record.';
create index selections_org_id_idx on builder.selections (org_id);

-- selection_history -------------------------------------------------------------
create table builder.selection_history (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null,
  slot_id       uuid not null,
  action        text not null check (action in ('set', 'change', 'clear')),
  product_name  text check (product_name is null or length(btrim(product_name)) between 1 and 200),
  changed_by    uuid references public.users (id) on delete set null,
  actor_kind    text not null check (actor_kind in ('builder', 'staff')),
  changed_at    timestamptz not null default now(),
  constraint selection_history_product_matches_action
    check ((action = 'clear') = (product_name is null)),
  constraint selection_history_slot_fk foreign key (slot_id, org_id)
    references builder.project_slots (id, org_id) on delete restrict
);
comment on table builder.selection_history is 'Append-only log of every set / change / clear. actor_kind (builder|staff) drives the stall rule.';
create index selection_history_slot_changed_at_idx on builder.selection_history (slot_id, changed_at desc);
create index selection_history_org_id_idx on builder.selection_history (org_id);

-- touch triggers (history is append-only, so no trigger there) -------------------
create trigger trg_projects_touch before update on builder.projects
  for each row execute function private.touch_updated_at();
create trigger trg_project_slots_touch before update on builder.project_slots
  for each row execute function private.touch_updated_at();
create trigger trg_selections_touch before update on builder.selections
  for each row execute function private.touch_updated_at();

-- locked until STW-21 adds policies ----------------------------------------------
alter table builder.projects          enable row level security;
alter table builder.projects          force row level security;
alter table builder.project_slots     enable row level security;
alter table builder.project_slots     force row level security;
alter table builder.selections        enable row level security;
alter table builder.selections        force row level security;
alter table builder.selection_history enable row level security;
alter table builder.selection_history force row level security;

revoke all on table builder.projects, builder.project_slots, builder.selections, builder.selection_history
  from public, anon, authenticated;
