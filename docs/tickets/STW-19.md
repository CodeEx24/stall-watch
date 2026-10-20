# STW-19 — Identity RLS: enable, force, read-only policies

- **Jira:** https://stratyge.atlassian.net/browse/STW-19 (blueprint US-011)
- **Branch:** `feat/stw-19/identity-rls-policies`

## Overview
Forced RLS on `orgs`, `users` and `memberships`, with read-only policies, so the app can read identity data scoped to the caller but never write it.

## Implementation details
Migration `20261020124000_identity_rls_policies.sql`:
- Re-asserts `enable` + `force row level security` on all three tables (first set in STW-16).
- `p_orgs_select`: `id = any(current_user_org_ids)` or staff.
- `p_memberships_select`: `org_id = any(current_user_org_ids)` or staff. Members can see who else is in their org; builders need this to find their admins.
- `p_users_select`: self, users who share an org with the caller, or staff.
- Helpers are written `(select private.current_user_org_ids())::uuid[]`: the scalar subquery makes Postgres evaluate them once per statement (initPlan), and the cast makes `= any(...)` compare against the array's elements rather than treating the subquery as a row set.
- `grant select … to authenticated`; `revoke insert, update, delete, truncate, references, trigger` from `anon` and `authenticated`; `anon` loses select too. There are no write policies at all.
- `supabase/tests/rls_helpers.sql` (from STW-18): the "direct read denied" assertion is now grant-independent, because from this ticket on `authenticated` may read memberships through RLS.

## API changes
`GET /rest/v1/orgs|users|memberships` now returns rows for signed-in users, filtered by RLS. All writes fail with 403 / `42501`.

## Database changes
Three policies and the grants/revokes above. Rollback is in the header and `MIGRATIONS.md`.

## Dependencies on other tickets
Blocked by STW-18. Blocks STW-20 (builder schema), which reuses this pattern for every business table.

## Known limitations
None.

## Testing notes
`npm run test:db` → `supabase/tests/identity_rls.sql` (rolled back, with JWT claims set as PostgREST does):
1. PASS: RLS enabled and forced; only `p_<table>_select` policies; no insert/update/delete for `anon`/`authenticated`; no `anon` select.
2. PASS: **a user with no membership sees 0 orgs** (and only their own user row); builder A sees 1 org / 2 users / 2 memberships; builder B sees only its own 1 / 1 / 1; staff sees all 3 / 5 / 4.
3. PASS: these are denied: a builder creating a staff org, joining the staff org, promoting a member, turning their org into staff, deleting a user, and staff editing a user.
4. PASS: `anon` can't read identity tables.

## Follow-up tasks
None. This closes Epic STW-2 (Identity, Tenancy & RLS Core).
