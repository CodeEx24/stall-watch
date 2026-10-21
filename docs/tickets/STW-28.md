# STW-28 — /projects with live stalled badge

- **Jira:** https://stratyge.atlassian.net/browse/STW-28
- **Branch:** `feat/stw-28/projects-list`

## Overview
As a Builder A admin, I want my org's projects with a stalled badge so that I know which ones need attention.

Acceptance criteria:
- Builders see only their org's projects; staff see all with the org name.
- Each project shows empty slots, due date and a Stalled badge driven by v_projects.
- Given Ana makes one selection on Lot 12, when the page reloads, then the badge is gone.

## Implementation details
- `src/features/projects/queries.ts` — `listProjects()` (server-only): `requireUser()` (reused from `features/auth`), then `createClient().schema("builder").from("v_projects")` selecting only the columns the table renders. **No org filter in app code**: the view is `security_invoker`, so RLS on the caller decides (builders: own org; staff: all). Order: active first, archived last, then org name, project name. Errors log only the Postgres error code and return one generic message.
- `src/features/projects/schemas.ts` — `projectRowSchema` / `projectRowsSchema` (zod) parse the response at the boundary; `ProjectRow` / `ProjectStatus` types come from it. Ids use `z.guid()` because the seed ids (`…0000a012`) aren't RFC 4122 versioned, and `z.uuid()` rejects them. Statuses mirror the `builder.projects` check constraint.
- `src/features/projects/components/`
  - `ProjectList.tsx` (async server component, rendered inside `<Suspense>` as Cache Components requires) → `ProjectTable.tsx` (plain HTML table) → `StalledBadge.tsx`. `ProjectTable.module.css` holds the minimal styles, so no shared CSS changes.
  - Columns: Project (links to `/projects/[id]`, which STW-29 builds), Builder (org name, always shown: useful for staff, harmless for builders), Status, Empty slots (`empty_slots of slot_count`), Due date (`selection_due_date` as-is, so no timezone shift), Stalled (badge only when `is_stalled`).
- **Archived projects:** shown, with an "Archived" marker, dimmed, listed last. Hiding them would make Lot 3 vanish without explanation, and the view already never marks them stalled. A filter can come later if lists grow.
- **Live, never cached:** `createClient()` calls `connection()`, so the list renders at request time on every load (the route builds as Partial Prerender with only the static shell prerendered). `is_stalled` is computed by the view at query time (ADR-006).
- `src/app/projects/page.tsx` stays thin: heading, STW-27's `SignedInAs` (signed-in marker + sign out), and `ProjectList`.
- STW-27 follow-up (commits `(STW-27)`): `src/lib/supabase/client.ts` now starts with `import "client-only"` and no longer has a `"use client"` directive. With the directive a server import received a client reference and the guard never fired (found in review). `client-only 0.0.1` is pinned exactly (it was already a transitive dependency of Next). Verified: a temporary import of the browser client from server-only `queries.ts` made `npm run build` fail with `Error: 'client-only' cannot be imported from a Server Component module`. A temporary `"use client"` component importing it built with exit 0. Both probes were reverted. Also fixed the stale STW-27 follow-up line about adding `client.ts`.

## API changes
None new. Reads `GET /rest/v1/v_projects` (`Accept-Profile: builder`) as the signed-in user.

## Database changes
None (no migration). New SQL test `supabase/tests/projects_list.sql`.

## Dependencies on other tickets
Uses STW-26 (`builder.v_projects`) and STW-27 (SSR clients, `requireUser()`, sign-in wall). Links to `/projects/[id]`, which STW-29 builds; until then the link is a 404.

## Known limitations
- No pagination, sorting controls or filters. Fine at seed scale.
- Due date is shown raw (`YYYY-MM-DD`); there's no overdue highlight.
- No generated `database.types.ts` yet; the row type comes from the zod schema.

## Testing notes
- `supabase/tests/projects_list.sql` (rolled back): (1) `v_projects` has every column the page selects; (2) **AC3 on the real seed**: as the seeded Ana (`request.jwt.claims` + `set local role authenticated`), Lot 12 is stalled, she inserts one selection into an empty Lot 12 slot, and `is_stalled` goes true → false, `empty_slots` 3 → 2, and history records `actor_kind = 'builder'`. Skipped with a NOTICE when the seed is absent (CI without seed).
- `npm run test:db`: 14 files, 74 PASS, 0 FAIL. `npm ci && npm run ci` (lint, typecheck, build) green.
- Playwright E2E (`next start -p 3028`, signing in through the real `/login` form), all PASS:
  - Ana: exactly Lot 12/14/15/9/3, all "Builder A", Stalled only on Lot 12; Lot 12 shows "3 of 8" empty, due 2026-10-30, links to `/projects/00000000-0000-0000-0000-00000000a012`; Lot 3 marked Archived and listed last; signed-in marker shown.
  - Mia: same 5. Bruno: exactly Unit 2A/4B/5A/7C, all "Builder B", Stalled on Unit 4B and 7C. Staff: all 9 with the correct org name per row, Stalled on Lot 12, Unit 4B, Unit 7C.
  - **Live badge through the page:** a throwaway project `E2E STW-28 probe` was inserted for Builder A as postgres, in `selection_phase`, phase started 8 days ago, **no slots and no history**. Ana's reload shows it Stalled. Then `selection_phase_started_at` was set to now(), and after a reload the badge was gone. The probe was then deleted, and Ana's reload shows the 5 seed projects again (project count back to 9).
  - Sign out from `/projects` still works, and `/projects` is walled again afterwards.
- **Why AC3 is split this way:** a real selection writes append-only `selection_history`, which nobody can delete (not even postgres). Doing it on Lot 12, or on a probe project, would permanently change the shared stack. Lot 12 would stay un-stalled, or Builder A would gain a sixth project, which also breaks `stall_views.sql`'s "seeded Ana sees exactly 5". So the selection → `is_stalled` flip is proven on the real seed in a rolled-back SQL test. The page's live reading of `is_stalled` is proven with a probe that leaves nothing behind. Together they cover AC3: the page renders `v_projects.is_stalled` uncached on every reload, and one builder selection makes it false.

## Follow-up tasks
- STW-29 builds `/projects/[id]`. After it merges, an E2E against a disposable database can do AC3 fully through the UI (select on Lot 12, reload, badge gone).
- Consider an overdue marker on the due date, and pagination if project counts grow.
