# STW-29 — /projects/[id] slots with set, change and clear

- **Jira:** https://stratyge.atlassian.net/browse/STW-29
- **Story:** US-021
- **Branch:** `feat/stw-29/project-slots`

## Overview
As a Builder A member, I want to pick, change or clear a product per slot so that the project progresses.

Acceptance criteria:
- Slots grouped by room show the current product with Set/Change and Clear.
- A builder write records history with actor_kind 'builder'; a staff write records 'staff'.
- Given Ana opens a Builder B project id, then not found or empty; no data leaks.

## Implementation details
Feature folder `src/features/selections/`; the route `src/app/projects/[id]/page.tsx` stays thin.
- `page.tsx` — static shell ("← Projects" link + `<Suspense>`). Under Cache Components `params` is runtime data, so it is awaited inside the Suspense boundary (`params.then(...)`); the shell holds nothing project-specific.
- `components/ProjectDetail.tsx` (server) — `requireUser()` (STW-27), then `getProjectDetail(id)`; `null` → `notFound()`. Renders name, org, status, archived/stalled flags and one table per room. Rows are keyed by `slot id + lock_version`, so a successful write (which revalidates) remounts the row with fresh values.
- `components/SlotRow.tsx` (client) — `useActionState` for each of the three actions. Empty slot: product input + **Set**. Filled slot: input prefilled + **Change**, and **Clear**. Both carry hidden `slotId` and `lockVersion` (the version rendered). Errors show in `role="alert"`.
- `queries.ts` (server-only) — `getProjectDetail(rawId)`: id shape-checked first (malformed → `null`, no query); then `builder.v_projects` by id (RLS via `security_invoker`); if no row → `null` **before any slot query**, so another org's id reveals nothing (no name, no slot count). Then `project_slots` (ordered room, category) and `selections` for those slot ids; grouped by room in code.
- `slot-lookup.ts` (server-only, deliberately not `"use server"` so it is not an action endpoint) — `findVisibleSlot()` reads `id, org_id, project_id` of a slot through RLS.
- `actions/set-selection.ts`, `actions/change-selection.ts`, `actions/clear-selection.ts` (`"use server"`): each calls `requireUser()`, validates with zod, reads the slot through RLS (hidden/missing → generic error), then:
  - **set**: `insert (org_id, slot_id, product_name)` with `org_id` from the slot row, never from the form. Unique violation (someone set it meanwhile) → conflict message.
  - **change**: `update product_name … eq(slot_id).eq(lock_version, expected).select('id')`; 0 rows → "This slot was changed by someone else — reload."
  - **clear**: `delete … eq(slot_id).eq(lock_version, expected).select('id')`; 0 rows → same conflict message.
  - success → `revalidatePath('/projects/<project_id>')` and `/projects` (empty-slot counts). A conflict does **not** revalidate, so the message stays on screen until the user reloads.
- `schemas.ts` — `rowIdSchema` = `z.guid()` (hex 8-4-4-4-12; `z.uuid()` would reject the seed ids such as `…00000000a014`, which are valid Postgres uuids but not RFC v1–v8), `productNameSchema` trimmed 1–200, `lockVersionSchema` decimal string → int 0…2^31-1 (no `z.coerce`, which would turn a missing field into 0).
- `action-state.ts` — client-safe state type and messages (a `"use server"` file may only export async functions). `types.ts` — view-model types shared by server and client components.
- `selected_by`, `updated_at`, `lock_version` and the history row (`set`/`change`/`clear`, `changed_by`, `actor_kind`) are all written by database triggers (STW-21, STW-23, touch trigger); the app never sends them.

## API changes
Server Actions `setSelection`, `changeSelection`, `clearSelection` (signature `(prevState, formData)`, return `{ status, message }`). Route `/projects/[id]`.

## Database changes
None. Uses existing grants (`insert (org_id, slot_id, product_name)`, `update (product_name)`, `delete` on `builder.selections`), RLS policies and triggers.

## Dependencies on other tickets
Blocked by STW-21 (RLS + grants), STW-23 (history trigger), STW-26 (`v_projects`), STW-27 (SSR auth). Parallel with STW-28 (project list links to this page). Feeds STW-32/detector via builder history.

## Known limitations
- Not-found renders inside the Suspense boundary after the shell has streamed, so the HTTP status is 200 with the not-found UI (Next.js streaming behaviour; documented in `not-found.md`). The body holds no project data.
- Archived projects are still editable (RLS allows it; no rule forbids it yet).
- Changing a product to the same name bumps `lock_version` but writes no history (the trigger ignores no-op changes by design).
- `requireUser()` is imported from `src/features/auth/queries.ts` (STW-27); no new shared helper was added.

## Testing notes
Local stack, `npm run build && next start -p 3029`, Playwright (chromium) through the real `/login` form. 29/29 PASS:
- Ana on Lot 14: rooms Great Room / Kitchen / Primary Bath, 6 slot rows; empty slot offers Set, filled slot Change + Clear; whitespace-only product → "Enter a product name (1–200 characters)." and nothing written; Kitchen Faucet set → change → (stale-lock test) → clear, ending empty as seeded.
- Stale lock: a second tab rendered the same version; tab 1 changed, tab 2's Change and Clear both → "This slot was changed by someone else — reload."; tab 2 kept showing what it rendered; after reload it showed tab 1's value.
- Tampered form: Ana's Set form posted with Unit 2A's slot id → generic error; Unit 2A stayed empty.
- Ana opens Unit 4B (Builder B), a malformed id, and an unknown id → not-found page, no detail or slot rows, HTML contains no project, org or slot names.
- Staff on Unit 2A (pending_kickoff) Kitchen Countertop: set + clear.
- psql: history rows for the run — Lot 14 Faucet `set`, `change`, `change`, `clear` all `actor_kind = builder`, `changed_by = ana`; Unit 2A Countertop `set`, `clear` both `actor_kind = staff`, `changed_by = staff`. No row for the stale "D" change or the cross-tenant attempt. No selections left on the touched slots; `v_projects.is_stalled` unchanged (Lot 12, Unit 4B, Unit 7C stalled; Lot 14 not).
- `npm run test:db`: 13 files, 72 PASS, exit 0; `npm ci && npm run ci` (lint, typecheck, build) green.

## Follow-up tasks
- STW-28 list rows should link to `/projects/<id>`.
- Decide whether archived or `complete` projects should be read-only (DB rule, not UI).
- A shared `rowIdSchema` (guid) may belong in a common place once a second feature needs it.
