# STW-36 — Detector scenario tests

- **Jira:** https://stratyge.atlassian.net/browse/STW-36
- **Branch:** `test/stw-36/detector-scenarios`

## Overview
End-to-end scenario tests for the stall detector (`private.run_stall_detector`, STW-32) and the staff "Run now" RPC (STW-33), against a seed-shaped synthetic fixture.

Acceptance criteria:
- First-run counts, immediate re-run (0 new), new stall after builder activity plus backdating (1 new alert).
- Failure injection leaves a failed run with no partial alerts; two concurrent sessions create one set of alerts.
- Builder, anon and direct private-function calls are rejected; staff activity on Unit 7C leaves it stalled.

## Implementation details
Tests only; no migration, no app code. No detector bug was found.

- `supabase/tests/detector_scenarios.sql`: one rolled-back transaction.
  - **Baseline run first.** Before the fixture exists, one detector run gives every project the shared DB already has stalled its episode. So every later episode or alert belongs to this fixture, and the counts are exact (`projects_flagged = base + 3`, `alerts_created = 3`, and so on) whatever state the shared DB is in. The advisory lock that run takes is held until `ROLLBACK`, so no other detector run can interleave.
  - **Fixture:** copies of the nine seed shapes (`DS Lot 12/14/15/9/3`, `DS Unit 4B/5A/7C/2A`, ids `...36xx`/`...37xx`, `ds.*@example.test`). Org A has exactly one admin plus one member, org B one admin, and the staff user is admin of a staff org. `DS Lot 3` is archived while still in `selection_phase` and long quiet, so archiving is what keeps it unflagged.
  - **Unit 7C trap through the real path:** the staff user edits a 7C selection as `authenticated` (RLS, history trigger). That logs `actor_kind = 'staff'` and refreshes `selections.updated_at`, but the project stays stalled and its episode's `quiet_since` is the last builder activity (9 days ago).
  - **Recovery through the real path:** the builder admin edits a `DS Lot 12` selection, which logs builder activity at `now()`.
  - **Time travel:** to re-stall, the fixture's own history row is backdated to 8 days ago. `selection_history` is append-only, so `trg_selection_history_immutable` is disabled for that one update and re-enabled, all inside the rolled-back transaction.
  - **Failure injection:** a throw-away `before insert` trigger on `builder.alerts` raises after the run inserted its episodes (the STW-32 design: no backdoor in the function).
- `supabase/tests/detector_concurrency.sh`: two real concurrent sessions. One psql transaction can't hold two connections, so this is a script. It commits a tiny fixture (`DC Quiet`, ids `...38xx`, `dc.admin@example.test`, one admin) so that both sessions can see it. Session A runs the detector (scheduled) and holds the lock until it sees session B waiting in `pg_locks`. Session B waits until A holds the lock, checks that `pg_try_advisory_xact_lock(2026032)` is false, then runs the detector (manual), which blocks. A commits, B resumes, sees A's episode and creates nothing. The two sessions coordinate through `pg_locks` / `pg_stat_activity` (clearing the stats snapshot on each poll), so the test doesn't depend on client timing. An `EXIT` trap deletes the fixture and everything runs A and B created (by run id, including any episodes or alerts for pre-existing stalled projects), and the script pre-cleans leftovers from an interrupted run. The DB is left as found: run, episode and alert counts were checked before and after.
- `scripts/test-db.sh` now also runs `supabase/tests/*.sh` after the `.sql` files, with the same `DB_URL` / `DB_CONTAINER` rules.

## API changes
None.

## Database changes
None. No migration.

## Dependencies on other tickets
Uses STW-26 (stall views), STW-31 (detector tables), STW-32 (detector function) and STW-33 (run-now RPC), all merged.

## Known limitations
- The design has no "closed" episode state. When a project recovers, its open episode just stops being current: the detector no longer flags the project. The next stall has a new `quiet_since`, so it is a new episode with new alerts. The tests assert exactly that.
- `detector_concurrency.sh` briefly commits rows. If the DB has stalled projects with no episode yet, run A creates their episodes and alerts. They are visible to other sessions for a few seconds, then deleted by run id. On the shared stack today every stalled seed project already has its episode, so in practice only the fixture rows appear.
- `docker exec` latency on this machine is about 15 s per call, so the concurrency script takes about 2 minutes locally. Each in-DB wait is capped at about 180 s.
- The `scheduled` trigger is exercised by calling `private.run_stall_detector('scheduled')` as `postgres`, which is what pg_cron will do. The cron job itself is STW-34.

## Testing notes
`npm run test:db`: all files pass, including:
```
== supabase/tests/detector_scenarios.sql
  PASS: baseline run absorbed 3 pre-existing stalled project(s) on this DB
  PASS: Unit 7C trap armed -> staff edit logged as staff, updated_at = now(), project still stalled (quiet 9 days)
  PASS: builder admin / member / other-org admin / anon -> RPC 42501; direct private.run_stall_detector as admin / member / staff / anon -> 42501; no run logged
  PASS: injected failure -> run logged as failed with error_message, counts 0; no episode or alert left behind
  PASS: first run -> flagged base+3, 3 alerts: DS Lot 12 (ana), DS Unit 4B + DS Unit 7C (bruno); mia/staff 0; Lot 14/15/9/3, Unit 5A/2A untouched; 7C episode at last builder activity
  PASS: immediate re-run (manual, staff RPC) -> succeeded, still flags base+3, 0 new episodes, 0 new alerts
  PASS: recovery -> builder edit logged as builder, DS Lot 12 not stalled, next run flags base+2 and creates nothing (the old episode is no longer current)
  PASS: re-stall (backdated builder activity) -> manual run opens a 2nd DS Lot 12 episode and exactly 1 new alert (ana), member none
  PASS: stall_runs logs 4 scheduled (1 failed) + 2 manual runs from this test; staff reads all 6, builder admin 0
  PASS: seed Unit 7C (read-only) -> stalled despite the recent staff edit
== supabase/tests/detector_concurrency.sh
  PASS: session B could not take the detector lock (try_lock false) and waited on it while session A's run held it
  PASS: two concurrent sessions -> run A (scheduled) created the episode + 1 alert, run B (manual) waited, then created 0; DC Quiet has exactly 1 episode and 1 alert
```
Shared-DB counts (stall_runs / stall_episodes / alerts) were the same before and after the concurrency script (17 / 3 / 3), and no `dc.*` user remains.

## Follow-up tasks
- The CI database job (seed + SQL tests) should run `npm run test:db` with `DB_URL`; the `.sh` scenario then needs `psql` on the runner.
