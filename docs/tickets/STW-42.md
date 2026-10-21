# STW-42 — Late-change alert trigger (bonus)

- **Jira:** https://stratyge.atlassian.net/browse/STW-42
- **Branch:** `feat/stw-42/late-change-alert`
- **Status:** Code Review

## Overview
When a builder changes or clears a selection on a project that is already in `revision` (seed Lot 15), Reverie3D staff get an in-app alert straight away. This is the Part 3 bonus proposed in `docs/what-id-build-next.md` (STW-41). Where that proposal and this ticket differ, the ticket's AC wins: recipients are **staff**, not builder admins, and only **`revision`** counts, not `complete`.

Acceptance criteria:
- Given a builder change on a project in status 'revision' (Lot 15), then every staff user receives one alert with org_id = the builder org.
- Staff changes, and changes on projects not in revision, produce no alert; retries cannot duplicate (dedupe key = history row).
- Trigger function is definer, pinned search_path, not callable by authenticated.

## Implementation details
- **Trigger, not the detector.** An `AFTER INSERT` trigger `trg_late_change_alert` on `builder.selection_history` runs `private.raise_late_change_alert()`. Every set/change/clear already goes through the definer history trigger (STW-23), which computes `actor_kind` from memberships. So this trigger sees a trustworthy actor and the project status at the moment of the change. The alert is created in the same transaction: if the selection write rolls back, so does the alert.
- **What "a builder change" means:** `actor_kind = 'builder'` and `action in ('change', 'clear')`. A `set` fills an empty slot, so it adds to the set rather than breaking a finished one. Clearing a slot does break it. If a builder clears a slot and then sets it again, one alert fires, on the clear. That clear-then-set is also how the app's "replace" would show up in history if it were done in two steps.
- **Project status:** read through `project_slots` → `projects`, joined on `(id, org_id)`. Only `status = 'revision'` alerts. `archived_at` is not checked; the AC is status-only (see Known limitations).
- **Recipients:** every user with a membership in an org whose `org_type = 'staff'`. That is the same rule as `private.is_staff()`, written inline because `is_staff()` checks `auth.uid()`, not a given user. `distinct` covers a user who belongs to two staff orgs. Builder users never get these alerts.
- **Row:** `kind = 'late_change'`, `org_id` = the project's (builder) org, `project_id`, `history_id` = the new history row, `episode_id` null.
- **Message** (plain text, the app renders it as text): `LCA Lot 15: Kitchen Countertop was changed to "Calacatta Quartz" by the builder while the project is in revision.` or `… was cleared by the builder …`. It is cut to 500 characters with `left(…, 500)`, because names can add up to more than the `alerts.message` check allows.
- **De-dup:** `unique (history_id, user_id)` plus `on conflict (history_id, user_id) do nothing`. Running the insert path again for the same history row creates nothing. `history_id` has a composite FK `(history_id, org_id) → selection_history (id, org_id)` (ADR-003), so an alert can't point at another org's history. That needed a new `unique (id, org_id)` on `selection_history`.
- **Why definer:** app roles have no INSERT on `alerts` and cannot read other orgs' memberships. The function takes no arguments and reads only the new history row, which only the definer history trigger can write. It uses `search_path = ''` and schema-qualified names, and execute is revoked from `public`, `anon` and `authenticated`.
- **RLS / grants unchanged.** I checked `p_alerts_select`: it is `user_id = auth.uid()` only, with no org condition. So a staff user reads alerts addressed to them even though `org_id` is a builder org. Builder users can't see them, because `user_id` is never theirs. RLS stays enabled and forced on `alerts` and `selection_history`.
- **UI:** `/alerts` now shows a kind label (`Stalled` / `Late change`, fallback `Alert`) before the project name. The files are `src/features/alerts/queries.ts`, which adds `kind` to `AlertListItem` (the column was already selected), and `src/features/alerts/components/AlertInbox.tsx`. Staff already have the `/alerts` page; nothing else changed.

## API changes
None. The `/alerts` read returns the same columns; the list item now carries `kind`.

