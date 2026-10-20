# Setup prompt — paste into Claude Code in an empty repo folder

You are setting up the **Stall Watch** repository (Reverie3D Automation Engineer trial). Read `CLAUDE.md` and `AGENTS.md` first; they are binding. Work on small branches with Conventional Commits and open PRs (merge commit or rebase, never squash).

## Stack (locked)
Next.js App Router + TypeScript (strict), Supabase (Postgres + Auth), Vercel, GitHub Actions, pg_cron. No service-role key anywhere.

## Do these in order (stop at step 5 and show me what exists)
1. **SW-002 DESIGN.md first.** Create `DESIGN.md` starting with `Candidate: <my name>` and `Hours spent: <fill at the end>`. Add Problem, Goals/non-goals, planned data and permissions, decisions with rejected alternatives. Commit it as `docs: initial design note` before any other file.
2. **SW-003 Scaffold.** `create-next-app` (App Router, TypeScript, ESLint, no extras). Add `typecheck` script (`tsc --noEmit`). Add `.gitignore` entries for `.env*` (except `.env.example`), `supabase/.temp`, `.vercel`. Create `.env.example` listing `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, each with a comment and no value. Write a short README.
3. **SW-004 Supabase.** `supabase init`, `supabase link --project-ref <ref>` (I will give the ref). In `supabase/config.toml` set `[api] schemas = ["public", "builder", "graphql_public"]`. Copy the provided `seed.sql` and `link-test-users.sql` into `supabase/`. Do not create any schema objects in the dashboard.
4. **SW-006 CI.** `.github/workflows/ci.yml`: on pull_request and push to main, run `npm ci`, `npm run lint`, `npm run typecheck`, `npm run build`. No secrets.
5. **Pause.** Summarize what exists and what I must do manually: create the Vercel project and set the two `NEXT_PUBLIC_*` variables for Production, Preview and Development; confirm pg_cron availability under Database > Extensions.
6. Then proceed story by story from the backlog (`jira_import.csv` / workbook) starting at SW-007. For each migration: file `YYYYMMDDHHMMSS_what.sql`, a WHY / WHAT / ROLLBACK header, a row in `MIGRATIONS.md`, and a ticket doc in `docs/tickets/`.

## Guardrails for every step
- RLS enabled **and forced** on every table; every write policy has `with check`.
- Every `security definer` function pins `search_path = ''`, revokes from `public, anon`, and checks the caller when `authenticated` can call it.
- Compute builder activity from `selection_history.actor_kind`, not `selections.updated_at`.
- Show me the SQL before applying migrations; verify in the catalog afterward (RLS forced, policies present, grants correct).
- Never commit secrets or passwords. Ask me for the Supabase project ref and keys; keys go in Vercel and `.env.local` only.
