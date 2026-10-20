# STW-12 — Create Supabase project, link CLI, set exposed schemas in config.toml

- **Jira:** https://stratyge.atlassian.net/browse/STW-12 (blueprint US-004)
- **Branch:** `chore/stw-12/supabase-config`

## Overview
The database must be rebuildable from the repo: a committed `supabase/config.toml` exposing `public` and `builder`, a CLI linked to the hosted project, and nothing created in the dashboard.

## Implementation details
- `npx supabase@2.121.0 init` creates `supabase/config.toml` and `supabase/.gitignore`.
- `project_id = "stall-watch"`, which names the local Docker containers.
- `[api] schemas = ["public", "builder", "graphql_public"]`; `extra_search_path` stays `["public", "extensions"]`; `private` is not exposed.
- Postgres major version 17 (CLI default). Auth: email provider with signup enabled locally (CLI default). Hosted auth settings are configured in the dashboard, and test users come from the provided seed scripts (STW-24).
- `SETUP.md` started with the Supabase steps (AC3); STW-39 finalises it.
- Local ports moved to 55420–55429 (`inspector_port` 8093) so the stack can run beside another local Supabase project that uses the defaults.
- First migration `20261020113000_builder_schema.sql`: PostgREST fails its health check (503, `schema "builder" does not exist`) when an exposed schema is missing, so the empty schema is created by migration. No grants (STW-21).
- `MIGRATIONS.md` ledger started.

## API changes
Data API exposes the `builder` schema (empty; no `usage` for `anon`/`authenticated` yet).

## Database changes
`create schema builder` only. Rollback: `drop schema if exists builder;`.

## Dependencies on other tickets
Blocked by STW-11 (done). Blocks STW-13 (env values) and STW-15 (first migration).
**Person action:** create the hosted project and log in the CLI (`docs/actions/STW-12-create-supabase-project.md`). `supabase link` needs the project ref, plus the database password typed at the prompt.

## Known limitations
- Linked 2026-10-20: `npx supabase link --project-ref wgfxpdrlijzxkqaxlrbc` returned `{"project_ref":"wgfxpdrlijzxkqaxlrbc"}`; `supabase/.temp/` (gitignored) holds the link. `pg_cron` enabled in the dashboard (a setting, not a schema object).
- `supabase/seed.sql` and `supabase/link-test-users.sql` are "provided" but not in the repo yet; `db reset` warns until they're added (STW-24).

## Testing notes
- `npx supabase start` (exit 0) applies `20261020113000_builder_schema.sql`; every service is healthy. Catalog: `builder` exists with 0 relations; `has_schema_privilege('authenticated'|'anon','builder','usage')` = false/false; `supabase_migrations.schema_migrations` lists `20261020113000`.
- Without the migration, `supabase start` fails: `supabase_rest unexpected status 503` / `schema "builder" does not exist`.
- Dashboard check after linking: no tables, functions or policies created by hand.

## Follow-up tasks
Push migrations to the hosted project and expose `builder` there (`docs/actions/hosted-database.md`).
