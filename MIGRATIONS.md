# Migrations ledger

Every schema change is a file in `supabase/migrations/` named `YYYYMMDDHHMMSS_what_it_does.sql`, with a WHY / WHAT / ROLLBACK header. Applied migrations are never edited; a change is a new migration.

| Migration | Ticket | What | Rollback |
|---|---|---|---|
| `20261020113000_builder_schema.sql` | STW-12 | Creates the empty `builder` schema exposed by `config.toml`; no grants | `drop schema if exists builder;` (while empty) |
| `20261020120000_private_schema_touch_trigger.sql` | STW-15 | Schema `private` (not exposed, `public` revoked) and `private.touch_updated_at()` BEFORE UPDATE trigger fn (`search_path=''`, execute revoked from app roles) | `drop function if exists private.touch_updated_at(); drop schema if exists private;` |
| `20261020121000_identity_tables.sql` | STW-16 | `public.orgs`, `public.users` (FK `auth.users`), `public.memberships`; checks, unique keys, touch triggers; RLS enabled + forced with no policies; all privileges revoked from app roles | `drop table if exists public.memberships, public.users, public.orgs;` |
| `20261020122000_auth_mirror_trigger.sql` | STW-17 | `private.mirror_auth_user()` (security definer, `search_path=`, execute revoked from app roles) + `trg_auth_users_mirror` after insert/update of email on `auth.users`; backfill | `drop trigger if exists trg_auth_users_mirror on auth.users; drop function if exists private.mirror_auth_user();` |
| `20261020123000_rls_helper_functions.sql` | STW-18 | `private.current_user_org_ids()` and `private.is_staff()` (security definer, stable, `search_path=`, identity from `auth.uid()`); execute + `usage on private` for authenticated only | `drop function if exists private.is_staff(); drop function if exists private.current_user_org_ids(); revoke usage on schema private from authenticated;` |
| `20261020124000_identity_rls_policies.sql` | STW-19 | RLS enabled + forced on orgs/users/memberships; `p_orgs_select`, `p_memberships_select`, `p_users_select` (own org / co-members / self, or staff); select granted to authenticated; all writes and anon access revoked | drop the three policies; `revoke select on public.orgs, public.users, public.memberships from authenticated;` |
| `20261020130000_builder_core_tables.sql` | STW-20 | `builder.projects`, `project_slots`, `selections`, `selection_history`; unique (id, org_id), composite FKs (parent_id, org_id), text+check statuses, selection_phase start check, history product null iff clear; touch triggers; RLS enabled + forced, locked (no grants) | `drop table if exists builder.selection_history, builder.selections, builder.project_slots, builder.projects;` |
| `20261020131000_builder_rls_policies.sql` | STW-21 | Builder policies `p_<table>_<command>` (org-or-staff; projects update staff-only; selections CRUD with check; slots/history select only); usage + column grants to authenticated only; `private.stamp_selected_by()` trigger | drop the 8 policies + trigger + function; revoke builder grants from authenticated (see header) |
| `20261020132000_alerts_table.sql` | STW-22 | `builder.alerts` (composite FK to projects, kind check, read_at >= created_at, touch trigger); recipient-only `p_alerts_select` / `p_alerts_update`; grants select + update (read_at) only | `drop table if exists builder.alerts;` |
| `20261020133000_selection_history_trigger.sql` | STW-23 | `private.record_selection_history()` (deliberate security definer; set/change/clear, changed_by = auth.uid(), actor_kind builder/staff from memberships) on builder.selections; `private.forbid_history_change()` makes history append-only for every role | drop both triggers and both functions (see header) |
| `20261020140000_detector_tables.sql` | STW-31 | `builder.stall_runs` (state checks, touch trigger), `builder.stall_episodes` (unique (project_id, quiet_since), composite FKs), `alerts.episode_id` (composite FK, unique (episode_id, user_id), stalled needs episode); forced RLS, staff-only select, no app writes | see header (drop alerts constraints/column, then both tables) |
| `20261020150000_stall_rule_views.sql` | STW-26 | `private.stall_window()` (immutable, 7 days, execute authenticated only); `builder.v_project_stall` (quiet_since = greatest(phase start, last builder history), is_stalled) and `builder.v_projects` (org_name, slot_count, empty_slots, quiet_since, is_stalled); both `security_invoker = true` (re-set by ALTER VIEW), select for authenticated only | `drop view if exists builder.v_projects; drop view if exists builder.v_project_stall; drop function if exists private.stall_window();` |
| `20261020160000_stall_detector_function.sql` | STW-32 | `private.run_stall_detector(p_trigger)` returns run id: validates trigger, `pg_advisory_xact_lock(2026032)`, run row inserted before an inner `begin … exception` block that inserts episodes from `builder.v_projects.is_stalled` (on conflict do nothing) and alerts for org admins of new episodes only; failure marks the run `failed` with `left(sqlerrm, 2000)` and returns. Security definer, `search_path=''`, execute revoked from public/anon/authenticated | `drop function if exists private.run_stall_detector(text);` |
| `20261020170000_run_stall_detector_now_rpc.sql` | STW-33 | `public.run_stall_detector_now()` returns `builder.stall_runs`: first statement raises `42501` unless `private.is_staff()`, then `private.run_stall_detector('manual')` and the run row read by id in a separate statement (READ COMMITTED-safe). Security definer, `search_path=''`, plpgsql; execute revoked from public/anon, granted to authenticated. PostgREST `POST /rest/v1/rpc/run_stall_detector_now` | `drop function if exists public.run_stall_detector_now();` |
| `20261020171000_stall_detector_cron_schedule.sql` | STW-34 | `create extension if not exists pg_cron` (schema pg_catalog); idempotent unschedule-then-schedule of job `stall-detector-daily`, `0 18 * * *` UTC (02:00 Asia/Manila), command `select private.run_stall_detector('scheduled')`, runs as `postgres`; no secret, no HTTP; grants nothing (app roles have no usage on schema `cron`). **NOT SELF-CONTAINED**: needs pg_cron enabled (dashboard on hosted) | `select cron.unschedule('stall-detector-daily');` |
| `20261020180000_late_change_alert_trigger.sql` | STW-42 | `selection_history` unique (id, org_id); `alerts.history_id` (nullable, composite FK (history_id, org_id), unique (history_id, user_id)); `private.raise_late_change_alert()` AFTER INSERT on `selection_history` (security definer, `search_path=''`, execute revoked from public/anon/authenticated): builder `change`/`clear` on a `revision` project -> one `late_change` alert per staff user, org_id = builder org, on conflict do nothing. No policy or grant changes | drop trigger + function, drop `alerts_history_user_key`, `alerts_history_fk`, `alerts.history_id`, `selection_history_id_org_key` (see header) |

