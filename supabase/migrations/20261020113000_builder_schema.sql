-- WHY:  supabase/config.toml exposes the `builder` schema over the Data API
--       ([api] schemas = public, builder, graphql_public). PostgREST refuses to
--       load its schema cache if an exposed schema is missing, so the schema has
--       to exist before anything else. Created by migration, never in the dashboard.
-- WHAT: Creates the empty `builder` schema (business tables arrive in STW-20).
--       No grants yet: `usage` for authenticated is granted with the first
--       tables and their RLS policies (STW-21), so nothing is reachable early.
-- ROLLBACK: drop schema if exists builder;   -- only while it is still empty

create schema if not exists builder;

comment on schema builder is 'Stall Watch business tables (projects, slots, selections, alerts, detector). Exposed via Data API; every table has RLS enabled and forced.';
