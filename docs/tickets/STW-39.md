# STW-39 — SETUP.md for a teammate rebuilding from nothing

- **Jira:** https://stratyge.atlassian.net/browse/STW-39
- **Branch:** `docs/stw-39/setup-guide`

## Overview
`SETUP.md` was a work-in-progress list that each ticket appended to. This ticket rewrites it as one ordered guide that takes a teammate from an empty machine to a working local sandbox and a working hosted production setup.

Acceptance criteria:
- Covers Supabase (create, link, db push, exposed schemas, pg_cron, other settings), order: migrations, seed, users, link script.
- Covers every Vercel env var with environments and browser exposure, CI contents, and the sandbox/production split.
- Followed literally on a scratch project it succeeds.

## Implementation details
`SETUP.md` is organised as:
- **Rules** that apply everywhere: only the publishable key (`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, from `src/lib/env.ts`); no service-role / `sb_secret_` key anywhere; no secrets in git; no schema changes in the dashboard; the CLI pinned as `npx -y supabase@2.121.0`.
- **§0 Environments:** sandbox (local Docker stack) vs production (hosted project + Vercel Production), and Vercel Preview vs Production. Stated plainly: Preview and Production use the same hosted project (one Supabase project, same two values in every Vercel environment).
- **§1–2:** tools (Node, Docker, bash, python3, curl), clone, `npm ci`.
- **Part A, local sandbox:** `start` → `db reset` (migrations, then `seed.sql`) → test users (`read -rs LOCAL_TEST_PASSWORD && export LOCAL_TEST_PASSWORD`, then `npm run db:local-users`) → `npm run db:local-link` → `npm run test:db` / `check:migrations` → `.env.local` + `npm run dev` + sign in. Also: how to run a second, side-by-side copy (`project_id`, ports, `DB_CONTAINER`).
- **Part B, hosted production:** create project → enable pg_cron (before any push) → `login` / `link` (password at the hidden prompt only) → `db push` (migrations) → exposed schemas `public`, `builder`, `graphql_public`, never `private` (after the push, since the dashboard only lists existing schemas) → `seed.sql` in SQL Editor → users in Authentication with Auto Confirm → `link-test-users.sql`. Auth settings: defaults; Auto Confirm means Site URL / redirect URLs / email delivery need no setup for password sign-in. Vercel: import, a table of the two variables with value source, environments (Production, Preview, Development) and why each is browser-exposed by design; redeploy after changing a `NEXT_PUBLIC_` value; Production branch `main`, previews per PR.
- **Part C, CI:** exactly what `ci.yml` runs (read-only token, no secrets, Node 22, `npm ci`, lint, typecheck, build); that GitHub Actions does not currently start on this private repo, so the same checks run locally (`npm ci && npm run ci`, `npm run test:db`, `npm run check:migrations`); STW-37 adds the database job.
- **Part D:** the pg_cron schedule notes (kept from STW-34) and a troubleshooting table.

Review notes folded in: the test-user password step is a two-step `read -rs` so it runs as pasted (a `<placeholder>` would be parsed by bash as a redirect) and no password-shaped value appears in the doc; migrations are applied with `db reset` / `migration up --local`, never with `psql`.

## API changes
None.

## Database changes
None.

## Dependencies on other tickets
Uses the outcomes of STW-12 (project, link), STW-13 (Vercel), STW-14 (CI), STW-21 (exposed `builder`), STW-24 (seed and users), STW-27 (sign-in), STW-28 (projects list, used in the dry run), STW-34 (pg_cron), STW-38 (`check:migrations`). STW-37 (CI database job) will update Part C.

## Known limitations
- **Preview = production data.** Vercel Preview deployments use the same hosted project as Production. A staging Supabase project with Preview-scoped values would remove this; not in scope.
- Hosted steps (Part B) could not be re-run here: creating a hosted project is a person action. They are taken from the owner's completed run (see Testing notes) rather than re-proven.
- Hosted public sign-up stays at the Supabase default (on). A self-registered user has no membership and RLS shows them nothing.
- GitHub Actions is not running (billing); CI contents are described as committed and run locally.

## Testing notes
**AC3: literal dry run on a scratch local stack** (never the shared `stall-watch` stack). A fresh `git clone` of this branch went to a scratchpad folder; in that copy only, `config.toml` got `project_id = "stall-watch-setup39"` and ports 55520–55529 (the A1 side-by-side note), and `DB_CONTAINER=supabase_db_stall-watch-setup39` was exported for the DB scripts. Then every Part A step ran as written. Final run on commit `4818567` (main `4cfcdf9` + this guide):

| Step | Command | Outcome |
|---|---|---|
| 2 | `git clone …`, `npm ci` | installed |
| A1 | `npx -y supabase@2.121.0 start` | stack up; on a new stack it applied all 15 migrations and `seed.sql` (now noted in A1) |
| A2 | `npx -y supabase@2.121.0 db reset` | 15 migrations, then seed; `Finished supabase db reset on branch docs/stw-39/setup-guide.` (doc says `<your git branch>`); 3 orgs / 9 projects / 43 slots / 22 selections / 26 history / 1 cron job / 0 auth users |
| A3 | `read -rs LOCAL_TEST_PASSWORD && export LOCAL_TEST_PASSWORD`; `npm run db:local-users` | `created` ×4; second run `skipped … (already registered)` ×4 |
| A4 | `npm run db:local-link` (twice) | the 4 expected `email -> org (role)` lines both times |
| A5 | `npm run test:db`; `npm run check:migrations` | 17 `.sql` files + `detector_concurrency.sh`: `SQL tests passed`; `migration checks passed (15 files, 15 ledger rows)` |
| A6 | `npx -y supabase@2.121.0 status` → `.env.local` (URL + `PUBLISHABLE_KEY`); `PORT=3039 npm run dev` | Ready on :3039 |
| A6 | Playwright (chromium), real `/login` form | signed-out `/` → `/login` for each; ana 5 projects, mia 5, bruno 4 (Unit 2A/4B/5A/7C), staff 9; staff `/detector` HTTP 200. All PASS |
| B5 check | anonymous REST with the publishable key | `builder.projects` → 401 `42501`; `private` → 406 `PGRST106` |

Teardown: `npx -y supabase@2.121.0 stop --no-backup --project-id stall-watch-setup39` (0 containers and 0 volumes left for it; the shared stack's 11 containers untouched), dev server stopped, clone deleted.

Findings that changed the guide: `start` already migrates and seeds a new stack; the `db reset` success line names the current git branch; `status` also prints `SECRET_KEY` / `SERVICE_ROLE_KEY` (guide now says never copy those); feeding `read` from a CRLF file keeps a trailing `\r`, so sign-in then fails (added to troubleshooting; the first pass hit this and was redone from `db reset`).

Incident (no effect): in the first pass one `npm run db:local-link` ran without `DB_CONTAINER`, so it used the default shared container. `link-test-users.sql` is `insert … on conflict do nothing` and those users were already linked: the shared stack still had 4 memberships, all created 2026-10-20. Every DB command in the final pass had `DB_CONTAINER` set.

**Hosted steps (Part B): from the owner's completed run, not re-run here**
| Step | Source (completed) |
|---|---|
| B1 create, B2 pg_cron, B3 login/link | `docs/actions/STW-12-create-supabase-project.md` (done 2026-10-20) |
| B4 `db push`, B5 exposed schemas (`builder` added; anon 42501 on builder, PGRST106 on private) | `docs/actions/hosted-database.md` (done 2026-10-20); 15/15 local = remote per the STW-38 audit in `MIGRATIONS.md` |
| B6 seed, B7 users + link script | `docs/actions/STW-24-hosted-test-users.md` |
| B8 Vercel vars in all three environments, no service-role key, previews on | `docs/actions/STW-13-vercel-project.md` (done 2026-10-20, https://stall-watch.vercel.app/) |
| Part C CI contents | `.github/workflows/ci.yml` as committed; `docs/actions/github-actions-billing.md` |

`npm ci && npm run ci` in the worktree: lint, typecheck, build green.

## Follow-up tasks
- STW-37: when the CI database job lands, update Part C (what it runs, and that `test:db` uses `DB_URL` there).
- Optional: a staging Supabase project for Vercel Preview, or turning off hosted public sign-up (Authentication → Sign In / Providers → Allow new users to sign up).
