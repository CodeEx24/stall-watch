# STW-15 — Private schema and shared updated_at / lock_version trigger

- **Jira:** https://stratyge.atlassian.net/browse/STW-15 (blueprint US-007)
- **Branch:** `feat/stw-15/private-schema-touch-trigger`

## Overview
A `private` schema for internals, never exposed over the Data API, and one shared BEFORE UPDATE trigger function so every mutable table stamps `updated_at` and bumps `lock_version` the same way.

## Implementation details
- Migration `20261020120000_private_schema_touch_trigger.sql`:
  - `create schema private`, then `revoke all on schema private from public`. It is not in `config.toml` `[api] schemas`.
  - `private.touch_updated_at()`: plpgsql, `set search_path = ''`. It sets `new.updated_at := now()` and `new.lock_version := old.lock_version + 1`, always derived from the stored row so a client can't choose its own version or timestamp.
  - `revoke execute … from public, anon, authenticated`. Postgres checks EXECUTE on a trigger function only at `create trigger` time, so app roles never need rights on `private` for this. Test 4 proves it.
- How tables use it (STW-16, STW-20): `create trigger trg_<table>_touch before update on <table> for each row execute function private.touch_updated_at();`.
- `scripts/test-db.sh` + `npm run test:db`: runs every `supabase/tests/*.sql`, via `docker exec` on the local stack or `DB_URL` with psql (for the STW-37 CI job).

## API changes
None. `private` is not exposed.

## Database changes
Schema `private`; function `private.touch_updated_at()`. Rollback is in the migration header and `MIGRATIONS.md`.

## Dependencies on other tickets
Blocked by STW-12. Blocks STW-16. STW-18 grants `usage` on `private` to `authenticated`, for the RLS helpers only.

## Known limitations
`lock_version` is bumped, not checked. Rejecting stale writes (`where lock_version = $expected`) is done by the update statements in the app (STW-29).

## Testing notes
`npm run test:db`, which runs `supabase/tests/touch_trigger.sql` inside a rolled-back transaction:
1. PASS: `private` exists, not exposed, no `anon` usage.
2. PASS: `search_path` pinned to `''`; execute revoked from `anon` and `authenticated`.
3. PASS: on update, `updated_at = now()` and `lock_version` goes 0→1→2, even when the client sends `lock_version = 99` and an old `updated_at`.
4. PASS: the trigger fires for `authenticated`, which has no usage on `private`.

## Follow-up tasks
STW-37 wires `npm run test:db` into the CI database job.
