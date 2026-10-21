-- STW-37: forced-RLS catalog check over EVERY application schema (CI gate).
-- isolation.sql (STW-25) already checks public and builder. This file widens the net to
-- every schema that is not owned by Postgres or the Supabase platform, so a table added
-- later in private (or in a brand-new schema) without `enable` + `force row level security`
-- fails the PR. Catalog-driven: no table or app-schema list is hardcoded; only the
-- platform schemas are excluded. Everything runs inside a rolled-back transaction.
\set ON_ERROR_STOP on
begin;

-- schemas the app does not own (Postgres internals, Supabase services, extensions)
create or replace function pg_temp.is_platform_schema(s name)
returns boolean language sql immutable as $$
  select s in ('pg_catalog', 'information_schema', 'pg_toast', 'auth', 'storage', 'realtime',
               '_realtime', 'extensions', 'graphql', 'graphql_public', 'vault', 'cron', 'net',
               'pgbouncer', 'pgsodium', 'pgsodium_masks', '_analytics', 'supabase_functions',
               'supabase_migrations', 'pgmq', 'pgtle', 'topology', 'tiger', 'tiger_data')
      or s like 'pg\_temp\_%' or s like 'pg\_toast\_temp\_%' or s like 'supabase\_%'
$$;

create or replace function pg_temp.app_tables_missing_forced_rls()
returns setof text language sql stable as $$
  select n.nspname || '.' || c.relname
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where c.relkind in ('r', 'p')
    and not pg_temp.is_platform_schema(n.nspname)
    and not (c.relrowsecurity and c.relforcerowsecurity)
  order by 1
$$;

-- 1. the real check: zero app tables lack enable + force
do $$
declare
  missing text[];
  n_tables integer;
  schemas text;
begin
  select count(*), string_agg(distinct n.nspname, ', ')
    into n_tables, schemas
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where c.relkind in ('r', 'p') and not pg_temp.is_platform_schema(n.nspname);
  if n_tables < 10 then  -- 3 identity + 7 builder tables exist today; fewer means a broken DB
    raise exception 'FAIL: expected at least 10 app tables, found % (schemas: %)', n_tables, schemas;
  end if;
  if not exists (select 1 from pg_namespace where nspname = 'private') then
    raise exception 'FAIL: schema private not found';
  end if;
  select array_agg(t) into missing from pg_temp.app_tables_missing_forced_rls() t;
  if missing is not null then
    raise exception 'FAIL: app tables lacking enable+force RLS: %', missing;
  end if;
  raise notice 'PASS: forced-RLS catalog: 0 of % tables in app schemas (%) lack enable+force', n_tables, schemas;
end $$;

-- 2. negative controls: the check catches a bad table in private and in a new schema
do $$
begin
  create table private.stw37_probe (id integer);
  create schema stw37_probe_schema;
  create table stw37_probe_schema.t (id integer);
  alter table stw37_probe_schema.t enable row level security;  -- enabled, not forced
  if not exists (select 1 from pg_temp.app_tables_missing_forced_rls() t where t = 'private.stw37_probe') then
    raise exception 'FAIL: catalog check missed a private table without RLS';
  end if;
  if not exists (select 1 from pg_temp.app_tables_missing_forced_rls() t where t = 'stw37_probe_schema.t') then
    raise exception 'FAIL: catalog check missed an enabled-but-not-forced table in a new schema';
  end if;
  alter table private.stw37_probe enable row level security;
  alter table private.stw37_probe force row level security;
  alter table stw37_probe_schema.t force row level security;
  if exists (select 1 from pg_temp.app_tables_missing_forced_rls() t
             where t in ('private.stw37_probe', 'stw37_probe_schema.t')) then
    raise exception 'FAIL: catalog check flagged tables with RLS enabled and forced';
  end if;
  raise notice 'PASS: catalog check flags unprotected tables in private and in new schemas (negative control)';
end $$;

rollback;
