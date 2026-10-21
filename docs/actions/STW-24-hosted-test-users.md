# Action for you: load the seed and create the test users on the hosted project (STW-24)

**Who:** you. The passwords are yours to choose and must never be committed.
**When:** after PRs #17/#18 merge and you've run `! npx supabase db push`, so the hosted DB has every migration.
**Project:** `wgfxpdrlijzxkqaxlrbc`.
**Jira:** https://stratyge.atlassian.net/browse/STW-24

## Why
The deployed app (https://stall-watch.vercel.app/) needs the provided sample data and four users to demonstrate every scenario. Locally this is already done with `npm run db:local-users` and `npm run db:local-link`.

## Steps
1. **Load the seed (once).** Dashboard → **SQL Editor → New query**. Paste the full contents of `supabase/seed.sql` and click **Run**. Expected: success, with no rows returned.
   - Run it only once. Running it again fails on duplicate org ids, and that's harmless.
2. **Create the four users.** Dashboard → **Authentication → Users → Add user → Create new user**, ticking **Auto Confirm User** for each:
   | Email | Role after linking |
   |---|---|
   | `staff@stallwatch.test` | admin of Reverie3D Studio (staff) |
   | `ana@builder-a.test` | admin of Builder A |
   | `bruno@builder-b.test` | admin of Builder B |
   | `mia@builder-a.test` | member of Builder A |
   Use a password you choose and keep it in your password manager. **Don't paste it into chat or any file in the repo.** (STW-44 shares the credentials with Reverie3D through one-time secret links.)
3. **Link them to their orgs.** SQL Editor → New query → paste `supabase/link-test-users.sql` → **Run**. It's safe to run twice. If it says "Not found in public.users", the auth-mirror trigger isn't on the hosted DB yet, so run `db push` first.
4. Tell Claude "hosted users linked". Claude then signs in through the hosted API without seeing your password (you type it at a hidden prompt), or you confirm the row counts below.

## Expected (same as local)
| User | Projects visible |
|---|---|
| ana / mia | 5 (Builder A) |
| bruno | 4 (Builder B) |
| staff | 9 (all) |
| anonymous | denied (42501) |

## Done when
- [ ] `seed.sql` ran once without error
- [ ] Four users exist and are confirmed
- [ ] `link-test-users.sql` ran clean (twice is fine)
