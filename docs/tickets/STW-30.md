# STW-30 — /alerts inbox with mark as read

- **Jira:** https://stratyge.atlassian.net/browse/STW-30
- **Branch:** `feat/stw-30/alerts-inbox`

## Overview
As an admin, I want my alerts newest first with mark as read so that I act on stalls.

Acceptance criteria:
- Lists only the caller's alerts ordered by created_at desc; unread are visually distinct.
- Mark as read updates read_at only.
- Given Sam, then he sees only his own alerts, never Ana's.

## Implementation details
- `src/app/alerts/page.tsx` — thin route: heading, "← Projects" link, `<AlertInbox />` inside `<Suspense>` (Cache Components: the session read is request-time).
- `src/features/alerts/queries.ts` (server-only) — `listMyAlerts()`: `requireUser()`, then `builder.alerts` with the embedded project name (`project:projects!alerts_project_fk(name)`, the composite FK), `order created_at desc, id desc` (id breaks ties: one detector run stamps all its alerts with the same `now()`). The `user_id = me` filter only matches the `(user_id, created_at desc)` index; RLS `p_alerts_select` is the wall. Rows are parsed with zod (`alertRowSchema`) because the client is untyped; any error returns one generic message.
- `src/features/alerts/actions/mark-alert-read.ts` — `markAlertRead(alertId)` Server Action: zod-checks the id, re-checks the session (`getCurrentUser()`), then `update({ read_at })` `.eq("id", id).is("read_at", null)`. The payload holds `read_at` only, matching the `update (read_at)` column grant; the `read_at is null` filter makes it idempotent (a repeat keeps the first read time). RLS `p_alerts_update` limits it to the recipient, so another user's id matches 0 rows. `revalidatePath("/alerts")` afterwards. Failures return a generic message.
- `src/features/alerts/schemas.ts` — `markAlertReadInputSchema`, `alertRowSchema`. Ids use `z.guid()`, not `z.uuid()`: zod 4's `uuid()` enforces RFC version/variant bits and rejects the seed's ids (`00000000-0000-0000-0000-00000000a012`), while Postgres `uuid` accepts any 8-4-4-4-12 hex.
- `src/features/alerts/mark-alert-read-state.ts` — client-safe result type and message (a `"use server"` file exports only async functions).
- Components: `AlertInbox.tsx` (server; summary "N alerts, M unread", list, empty and error states) and `MarkReadButton.tsx` (client; `useTransition`, shows the generic error). Unread rows are bold with an amber left border, a "New ·" prefix and the button; read rows are normal weight, grey border, no button. Project name links to `/projects/[id]` (STW-29 builds that page). Times are shown in UTC.
- Reuses `createClient()` and `requireUser()`/`getCurrentUser()` from STW-27; no new client, no new dependency.

## API changes
- Server Action `markAlertRead(alertId)` → `{ ok: true } | { ok: false, error }`.
- Route `/alerts` (behind the proxy sign-in wall).

## Database changes
None. Relies on STW-22 (`builder.alerts`, recipient-only RLS, `update (read_at)` grant) and STW-32 (detector creates the alerts).

## Dependencies on other tickets
Blocked by STW-22, STW-27, STW-31, STW-32. Links to STW-29's `/projects/[id]`. A later nav ticket can link to `/alerts` from the layout.

## Known limitations
- `read_at` is the app server's clock (`new Date()`), since PostgREST cannot send `now()`. The `read_at >= created_at` check would reject it only if the app server clock ran behind the DB by more than the age of the alert; then the user sees the generic error and can retry.
- No pagination; an admin has at most one alert per stall episode, so the list stays small.
- No unread badge outside `/alerts` (needs the shared layout/nav).

## Testing notes
Local stack, `npm run build && next start -p 3030`. Alerts created by one manual detector run as postgres (`select private.run_stall_detector('manual')`, the first run on the shared DB): Ana 1 (Lot 12), Bruno 2 (Unit 4B, Unit 7C).
- Playwright (chromium, real `/login`), all PASS:
  - ana: 1 alert, Lot 12, unread styling (font-weight 700, "New", button), newest first. Click Mark as read → font-weight 400, no "New", no button; DB `read_at` set, `message` unchanged, `lock_version` 0 → 1; still read after reload.
  - staff (Sam): 0 alerts, empty state, Ana's text absent.
  - mia (Builder A member): 0 alerts.
  - bruno: 2 unread alerts (Unit 7C, Unit 4B), created_at non-increasing.
  - Afterwards `read_at` reset to null as postgres (3 of 3 unread) so the demo data stays unread.
- DB level: `supabase/tests/alerts.sql` already proves the recipient's `update ... set message` fails with 42501, the `read_at` update succeeds, and non-recipients (co-member, staff) cannot mark read.
- `npm run test:db` — 13 files, 72 PASS notices, "SQL tests passed". `npm ci && npm run ci` (lint, typecheck, build) green.

## Follow-up tasks
- Global nav with an unread count (layout ticket).
- Use generated `database.types.ts` once committed, replacing the local zod row schema's role as the type source.
