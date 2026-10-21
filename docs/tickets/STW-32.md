# STW-32 — private.run_stall_detector with failure logging and locking

- **Jira:** https://stratyge.atlassian.net/browse/STW-32 (blueprint US-024)
- **Branch:** `feat/stw-32/stall-detector-function`

## Overview
As a Builder A admin, I want an alert when my project stalls so that I act before the due date. This ticket ships the detector function that pg_cron (STW-34) and the staff "Run now" RPC (STW-33) will call.

Acceptance criteria:
- Given the seed, first run flags 3 projects and creates alerts: Ana 1, Bruno 2, Mia 0, staff 0.
- Given a second immediate run, zero new episodes and zero new alerts; run still logged as succeeded.
- Alert text matches: 'Lot 12 has had no builder activity for 7 days. 3 slots are still empty.'
- Given a forced error inside the work block, the run row is failed with error_message and no partial alerts remain.
- security definer, search_path = '', pg_advisory_xact_lock taken, execute revoked from public, anon and authenticated.

## Implementation details
Migration `20261020160000_stall_detector_function.sql`, `private.run_stall_detector(p_trigger text) returns uuid` (the run id):
1. `p_trigger` must be `scheduled` or `manual`; anything else (including null) raises `22023` before any row is written.
2. `pg_advisory_xact_lock(2026032)`: one fixed key, so runs serialize; held until the caller's transaction ends. An overlapping run waits, then sees the first run's committed episodes and creates nothing twice (ADR-004).
3. The `builder.stall_runs` row (`running`) is inserted **outside** the inner block (ADR-005).
4. Inner `begin … exception when others … end` block:
   - guard: raises if the function owner lacks `BYPASSRLS` (the views are `security_invoker`; without bypass the run would silently find nothing, now it is logged as failed instead);
   - loops over `builder.v_projects where is_stalled` — the STW-26 rule is reused, not re-implemented;
   - `insert into builder.stall_episodes … on conflict (project_id, quiet_since) do nothing returning id`;
   - only when this run inserted the episode: one `stalled` alert per `admin` membership of the project's org (`on conflict (episode_id, user_id) do nothing`). Members (Mia) get none; staff are admins of the staff org, not the builder org, so they get none;
   - run row → `succeeded`, `finished_at = now()` (same transaction clock as `started_at`).
5. Handler: the inner block's savepoint rollback removes every episode/alert of this run; the run row → `failed`, `finished_at = now()`, counts 0, `error_message = left(sqlerrm, 2000)` (column check is ≤ 2000, so a long message cannot make the handler fail). The run id is **returned, not re-raised**, so the failed row commits.

Decisions:
- **Message**: `'<name> has had no builder activity for <N> days. <M> slots are still empty.'`, N = `floor(epoch(now() - quiet_since) / 86400)`, M = `v_projects.empty_slots`. Singular forms `1 day` / `1 slot is`; `1 day` is unreachable with the 7-day window. `0 slots are still empty.` is kept as is.
- **projects_flagged** = stalled projects seen by this run (a re-run of the seed still reports 3, with 0 new alerts); **alerts_created** = alerts inserted by this run (G-04).
- **Forcing an error in tests** needs no production backdoor: `supabase/tests/stall_detector.sql` creates a throw-away `before insert` trigger on `builder.alerts` inside its rolled-back transaction, so the error happens after episodes were inserted. No GUC or flag in the function changes its behaviour. Rejected: a `stall_watch.force_detector_error` GUC (any session can set a custom GUC) and a shipped no-op hook function.
- Security: `security definer`, `set search_path = ''`, all names schema-qualified, owner `postgres`, execute revoked from `public`, `anon`, `authenticated`.

## API changes
None. The function is in `private` (not exposed) and not executable by app roles. STW-33 adds the staff-guarded RPC.

## Database changes
One function. Rollback (header + `MIGRATIONS.md`): `drop function if exists private.run_stall_detector(text);`

## Dependencies on other tickets
Blocked by STW-31 (`stall_runs`, `stall_episodes`, `alerts.episode_id`) and STW-26 (`v_projects`, `stall_window()`), both merged. Blocks STW-33 (staff RPC + `/detector` Run now) and STW-34 (pg_cron schedule).

## Known limitations
- Relies on the owner (`postgres`) having `BYPASSRLS` (true locally and on Supabase); if not, every run is logged `failed` with an explicit message rather than succeeding with zero projects.
- The advisory lock key `2026032` is a fixed constant; another feature taking the same key would serialize with the detector.
- Alerts snapshot the text at run time (days and empty slots are not updated later).
- The exact AC text depends on the seed's relative clock: Lot 12 reads `7 days` while the seed was loaded less than a day ago (the test checks the exact string then, the formula otherwise, with a NOTE).

## Testing notes
`supabase/tests/stall_detector.sql` (rolled back; synthetic fixtures `...32xx`, `sd.*@example.test`):
1. Hygiene: `prosecdef`, `proconfig = {search_path=""}`, `prosrc` contains `pg_advisory_xact_lock(`, returns uuid, no execute for public/anon/authenticated, owner bypasses RLS.
2. Invalid triggers (`cron`, `''`, `MANUAL`, null) raise 22023 and write no run row.
3. Seed + linked users (skipped with a NOTICE otherwise): run 1 succeeded, flagged 3, alerts 3: Ana 1 (Lot 12), Bruno 2 (Unit 4B, Unit 7C), Mia 0, staff 0; exact Lot 12 text; advisory lock 2026032 held in `pg_locks`; via `request.jwt.claims`: Ana sees 1 alert, Mia 0, Bruno 2, staff 0; run log staff-only. Run 2: succeeded, 0 new episodes, 0 new alerts.
4. Forced error (throw-away trigger raising a 3000-char message): run row `failed`, `finished_at` set, `error_message` = sqlerrm cut to 2000, 0 episodes/alerts from that run.
5. Synthetic: episodes only for the 2 stalled projects; messages `SD Quiet A … 10 days. 1 slot is still empty.` and `SD Phase B … 7 days. 3 slots are still empty.`; member/staff none; RLS recipients only; immediate re-run 0 new; re-stall (builder activity moves quiet_since) → new episode + 1 new alert.

After the run the shared DB still has 0 runs / episodes / alerts.

## Follow-up tasks
- STW-33: staff-guarded RPC calling `private.run_stall_detector('manual')`; `/detector` run history.
- STW-34: `pg_cron` job calling `private.run_stall_detector('scheduled')`.
