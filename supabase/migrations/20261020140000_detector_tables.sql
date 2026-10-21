-- WHY:  Every detector run must be recorded (including failures), and re-runs or
--       overlapping runs must never duplicate alerts (ADR-004). A time window is
--       not idempotency: the episode record is.
-- WHAT: builder.stall_runs   one row per run: trigger (scheduled | manual), status
--                            (running | succeeded | failed), started_at, finished_at,
--                            projects_flagged, alerts_created, error_message.
--       builder.stall_episodes one row per stall episode: unique (project_id, quiet_since);
--                            new builder activity moves quiet_since, so a re-stall is a
--                            new episode. Composite FK (project_id, org_id).
--       builder.alerts.episode_id -> stall_episodes, composite (episode_id, org_id) so an
--                            alert can't point at another org's episode;
--                            unique (episode_id, user_id): one alert per admin per episode.
--                            'stalled' alerts require an episode.
--       RLS enabled + forced on both new tables; staff-only SELECT via
--       private.is_staff(); no write grants to authenticated (rows come only from
--       private.run_stall_detector, STW-32, with definer rights). anon: nothing.
-- ROLLBACK: alter table builder.alerts drop constraint if exists alerts_stalled_needs_episode,
--             drop constraint if exists alerts_episode_user_key,
--             drop constraint if exists alerts_episode_fk, drop column if exists episode_id;
--           drop table if exists builder.stall_episodes, builder.stall_runs;

-- stall_runs ---------------------------------------------------------------------
create table builder.stall_runs (
  id                uuid primary key default gen_random_uuid(),
  trigger           text not null check (trigger in ('scheduled', 'manual')),
  status            text not null default 'running' check (status in ('running', 'succeeded', 'failed')),
  started_at        timestamptz not null default now(),
  finished_at       timestamptz,
  projects_flagged  integer not null default 0 check (projects_flagged >= 0),
  alerts_created    integer not null default 0 check (alerts_created >= 0),
  error_message     text check (error_message is null or length(error_message) <= 2000),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  lock_version      integer not null default 0 check (lock_version >= 0),
  constraint stall_runs_finished_iff_done check ((status = 'running') = (finished_at is null)),
  constraint stall_runs_finished_after_start check (finished_at is null or finished_at >= started_at),
  constraint stall_runs_error_iff_failed check ((status = 'failed') = (error_message is not null))
);
comment on table builder.stall_runs is 'Detector run log (scheduled and manual), including failures. Staff-only.';
create index stall_runs_started_at_idx on builder.stall_runs (started_at desc);

create trigger trg_stall_runs_touch before update on builder.stall_runs
  for each row execute function private.touch_updated_at();

-- stall_episodes -------------------------------------------------------------------
create table builder.stall_episodes (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null,
  project_id   uuid not null,
  quiet_since  timestamptz not null,
  run_id       uuid not null references builder.stall_runs (id) on delete restrict,
  created_at   timestamptz not null default now(),
  constraint stall_episodes_project_quiet_key unique (project_id, quiet_since),
  constraint stall_episodes_id_org_key unique (id, org_id),
  constraint stall_episodes_project_fk foreign key (project_id, org_id)
    references builder.projects (id, org_id) on delete restrict
);
comment on table builder.stall_episodes is 'One row per stall episode (project, quiet_since). De-duplicates alerts across runs. Append-only, staff-only.';
create index stall_episodes_org_id_idx on builder.stall_episodes (org_id);
create index stall_episodes_run_id_idx on builder.stall_episodes (run_id);

-- alerts.episode_id ------------------------------------------------------------------
alter table builder.alerts add column episode_id uuid;
alter table builder.alerts
  add constraint alerts_episode_fk foreign key (episode_id, org_id)
    references builder.stall_episodes (id, org_id) on delete restrict,
  add constraint alerts_episode_user_key unique (episode_id, user_id),
  add constraint alerts_stalled_needs_episode check (kind <> 'stalled' or episode_id is not null);
create index alerts_episode_id_idx on builder.alerts (episode_id);

-- RLS: staff-only read, no app writes ------------------------------------------------------
alter table builder.stall_runs     enable row level security;
alter table builder.stall_runs     force row level security;
alter table builder.stall_episodes enable row level security;
alter table builder.stall_episodes force row level security;

create policy p_stall_runs_select on builder.stall_runs
  for select to authenticated
  using ((select private.is_staff()));

create policy p_stall_episodes_select on builder.stall_episodes
  for select to authenticated
  using ((select private.is_staff()));

revoke all on table builder.stall_runs, builder.stall_episodes from public, anon, authenticated;
grant select on table builder.stall_runs, builder.stall_episodes to authenticated;
