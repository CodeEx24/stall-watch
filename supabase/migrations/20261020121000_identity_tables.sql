-- WHY:  Tenancy and staff status must come from rows the client cannot influence.
--       orgs / users / memberships are the single source of "who belongs where"
--       (never auth user metadata, never caller-passed ids).
-- WHAT: public.orgs (org_type 'staff' | 'builder'), public.users (1:1 with
--       auth.users, unique lower-case email), public.memberships (role 'admin' |
--       'member', unique (user_id, org_id)). uuid keys, created_at / updated_at /
--       lock_version, touch trigger on every table.
--       Locked by default: Supabase's default privileges grant anon and
--       authenticated ALL on new public tables, so this migration enables AND
--       forces RLS with no policies and revokes every privilege from app roles.
--       Read access is opened by STW-19 (p_<table>_select policies); writes stay
--       closed (rows come from the auth-mirror trigger and seed scripts).
--       public tables never reference builder tables.
-- ROLLBACK: drop table if exists public.memberships, public.users, public.orgs;

-- orgs -----------------------------------------------------------------------
create table public.orgs (
  id           uuid primary key default gen_random_uuid(),
  name         text not null check (length(btrim(name)) between 1 and 200),
  org_type     text not null check (org_type in ('staff', 'builder')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  lock_version integer not null default 0 check (lock_version >= 0)
);
comment on table public.orgs is 'Tenants. org_type = staff marks the Reverie3D staff org.';

-- users ----------------------------------------------------------------------
create table public.users (
  id           uuid primary key references auth.users (id) on delete cascade,
  email        text not null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  lock_version integer not null default 0 check (lock_version >= 0),
  constraint users_email_key unique (email),
  constraint users_email_lowercase check (email = lower(email)),
  constraint users_email_shape check (email ~ '^[^@\s]+@[^@\s]+$' and length(email) <= 320)
);
comment on table public.users is 'Mirror of auth.users (id, email); filled by the auth-mirror trigger (STW-17).';

-- memberships ------------------------------------------------------------------
create table public.memberships (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.users (id) on delete cascade,
  org_id       uuid not null references public.orgs (id) on delete restrict,
  role         text not null check (role in ('admin', 'member')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  lock_version integer not null default 0 check (lock_version >= 0),
  constraint memberships_user_org_key unique (user_id, org_id)
);
comment on table public.memberships is 'Which user belongs to which org, and as admin or member. Source of all RLS decisions.';
-- (user_id, org_id) unique index serves user_id lookups; org_id needs its own.
create index memberships_org_id_idx on public.memberships (org_id);

-- touch triggers ----------------------------------------------------------------
create trigger trg_orgs_touch before update on public.orgs
  for each row execute function private.touch_updated_at();
create trigger trg_users_touch before update on public.users
  for each row execute function private.touch_updated_at();
create trigger trg_memberships_touch before update on public.memberships
  for each row execute function private.touch_updated_at();

-- locked until STW-19 adds read policies -----------------------------------------
alter table public.orgs        enable row level security;
alter table public.orgs        force row level security;
alter table public.users       enable row level security;
alter table public.users       force row level security;
alter table public.memberships enable row level security;
alter table public.memberships force row level security;

revoke all on table public.orgs, public.users, public.memberships from public, anon, authenticated;
