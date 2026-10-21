-- WHY:  Staff need to run the stall detector on demand to verify a fix immediately
--       (US-025, ADR-001). The detector itself (private.run_stall_detector, STW-32)
--       is not executable by any app role, so staff reach it only through this one
--       guarded entry point in the exposed public schema.
-- WHAT: public.run_stall_detector_now() returns builder.stall_runs (the run row).
--       PostgREST: POST /rest/v1/rpc/run_stall_detector_now (no arguments).
--       1. FIRST statement: unless (select private.is_staff()), raise 'forbidden'
--          with errcode 42501 (PostgREST -> 403). Nothing runs before the check, so a
--          builder user cannot start a run, take the advisory lock or log a row.
--       2. v_run_id := private.run_stall_detector('manual'), then the run row is read
--          by id in a SEPARATE statement and returned. Not a single
--          `select ... where id = private.run_stall_detector(...)`: in one statement
--          the volatile call would be evaluated per scanned row (a run per existing
--          row) and the scan's READ COMMITTED snapshot, taken before the call, would
--          not see the new row. A later statement in the same transaction sees it.
--       Rights: security definer (owner postgres) because private.run_stall_detector
--       is revoked from authenticated; set search_path = ''; names schema-qualified;
--       no arguments, so there is no caller input to validate. Execute revoked from
--       public and anon, granted to authenticated only; the staff check is inside.
--       A failed detector run is not an error here: the 'failed' run row is returned
--       (ADR-005), so the caller sees status and error_message.
-- ROLLBACK: drop function if exists public.run_stall_detector_now();

create or replace function public.run_stall_detector_now()
returns builder.stall_runs
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_run_id uuid;
  v_run    builder.stall_runs;
begin
  if not (select private.is_staff()) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  v_run_id := private.run_stall_detector('manual');

  select r.* into strict v_run
  from builder.stall_runs r
  where r.id = v_run_id;

  return v_run;
end;
$$;

comment on function public.run_stall_detector_now() is
  'Staff-only "Run now" (ADR-001): raises 42501 unless private.is_staff(), then runs private.run_stall_detector(''manual'') and returns the builder.stall_runs row (failed runs included).';

revoke execute on function public.run_stall_detector_now() from public, anon;
grant execute on function public.run_stall_detector_now() to authenticated;
