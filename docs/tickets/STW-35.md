# STW-35 — Detector console page (staff only)

- **Jira:** https://stratyge.atlassian.net/browse/STW-35
- **Branch:** `feat/stw-35/detector-console`

## Overview
Staff see the stall detector's run history at `/detector` and can start a run with "Run now". Builders get a "Staff only" page with no run data.

Acceptance criteria:
- Table lists started, finished, trigger, projects flagged, status and error, newest first; failed runs show the error.
- Run now calls the RPC and refreshes with the new row.
- Given Ana opens /detector, then no data and the RPC is rejected (verified in the database, not just hidden in the UI).

## Implementation details
New feature folder `src/features/detector/` and thin route `src/app/detector/page.tsx` (Suspense around a Server Component).

- `queries.ts` → `getDetectorConsole()`: `requireUser()` (STW-27), then a staff check, then (staff only) `builder.stall_runs` ordered `started_at desc, id desc`, limit `RUN_HISTORY_LIMIT` (50). Returns `ok | not-allowed | error`; rows are parsed with zod (`stallRunRowSchema`).
- **Staff check (UX only):** `public.memberships` with an inner join on `public.orgs` filtered to `org_type = 'staff'` for the caller's `user_id`, under RLS. This reads from the database, not from the JWT or user metadata, and needs no migration. It only decides what the page renders. A non-staff user gets the "Staff only" page, and the history query isn't run at all.
- **The real walls are in the database:** `p_stall_runs_select` (`private.is_staff()`) returns no rows to non-staff, and `public.run_stall_detector_now()` raises `42501` as its first statement unless `is_staff`.
- `actions/run-detector-now.ts` (`"use server"`): takes no input, re-checks the session (`getCurrentUser()`), and calls `supabase.rpc("run_stall_detector_now")` (POST `/rest/v1/rpc/run_stall_detector_now`) as the signed-in user. Errors map to generic messages: `42501` → "You are not allowed to run the detector.", anything else → "Could not run the detector. Please try again." No DB text reaches the browser. On success it calls `revalidatePath("/detector")`, so the new row appears at the top of the table without a reload, and it returns the run's status (a `failed` run is a normal result, shown with its error in the table).
- `components/DetectorConsole.tsx` renders the table (Started, Finished, Trigger, Status, Projects flagged, Alerts created, Error; UTC times). `components/RunNowButton.tsx` is a client component that uses `useTransition` and copies STW-30's `MarkReadButton` pattern.
- Client-safe result type and messages live in `run-detector-now-state.ts`, because a `"use server"` file may only export async functions. This is the same split as STW-30.

## API changes
- New page `/detector`.
- New Server Action `runDetectorNow()`. No new database API; it uses the STW-33 RPC.

## Database changes
None.

## Dependencies on other tickets
Uses STW-31 (`builder.stall_runs`), STW-32 (detector), STW-33 (`run_stall_detector_now` RPC), STW-18 (`is_staff` / RLS helpers) and STW-27 (SSR auth, `requireUser`, `createClient`), all merged.

## Known limitations
- History shows the latest 50 runs only (no pagination).
- The "Staff only" page returns HTTP 200. `forbidden()` / 403 would need `experimental.authInterrupts` in the shared `next.config.ts`.
- No rate limit on Run now (same as STW-33). Runs serialize on the detector's advisory lock and create no duplicate alerts.
- No global nav link to `/detector` yet. A later ticket adds the nav.

## Testing notes
- `npm run ci` (lint, typecheck, build) passes; `npm run test:db` passes (no SQL changes).
- E2E with Playwright against `next start` on port 3035, signing in through the real `/login` form (script kept in the session scratchpad, not committed). 32/32 checks passed:
  - staff: the column headers match. 17 rows = the DB count, newest first. A synthetic `failed` run (inserted for the test and deleted afterwards) shows status `failed` and its error text.
  - staff, Run now: one Server Action POST. The message reads "Run finished.", and a new `manual/succeeded` row appears on top without a reload; it matches the DB's newest row. The manual run count went from 3 to 4. This added one real manual run on the shared local DB; it created no alerts because the detector is idempotent.
  - ana, bruno and mia: each sees "Staff only", with no table, no rows, no Run now button and no run data in the HTML.
  - DB rejection, tested directly with each user's own token and the publishable key: ana and bruno `POST /rest/v1/rpc/run_stall_detector_now` → `403 {"code":"42501","message":"forbidden"}`; `GET builder.stall_runs` → `200 []`. Anon RPC → `401` (42501). The run count didn't change.

## Follow-up tasks
- Add `/detector` to the global nav, shown to staff only (UX), when the nav ticket lands.
- Once `src/types/database.types.ts` is generated, type the RPC and `stall_runs` rows instead of parsing them as untyped data.
