# STW-18 — RLS helper functions in private

- **Jira:** https://stratyge.atlassian.net/browse/STW-18 (blueprint US-010)
- **Branch:** `feat/stw-18/rls-helper-functions`

## Overview
One audited predicate for every policy: `private.current_user_org_ids()` (the caller's orgs) and `private.is_staff()` (is the caller in a staff org).

## Implementation details
Migration `20261020123000_rls_helper_functions.sql`:
- Both functions are `language sql stable security definer set search_path = ''`, with schema-qualified names. Identity comes only from `auth.uid()`, never from arguments or user metadata.
- `current_user_org_ids()` returns `coalesce(array_agg(org_id order by org_id), '{}')` from `public.memberships`: an empty array when the user has no membership or isn't signed in.
- `is_staff()` checks for a membership in an org with `org_type = 'staff'`.
- Execute revoked from `public` and `anon`, granted to `authenticated`; `grant usage on schema private to authenticated`. The other `private` functions (`touch_updated_at`, `mirror_auth_user`) keep execute revoked, so usage alone exposes nothing else.
- Why they work despite forced RLS: they run as the owner `postgres`, which has `BYPASSRLS`, and `FORCE ROW LEVEL SECURITY` doesn't apply to BYPASSRLS roles. Without definer rights, a policy on `memberships` that queried `memberships` would recurse.
- Policies should call `(select private.current_user_org_ids())` so it's evaluated once per statement (initPlan).

## API changes
None. `private` isn't exposed; the functions are callable only from SQL and policies.

## Database changes
Two functions, one schema usage grant. Rollback is in the header and `MIGRATIONS.md`.

## Dependencies on other tickets
Blocked by STW-16. Blocks STW-19 (identity RLS policies) and every tenant policy after it.

## Known limitations
None.

## Testing notes
`npm run test:db` → `supabase/tests/rls_helpers.sql` (rolled back), with JWT claims set as PostgREST does:
1. PASS: definer, stable, `search_path` pinned; execute for `authenticated` only; usage on `private` for `authenticated` only.
2. PASS: a builder in two orgs gets both ids; a user with no membership gets `{}` and not staff; a staff member is staff; no `sub` claim gives `{}` and not staff.
3. PASS: `authenticated` is denied reading `memberships` directly, yet the helper still returns its 2 orgs under forced RLS.
4. PASS: `anon` can't execute the helpers.

## Follow-up tasks
STW-19 uses these in `p_<table>_select` policies.
