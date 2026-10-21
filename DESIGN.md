Candidate: Jocarl Basco
Hours spent: TBD (candidate to fill in before submission)

# Stall Watch — Design Note

## Problem
Home builders choose finishes (slots such as "Kitchen – Countertop") per project. Projects go quiet and nobody notices until a deadline slips. Builder admins need an in-app alert when a project stalls; Reverie3D staff need to see every builder and whether the detector ran. Builders share one database, so one builder must never read or change another's data.

## Goals and non-goals
- Builders sign in (email + password), see only their org's projects, slots and alerts, and set, change or clear selections; every change is recorded in history.
- A scheduled detector flags a `selection_phase`, non-archived project with no builder activity for 7 days and alerts that org's admins once per stall episode. Staff see all builders and the run log (failures too) and can start a run.
- Tenant isolation is proven by SQL tests (`supabase/tests/`).
- Non-goals: email/SMS, SSO, invitations, self-serve orgs, visual polish, any service-role code path.

## Data and permissions
- `public` holds identity (`orgs`, `users` mirrored from `auth.users`, `memberships`); `builder` holds business tables (`projects`, `project_slots`, `selections`, `selection_history`, `alerts`, `stall_runs`, `stall_episodes`) and `security_invoker` views `v_project_stall`, `v_projects`; `private` (not exposed) holds helpers, trigger functions and the detector.
- Every child row carries `org_id` and references `(parent_id, org_id)` of its parent.
- All queries run as the signed-in user with the publishable key. RLS is enabled **and forced** on every `public` and `builder` table (`rls_forced.sql`); every write policy has `with check`.
- Alerts are recipient-only; only `read_at` is updatable (column grant). `selection_history` is append-only, written only by a definer trigger that computes `actor_kind` (builder/staff) in the database, so staff edits can't hide a stall.

## Stall detector
- **Where it runs:** in Postgres, as `private.run_stall_detector(p_trigger)`. The pg_cron job `stall-detector-daily` calls it at `0 18 * * *` UTC (02:00 Asia/Manila); staff "Run now" on `/detector` calls the RPC `public.run_stall_detector_now()`. No HTTP route, Vercel Cron or shared secret.
- **How it gets permission:** `security definer`, owned by `postgres` (bypasses RLS), `search_path = ''`, schema-qualified names; execute revoked from `public`, `anon`, `authenticated`, so only the cron job (as `postgres`) and the RPC reach it. The RPC is a no-argument definer whose first statement raises `42501` unless `private.is_staff()`. No service-role key exists in code, `.env`, Vercel or CI.
- **What stops duplicates:** `pg_advisory_xact_lock(2026032)` serializes overlapping runs (`detector_concurrency.sh`). Episodes are unique on `(project_id, quiet_since)` (`stall_episodes_project_quiet_key`): re-runs insert nothing, while new builder activity moves `quiet_since`, so a re-stall is a new episode. Alerts are unique on `(episode_id, user_id)` (`alerts_episode_user_key`) and created only for episodes this run inserted; late-change alerts on `(history_id, user_id)` (`alerts_history_user_key`).
- **Failures:** the run row is inserted first and the work runs in an inner `begin … exception` block, so a failure rolls back partial work, marks the run `failed` with the error, and the log row still commits.
- **What I gave up:** no "closed" episode state (a recovered project's episode just stops being current); daily granularity, and a missed night (database paused/down) is not caught up; the schedule is invisible from the app and depends on pg_cron; alert text is a snapshot; Run now has no rate limit (runs just queue on the lock).

## Decisions and rejected alternatives
| Decision | Rejected | Why |
|---|---|---|
| Authorization entirely in RLS | API using the service-role key | Builders and staff share `authenticated`; UI checks protect nothing and the key bypasses every rule. |
| Composite FKs `(parent_id, org_id)` | `org_id`-only policies | Otherwise a row can hang off another org's parent. |
| pg_cron + definer function | Vercel Cron + `CRON_SECRET` route | No secret or public route; Hobby cron is daily anyway. |
| Episodes keyed by `quiet_since` | De-dup by time window | A window is not idempotency. |
| Activity = `actor_kind = 'builder'` history | `selections.updated_at` | Staff edits would hide a stall. |

Detail: `docs/architecture.md` (ADR-001 to ADR-009).

## Rules I bent
- **CI is run locally, not on GitHub.** `ci.yml` has an app job and a database job (STW-37), but Actions won't start on this private repo (billing; `docs/actions/github-actions-billing.md`). Every merge was gated on the same steps run locally (`npm run ci`, `npm run test:db`, `npm run check:migrations`); the database job was replayed once on a scratch Supabase stack.
- **History immutability disabled inside one test.** `detector_scenarios.sql` disables `trg_selection_history_immutable` for one backdating update to simulate a re-stall, re-enables it, and rolls the transaction back. No migration or app path does this.
- **`z.guid()` instead of `z.uuid()`.** The provided seed ids (e.g. `…-00000000a014`) are valid Postgres uuids but not RFC 4122 versions, which `z.uuid()` rejects. The boundary checks shape; RLS decides access.
- **Not-found and "Staff only" pages return HTTP 200.** Not-found renders after streaming starts; a real 403 needs `experimental.authInterrupts` in the shared config. Neither page shows data.
- **`read_at` uses the app server's clock** (`new Date()`), since PostgREST can't send `now()`; `read_at >= created_at` holds unless that clock lags the database.

## What I cut
- Pagination and sorting (project list, alerts; the run log shows the latest 50).
- Global nav and an unread badge: `/alerts` and `/detector` are reached by URL and link back to `/projects`.
- A due-soon/overdue warning; the due date is shown raw.
- Email/SMS, and per-org settings (the 7-day window is one constant in `private.stall_window()`; late-change alerts can't be turned off).
- Locking archived projects: they stay editable, and an archived project in `revision` still raises late-change alerts.
- A staging database (Vercel Preview uses the production Supabase project), a post-login return path, and app-level rate limits (Supabase Auth's apply).

## What I'd build next
A **late-change alert**, **built in STW-42**: when a builder changes or clears a selection on a project in `revision` (e.g. Lot 15), **every staff user** gets one `late_change` alert (`org_id` = the builder org), raised by a definer AFTER INSERT trigger on `selection_history` and de-duplicated on `(history_id, user_id)`. A builder `set`, staff changes and other statuses raise nothing. Details: [docs/tickets/STW-42.md](docs/tickets/STW-42.md); the original STW-41 proposal (builder admins, `revision`/`complete`) and the differences: [docs/what-id-build-next.md](docs/what-id-build-next.md). After that: a staging project for Preview, and a closed episode state so staff can see recoveries.