## Database changes
`supabase/migrations/20261020180000_late_change_alert_trigger.sql`:
- `builder.selection_history`: constraint `selection_history_id_org_key unique (id, org_id)`.
- `builder.alerts.history_id uuid null` with `alerts_history_fk (history_id, org_id) → selection_history (id, org_id) on delete restrict` and `alerts_history_user_key unique (history_id, user_id)`. Existing rows keep null.
- `private.raise_late_change_alert()` (security definer, `search_path=''`, execute revoked from public/anon/authenticated) plus `trg_late_change_alert after insert on builder.selection_history`.
- No policy or grant changes.

ROLLBACK:
```sql
drop trigger if exists trg_late_change_alert on builder.selection_history;
drop function if exists private.raise_late_change_alert();
alter table builder.alerts drop constraint if exists alerts_history_user_key,
  drop constraint if exists alerts_history_fk, drop column if exists history_id;
alter table builder.selection_history drop constraint if exists selection_history_id_org_key;
```

## Dependencies on other tickets
Uses STW-20 (core tables), STW-22 (alerts), STW-23 (history trigger and `actor_kind`), STW-31 (`alerts.episode_id`, the pattern for the de-dup key) and STW-30 (`/alerts` inbox), all merged. It follows the STW-41 proposal. STW-40 (DESIGN.md finalisation) should keep the "Built in STW-42" note.

## Known limitations
- **No `kind = 'late_change' ⇒ history_id is not null` check.** Unlike `alerts_stalled_needs_episode`, I didn't add one. The existing `alerts.sql` and `isolation.sql` fixtures insert `late_change` alerts without history (they use the kind to avoid needing a detector episode). The only writer in production is this definer trigger, which always sets `history_id`, and app roles cannot insert alerts at all.
- **Archived projects** still in `revision` would alert. The AC is status-only, and archiving doesn't change status.
- **Noise:** every change during a revision alerts every staff user. There is no grouping, and no setting to turn it off (left out on purpose, as in the proposal).
- A user who is both staff and a member of the builder org is logged as `actor_kind = 'builder'` (STW-23 rule), so their own change would alert staff, themselves included.
- **Hosted DB:** the migration is not pushed by this PR. The coordinator applies it after merge.

## Testing notes
- `supabase/tests/late_change_alert.sql` runs in one rolled-back transaction with its own fixture: staff org `LCA Staff` with 2 staff users, `LCA Builder` with an admin and a member, revision / selection_phase / complete projects, ids `...42xx`, `lca.*@example.test`. The expected recipients are computed as every staff user on the DB (fixture plus seed), so "every staff user" is exact. It checks:
  1. Catalog: `prosecdef`, `proconfig` has `search_path=""`, no execute for public/anon/authenticated, trigger attached, `history_id` nullable, key and composite FK present, RLS forced on alerts and history, no INSERT on alerts for authenticated.
  2. Builder admin change on revision gives exactly one alert per staff user, with kind, org_id (builder org), project, episode null and the exact message.
  3. Builder member clear on revision gives one alert per staff user.
  4. No alert for: a builder `set` of an empty slot, a staff change or clear on the revision project, a builder change on `selection_phase`, or a builder clear on `complete`. The test also checks that those history rows exist.
  5. Retry: a throw-away second trigger runs the same function again for the same history row. There is still one alert per staff user. A direct duplicate `(history_id, user_id)` insert raises `unique_violation`.
  6. Oversized names give a 500-character message, and the alert is still created.
  7. RLS: each staff user sees only their own alert, with its project name. Staff1 can't see staff2's. The builder admin and member see none, and the admin's `read_at` update affects nothing.
  8. `authenticated` cannot call the function directly.
- `npm run test:db` (all files), `npm run check:migrations`, and `npm ci && npm run ci` were run; results are in the PR.
- No E2E change to seed Lot 15: other tests rely on its state, so the behaviour is verified only in the rolled-back SQL test. The shared DB has no new alerts.

## Follow-up tasks
- Optional: add the `late_change ⇒ history_id` check once `alerts.sql` / `isolation.sql` fixtures create alerts through real history rows.
- Grouping or digest of several late changes, if staff find it noisy.
