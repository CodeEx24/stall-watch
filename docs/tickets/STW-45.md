# STW-45 — Premium UI redesign of all pages with motion (UI UX Pro Max)

- **Story:** — (added after the blueprint; no US number)
- **Epic / Feature:** EP-05 Builder & Staff Screens (STW-5)
- **Wave / Workstream / Sprint:** post-delivery polish / WS-UI / S2
- **Branch:** `feat/stw-45/premium-ui-redesign`
- **Status:** Code Review

## Overview
Every screen is redesigned to look premium for home builders, and a public landing page explains the product. Stack decision from the owner: Tailwind CSS + shadcn/ui, customised to be unique. Design references: the UI UX Pro Max skill (style, palette, typography: warm stone neutrals, gold accent, serif display — its "Liquid Glass" pick was used only for the frosted top bar because of its contrast warnings) and the motion skills.

Acceptance criteria (from Jira):
- [x] Design system first: tokens defined once (`globals.css`), documented in `docs/design-system.md`, summarised in DESIGN.md "Interface"; no one-off colours.
- [x] Shared components built once and reused: Button, Input, Badge (stalled / healthy / brass), Card, Table pattern, EmptyState, Skeleton, Toast, PageHeader, StatTile.
- [x] All 5 pages + shell redesigned; checked at 375/390, 954 and 1440 px with no horizontal page scroll.
- [x] Motion: page entry, staggered lists/tables, hover/press, toasts, alert-read transition, skeleton → content, optimistic slot feedback, sliding nav pill; transform/opacity only, 150–400 ms, off under reduced motion.
- [x] Loading, empty, error, success and pending states on every page.
- [x] Accessibility: WCAG 2.2 AA contrast, focus rings, keyboard navigation, semantic headings and labels.
- [x] Performance: Lighthouse performance ≥ 90 and accessibility ≥ 90 on `/projects` and `/projects/[id]`.
- [x] No behaviour or security change; all SQL tests pass.
- [~] Screenshots: "after" set committed in `docs/screenshots/stw-45/` and linked from the PR. No "before" set (the old UI was unstyled HTML; it is on `main` before this merge).

## Implementation details
- **Stack (ADR-010):** Tailwind CSS 4.3.3 via `@tailwindcss/postcss`; shadcn/ui 4.22 (radix-nova, Radix base) copied into `src/components/ui/` and customised (touch targets, brass focus ring, status badge variants, warm inputs, toaster without `next-themes`); `motion` 14.5.0; `tw-animate-css`; fonts self-hosted with `next/font` (Cormorant Garamond, Geist, Geist Mono). All versions pinned exactly. shadcn's `cn` import is routed through `src/lib/utils.ts` (the `cn` package is published by shadcn).
- **Shell:** routes that need a session moved into the `src/app/(app)/` route group (URLs unchanged) with a layout: skip link, frosted sticky header (`AppHeader`, streamed behind `AppHeaderSkeleton`), `NavLinks` (active pill via shared layout animation, unread count, staff-only Detector link), `UserMenu` (identity + sign out; replaces `SignedInAs` / `SignOutButton`), footer. New `not-found.tsx` and `(app)/error.tsx`.
- **Pages:** Projects (stat tiles derived from the same rows, table that becomes cards below `md`), project detail (dark selection-progress banner, room cards, slot rows with Change that opens in place, optimistic pending value, inline error), Alerts (cards with unread accent, kind badges, toast on read), Detector (Run now banner, last-run tiles, responsive run table), Login (split screen with a line-drawn house elevation).
- **Landing (`/`):** static page — hero with a live-looking app preview built from the real badge components, how it works, feature bento, interactive product tour (WAI-ARIA tabs), audience split, closing CTA. Copy matches the product (7 quiet days, daily run, one alert per stall, late-change alerts). The `/ → /projects` redirect was removed and `/` added to the proxy's public paths.
- **Motion architecture:** server-rendered entry motion is CSS (`animate-rise`, `stagger-children`) so content paints with the HTML; the `motion` library is only used in client components. Run now and Mark as read are form actions (`useActionState`) instead of `onClick`.
- **Reuse:** dates go through `src/lib/format.ts` (was three separate `Intl.DateTimeFormat`s); `DataTable` serves the project and run tables; room cards use the shadcn `Card`; `StatTile` serves Projects and Detector; `ProjectStatusBadge`/`StalledBadge` serve the app and the landing previews.

## API changes
- New read helpers: `countMyUnreadAlerts()` (`features/alerts/queries.ts`, head-only count on `builder.alerts` under the existing RLS policy) and `isSignedInUserStaff()` (`features/detector/queries.ts`, the existing staff check wrapped in React `cache`). Both use the per-request client.
- No server action signatures changed.

## Database changes
None. No migration, policy or grant touched.

## Dependencies on other tickets
Builds on the merged screens (STW-27 login, STW-28 projects, STW-29/30 selections, STW-33 alerts, STW-34 detector console). Nothing depends on it.

## Known limitations
- **Selection history is not shown** on the project page: the ticket listed it, but there is no history query today and the AC forbids new data paths; left for a follow-up.
- **Orca's embedded browser does not hydrate streamed (PPR) sections** of the production build — on `main` as well, so not a regression. Verified in headless Edge (Puppeteer) instead: sections hydrate, Run now records a run, Mark as read clears the badge, no page errors.
- Lighthouse scores are from a local production build (mobile preset) with local Supabase, not from Vercel.
- One light theme; no dark mode.
- shadcn files keep lowercase names (`button.tsx`), an ADR-010 exception to the PascalCase rule.

## Testing notes
- `npm run ci` (lint, typecheck, build): green. Routes: `/` and `/login` static; app pages partially prerendered.
- `npm run test:db`: 19 files, 102 PASS, 0 FAIL (after resetting the walkthrough's test data).
- Lighthouse 12.8.2, mobile preset, local production build, signed in where needed:

  | Page | Performance | Accessibility |
  | --- | --- | --- |
  | `/` | 93 | 100 |
  | `/login` | 95 | 100 |
  | `/projects` (Ana) | 94 | 100 |
  | `/projects/[id]` (Ana) | 93 | 100 |
  | `/alerts` (Ana) | 94 | 100 |
  | `/detector` (staff) | 93 | 100 |

- Browser walkthrough (Orca + headless Edge) as staff, Ana (builder admin): wrong password shows the error; staff sees Detector, runs it (alert created); Ana sees no Detector link, `/detector` shows "Staff only", sees only Builder A's 4 projects, sets a slot (progress 62% → 75%, stall cleared), marks the alert read (badge clears); signed-out `/alerts` redirects to `/login`.
- Overflow check (`scrollWidth ≤ innerWidth`) on every page at 375 and 1440 px.

## Follow-up tasks
- Selection history timeline on the project page (needs a history query + RLS test).
- A real 403 for "Staff only" (see DESIGN.md "Rules I bent").
