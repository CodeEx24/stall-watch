# SETUP — rebuild Stall Watch from nothing

This guide takes a teammate from an empty machine to (A) a working **local sandbox** and (B) a working **hosted production** setup: Supabase project, Vercel deployment and CI. Follow it top to bottom. Each step says what to run and what you should see.

Rules that apply everywhere:
- **Only the publishable key is used.** The app reads exactly two variables, `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` (`src/lib/env.ts`). No service-role / `sb_secret_` key is used anywhere: not in code, not in `.env.local`, not in Vercel, not in CI. Postgres row level security is the security wall.
- **Never commit a secret.** The database password, test-user passwords and keys go in your password manager, `.env.local` (gitignored) or Vercel, never in git or in chat. Type the database password only at the CLI's hidden prompt, never as a `-p` / `--password` flag.
- **Never change schema in the dashboard.** Every table, policy, function, view and cron job comes from `supabase/migrations/`.
- The Supabase CLI is pinned: always run it as `npx -y supabase@2.121.0 …` (no global install).

## 0. Environments (sandbox / production split)

| | Sandbox (local) | Production (hosted) |
|---|---|---|
| Database | Supabase stack in Docker, from `supabase/config.toml` | Supabase project (Free plan) |
| Schema | `supabase db reset` applies `supabase/migrations/` | `supabase db push` applies `supabase/migrations/` |
| Seed and test users | `db reset` loads `seed.sql`; `npm run db:local-users` + `npm run db:local-link` | `seed.sql` in SQL Editor; users in Authentication dashboard; `link-test-users.sql` in SQL Editor |
| App | `npm run dev` on `http://localhost:3000` with `.env.local` | Vercel: **Production** = `main` at `https://stall-watch.vercel.app/`; **Preview** = one deployment per PR |
| Who uses it | developers, SQL tests, E2E checks | reviewers, Reverie3D |

**Known limitation:** there is only one hosted Supabase project. Vercel **Preview and Production use the same two variable values**, so every PR preview reads and writes the production database. Treat previews as production: never use them to try destructive changes. Schema changes are tested on the local sandbox before `db push`. A separate hosted staging project (with its own Preview-scoped values in Vercel) would remove this.

## 1. Tools

- **Node.js 20.9+** and npm (`node -v`). Node 22 is what CI uses.
- **Docker Desktop**, running (`docker ps` works).
- **Git** and a POSIX shell (`bash`). On Windows use Git Bash; the npm `db:*` and `test:db` scripts are bash.
- **python3** (or `python`) and **curl**: the local test-user script uses them.
- Accounts: Supabase, Vercel, GitHub (with access to the repo).

## 2. Get the code

```bash
git clone https://github.com/CodeEx24/stall-watch.git
cd stall-watch
npm ci            # exact dependencies from package-lock.json
```

---

# Part A — Local sandbox

## A1. Start the local stack

```bash
npx -y supabase@2.121.0 start
```
The first run downloads the Docker images (several minutes). On a brand-new stack `start` already applies the migrations and the seed; A2 rebuilds from scratch the same way and is the command to use any time after.

Local ports are moved to **55420–55429** (shadow DB `55420`, API `http://127.0.0.1:55421`, DB `55422`, Studio `http://127.0.0.1:55423`, Inbucket `55424`, analytics `55427`, pooler `55429`), so this stack can run beside another local Supabase project on the default 5432x ports. The Docker containers are named after `project_id = "stall-watch"` in `supabase/config.toml` (e.g. DB container `supabase_db_stall-watch`).

> Running a second copy side by side (e.g. a scratch rebuild)? In that copy's `supabase/config.toml` change `project_id` and every port above to a free range, and pass `DB_CONTAINER=supabase_db_<your project_id>` to the `db:local-link` and `test:db` scripts.

What `config.toml` sets, so you don't have to:
- `[api] schemas = ["public", "builder", "graphql_public"]`: the identity (`public`) and business (`builder`) schemas are exposed over the Data API; `private` is never exposed.
- `[auth]` email + password, `enable_confirmations = false` (local sign-ups are confirmed at once), `site_url = "http://127.0.0.1:3000"`.
- `[db.seed] sql_paths = ["./seed.sql"]`.
- `pg_cron` needs nothing locally: the Supabase image preloads it and the migration creates the extension.

