# STW-17 — Auth-mirror trigger copies auth.users into public.users

- **Jira:** https://stratyge.atlassian.net/browse/STW-17 (blueprint US-009)
- **Branch:** `feat/stw-17/auth-mirror-trigger`

## Overview
Every Supabase Auth user gets a `public.users` row with the same id and email, so `link-test-users.sql` can find them and the app has a users table. Clients still cannot write `public.users`.

## Implementation details
Migration `20261020122000_auth_mirror_trigger.sql`:
- `private.mirror_auth_user()`: `security definer`, `set search_path = ''`, schema-qualified names. It upserts `(new.id, lower(new.email))` into `public.users` and skips rows without an email.
- Trigger `trg_auth_users_mirror` runs `after insert or update of email on auth.users`, so email changes are mirrored too.
- Deletes need no trigger: `public.users.id` references `auth.users on delete cascade`.
- Execute revoked from `public`, `anon` and `authenticated`. Only the trigger runs it.
- Why definer rights: the caller is GoTrue (`supabase_auth_admin`), which has no rights on `public.users`. The owner `postgres` has `BYPASSRLS`, so the insert works despite forced RLS.
- The backfill inserts every existing auth user with an email (`on conflict do nothing`).

## API changes
None.

## Database changes
One function and one trigger on `auth.users`, plus the backfill. Rollback is in the header and `MIGRATIONS.md`; mirrored rows are left in place.

## Dependencies on other tickets
Blocked by STW-16. Blocks STW-24 (`link-test-users.sql`). Runs in parallel with STW-18 in the plan; stacked here only because migrations share one local database.

## Known limitations
Users without an email (phone auth) aren't mirrored. Email/password is the only method.

## Testing notes
- `npm run test:db` → `supabase/tests/auth_mirror.sql` (rolled back): definer, `search_path`, revoked execute and trigger present; an insert is mirrored with a lower-cased email; an email change is mirrored; deleting the auth user cascades; every auth user with an email has a mirror row (backfill); `authenticated` can't insert into `public.users`.
- E2E through the real GoTrue (AC1, "user created → same id and email"): `POST /auth/v1/signup` on the local stack returned 200, and `auth.users` = 1 and the `public.users` mirror (same id) = 1. Deleting the auth user then left 0 mirror rows.

## Follow-up tasks
None.
