# STW-37 — CI database job

- **Jira:** https://stratyge.atlassian.net/browse/STW-37
- **Branch:** `ci/stw-37/ci-database-job`
- **Status:** Code Review

## Overview
Every PR (and every push to main) must prove the database still works from scratch: migrations apply, `seed.sql` loads, and every SQL assertion in `supabase/tests/` passes, including the forced-RLS catalog check.

Acceptance criteria:
- Job starts local Supabase, applies migrations, loads seed.sql, runs supabase/tests/*.sql.
- Any failed assertion fails the PR; forced-RLS catalog check included.
- Job is green on main.

## Implementation details
`.github/workflows/ci.yml` gets a second job, `database`, next to the existing `ci` job (lint, typecheck, build). Workflow-wide `permissions: contents: read` is unchanged and no secrets are used. `timeout-minutes: 20`.

Steps:
1. `actions/checkout@v4` (`persist-credentials: false`).
2. `npm run check:migrations` (STW-38 static checks: filenames, ledger, headers).
3. `supabase/setup-cli@v1` with `version: 2.121.0`, the version used locally.
4. `supabase start -x realtime,storage-api,imgproxy,mailpit,postgrest,postgres-meta,studio,edge-runtime,logflare,vector,supavisor`. This starts only Postgres, Auth and Kong. On a fresh project, start applies every migration and `seed.sql` (`[db.seed]` is enabled in `config.toml`). The local image ships pg_cron, so the cron migration applies.
5. `supabase db reset`, to prove the migrations and seed also apply cleanly from a reset (the AC's "applies migrations, loads seed.sql" made explicit).
6. Create and link the four test users. The password is `openssl rand -hex 16`, generated once per run and masked with `::add-mask::`. It's a throwaway for a stack that is destroyed afterwards, and it's never committed or printed. Then `scripts/create-local-test-users.sh` (local Auth API signup, publishable key, no service role) and `scripts/link-local-test-users.sh` run (`supabase/link-test-users.sql`). With the users linked, the seed-specific assertions in `stall_detector.sql`, `stall_views.sql`, `projects_list.sql` and `detector_scenarios.sql` run instead of being SKIPped.
7. `npm run test:db` runs every `supabase/tests/*.sql` (psql `ON_ERROR_STOP`) and then every `supabase/tests/*.sh`. If any file fails, the script exits 1 and the job fails. The DB is reached by `docker exec` into `supabase_db_stall-watch` (the project_id in `config.toml`), the same path as local runs, so the runner doesn't need its own psql.
8. `supabase stop --no-backup` (`if: always()`).

Forced-RLS check: `isolation.sql` (STW-25) already checked `public` and `builder`. The new `supabase/tests/rls_forced.sql` widens that check to every application schema: it covers every schema except the Postgres and Supabase platform schemas (`auth`, `storage`, `cron`, `extensions`, …), so `private` and any future schema are included. It is catalog-driven, with no list of tables or app schemas, and fails if any ordinary or partitioned table lacks `relrowsecurity` or `relforcerowsecurity`. Its negative controls show it flags an unprotected table in `private` and an enabled-but-not-forced table in a brand-new schema.

Script change: `scripts/create-local-test-users.sh` accepts an optional `SUPABASE_CLI` (default `npx -y supabase@2.121.0`, unchanged behaviour), so CI can use the pinned installed binary. The usage comment no longer contains a quoted sample password, which the secret scanner flagged as a false positive (same fix as STW-38 did for SETUP.md).

## API changes
None.

## Database changes
None. There is no migration; this ticket adds one test file only.

## Dependencies on other tickets
STW-25 (isolation suite), STW-36 (`*.sh` scenarios in test-db.sh), STW-38 (`check:migrations`), STW-24 (test-user scripts). All are merged.

## Known limitations
- **GitHub Actions cannot currently run on this repo** (private repo on the free plan, blocked by billing). "Green on main" is therefore proven locally: the job's run steps were replayed literally on a scratch Supabase project (`project_id stall-watch-ci37`, ports 55530–55539, CLI 2.121.0) on a copy of the branch. `act` isn't installed on the Windows dev box. Once Actions is unblocked, the first real run on main is the final proof.
- The `ubuntu-latest` runner's own Docker hosts the stack. The first run downloads the Supabase images, which takes a few minutes.
- The daily cron job (18:00 UTC) could in theory fire during a run. `stall_detector.sql` then SKIPs its first-run scenario instead of failing.

## Testing notes
Local replay of the job (scratch project, full log kept outside the repo):
- Run 1 (branch as committed): `check:migrations` passed (15 files, 15 ledger rows). `start` and `db reset` each applied all 15 migrations and `seed.sql`. The 4 users were created and linked. All 18 `.sql` files and `detector_concurrency.sh` passed, with no SKIPs. **Job exit 0.**
- Run 2 (one assertion in `projects_list.sql` deliberately broken: `empty_before - 1` changed to `- 2`): `FAIL: empty_slots went 3 -> 2, expected one fewer`, `SQL tests FAILED`, **job exit 1**. Reverted.
- Run 3 (table `private.leak` created with RLS enabled but not forced): `rls_forced.sql` failed with `FAIL: app tables lacking enable+force RLS: {private.leak}`, and `test:db` exited 1. `isolation.sql` alone wouldn't have caught it. After dropping the table, the tests passed again.
- On the shared stack: `npm run test:db` passed (19 files). `npm ci && npm run ci` (lint, typecheck, build) was green.

## Follow-up tasks
- When GitHub Actions billing is resolved, confirm the first `database` run on main is green, and make both jobs required status checks on `main`.
