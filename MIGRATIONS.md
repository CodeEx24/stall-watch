# Migrations ledger

Every schema change is a file in `supabase/migrations/` named `YYYYMMDDHHMMSS_what_it_does.sql`, with a WHY / WHAT / ROLLBACK header. Applied migrations are never edited; a change is a new migration.

| Migration | Ticket | What | Rollback |
|---|---|---|---|
| `20261020113000_builder_schema.sql` | STW-12 | Creates the empty `builder` schema exposed by `config.toml`; no grants | `drop schema if exists builder;` (while empty) |
