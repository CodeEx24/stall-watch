# Action for you: add the provided seed files — DONE (2026-10-20)

**Who:** you. The files come from the Reverie3D trial pack.
**When:** as soon as you can. They're needed by STW-24, and their columns may shape STW-16 and STW-20.
**Jira:** https://stratyge.atlassian.net/browse/STW-24

## Why
The setup prompt says `seed.sql` and `link-test-users.sql` are **provided** and must be copied into `supabase/`. The schema has to accept exactly what they insert, so Claude checks every table and column against them.

## Steps
1. Find both files in the trial materials (email attachment, zip or shared drive).
2. Copy them into the repo as `supabase/seed.sql` and `supabase/link-test-users.sql`. Don't edit them.
3. Make sure neither contains a real password, API key or service-role key. If one does, tell Claude before committing. Test-user passwords belong in the one-time secret links (STW-44), not in git.
4. Tell Claude "seed files added". Claude compares them with the migrations, adjusts the schema with a new migration if needed, and commits them on the STW-24 branch.

## Done when
- [x] `supabase/seed.sql` and `supabase/link-test-users.sql` exist (committed unchanged in PR #12, byte-identical to the provided files)
- [x] Claude has confirmed the schema matches them (seed.sql applies unchanged: 3 orgs, 9 projects, 43 slots, 22 selections, 26 history; no passwords or keys in either file)