## Audit (STW-38, 2026-10-21)

Run `npm run check:migrations` (`scripts/check-migrations.sh`, pure bash, no DB) to re-check rules 1–3 below (plus: a migration that creates an extension or uses `cron.` must carry `NOT SELF-CONTAINED:`) on every change; the CI database job (STW-37) can call it.

**Result: 15 files, 15 ledger rows, all rules pass. No migration file was edited by this audit** (all 15 are applied on the hosted project and the shared local stack, so even a header-comment fix would itself be an after-the-fact edit; gaps would have been recorded here instead, and none were found).

1. **Filenames:** all match `^\d{14}_[a-z0-9_]+\.sql$`; timestamps are unique and strictly increasing (`20261020113000` … `20261020171000`).
2. **Ledger:** exactly one row per file above, and every row names an existing file.
3. **Headers:** every file's leading comment block has `-- WHY:`, `-- WHAT:` and `-- ROLLBACK:`. `-- NOT SELF-CONTAINED:` is required where a migration depends on something outside `supabase/migrations/`: only `20261020171000_stall_detector_cron_schedule.sql` (pg_cron must be available/enabled; job runs as the applying role; `cron.timezone`), and it has the note. Migrations that use `auth.users`, `auth.uid()` or the `anon`/`authenticated` roles (`122000`, `123000`, `124000`, `131000`, …) rely only on objects every Supabase project ships, so they need no note.
4. **No applied migration edited after the fact:**

