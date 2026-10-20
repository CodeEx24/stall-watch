-- WHY:  Helpers and internals (RLS predicates, triggers, the stall detector) must
--       live in a schema the Data API never exposes, and every mutable table must
--       stamp updated_at and bump lock_version the same way (optimistic locking).
-- WHAT: Creates schema `private` (NOT listed in supabase/config.toml [api] schemas)
--       and private.touch_updated_at(), a BEFORE UPDATE trigger function that sets
--       updated_at = now() and lock_version = old.lock_version + 1. Tables attach it
--       with: create trigger trg_<table>_touch before update on <table>
--             for each row execute function private.touch_updated_at();
--       No grants: Postgres checks EXECUTE on a trigger function only when the
--       trigger is created (by the migration owner), not when it fires, so app
--       roles never need access to `private` for this. STW-18 grants usage on
--       `private` for the RLS helper functions only.
-- ROLLBACK: drop function if exists private.touch_updated_at();
--           drop schema if exists private;   -- only once nothing else lives in it

create schema if not exists private;

comment on schema private is 'Stall Watch internals: RLS helpers, triggers, detector. Never exposed via the Data API.';

revoke all on schema private from public;

create or replace function private.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  -- Always derive from the stored row so a client cannot pick its own version.
  new.lock_version := old.lock_version + 1;
  return new;
end;
$$;

comment on function private.touch_updated_at() is
  'BEFORE UPDATE trigger: sets updated_at = now() and lock_version = old.lock_version + 1.';

revoke execute on function private.touch_updated_at() from public, anon, authenticated;
