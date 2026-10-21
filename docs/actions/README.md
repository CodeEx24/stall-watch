# Your actions — status board

Last checked: **2026-10-21** by Claude (read-only checks of GitHub, the hosted Supabase project, the live site and `main`).
Each guide has the step-by-step instructions and its own "Done when" checklist. Ticked boxes were verified; unticked ones are still open.

## Done
| Guide | What | Evidence |
|---|---|---|
| [STW-9-send-estimate.md](STW-9-send-estimate.md) | Estimate email sent | You confirmed; STW-9 Done in Jira |
| [STW-12-create-supabase-project.md](STW-12-create-supabase-project.md) | Supabase project, pg_cron, CLI login + link | Project `stall-watch` ACTIVE_HEALTHY; pg_cron on; CLI linked |
| [seed-files.md](seed-files.md) | Seed files added | Committed unchanged (PR #12) |
| [STW-13-vercel-project.md](STW-13-vercel-project.md) | Vercel project + env vars | https://stall-watch.vercel.app/ live; `/login` 200, `/projects` → `/login` when signed out |
| [hosted-database.md](hosted-database.md) | Push migrations, expose `builder` | 16 of 16 migrations on hosted; Claude now pushes new ones itself |
| [STW-24-hosted-test-users.md](STW-24-hosted-test-users.md) | Seed + 4 users on hosted | 3 orgs, 9 projects, 4 confirmed users, 4 memberships |

## Still to do (in this order)
| # | Guide | What | Status found |
|---|---|---|---|
| 1 | [STW-40-hours-spent.md](STW-40-hours-spent.md) | Put your honest hours on DESIGN.md line 2 | Not done: still `TBD` |
| 2 | [STW-43-pre-submission.md](STW-43-pre-submission.md) § 1 | Rebuild on a throwaway 2nd Supabase project from SETUP.md | Not done: only one Supabase project exists |
| 3 | [STW-43-pre-submission.md](STW-43-pre-submission.md) § 2 | Review Security + Performance Advisors | Not confirmed (Claude can't see the dashboard) |
| 4 | [STW-43-pre-submission.md](STW-43-pre-submission.md) § 3 | Walk the story on the live site as Ana, Mia, Bruno, Sam | In progress? Bruno signed in (09:31 UTC); Ana and Mia never have. Tell Claude "live walk OK" when done |
| 5 | [STW-44-submit.md](STW-44-submit.md) § 1 | Make the repo public | Not done: repo is private |
| 6 | [STW-44-submit.md](STW-44-submit.md) § 2–3 | Two one-time secret links + send the message | Not started |
| 7 | [STW-44-submit.md](STW-44-submit.md) § 4 | Keep Supabase + Vercel up 7 days | Starts after sending |

**Before step 4:** the hosted detector hasn't run yet (0 runs, 0 alerts). It first runs tonight at 02:00 Manila (18:00 UTC). If you walk earlier, sign in as Sam → `/detector` → **Run now** once, so Ana and Bruno have their alerts.

## Optional (fixed for free by step 5)
| Guide | What | Status found |
|---|---|---|
| [github-actions-billing.md](github-actions-billing.md) | Let GitHub Actions run CI | Not done: every run "not started" (billing). Public repo fixes it |
| [github-branch-protection.md](github-branch-protection.md) | Protect `main` on GitHub | Not possible while private (GitHub returns 403); possible once public |

When you finish a step, tell Claude (for example "hours: 9.5", "advisors: 0 errors", "live walk OK", "repo is public", "submitted"). Claude re-checks, ticks the box and updates Jira.
