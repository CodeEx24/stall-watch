# STW-27 — Supabase SSR clients, session refresh and /login

- **Jira:** https://stratyge.atlassian.net/browse/STW-27
- **Branch:** `feat/stw-27/ssr-auth-login`

## Overview
As a user, I want to sign in with email and password so that I can reach my projects. First app-code ticket: it wires `@supabase/ssr` into Next.js 16 (App Router, Cache Components) and puts a sign-in wall in front of every route.

Acceptance criteria:
- `@supabase/ssr` server and browser clients configured with the publishable key only; session refreshed in middleware/proxy.
- Given valid credentials, `/login` redirects to `/projects`; invalid credentials show a plain error.
- Given a signed-out visitor, `/projects` redirects to `/login`; no service-role key exists in code or Vercel.

## Implementation details
- `src/lib/env.ts` — `getSupabaseEnv()`: reads `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` once, throws a clear error naming any missing variable. These are the only two variables the app reads.
- `src/lib/supabase/server.ts` — `createClient()` (`import "server-only"`): `createServerClient` with `getAll`/`setAll` over `cookies()`. It calls `connection()` first so every auth/data read is request-time under Cache Components (a runtime prefetch otherwise trips on the token-expiry `Date.now()`), and so `next build` never needs the env vars.
- `src/lib/supabase/proxy.ts` + `src/proxy.ts` — Next 16 renamed Middleware to **Proxy** (`proxy.ts`, Node runtime). `updateSession()` refreshes the session on every non-static request with `supabase.auth.getClaims()` (verifies the JWT; `getSession()` is never trusted on the server), writes refreshed cookies and the Cache-Control headers `@supabase/ssr` asks for, and redirects:
  - signed-out + any path except `/login` → `/login` (default deny, so new routes are protected without touching the proxy);
  - signed-in + `/login` → `/projects`.
  Redirect targets are fixed internal paths; there is no `next`/`redirectTo` parameter, so no open redirect.
- `next.config.ts` — `/` → `/projects` (temporary redirect); the placeholder home page is removed.
- `src/features/auth/`
  - `schemas.ts` — `signInInputSchema` (zod): trimmed email, ≤ 254 chars, valid format; password non-empty, ≤ 72 chars (bcrypt limit Supabase Auth enforces at sign-up).
  - `sign-in.ts` — `signIn` Server Action: validate, `signInWithPassword`, `redirect("/projects")`. Every failure (bad format, wrong password, unknown user, Auth error) returns the same `"Invalid email or password."`; Supabase error details never leave the server. The typed email is echoed back so the field keeps its value; the password never is.
  - `sign-out.ts` — `signOut` Server Action (`scope: "local"`), then `/login`.
  - `sign-in-state.ts` — client-safe state type, initial state, message and length limits (a `"use server"` file may only export async functions).
  - `queries.ts` — `getCurrentUser()` (React `cache`, `getClaims()`, returns `{ id, email }`) and `requireUser()` (redirects to `/login`). Server-only.
  - `components/LoginForm.tsx` (client, `useActionState`), `SignedInAs.tsx` (server), `SignOutButton.tsx`.
- `src/app/login/page.tsx` and `src/app/projects/page.tsx` stay thin. `/projects` is a placeholder (STW-28 builds the list); its session read sits inside `<Suspense>`, as Cache Components requires, and calls `requireUser()` as defense in depth behind the proxy.
- **Browser client** `src/lib/supabase/client.ts`: `createBrowserClient` with the same env helper and publishable key. Guarded by `import "client-only"` (no `"use client"` directive: with the directive a server import gets a client reference and the guard never fires). Added to meet AC1 as written; nothing calls it yet (sign-in and sign-out are Server Actions). It's for later browser-side features. Data access stays in Server Components and Server Actions.
- Dependencies pinned exactly: `@supabase/ssr 0.12.7`, `@supabase/supabase-js 2.118.0`, `zod 4.6.7`, `server-only 0.0.1`.

## API changes
- Server Actions `signIn(prevState, formData)` and `signOut()`.
- Proxy on all non-static paths (session refresh + sign-in wall).
- Redirect `/` → `/projects`.

## Database changes
None.

## Dependencies on other tickets
Blocked by STW-13 (Vercel project/env), STW-17 (auth mirror) and STW-24 (test users). Blocks STW-28 (project list) and every later UI ticket, which reuse `createClient()` and `requireUser()`.

## Known limitations
- No `next` return-path after sign-in: always lands on `/projects`. If added later, accept only paths starting with `/` and not `//`.
- No rate limiting in the app; Supabase Auth's own sign-in rate limits apply.
- Vercel: the env vars are set by the STW-13 person action (URL + publishable key only); this ticket adds no Vercel config.
- Generated DB types (`src/types/database.types.ts`) not yet used; the client is untyped until a data ticket needs it.

## Testing notes
Local stack (`http://127.0.0.1:55421`), `npm run build && next start -p 3027`, `.env.local` with the local publishable key.
- `curl -i /projects` signed out → `307 location: /login`; `/` → `307 /projects`; `/login` → 200; a forged `sb-127-auth-token` cookie → `307 /login`; `/favicon.ico` → 200 (static files bypass the proxy). `next build` also passes with no env vars (as in CI).
- Playwright (chromium, headless), all PASS: wrong password for ana stays on `/login` with "Invalid email or password.", email kept, no auth cookie; malformed email → same message; signed-out `/projects` → `/login`; ana's real sign-in → `/projects` showing "Signed in as ana@builder-a.test", cookie `sb-127-auth-token` (SameSite=Lax); signed-in `/login` → `/projects`; Sign out → `/login`, and `/projects` is walled again. Server log clean.
- `git grep` for `service_role` / `sb_secret_`: only docs, warnings and the secret-scanner pattern; nothing in `src/` or config.
- `npm run test:db` (12 files, 65 PASS, on main incl. STW-25/26) and `npm ci && npm run ci` (lint, typecheck, build) green.

## Follow-up tasks
- STW-28: project list on `/projects` using `createClient()` / `requireUser()`.
- `src/lib/supabase/client.ts` exists (added for AC1). It is guarded with `import "client-only"` and has no `"use client"` directive, so importing it from a server module fails `next build` with "'client-only' cannot be imported from a Server Component module" (verified in STW-28 by a temporary import from `src/features/projects/queries.ts`). Importing it from a `"use client"` component builds fine. The first browser-side Supabase feature (e.g. live alerts) should import it instead of creating another client.
