# STW-33 — Staff-guarded run-now RPC

- **Jira:** https://stratyge.atlassian.net/browse/STW-33 (blueprint US-025)
- **Branch:** `feat/stw-33/staff-run-now-rpc`

## Overview
As a staff user, I want to run the detector on demand so that I can verify fixes immediately.

Acceptance criteria:
- public.run_stall_detector_now() raises 42501 unless private.is_staff(); first lines of the body perform the check.
- Returns the run row; revoked from public and anon, granted to authenticated.
- Given Ana or anon, then forbidden; given Sam, a manual run is logged.

## Implementation details
Migration `20261020170000_run_stall_detector_now_rpc.sql`, `public.run_stall_detector_now() returns builder.stall_runs` (ADR-001):
1. First statement: `if not (select private.is_staff()) then raise exception 'forbidden' using errcode = '42501'; end if;` Nothing runs before it, so a builder cannot start a run, take the advisory lock or log a row.
2. `v_run_id := private.run_stall_detector('manual');` then `select r.* into strict v_run from builder.stall_runs r where r.id = v_run_id;` and `return v_run`.

Decisions:
- **Two statements, not one.** The brief's one-liner `return (select r from builder.stall_runs r where r.id = private.run_stall_detector('manual'))` was rejected: the volatile call sits in a `WHERE` clause, so Postgres evaluates it per scanned row (one detector run per existing run row; the lock makes them serialize but each still logs), and that scan's READ COMMITTED snapshot is taken before the call, so it would not see the new row. A later statement in the same transaction sees it.
- **Returns `builder.stall_runs`** (one row, not `setof`): PostgREST returns a JSON object.
- **A failed detector run is not an error**: the `failed` row (with `error_message`) is returned with HTTP 200 (ADR-005), so the UI can show it.
- Security: `security definer` (owner `postgres`) because `private.run_stall_detector` is revoked from `authenticated`; `set search_path = ''`; no arguments, so no caller input. Execute revoked from `public` and `anon`, granted to `authenticated`; the staff check is the authorization.

## API changes
New RPC `POST /rest/v1/rpc/run_stall_detector_now` (body `{}`):
- staff → `200` with the run row JSON (`id, trigger='manual', status, started_at, finished_at, projects_flagged, alerts_created, error_message, created_at, updated_at, lock_version`);
- signed-in non-staff → `403` `{"code":"42501","message":"forbidden"}`;
- anon (publishable key only) → `401` `{"code":"42501","message":"permission denied for function run_stall_detector_now"}`.

## Database changes
One function. Rollback (header + `MIGRATIONS.md`): `drop function if exists public.run_stall_detector_now();`

## Dependencies on other tickets
Blocked by STW-32 (`private.run_stall_detector`), STW-31 (`builder.stall_runs`) and STW-18 (`private.is_staff()`), all merged. Blocks STW-35 (`/detector` page "Run now" button and run history).

## Known limitations
- No rate limit: a staff user can start runs back to back; each serializes on the detector's advisory lock and logs a row (re-runs create no duplicate episodes or alerts).
- Every staff member (any role in the staff org) may run it; there is no finer staff permission.

## Testing notes
`supabase/tests/run_now_rpc.sql` (rolled back; synthetic fixtures `...33xx`, `rn.*@example.test`):
1. Hygiene: `prosecdef`, `proconfig = {search_path=""}`, plpgsql, returns `builder.stall_runs` (not a set), body (whitespace-normalised) begins with the is_staff check; execute: public/anon no (no PUBLIC ACL entry), authenticated yes; `private.run_stall_detector` still not executable by authenticated.
2. Builder admin, builder member and a JWT with no membership → `42501 forbidden`; anon → `42501 permission denied for function`; no run row written.
3. Staff → one run row logged and returned, `trigger = 'manual'`, `status = 'succeeded'`; staff reads it through RLS, builder admin cannot.
4. Returned row carries every run column.

E2E against the local stack (`http://127.0.0.1:55421`, real sign-in with the publishable key):
- no token → `HTTP 401` `{"code":"42501",…"permission denied for function run_stall_detector_now"}`
- ana@builder-a.test → `HTTP 403` `{"code":"42501",…"message":"forbidden"}`
- staff@stallwatch.test → `HTTP 200` `{"trigger":"manual","status":"succeeded","projects_flagged":3,"alerts_created":0,…}`; this created one real `manual` run on the shared DB (earlier runs already existed, so no new alerts).

`npm run test:db` all files pass; `npm ci && npm run ci` (lint, typecheck, build) green.

## Follow-up tasks
- STW-35: `/detector` page calls this RPC from a Server Action ("Run now") and lists `builder.stall_runs`; map `42501` to a generic message.
- Regenerate `src/types/database.types.ts` once it exists so the RPC is typed.
