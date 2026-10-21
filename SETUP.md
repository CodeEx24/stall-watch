# SETUP — rebuild Stall Watch from nothing

Work in progress: each ticket adds its steps, and STW-39 finalises this guide for a teammate starting from scratch.

## 1. Tools
- Node.js 20.9+ and npm
- Docker Desktop, running (for the local Supabase stack)
- Supabase CLI, via `npx supabase@2.121.0 …` (no global install needed)

## 2. Supabase project (STW-12)
1. Create the project in the Supabase dashboard (Free plan): name `stall-watch`, a generated database password saved in a password manager, and the nearest region. Full steps: [`docs/actions/STW-12-create-supabase-project.md`](docs/actions/STW-12-create-supabase-project.md).
2. **Create no schema objects in the dashboard.** Every table, policy and function comes from `supabase/migrations/`.
3. Dashboard **Database → Extensions**: enable `pg_cron` (a setting; the detector schedule needs it).
4. Log in and link the CLI. Enter the database password only at the hidden prompt, never as a flag:
   ```bash
   npx supabase login
   npx supabase link --project-ref <project-ref>
   ```
5. Hosted Data API: dashboard **Project Settings → Data API → Exposed schemas** must list `public`, `builder`, `graphql_public` (never `private`). The local stack reads the same list from `config.toml`.
6. `supabase/config.toml` is committed. `[api] schemas = ["public", "builder", "graphql_public"]` exposes the identity (`public`) and business (`builder`) schemas over the Data API; `private` is never exposed.

## 3. Local database
```bash
npx supabase start      # local Postgres + Auth + API in Docker
npx supabase db reset   # apply migrations, then supabase/seed.sql
```
Test users (local only):
```bash
LOCAL_TEST_PASSWORD='pick-a-local-password' npm run db:local-users   # signs up the 4 users via the local Auth API
npm run db:local-link                                                  # runs supabase/link-test-users.sql (safe twice)
```
`db reset` reloads `supabase/seed.sql` and wipes auth users, so run both commands again after a reset. Hosted project: `docs/actions/STW-24-hosted-test-users.md`.

Local ports are moved to **55420–55429** (API `http://127.0.0.1:55421`, DB `55422`, Studio `55423`, Inbucket `55424`), so this stack can run beside another local Supabase project on the default 5432x ports.

## 4. Push migrations to the linked project
```bash
npx supabase db push
```

### Nightly detector schedule (STW-34)
Migration `20261020171000_stall_detector_cron_schedule.sql` runs `create extension if not exists pg_cron` and schedules job `stall-detector-daily` at `0 18 * * *` (pg_cron uses UTC: 02:00 Asia/Manila) calling `private.run_stall_detector('scheduled')`. It is **not self-contained**:
- Hosted: pg_cron must be enabled first in the dashboard, **Database → Extensions → pg_cron** (step 2.3; already done on the owner's project), then `npx supabase db push` creates the job. The job runs as `postgres`, the role `db push` uses, which owns the detector function.
- Local: the Supabase image preloads pg_cron, so `db reset` creates the extension and the job.
- Check: `select jobname, schedule, command, username from cron.job;` and, after a run, `select status, return_message from cron.job_run_details order by start_time desc limit 5;`. App roles (`anon`, `authenticated`, `service_role`) have no `usage` on schema `cron`, so only `postgres` sees or changes jobs.
- Rollback: `select cron.unschedule('stall-detector-daily');`

## 5. App
See [`README.md`](README.md): `npm ci`, copy `.env.example` to `.env.local` with the two `NEXT_PUBLIC_` values, `npm run dev`.
For the local stack, `NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:55421` and the publishable key from `npx supabase status` (`PUBLISHABLE_KEY`). Open `/login` and sign in as one of the test users (STW-27); signed-out visitors are sent to `/login`.
