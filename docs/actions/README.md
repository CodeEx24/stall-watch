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
| [STW-40-hours-spent.md](STW-40-hours-spent.md) | Honest hours on DESIGN.md line 2 | `Hours spent: 8` (2026-10-21) |
| [STW-44-submit.md](STW-44-submit.md) § 1 | Make the repo public | Repo is PUBLIC; GitHub Actions now runs and is green on `main` |

## Still to do (in this order)
| # | Guide | What | Status found |
|---|---|---|---|
| 1 | [STW-43-pre-submission.md](STW-43-pre-submission.md) § 1 | Rebuild on a throwaway 2nd Supabase project from SETUP.md | Not done: only one Supabase project exists |
| 2 | [STW-43-pre-submission.md](STW-43-pre-submission.md) § 2 | Review Security + Performance Advisors | Not confirmed (Claude can't see the dashboard) |
| 3 | [STW-43-pre-submission.md](STW-43-pre-submission.md) § 3 | Walk the story on the live site as Ana, Mia, Bruno, Sam | In progress: signed-out and staff OK. Production data was **reset to the seed on 2026-10-21** (Lot 12, Unit 4B, Unit 7C stalled again; 0 runs) |
| 4 | [STW-44-submit.md](STW-44-submit.md) § 2–3 | Two one-time secret links + send the message | Not started |
| 5 | [STW-44-submit.md](STW-44-submit.md) § 4 | Keep Supabase + Vercel up 7 days | Starts after sending |

**Before step 3:** after the reset the detector has 0 runs. Sign in as staff → `/detector` → **Run now** once (3 projects flagged, 3 alerts: Ana gets Lot 12, Bruno gets Unit 4B and Unit 7C). With Lot 12 stalled again, Ana can lead the email's walk again; the "Note D" and Bruno-first wording from 2026-10-21 apply only if Lot 12 is un-stalled again.

## Optional
| Guide | What | Status found |
|---|---|---|
| [github-actions-billing.md](github-actions-billing.md) | Let GitHub Actions run CI | Resolved by the public repo: both CI jobs run and pass |
| [github-branch-protection.md](github-branch-protection.md) | Protect `main` on GitHub | Now possible (repo is public); not set up yet |

When you finish a step, tell Claude (for example "hours: 9.5", "advisors: 0 errors", "live walk OK", "repo is public", "submitted"). Claude re-checks, ticks the box and updates Jira.
