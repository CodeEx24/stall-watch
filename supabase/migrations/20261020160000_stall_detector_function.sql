-- WHY:  Builder admins need an alert when a project stalls, once per stall episode,
--       and staff need proof the detector ran -- including when it failed (ADR-001,
--       ADR-004, ADR-005). pg_cron (STW-34) and the staff "Run now" RPC (STW-33)
--       both call this one function; no app role may call it directly.
-- WHAT: private.run_stall_detector(p_trigger text) returns uuid (the run id).
--       1. p_trigger must be 'scheduled' or 'manual' (raises 22023 otherwise; no run row).
--       2. pg_advisory_xact_lock(2026032): runs serialize; the lock is held until the
--          caller's transaction ends, so an overlapping run waits, then sees the
--          episodes the first one committed and creates nothing twice.
--       3. INSERT the builder.stall_runs row ('running') OUTSIDE the inner block.
--       4. Inner block (begin ... exception when others ... end) does the work:
--          for every project with is_stalled in builder.v_projects (the live rule of
--          STW-26 -- not re-implemented here), insert builder.stall_episodes
--          (project_id, quiet_since) ON CONFLICT DO NOTHING; only for an episode
--          inserted by THIS run, one 'stalled' alert per ADMIN membership of the
--          project's org (members get none; staff are admins of the staff org, not
--          the builder org, so they get none), ON CONFLICT (episode_id, user_id) DO
--          NOTHING. Message:
--            '<name> has had no builder activity for <N> days. <M> slots are still empty.'
--          N = whole days since quiet_since (floor), M = v_projects.empty_slots;
--          singular forms '1 day' and '1 slot is' (N >= 7 under the current window, so
--          '1 day' is unreachable today). Then the run row -> 'succeeded',
--          finished_at = now() (the same transaction clock as started_at),
--          projects_flagged = stalled projects seen by this run (also on a re-run:
--          G-04, "flagged" = currently stalled), alerts_created = alerts inserted
--          by this run.
--       5. Exception handler: the inner block's savepoint is rolled back (no partial
--          episodes or alerts), the run row -> 'failed', finished_at = now(),
--          error_message = left(sqlerrm, 2000) (the column check is <= 2000, so a
--          longer message cannot make the handler itself fail), and the run id is
--          RETURNED, not re-raised, so the failed run row commits.
--       Rights: security definer, owned by postgres (BYPASSRLS), because the views it
--       reads are security_invoker and must see every org; the work block raises (and
--       so logs a failed run) if the owner cannot bypass RLS, instead of silently
--       finding nothing. set search_path = ''; every name schema-qualified. Execute
--       revoked from public, anon and authenticated.
--       Testing a failure needs no backdoor: the SQL test adds a throw-away trigger on
--       builder.alerts inside its own rolled-back transaction. Nothing an app role
--       can set or call changes this function's behaviour.
-- ROLLBACK: drop function if exists private.run_stall_detector(text);

create or replace function private.run_stall_detector(p_trigger text)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  c_lock_key   constant bigint := 2026032;  -- fixed key: one detector run at a time
  v_run_id     uuid;
  v_episode_id uuid;
  v_flagged    integer := 0;
  v_alerts     integer := 0;
  v_rows       integer;
  v_days       integer;
  v_message    text;
  r            record;
begin
  if p_trigger is null or p_trigger not in ('scheduled', 'manual') then
    raise exception 'invalid detector trigger: %', coalesce(p_trigger, 'null')
      using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(c_lock_key);

  insert into builder.stall_runs (trigger) values (p_trigger)
  returning id into v_run_id;

  begin
    if not (select rolbypassrls from pg_catalog.pg_roles where rolname = current_user) then
      raise exception 'detector owner % cannot bypass RLS; it would see no projects', current_user;
    end if;

    for r in
      select p.id, p.org_id, p.name, p.quiet_since, p.empty_slots
      from builder.v_projects p
      where p.is_stalled
      order by p.org_id, p.name
    loop
      v_flagged := v_flagged + 1;

      insert into builder.stall_episodes (org_id, project_id, quiet_since, run_id)
      values (r.org_id, r.id, r.quiet_since, v_run_id)
      on conflict (project_id, quiet_since) do nothing
      returning id into v_episode_id;

      if v_episode_id is not null then
        v_days := pg_catalog.floor(extract(epoch from (now() - r.quiet_since)) / 86400)::integer;
        v_message := pg_catalog.format(
          '%s has had no builder activity for %s %s. %s %s still empty.',
          r.name,
          v_days, case when v_days = 1 then 'day' else 'days' end,
          r.empty_slots, case when r.empty_slots = 1 then 'slot is' else 'slots are' end
        );

        insert into builder.alerts (org_id, user_id, project_id, kind, message, episode_id)
        select r.org_id, m.user_id, r.id, 'stalled', v_message, v_episode_id
        from public.memberships m
        where m.org_id = r.org_id
          and m.role = 'admin'
        on conflict (episode_id, user_id) do nothing;

        get diagnostics v_rows = row_count;
        v_alerts := v_alerts + v_rows;
      end if;
    end loop;

    update builder.stall_runs
    set status = 'succeeded',
        finished_at = now(),
        projects_flagged = v_flagged,
        alerts_created = v_alerts
    where id = v_run_id;
  exception when others then
    -- the savepoint of this block is gone: no episode or alert of this run remains
    update builder.stall_runs
    set status = 'failed',
        finished_at = now(),
        projects_flagged = 0,
        alerts_created = 0,
        error_message = left(sqlerrm, 2000)
    where id = v_run_id;
  end;

  return v_run_id;
end;
$$;

comment on function private.run_stall_detector(text) is
  'Stall detector (ADR-001/004/005): advisory-locked, logs every run in builder.stall_runs (failures too), one episode per (project, quiet_since), alerts for org admins of new episodes only. Called by pg_cron and the staff RPC; no app role may execute it.';

revoke execute on function private.run_stall_detector(text) from public, anon, authenticated;
