# STW-23 — Selection history trigger with computed actor_kind

- **Jira:** https://stratyge.atlassian.net/browse/STW-23 (blueprint US-015)
- **Branch:** `feat/stw-23/selection-history-trigger`

## Overview
Every set, change and clear of a selection is written to `builder.selection_history` by the database, which also records who did it and whether they were a builder or staff. Builders can't forge history, and staff edits can't count as builder activity.

## Implementation details
Migration `20261020133000_selection_history_trigger.sql`:
- `private.record_selection_history()` runs as `AFTER INSERT OR UPDATE OR DELETE ON builder.selections`:
  - insert → `set` (new product); update → `change` (only if `product_name` actually changed; a no-op update isn't activity); delete → `clear` (`product_name` null, as the STW-20 check requires).
  - `changed_by = auth.uid()`.
  - `actor_kind = 'builder'` when the caller has a membership in the selection's org (which equals the project's org, guaranteed by the composite FKs); otherwise `'staff'`, including when there is no `auth.uid()` (SQL editor, cron).
  - **Security definer on purpose** (stated in the header): app roles have no INSERT on history (STW-21), so only this trigger writes it. No arguments; identity comes only from `auth.uid()` and the row; `search_path = ''`; execute revoked from `public`, `anon`, `authenticated`.
- `private.forbid_history_change()` runs as `BEFORE UPDATE OR DELETE ON builder.selection_history` and raises `insufficient_privilege` for **every** role, including the owner. History is append-only. The one exception is the FK action when a user is deleted (`changed_by … on delete set null`): an update that **only** nulls `changed_by` is allowed, so the row survives anonymised. Without it, deleting any user with history (for example from the Auth dashboard) failed, a bug caught in review.
- `seed.sql` loads with triggers off (`session_replication_role = replica`), so its backdated history isn't duplicated (verified: 26 rows, 1 staff).

## API changes
None. Clients keep writing `selections`, and history appears automatically.

## Database changes
Two functions and two triggers. Rollback is in the header and `MIGRATIONS.md`.

## Dependencies on other tickets
Blocked by STW-21 (and stacked on STW-22 only because migrations share one local database). Blocks STW-25 (isolation tests on history), STW-26 (stall views read `actor_kind`) and STW-29 (slot UI).

## Known limitations
- A staff user who is also a member of a builder org would be counted as `builder` for that org. The membership is what decides it, per the AC.
- When staff edit a selection, `selected_by` becomes the staff user (STW-21 stamp), while history records `actor_kind = 'staff'`.

## Testing notes
`npm run test:db` → `supabase/tests/selection_history.sql` (rolled back):
1. PASS: definer, `search_path` pinned, execute revoked, both triggers attached.
2. PASS: as Ana, set → change → no-op update → clear gives exactly `set|Quartz`, `change|Granite` and `clear|null`, all with `changed_by` = Ana and `actor_kind = builder`.
3. PASS: a staff caller records `staff`; with no `auth.uid()` it records `staff` with `changed_by` null.
4. PASS: app roles can't insert history directly; UPDATE and DELETE on history are blocked even for the owner.
5. PASS: deleting a user with history succeeds; their rows remain with `changed_by` null; nulling `changed_by` together with any other change is still blocked.
- `seed.sql` dry run with these triggers: 22 selections, 26 history rows, no duplicates.

## Follow-up tasks
STW-26 computes quiet-since from `actor_kind = 'builder'`.
