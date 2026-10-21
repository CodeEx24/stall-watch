#!/usr/bin/env bash
# STW-36: two CONCURRENT detector sessions create one set of alerts.
#
# Needs two connections, so it cannot live in a single-transaction .sql file. Run by
# scripts/test-db.sh (same DB_URL / docker container rules as the .sql tests).
#
#   session A: run_stall_detector('scheduled') -> holds advisory lock 2026032 ->
#              waits until it SEES session B blocked on that lock -> commits
#   session B: pg_try_advisory_xact_lock(2026032) must be false while A holds it, then
#              run_stall_detector('manual') blocks, resumes after A commits, sees A's
#              episode and creates nothing
#   check:     the fixture project has exactly 1 episode and 1 alert (its org has one
#              admin); run A alerts_created >= 1, run B succeeded with 0 alerts / 0 episodes
#
# The fixture (ids ...38xx, dc.admin@example.test) must be COMMITTED so both sessions
# see it. Everything this script commits (fixture, both runs, and every episode / alert
# those two runs created, including any for pre-existing stalled projects on the DB) is
# deleted again by run id in an EXIT trap, so the DB is left as it was found.
set -euo pipefail

CONTAINER="${DB_CONTAINER:-supabase_db_stall-watch}"
ORG='00000000-0000-0000-0000-0000000038a0'
ADMIN='00000000-0000-0000-0000-0000000038a1'
PROJECT='00000000-0000-0000-0000-000000003801'
TMP="$(mktemp -d)"
RUN_A=''
RUN_B=''

sql() {  # sql < file-or-heredoc ; prints unaligned tuples
  if [ -n "${DB_URL:-}" ]; then
    psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 -f -
  else
    docker exec -i "$CONTAINER" psql -U postgres -X -q -At -v ON_ERROR_STOP=1 -f -
  fi
}

cleanup_sql() {  # deletes the fixture and everything runs A / B created
  local runs="'00000000-0000-0000-0000-000000000000'"
  [ -n "$RUN_A" ] && runs="$runs,'$RUN_A'"
  [ -n "$RUN_B" ] && runs="$runs,'$RUN_B'"
  cat <<SQL
create temp table dc_runs as
  select id from builder.stall_runs where id in ($runs)
  union select run_id from builder.stall_episodes where project_id = '$PROJECT';
delete from builder.alerts where project_id = '$PROJECT'
   or episode_id in (select id from builder.stall_episodes where run_id in (select id from dc_runs));
delete from builder.stall_episodes where project_id = '$PROJECT' or run_id in (select id from dc_runs);
delete from builder.stall_runs where id in (select id from dc_runs);
delete from builder.projects where id = '$PROJECT';
delete from public.memberships where org_id = '$ORG';
delete from public.orgs where id = '$ORG';
delete from auth.users where id = '$ADMIN';
drop table dc_runs;
SQL
}

cleanup() {
  { echo 'begin;'; cleanup_sql; echo 'commit;'; } | sql > /dev/null \
    || echo "  WARN: cleanup failed; fixture ids ...38xx may remain"
  rm -rf "$TMP"
}
trap cleanup EXIT

# one connection: leftovers of an interrupted earlier run, then the committed fixture
{ echo 'begin;'; cleanup_sql; cat <<SQL; } | sql > /dev/null
insert into auth.users (instance_id, id, aud, role, email) values
  ('00000000-0000-0000-0000-000000000000', '$ADMIN', 'authenticated', 'authenticated', 'dc.admin@example.test');
insert into public.orgs (id, name, org_type) values ('$ORG', 'DC Builder', 'builder');
insert into public.memberships (user_id, org_id, role) values ('$ADMIN', '$ORG', 'admin');
insert into builder.projects (id, org_id, name, status, selection_phase_started_at)
  values ('$PROJECT', '$ORG', 'DC Quiet', 'selection_phase', now() - interval '10 days');
commit;
SQL

# Both sessions start at once and coordinate through pg_locks (no client-side polling:
# connection start-up can be slow). pg_stat_activity is snapshotted per transaction,
# so each poll clears the snapshot first. Each wait is capped at ~180 s.