| Migration | Commits touching it (`git log --follow`) | Hosted applied = file |
|---|---|---|
| `20261020113000_builder_schema.sql` | `7413f48` | yes |
| `20261020120000_private_schema_touch_trigger.sql` | `8aeb27c` | yes |
| `20261020121000_identity_tables.sql` | `5616ed7` | yes |
| `20261020122000_auth_mirror_trigger.sql` | `a769414` | yes |
| `20261020123000_rls_helper_functions.sql` | `2c8457f` | yes |
| `20261020124000_identity_rls_policies.sql` | `76c0bba` | yes |
| `20261020130000_builder_core_tables.sql` | `9f6fde9` | yes |
| `20261020131000_builder_rls_policies.sql` | `7bf943f` | yes |
| `20261020132000_alerts_table.sql` | `f7477bb` | yes |
| `20261020133000_selection_history_trigger.sql` | `00b27d6`, `63e7a33` (see note) | yes |
| `20261020140000_detector_tables.sql` | `4e56481` | yes |
| `20261020150000_stall_rule_views.sql` | `2d2a4d4` | yes |
| `20261020160000_stall_detector_function.sql` | `7745b87` | yes |
| `20261020170000_run_stall_detector_now_rpc.sql` | `f4679a9` | yes |
| `20261020171000_stall_detector_cron_schedule.sql` | `2a74844` | yes |

"Hosted applied = file": `supabase migration list --linked` shows all 15 versions local = remote, and for each version the statements the CLI recorded in the hosted `supabase_migrations.schema_migrations.statements` equal the committed file (every statement is a verbatim substring of the file, and the concatenated statements equal the whole file ignoring whitespace and `;`). So the SQL in git is exactly what ran on the hosted database.

**Note on `20261020133000_selection_history_trigger.sql` (STW-23):** the second commit `63e7a33` (2026-10-20 20:12 -04:00, "let user deletion anonymise history…") amended `private.forbid_history_change()` on the PR branch during review, **before** PR #17 merged into `main` (20:33) and before the hosted push (the hosted DB was at 8/8 migrations, through STW-21, at the time). The hosted DB therefore only ever ran the final file. The one exception is the shared local dev stack, which had applied the first version from the branch; its function was re-applied by hand with the fix (the live function body contains it), but its migration-history row still records the pre-fix statements. Rule going forward: once a migration has run on any shared database, local stack included, fix it with a new migration rather than amending the file.

**Stale cross-reference (noted STW-40, file not edited):** the `-- NOT SELF-CONTAINED:` header of `20261020171000_stall_detector_cron_schedule.sql` points to "SETUP.md section 2, step 3" for enabling pg_cron. Since STW-39 rewrote SETUP.md, that step is **B2. Enable pg_cron (before any push)**. The migration is applied, so its comment stays as is.

**Local stack history drift (not fixed here; shared stack):** `20261020170000` and `20261020171000` are applied on the shared local stack (`public.run_stall_detector_now()` and the `stall-detector-daily` job exist) but have no row in its `supabase_migrations.schema_migrations`, because parallel tickets applied them with `psql`. `supabase migration up --local` would try to apply them again. When nobody else is using the stack, record them with `npx supabase migration repair --local --status applied 20261020170000 20261020171000`, or rebuild with `npx supabase db reset` (then re-run `db:local-users` and `db:local-link`). CI and fresh clones are unaffected (`db reset` applies the files in order).
