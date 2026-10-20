# STW-24 — Load seed.sql, create test users, link memberships

- **Jira:** https://stratyge.atlassian.net/browse/STW-24 (blueprint US-016)
- **Branch:** `feat/stw-24/seed-and-test-users`

## Overview
The provided sample data and four test users, so every scenario (stalled, not stalled, staff trap, isolation) can be exercised.

## Implementation details
- `supabase/seed.sql` and `supabase/link-test-users.sql` are the provided files, committed unchanged in PR #12. `config.toml` `[db.seed] sql_paths = ["./seed.sql"]`, so `supabase db reset` loads it locally.
- `scripts/create-local-test-users.sh` (`npm run db:local-users`): signs up the four users on the **local** stack through the Auth API with the **publishable key** (no service-role key). The password comes from `LOCAL_TEST_PASSWORD`, which is never written to disk or printed. It refuses any non-`127.0.0.1` API, is idempotent (existing users are skipped), and local signup auto-confirms.
- `scripts/link-local-test-users.sh` (`npm run db:local-link`): runs the provided `link-test-users.sql` as the DB owner and prints the resulting memberships.
- Hosted project: a person action (`docs/actions/STW-24-hosted-test-users.md`): run `seed.sql`, create the users in the dashboard with Auto Confirm, then run `link-test-users.sql`.
- `SETUP.md` §3 documents the local flow.

## API changes
None.

## Database changes
None (data only).

## Dependencies on other tickets
Blocked by STW-17 (auth mirror), STW-21 and STW-22. Stacked on STW-23 (shared local DB). Blocks STW-25 (isolation tests), STW-26 (stall views) and STW-27 (login).

## Known limitations
- Hosted users and seed are pending the person action.
- Passwords are deliberately not in the repo. Reverie3D receives them in STW-44 through one-time secret links.

## Testing notes
On the local stack (all 10 migrations applied):
- AC1: `seed.sql` applied **unchanged**, giving 3 orgs, 9 projects, 43 slots, 22 selections and 26 history rows. With the STW-23 trigger present history is **not** duplicated, because the seed runs with triggers off.
- AC2: `npm run db:local-users` created all four users; a second run skipped all four ("User already registered"). `npm run db:local-link` ran **twice, clean** (exit 0 both times); memberships stayed at 4.
- AC3: memberships are `staff@stallwatch.test → Reverie3D Studio (admin)`, `ana → Builder A (admin)`, `bruno → Builder B (admin)` and `mia → Builder A (member)`. `git grep` finds no password in the repo.
- E2E through the real local GoTrue and PostgREST (sign in per user, count visible builder rows):
  - ana / mia: 5 projects, 25 slots, 19 selections, 22 history rows
  - bruno: 4 projects, 18 slots, 3 selections, 4 history rows
  - staff: 9 projects, 43 slots, 22 selections, 26 history rows
  - anon: denied (42501)

## Follow-up tasks
STW-25 turns the isolation checks into committed SQL tests; STW-44 shares the credentials.