# session A: run, then hold the lock until B is seen waiting for it
sql > "$TMP/a.out" 2>&1 <<'SQL' &
set application_name = 'stw36_conc_a';
begin;
select 'RUN_A=' || private.run_stall_detector('scheduled');
do $$
declare
  seen boolean := false;
begin
  for i in 1..1800 loop
    perform pg_stat_clear_snapshot();
    seen := exists (select 1 from pg_locks l join pg_stat_activity a on a.pid = l.pid
                    where a.application_name = 'stw36_conc_b' and l.locktype = 'advisory'
                      and l.classid = 0 and l.objid = 2026032 and not l.granted);
    exit when seen;
    perform pg_sleep(0.1);
  end loop;
  raise notice 'B_WAITED=%', seen;
end $$;
commit;
SQL
PID_A=$!

# session B: wait until A holds the lock, try it (must fail), then run (blocks on A)
sql > "$TMP/b.out" 2>&1 <<'SQL' &
set application_name = 'stw36_conc_b';
do $$
begin
  for i in 1..1800 loop
    perform pg_stat_clear_snapshot();
    exit when exists (select 1 from pg_locks l join pg_stat_activity a on a.pid = l.pid
                      where a.application_name = 'stw36_conc_a' and l.locktype = 'advisory'
                        and l.classid = 0 and l.objid = 2026032 and l.granted);
    perform pg_sleep(0.1);
  end loop;
end $$;
begin;
select 'TRY=' || pg_try_advisory_xact_lock(2026032);
select 'RUN_B=' || private.run_stall_detector('manual');
commit;
SQL
PID_B=$!

status_a=0; status_b=0
wait "$PID_A" || status_a=$?
wait "$PID_B" || status_b=$?
if [ "$status_a" -ne 0 ] || [ "$status_b" -ne 0 ]; then
  echo "FAIL: a session errored (A exit $status_a, B exit $status_b)"; cat "$TMP/a.out" "$TMP/b.out"; exit 1
fi

RUN_A=$(sed -n 's/^RUN_A=//p' "$TMP/a.out")
RUN_B=$(sed -n 's/^RUN_B=//p' "$TMP/b.out")
B_WAITED=$(sed -n 's/.*NOTICE: *B_WAITED=//p' "$TMP/a.out")
TRY=$(sed -n 's/^TRY=//p' "$TMP/b.out")
if [ -z "$RUN_A" ] || [ -z "$RUN_B" ]; then
  echo "FAIL: missing run ids"; cat "$TMP/a.out" "$TMP/b.out"; exit 1
fi
if [ "$TRY" != "false" ]; then
  echo "FAIL: session B acquired the detector lock while session A held it (TRY=$TRY)"; exit 1
fi
if [ "$B_WAITED" != "t" ]; then
  echo "FAIL: session A never saw session B waiting on the detector lock"; cat "$TMP/a.out" "$TMP/b.out"; exit 1
fi
echo "PASS: session B could not take the detector lock (try_lock false) and waited on it while session A's run held it"

sql <<SQL
do \$\$
declare
  a builder.stall_runs;
  b builder.stall_runs;
begin
  select * into a from builder.stall_runs where id = '$RUN_A';
  select * into b from builder.stall_runs where id = '$RUN_B';
  if a.status <> 'succeeded' or a.trigger <> 'scheduled' or a.alerts_created < 1 then
    raise exception 'FAIL: run A wrong: %', a;
  end if;
  if b.status <> 'succeeded' or b.trigger <> 'manual' or b.alerts_created <> 0
     or exists (select 1 from builder.stall_episodes where run_id = b.id) then
    raise exception 'FAIL: run B created episodes or alerts: %', b;
  end if;
  if (select count(*) from builder.stall_episodes where project_id = '$PROJECT') <> 1
     or (select run_id from builder.stall_episodes where project_id = '$PROJECT') <> a.id
     or (select count(*) from builder.alerts where project_id = '$PROJECT') <> 1
     or (select user_id from builder.alerts where project_id = '$PROJECT') <> '$ADMIN' then
    raise exception 'FAIL: concurrent runs did not leave exactly one episode and one alert for DC Quiet';
  end if;
  raise notice 'PASS: two concurrent sessions -> run A (scheduled) created the episode + 1 alert, run B (manual) waited, then created 0; DC Quiet has exactly 1 episode and 1 alert';
end \$\$;
SQL