## A2. Migrations, then seed

```bash
npx -y supabase@2.121.0 db reset
```
This applies every file in `supabase/migrations/` in timestamp order, **then** loads `supabase/seed.sql` (3 orgs, 9 projects, 43 slots, 22 selections, 26 history rows). Expected: `Finished supabase db reset on branch <your git branch>.` Always apply migrations this way (or with `migration up --local`), never by piping files into `psql`, so the local migration history stays correct.

`db reset` wipes the local database **including auth users**, so after any reset repeat A3 and A4.

## A3. Test users

Pick a local-only password (at least 6 characters). Do not reuse a real one and never commit it. The first command waits silently for you to type it and press Enter (nothing is echoed, and it never lands in your shell history); the second uses it:

```bash
read -rs LOCAL_TEST_PASSWORD && export LOCAL_TEST_PASSWORD
npm run db:local-users
```
It signs up the four users through the local Auth API with the publishable key (the same path as the app, no service-role key) and refuses to run against anything but `127.0.0.1` / `localhost`. Expected:
```
created  staff@stallwatch.test
created  ana@builder-a.test
created  bruno@builder-b.test
created  mia@builder-a.test
```
Running it again prints `skipped … (already registered)`.

## A4. Link script

```bash
npm run db:local-link
```
Runs the provided `supabase/link-test-users.sql` as the database owner (it writes memberships, which the app itself can never do). Safe to run twice. Expected:
```
ana@builder-a.test -> Builder A (admin)
bruno@builder-b.test -> Builder B (admin)
mia@builder-a.test -> Builder A (member)
staff@stallwatch.test -> Reverie3D Studio (admin)
```

| User | Role | Projects visible |
|---|---|---|
| `staff@stallwatch.test` | Reverie3D staff | 9 (all builders) |
| `ana@builder-a.test` | Builder A admin | 5 |
| `mia@builder-a.test` | Builder A member | 5 |
| `bruno@builder-b.test` | Builder B admin | 4 |

## A5. SQL tests

```bash
npm run test:db
```
Runs every `supabase/tests/*.sql` file (isolation, forced RLS, detector, cron, …) and then every `supabase/tests/*.sh` multi-session scenario against the local DB container. Each `.sql` file is one rolled-back transaction; each `.sh` scenario deletes everything it commits. Expected last line: `SQL tests passed`.

Also static, no database: `npm run check:migrations` (migration names, `MIGRATIONS.md` ledger rows, WHY / WHAT / ROLLBACK headers).

## A6. Run the app against the sandbox

1. Get the local publishable key: `npx -y supabase@2.121.0 status` and copy the value of `PUBLISHABLE_KEY` (`sb_publishable_…`). `status` also prints `SECRET_KEY` and `SERVICE_ROLE_KEY`: **never copy those** anywhere.
2. Create `.env.local` in the repo root (gitignored; `.env.example` is the template):
   ```
   NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:55421
   NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=<your-local-publishable-key>
   ```
3. `npm run dev` and open `http://localhost:3000`. Signed-out visitors are sent to `/login`.
4. Sign in as `ana@builder-a.test` with your local password. Expected: `/projects` lists Builder A's 5 projects. Sign in as `staff@stallwatch.test` to see all 9 and the detector console at `/detector`.

To stop the stack: `npx -y supabase@2.121.0 stop` (keeps data). `stop --no-backup` deletes the local data too.

---

# Part B — Hosted production

Do these in order. Steps B4–B7 follow the same order as local: **migrations, seed, users, link script**.

## B1. Create the Supabase project

1. https://supabase.com/dashboard → **New project**. Organization: yours (Free plan is fine). Name: `stall-watch`. Database password: **Generate a password**, save it in your password manager. Region: the closest one. Wait until the project is healthy (about 2 minutes).
2. **Create no tables, policies or functions in the dashboard.**
3. Copy the **project ref**: **Project Settings → General → Project ID** (about 20 lowercase letters; not a secret).

