# Action for you: create the Supabase project and log in the CLI (STW-12) — DONE (2026-10-20, ref wgfxpdrlijzxkqaxlrbc)

**Who:** you. It involves your Supabase account, org, billing and the database password.
**When:** any time now. Claude needs it before the database work (STW-15 onward).
**Jira:** https://stratyge.atlassian.net/browse/STW-12

## Why
The database must be rebuildable from the repo, so Claude links the CLI to your project and commits `supabase/config.toml`. Creating the project and logging in require your account. The ticket's acceptance criteria: `supabase link` succeeds, no schema object is created in the dashboard, and the steps are noted for SETUP.md.

## Steps
1. Open https://supabase.com/dashboard, then **New project**.
   - Organization: your personal org (Free plan is fine).
   - Name: `stall-watch`.
   - Database password: click **Generate a password** and save it in your password manager. **Never paste it into chat, a file in the repo, or a commit.**
   - Region: the one closest to you (e.g. Southeast Asia (Singapore)).
   - Create the project and wait until it shows as healthy (about 2 minutes).
2. **Do not create tables, policies or functions in the dashboard.** Everything comes from migrations.
3. Enable `pg_cron`: **Database → Extensions**, search `pg_cron`, switch it on. This is a setting, not a schema object; the detector (STW-34) needs it.
4. Copy the **project ref**: **Project Settings → General → Project ID** (about 20 lowercase letters). The ref is not a secret.
5. Log the CLI in on this machine. In this Claude Code session, type:
   ```
   ! npx supabase login
   ```
   A browser window opens; approve it. The access token is stored on your machine, not in the repo.
6. Link the repo. Claude runs `supabase link` and will ask you to type the database password into the terminal prompt yourself. **Never pass the password as a `-p` / `--password` argument**: output and arguments of `!` commands land in the chat transcript. If the prompt can't appear, type this yourself and enter the password only at the hidden prompt:
   ```
   ! npx supabase link --project-ref <your-ref>
   ```
7. Tell Claude: "Supabase ref is `<ref>`, pg_cron enabled, CLI logged in."

## What Claude does after
Runs `supabase init`, sets `[api] schemas = ["public", "builder", "graphql_public"]` in `supabase/config.toml`, copies the provided `seed.sql` / `link-test-users.sql`, notes these steps for SETUP.md, opens the STW-12 PR, and moves STW-12 to Done after merge.

## Note on seed files
The setup prompt says `seed.sql` and `link-test-users.sql` are *provided*. Neither is in the repo yet. If you have them from Reverie3D, put them in `supabase/` (or tell Claude where they are).

## Done when
- [ ] Project created, healthy, nothing built in the dashboard
- [ ] `pg_cron` enabled
- [ ] `npx supabase login` done
- [ ] Ref given to Claude; `supabase link` succeeded
- [ ] Seed files provided (needed by STW-24)
