Candidate: Jocarl Basco
Hours spent: 0

# Stall Watch — Design Note

## Problem
Home builders choose finishes (slots such as "Kitchen – Countertop") for each project. Projects go quiet and nobody notices until a deadline slips. Builder admins need an in-app alert when a project has stalled, and Reverie3D staff need to see every builder and whether the detector actually ran. Several builders share one database, so one builder must never read or change another builder's data.

## Goals
- Builders sign in (email + password) and see only their own org's projects, slots and alerts.
- Builders set, change and clear a selection per slot; every change is recorded in history.
- A scheduled detector marks projects with no builder activity for the stall window as stalled and alerts that org's admins, once per stall episode.
- Staff see all builders, the run history (including failures) and can trigger a run.
- Tenant isolation is proven by SQL tests that run in CI.

## Non-goals
- Email/SMS notifications, SSO, magic links, invitations or self-serve org creation.
- Visual polish; plain HTML with minimal styling.
- Any server path using the service-role key.

## Planned data
- `public` (identity): `orgs`, `users` (mirrored from `auth.users` by trigger), `memberships` (user, org, role).
- `builder` (business): `projects`, `project_slots`, `selections`, `selection_history`, `alerts`, `stall_runs`, `stall_episodes`; views `v_project_stall`, `v_projects` (`security_invoker`).
- `private` (never exposed): `current_user_org_ids()`, `is_staff()`, `touch_updated_at()`, `run_stall_detector(text)`.
- Every child row carries `org_id` and references `(parent_id, org_id)` of its parent. Mutable tables have `created_at`, `updated_at`, `lock_version`; statuses are `text` + `check`; uuid primary keys.

## Planned permissions
- All queries run as the signed-in user with the publishable key; RLS is enabled **and forced** on every `public` and `builder` table, and every write policy has `with check`.
- Builders: read and write rows of orgs they belong to. Staff: read everything, and run the detector through a guarded RPC.
- Alerts: only the recipient can read them, and only `read_at` can be updated (column grant).
- `selection_history` is written only by a `security definer` trigger, which computes `actor_kind` (builder vs staff) in the database so clients cannot forge activity.

## Decisions and rejected alternatives
| Decision | Rejected | Why |
|---|---|---|
| Authorization entirely in Postgres (RLS), no service-role key | Server API with service-role key | Builders and staff share the `authenticated` role; UI checks protect nothing, and the service key bypasses every rule. |
| Composite FKs `(parent_id, org_id)` as the tenant guard | `org_id`-only policies | Without it a user can attach a row to another org's parent while tagging it with their own org. |
| Detector on `pg_cron` calling a `security definer` function; staff "Run now" via a guarded RPC | Vercel Cron + `CRON_SECRET` HTTP route | No shared secret or public route to attack; Hobby cron is daily-only. Cost: schedule invisible from the app, depends on the extension. |
| Stall episodes unique on `(project_id, quiet_since)`, alerts unique on `(episode_id, user_id)`, advisory lock per run | De-duplicate by time window | A window is not idempotency; new activity moves `quiet_since`, so a re-stall is a new episode. |
| Run row inserted first, work in an inner `begin … exception` block that marks the run failed | Log in the same transaction | A log row in the failing transaction rolls back with it. |
| Activity computed from `selection_history.actor_kind = 'builder'` | `selections.updated_at` | Staff edits touch `updated_at` and would hide a stall. |
| Three schemas: `public` identity, `builder` business, `private` internals | Everything in `public` | Keeps internals off the API and lets `/detector` read the run log under a staff-only policy. |

Detail and consequences: `docs/architecture.md` (ADR-001 to ADR-009).
