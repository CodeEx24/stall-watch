# STW-20 — Builder schema and core tables with composite foreign keys

- **Jira:** https://stratyge.atlassian.net/browse/STW-20 (blueprint US-012)
- **Branch:** `feat/stw-20/builder-core-tables`

## Overview
Projects, slots, selections and selection history in schema `builder`, shaped to the provided `supabase/seed.sql`, so a child row can never disagree with its parent's org.

## Implementation details
Migration `20261020130000_builder_core_tables.sql`:
- `builder.projects`: `status text check in ('pending_kickoff','selection_phase','revision','complete')` (the values in the seed), `selection_phase_started_at`, `selection_due_date date`, `archived_at`. Check: `status = 'selection_phase'` requires `selection_phase_started_at`. `unique (id, org_id)`.
- `builder.project_slots`: `room`, `category`; `unique (id, org_id)`; `unique (project_id, room, category)` (the seed looks slots up this way); composite FK `(project_id, org_id) → projects (id, org_id)`.
- `builder.selections`: `product_name` not null (1–200 chars), `selected_by → public.users on delete set null`; **`unique (slot_id)`** (one current selection per slot); composite FK `(slot_id, org_id) → project_slots (id, org_id)`.
- `builder.selection_history`: `action in ('set','change','clear')`, **nullable `product_name`**, which must be null exactly when the action is `clear`; `changed_by → public.users on delete set null`; `actor_kind in ('builder','staff')`; `changed_at`; composite FK `(slot_id, org_id)`. Indexes on `(slot_id, changed_at desc)` and `org_id`. It is append-only, so it has no update columns; STW-23 blocks update and delete.
- Projects, slots and selections have `created_at`, `updated_at`, `lock_version` and `trg_<table>_touch`.
- **Locked by default:** RLS enabled and forced with no policies; all privileges revoked from `public`, `anon` and `authenticated`. STW-21 adds org-scoped policies and grants.
- `supabase/seed.sql` and `supabase/link-test-users.sql` (the provided files, unchanged) are committed here because the schema is shaped to them. Loading them and creating the test users is STW-24.

## API changes
None yet. The tables are unreadable over the API until STW-21.

## Database changes
Four tables, five indexes, three triggers. Rollback: drop the four tables (see the header and `MIGRATIONS.md`).

## Dependencies on other tickets
Blocked by STW-19. Blocks STW-21 (policies), STW-22 (alerts), STW-23 (history trigger) and STW-24 (seed load).

## Known limitations
None.

## Testing notes
- `npm run test:db` → `supabase/tests/builder_core_tables.sql` (rolled back):
  1. PASS: 4 tables, RLS enabled and forced and locked, audit columns and touch triggers, nullable history product, text statuses.
  2. PASS: `unique (id, org_id)` on projects and slots, `unique selections.slot_id`, and 3 composite FKs.
  3. PASS (AC4): a selection, slot or history row whose `org_id` differs from its parent's raises **23503 foreign key violation**.
  4. PASS: the selection_phase start rule, status/action/actor checks, one selection per slot, unique slots, and the clear-has-null-product rule.
- The provided `seed.sql`, run **unchanged** in a rolled-back transaction against this schema, loads 3 orgs, 9 projects, 43 slots, 22 selections and 26 history rows (1 clear with a null product).

## Follow-up tasks
STW-21 policies and grants; STW-24 load seed and link users.
