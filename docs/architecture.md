# Stall Watch — Architecture Notes

Status: proposed for the trial. Each decision is an ADR; change one only with a new ADR below it.

## Components
```
Browser ──► Next.js on Vercel (Server Components + Server Actions, @supabase/ssr, publishable key)
                │  every query runs as the signed-in user
                ▼
        Supabase Postgres (RLS is the wall)
          public   : orgs, users, memberships                (identity)
          builder  : projects, project_slots, selections, selection_history,
                     alerts, stall_runs, stall_episodes, v_project_stall, v_projects
          private  : current_user_org_ids(), is_staff(), touch_updated_at(),
                     run_stall_detector(text)               (not exposed over the API)
          pg_cron  : daily job ──► private.run_stall_detector('scheduled')
        Staff "Run now" ──► public.run_stall_detector_now() ──► private.run_stall_detector('manual')
```

## ADR-001 Detector runs on pg_cron (Option A)
Decision: pg_cron calls a `security definer` function; staff Run now calls a guarded RPC that calls the same function.
Why: no shared secret, no HTTP route to attack, nothing to rotate; the function is revoked from `authenticated` and `anon`.
Gave up: the schedule and logic are invisible from the app's runtime; no HTTP-level retry; depends on the `pg_cron` extension being enabled (documented in SETUP.md and the migration header).
Rejected: Vercel Cron with `CRON_SECRET` (needs a hand-inserted hash table, plus daily-only schedules on Hobby).

## ADR-002 Authorization lives entirely in Postgres; no service-role key
Decision: all queries run as the user; RLS enabled and forced on every `public` and `builder` table.
Why: builders and staff share the `authenticated` role, so UI checks protect nothing.
Rejected: a server API using the service-role key (bypasses every rule).

## ADR-003 Composite foreign keys as the tenant guard
Decision: every child row carries `org_id` and references `(parent_id, org_id)` of its parent.
Why: an `org_id`-only policy lets a user attach a row to another org's parent while tagging it with their own org.

## ADR-004 Stall episodes for de-duplication
Decision: `builder.stall_episodes` unique on `(project_id, quiet_since)`; alerts are created only for episodes inserted in this run; alerts also unique on `(episode_id, user_id)`; an advisory lock serializes runs.
Why: a time window alone is not idempotency. New builder activity moves `quiet_since`, so a re-stall is a new episode and a new alert.

## ADR-005 Failure logging via PL/pgSQL inner block
Decision: insert the run row first, do the work inside `begin ... exception when others then ... end`, and mark the row failed with `sqlerrm` in the handler.
Why: a log row in the same transaction as failing work rolls back with it; the inner block undoes only the half-finished work.

## ADR-006 Live stall badge from security_invoker views
Decision: `v_project_stall` computes quiet-since from `selection_history.actor_kind = 'builder'` and `selection_phase_started_at`; `v_projects` adds org name and counts.
Why: staff edits touch `selections.updated_at` (Unit 7C trap). The badge must reflect the rule right now; alerts are only created by runs.

## ADR-007 History via definer trigger, actor_kind computed in the database
Decision: a `security definer` trigger on `selections` writes `selection_history`; `actor_kind` is `builder` when the caller is a member of the project's org, else `staff` (also when there is no `auth.uid()`).
Why: clients must not be able to forge history or activity; definer rights here are deliberate and stated in the migration header.

## ADR-008 Alerts: recipient-only with a column grant
Decision: policies `user_id = auth.uid()`; `revoke update ... ; grant update (read_at)`; inserts only from the detector.
Why: RLS cannot limit columns; the grant makes "mark read changes nothing else" mechanical.

## ADR-009 Schema layout
public = identity; builder = business and detector tables (so `/detector` can read the run log under a staff-only policy); private = helpers and internals, never exposed.

## ADR-010 UI stack: Tailwind CSS v4, shadcn/ui and motion (STW-45)
Decision: style with Tailwind CSS v4 (PostCSS plugin, CSS-first tokens in `src/app/globals.css`), build primitives from shadcn/ui (Radix base, copied into `src/components/ui/` and customised), animate with the `motion` library in client components only and with CSS for server-rendered entry motion. Self-host fonts with `next/font`. Add a static public landing page at `/` (the proxy lists it as public; it reads no data).
Why: the product needed to look premium for builders; owning the component source (shadcn) lets the design be unique instead of a theme on a black-box library; Tailwind tokens keep one source of truth; CSS entry motion keeps content visible before hydration.
Gave up: a larger dependency set (Radix, class-variance-authority, lucide-react, sonner, motion); shadcn files keep the CLI's lowercase names (`button.tsx`), an accepted exception to the PascalCase rule so `shadcn add` keeps working.
Rejected: a full component kit (MUI, Chakra) — heavy runtime styling and a generic look; Framer Motion for all entry motion — server HTML would start invisible until JS loads.
Unchanged: authorization stays in Postgres (ADR-002); hiding a nav link is convenience only.

## Open items
See the workbook's Gaps & Assumptions tab (G-01 to G-20), especially G-01 (org_type value), G-04 (meaning of "flagged"), G-11 (AI-assistance policy).
