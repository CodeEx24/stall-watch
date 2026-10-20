# Migrations ledger

Every schema change is a file in `supabase/migrations/` named `YYYYMMDDHHMMSS_what_it_does.sql`, with a WHY / WHAT / ROLLBACK header. Applied migrations are never edited; a change is a new migration.

| Migration | Ticket | What | Rollback |
|---|---|---|---|
| `20261020113000_builder_schema.sql` | STW-12 | Creates the empty `builder` schema exposed by `config.toml`; no grants | `drop schema if exists builder;` (while empty) |
| `20261020120000_private_schema_touch_trigger.sql` | STW-15 | Schema `private` (not exposed, `public` revoked) and `private.touch_updated_at()` BEFORE UPDATE trigger fn (`search_path=''`, execute revoked from app roles) | `drop function if exists private.touch_updated_at(); drop schema if exists private;` |
| `20261020121000_identity_tables.sql` | STW-16 | `public.orgs`, `public.users` (FK `auth.users`), `public.memberships`; checks, unique keys, touch triggers; RLS enabled + forced with no policies; all privileges revoked from app roles | `drop table if exists public.memberships, public.users, public.orgs;` |
| `20261020122000_auth_mirror_trigger.sql` | STW-17 | `private.mirror_auth_user()` (security definer, `search_path=`, execute revoked from app roles) + `trg_auth_users_mirror` after insert/update of email on `auth.users`; backfill | `drop trigger if exists trg_auth_users_mirror on auth.users; drop function if exists private.mirror_auth_user();` |