## B2. Enable pg_cron (before any push)

Dashboard → **Database → Extensions**, search `pg_cron`, switch it on. This is a setting, not a schema object. The detector schedule migration (`20261020171000_stall_detector_cron_schedule.sql`) needs it and is marked NOT SELF-CONTAINED for this reason.

## B3. Log in and link the CLI

```bash
npx -y supabase@2.121.0 login                                # opens a browser; the token stays on your machine
npx -y supabase@2.121.0 link --project-ref <your-project-ref> # type the database password at the hidden prompt
```
`supabase/config.toml` is committed; `link` only writes local state to `supabase/.temp/` (gitignored).

## B4. Migrations

```bash
npx -y supabase@2.121.0 db push
```
It lists the migrations to apply; confirm with `y`. If it asks for the database password, type it at the prompt only. Expected: every file in `supabase/migrations/` applied, ending `Finished supabase db push.` Check with `npx -y supabase@2.121.0 migration list` (Local and Remote columns match).

**Ongoing:** after every merged migration, run `db push` again so production stays in sync.

## B5. Expose the schemas (after the push)

The dashboard only lists schemas that already exist, so do this after B4.
Dashboard → **Project Settings → Data API → Exposed schemas**: make the list exactly `public`, `builder`, `graphql_public`. **Never add `private`.** Save.
This mirrors `[api] schemas` in `config.toml` (which only configures the local stack). Every exposed table has forced RLS and authenticated-only grants. Check: an anonymous REST call to a `builder` table returns `42501` (permission denied) and to `private` returns `PGRST106` (schema not exposed).

## B6. Seed (once)

Dashboard → **SQL Editor → New query** → paste the full contents of `supabase/seed.sql` → **Run**. Expected: success, no rows returned. Run it only once; a second run fails on duplicate org ids, which is harmless.

## B7. Users, then the link script

1. Dashboard → **Authentication → Users → Add user → Create new user**, ticking **Auto Confirm User** for each of `staff@stallwatch.test`, `ana@builder-a.test`, `bruno@builder-b.test`, `mia@builder-a.test`. Choose your own password(s), keep them in your password manager, and never commit or paste them anywhere. (Auto Confirm means no confirmation email is sent, so email delivery, Site URL and redirect URLs need no configuration for password sign-in.)
2. **SQL Editor → New query** → paste `supabase/link-test-users.sql` → **Run**. Safe to run twice. If it says `Not found in public.users`, the auth-mirror trigger is missing: B4 did not complete.
3. Expected visibility is the table in A4 (anonymous: denied).

Auth settings: keep the defaults (Email provider on, email + password). No OAuth, magic links or SMS are used.

## B8. Vercel

1. https://vercel.com/new → **Import Git Repository** → `CodeEx24/stall-watch` (grant the Vercel GitHub app access if asked). Framework preset **Next.js**, build and output settings left as they are.
2. Before **Deploy**, add exactly these two **Environment Variables** (values from Supabase → **Project Settings → API Keys** and **Data API**):

   | Name | Value | Environments | Exposed to the browser? |
   |---|---|---|---|
   | `NEXT_PUBLIC_SUPABASE_URL` | `https://<your-project-ref>.supabase.co` | Production, Preview, Development | **Yes, by design.** The `NEXT_PUBLIC_` prefix inlines it into the client bundle at build time. It is not a secret. |
   | `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | `<your-publishable-key>` (`sb_publishable_…`; if the project only shows legacy keys, the **anon** key) | Production, Preview, Development | **Yes, by design.** It identifies the project only; RLS decides what each signed-in user can read or write. |

   There are no other variables. **Do not add the `service_role` / `sb_secret_` key**, here or anywhere. Because both names are `NEXT_PUBLIC_`, a change only takes effect after a **redeploy**.
3. **Deploy**. Open the production URL: you land on `/login`; sign in as a hosted test user and see the projects.
4. **Settings → Git**: Production Branch is `main`; preview deployments are on. Every push to `main` deploys Production (`https://stall-watch.vercel.app/` on the owner's project); every PR gets a Preview URL. Both use the hosted project (see the limitation in section 0).
5. Optional: `vercel env pull .env.local` copies the Development values locally if you want to run the app against production data. Prefer the sandbox (A6).

