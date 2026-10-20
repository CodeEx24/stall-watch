# STW-11 — Scaffold repo and Next.js app with conventions

- **Jira:** https://stratyge.atlassian.net/browse/STW-11 (blueprint US-003)
- **Branch:** `feat/stw-11/scaffold-nextjs-app`

## Overview
Next.js App Router + TypeScript (strict) app with lint, typecheck and build scripts, an env template, and a README for running locally.

## Implementation details
- `create-next-app@16.4.2` (App Router, `src/`, ESLint, no Tailwind; import alias `@/*`), generated in a scratch folder and copied in so the repo's own `AGENTS.md`/`README.md` were not overwritten.
- `npm run typecheck` = `next typegen && tsc --noEmit`. `typegen` creates the route types (`LayoutProps`, `PageProps`) so typecheck works before a build, which is the order CI runs in.
- `next.config.ts` keeps the 16.x defaults (`cacheComponents`, `partialPrefetching`). Revisit in STW-27 when cookie-based Supabase sessions make routes dynamic.
- No Google Fonts: system font stack, so the build needs no network.
- Next's agent-rules block is appended to `AGENTS.md`, because `next dev` re-adds it whenever it's missing.
- `.gitignore`: `.env*` with `!.env.example`, `.next`, `next-env.d.ts`, `.vercel`, `supabase/.temp`, `supabase/.branches`, `.claude/settings.local.json`.

## API changes
None. One static route, `/`.

## Database changes
None.

## Dependencies on other tickets
Blocked by STW-10 (done). Blocks STW-12, STW-13, STW-14.

## Known limitations
The hello page is static. No Supabase client yet (STW-27).

## Testing notes
- `npm run lint`, `npm run typecheck`, `npm run build`: all pass.
- `npm start`, then `GET /` returns 200 with `<title>Stall Watch</title>` and `<h1>Stall Watch</h1>`; `GET /nope` returns 404.
- `git check-ignore .env .env.local` matches; `.env.example` is tracked.

## Follow-up tasks
STW-14 adds CI running the same three scripts.
