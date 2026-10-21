# Action for you: the pre-submission checks an agent can't do (STW-43) — PENDING

**Who:** you, the owner of the Supabase, Vercel and GitHub accounts.
**When:** before STW-44 (submitting). Do part 1 and 2 in any order; part 3 last.
**Jira:** https://stratyge.atlassian.net/browse/STW-43
**Agent evidence so far:** `docs/tickets/STW-43.md` (secret scan clean, local CI green on `main`, local browser story PASS as Ana / Mia / Bruno / Sam, live site and hosted API checks).

Never paste a database password, user password or key into chat, a Jira comment, or any file in the repo.

---

## 1. Fresh hosted rebuild from SETUP.md only (AC1)

Proves that a teammate can rebuild production from the repo. It needs a **second, throwaway** Supabase project; the Free plan allows two active projects and `stall-watch` is the first. Don't touch `stall-watch` (`wgfxpdrlijzxkqaxlrbc`) during this.

Partial evidence already exists: the **local** half of SETUP.md (Part A) was followed literally on scratch stacks three times (STW-39 implementer, STW-39 reviewer, and STW-43's CI replay: 16 migrations, seed, 4 users, all SQL tests passed). The hosted half (Part B) has only been done once, by you, while building it.

### Steps
1. Use a fresh clone so your normal checkout's CLI link isn't changed:
   ```bash
   git clone https://github.com/CodeEx24/stall-watch.git stall-watch-rebuild
   cd stall-watch-rebuild && npm ci
   ```
2. Follow **SETUP.md Part B, B1 to B7, word for word**, with these two changes only:
   - B1: name the project `stall-watch-rebuild` (any region). Save its database password in your password manager.
   - B7: you can reuse the four test emails; choose a throwaway password. These users exist only in the scratch project.
   Write down every place where SETUP.md was unclear or wrong. That list is the real output of this check.
3. Check the result: in the scratch project's **SQL Editor**, run:
   ```sql
   select (select count(*) from public.orgs)              as orgs,        -- 3
          (select count(*) from builder.projects)         as projects,    -- 9
          (select count(*) from builder.project_slots)    as slots,       -- 43
          (select count(*) from builder.selections)       as selections,  -- 22
          (select count(*) from builder.selection_history) as history,    -- 26 (before anyone edits)
          (select count(*) from cron.job)                 as cron_jobs,   -- 1
          (select count(*) from public.memberships)       as memberships; -- 4
   ```
   Then `npx -y supabase@2.121.0 migration list` in the clone: Local and Remote columns both list 16 migrations.
4. Optional, closer to a real teammate: in the clone, create `.env.local` (SETUP.md A6) pointing at the scratch project's URL and **publishable** key, run `npm run dev`, sign in as `ana@builder-a.test`. Expected: 5 projects, Lot 12 Stalled.
5. **Clean up:** scratch project → **Project Settings → General → Delete project** (or **Pause project** if you want to keep it). Delete `.env.local` and the clone. Then re-link your normal checkout only if you ran step 1 there by mistake: `npx -y supabase@2.121.0 link --project-ref wgfxpdrlijzxkqaxlrbc`.

### Record
Reply to Claude with: the counts, the migration list result, and "SETUP.md worked as written" or the list of problems (Claude will fix the doc in a follow-up PR).

---

## 2. Supabase Security and Performance Advisors (AC2)

Agent proxy already done: the same lint queries the Advisors run (Supabase's open-source `splinter.sql`) were run read-only against a scratch stack built from the repo, plus `db lint --linked` on the hosted project (no errors). Expected dashboard results are below. The dashboard also has checks that aren't in the SQL (Auth settings), so open it yourself.

### Steps
1. https://supabase.com/dashboard/project/wgfxpdrlijzxkqaxlrbc → **Advisors → Security Advisor**. Click **Rerun linter** (top right) if offered. Look at the **Errors**, **Warnings** and **Info** tabs.
2. Same place → **Performance Advisor** → **Rerun linter**.
3. For each item, compare with the table below.

| Advisor | Expected item | Level | Verdict |
|---|---|---|---|
| Security | **No errors.** (RLS is enabled and forced on all 10 tables; no `security definer` views; no table without policies) | — | must be zero |
| Security | `authenticated_security_definer_function_executable`: `public.run_stall_detector_now()` | WARN | **Accepted by design** (ADR-001, STW-33). It is the staff "Run now" RPC; its first statement raises `42501` unless `private.is_staff()`. Anonymous callers get `42501` from the grant (verified on the live API). |
| Security | Auth items such as *Leaked password protection disabled* | WARN | Accepted: password breach checking is a paid-plan feature; sign-up is not part of the product (test users only). |
| Security | Anything else at WARN or ERROR | — | **Stop and tell Claude** (screenshot or copy the text). |
| Performance | `unindexed_foreign_keys` on `alerts`, `project_slots`, `selection_history`, `selections`, `stall_episodes` (9 items) | INFO | Accepted for now: the tables hold tens of rows, so the missing indexes cost nothing measurable. Recorded as a follow-up in `docs/tickets/STW-43.md`, not a blocker. |
| Performance | `unused_index` | INFO | Accepted: a demo database with almost no traffic uses few indexes. |
| Performance | `auth_rls_initplan` or `multiple_permissive_policies` | WARN | Not expected (the scratch-stack lint run found none). If shown, tell Claude. |

### Record
Reply to Claude with: "Security: N errors, M warnings (list)" and "Performance: …", or paste screenshots into the Jira ticket. Claude adds them to `docs/tickets/STW-43.md`.

---

## 3. Walk the brief's story on the live site (AC3)

The same walk passed automatically on the local stack. On the live site only you can sign in (the hosted passwords are yours).

Open https://stall-watch.vercel.app/ in a **private window** for each user (or sign out between users).

| As | Do | Expected |
|---|---|---|
| (signed out) | open `/projects` | lands on `/login` |
| Ana `ana@builder-a.test` | sign in | `/projects`: 5 projects (Lot 12, Lot 14, Lot 15, Lot 9, Lot 3 archived), all Builder A; **Lot 12 Stalled** |
| Ana | click Lot 12 | 4 rooms, 8 slots |
| Ana | open `/alerts` | a **Stalled** alert for Lot 12 (see note A) |
| Ana | open `/detector` | "Staff only", no Run now button |
| Ana | copy the Lot 12 address bar URL (you'll need it for Bruno) | |
| Mia `mia@builder-a.test` | sign in, `/projects`, then `/alerts` | same 5 projects with Lot 12 Stalled; **"You have no alerts."** (members get no stall alerts) |
| Bruno `bruno@builder-b.test` | sign in | only Unit 2A, 4B, 5A, 7C; **Unit 4B and Unit 7C Stalled** (7C is the trap: staff touched it yesterday, but staff activity doesn't count) |
| Bruno | paste Ana's Lot 12 URL | "404 This page could not be found." and nothing about Lot 12 |
| Bruno | `/alerts` | Stalled alerts for Unit 4B and Unit 7C |
| Sam `staff@stallwatch.test` | sign in | all 9 projects with the Builder column showing Builder A / Builder B; Lot 12, 4B, 7C Stalled |
| Sam | open `/detector` | run history table (scheduled runs at 18:00 UTC each night, plus any manual ones) |
| Sam | `/alerts` | no stall alerts (staff only receive late-change alerts, see note B) |

**Note A — no alerts yet?** Stall alerts are created by the detector, which runs nightly at 18:00 UTC (02:00 Manila). If Ana's `/alerts` is empty, sign in as Sam, open `/detector`, click **Run now once**, and re-check Ana. Bruno then gets his two alerts too.
**Note B:** if anyone changed a selection on Lot 15 (in `revision`), Sam has a *Late change* alert. That is the STW-42 feature working, not a leak.
**Note C — the seed ages.** `seed.sql` dates are relative to when it was loaded. About 5 days after the load, Unit 5A (entered selection phase 2 days before the load) becomes stalled, and about 6 days after, Lot 14 (last builder activity 1 day before the load), unless someone selects something there. That is the detector working correctly; mention it if a reviewer asks.

### Record
Reply "live walk OK" or list what differed.

---

## 4. Optional: make the repo public, then confirm CI is green on GitHub

Making the repo public is required for STW-44 anyway (the submission needs a public repo link). It also lets GitHub Actions run for free, which turns "CI green on main" from local evidence into a green check on GitHub.

1. Only after the STW-43 secret scan is clean (it is: see `docs/tickets/STW-43.md`) and STW-43's PR is merged, follow `docs/actions/STW-44-submit.md` step 1 to change visibility.
2. `ci.yml` has no manual trigger, so either merge the next PR into `main`, or open the last `main` run under GitHub → **Actions** → **CI** and click **Re-run all jobs**.
3. Expected: both jobs green, `lint, typecheck, build` (~2 min) and `database (migrations, seed, SQL tests)` (~5–8 min; first run downloads images).
4. If a job fails, tell Claude with the run link.

## Done when
**Status checked 2026-10-21 (Claude, read-only):**
- Rebuild: **not done.** Your Supabase account has only one project (`stall-watch`), so no scratch rebuild project exists yet.
- Advisors: **not confirmed.** Claude can't open the dashboard Advisors; reply with the result and Claude ticks it.
- Live walk: **not done.** On the hosted project Ana, Mia and Bruno have never signed in (`last_sign_in_at` empty); staff signed in once on 2026-10-21 03:53 UTC.
- **Heads-up for the walk:** the hosted detector has **never run yet** (0 runs, 0 alerts). Its first nightly run is 18:00 UTC = 02:00 Manila. If you walk before that, sign in as Sam, open `/detector`, click **Run now** once, then Ana and Bruno see their alerts (note A).
- Repo public / Actions green: **not done.** Repo is still private; every Actions run is "not started" (billing).

- [ ] Hosted rebuild on a scratch project matched the counts; scratch project deleted or paused
- [ ] Security Advisor: 0 errors; every warning is in the "accepted" rows above
- [ ] Performance Advisor reviewed; nothing beyond the expected INFO items
- [ ] Live walk as Ana, Mia, Bruno and Sam matched the table
- [ ] (Optional) Repo public and the first GitHub Actions run on `main` is green