---

# Part C — CI

`.github/workflows/ci.yml` runs on every pull request and every push to `main`, with a read-only token and **no secrets**:
1. checkout (credentials not persisted), Node 22 with npm cache
2. `npm ci`
3. `npm run lint` (ESLint: next core-web-vitals + typescript)
4. `npm run typecheck` (`next typegen`, then `tsc --noEmit`, strict)
5. `npm run build` (production build, telemetry off)

**Current status:** GitHub Actions does not start on this private repo (account billing / free-minutes limit; see `docs/actions/github-actions-billing.md`). Until that changes, the same checks run locally before every merge:
```bash
npm ci && npm run ci      # lint, typecheck, build (what ci.yml runs)
npm run test:db           # SQL tests against the local sandbox (A5)
npm run check:migrations  # migration names, ledger and headers (no database)
```
There is no database job in `ci.yml` yet; STW-37 adds one (start a Supabase stack, `db reset`, run `supabase/tests/`). `test:db` already accepts `DB_URL=<postgres connection URL>` for that job; never commit a real URL.

---

# Part D — Reference

## Nightly detector schedule (STW-34)
Migration `20261020171000_stall_detector_cron_schedule.sql` runs `create extension if not exists pg_cron` and schedules job `stall-detector-daily` at `0 18 * * *` (pg_cron uses UTC: 02:00 Asia/Manila) calling `private.run_stall_detector('scheduled')`. It is **not self-contained**:
- Hosted: pg_cron must be enabled first (B2), then `db push` (B4) creates the job. The job runs as `postgres`, the role `db push` uses, which owns the detector function.
- Local: the Supabase image preloads pg_cron, so `db reset` creates the extension and the job.
- Check: `select jobname, schedule, command, username from cron.job;` and, after a run, `select status, return_message from cron.job_run_details order by start_time desc limit 5;`. App roles (`anon`, `authenticated`, `service_role`) have no `usage` on schema `cron`, so only `postgres` sees or changes jobs.
- Rollback: `select cron.unschedule('stall-detector-daily');`
- Free-plan projects pause after a week of inactivity; a paused project runs no cron jobs. Restore it from the dashboard.

## Troubleshooting
| Symptom | Fix |
|---|---|
| `npx supabase start` fails on a port | Another stack uses 55420–55429: stop it, or change the ports in `config.toml` (A1 note). |
| `db:local-users`: `Local Supabase stack is not running` | Run A1 first, from the repo root. |
| `db:local-users`: `failed … (HTTP 422 …)` | Password too short (min 6) or rejected; pick another. |
| Local sign-in says `Invalid email or password.` although the users exist | The password the users were created with differs from what you type. If you fed `read` from a Windows (CRLF) file, it kept a trailing `\r`. Run A2–A4 again, typing the password. |
| `db:local-link`: `No such container` | Stack not running, or a different `project_id`: set `DB_CONTAINER=supabase_db_<project_id>`. |
| `link-test-users.sql`: `Not found in public.users` | Users not created yet, or migrations missing (auth-mirror trigger). Run A3 / B7.1, or B4. |
| App throws `Missing environment variable(s)` | `.env.local` (local) or the Vercel variables (hosted) are missing; restart `npm run dev` / redeploy after adding. |
| Signed in but no projects | User not linked: run the link script (A4 / B7.2). |
| `/rest/v1` returns `PGRST106` for `builder` | `builder` not in Exposed schemas (B5). |

More detail on what the owner did on the hosted project: `docs/actions/STW-12-create-supabase-project.md`, `docs/actions/hosted-database.md`, `docs/actions/STW-24-hosted-test-users.md`, `docs/actions/STW-13-vercel-project.md`.
