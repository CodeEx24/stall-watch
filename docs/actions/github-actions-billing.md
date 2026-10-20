# Action for you: unblock GitHub Actions (CI won't start)

**Who:** you, the account owner (`CodeEx24`). This is a billing setting.
**When:** now. It blocks STW-14 and every PR's CI after it.
**Jira:** https://stratyge.atlassian.net/browse/STW-14

## What happened
PR #5's first CI run failed in 4 seconds without running any step. GitHub's annotation says:

> The job was not started because recent account payments have failed or your spending limit needs to be increased. Please check the 'Billing & plans' section in your settings

The repo is **private**, so Actions minutes count against your account's quota and billing.

## Current decision (2026-10-20): optional
You chose to **bypass GitHub CI for now**. The workflow stays in the repo (STW-14), but every PR is checked locally instead: the merge-gate reviewer runs `npm ci && npm run ci` in a clean worktree, and treats a job that "was not started" as *CI unavailable*, not red. Nothing below is required. Do it only if you later want GitHub to run CI itself.

## Fix (optional): pick one
**Option A: fix billing (keeps the repo private).**
1. Open https://github.com/settings/billing.
2. If a payment failed, go to **Payment information**, update the card, and retry the payment.
3. Open **Spending limits** (or **Budgets and alerts**) → **Actions**. If the budget is $0 *and* the free private minutes are used up, raise the limit a little (a few dollars covers this project), or wait for the monthly quota to reset.
4. Check **Usage this month → Actions** to confirm minutes are available.

**Option B: make the repo public (Actions minutes are free and unlimited for public repos).**
Only do this if the trial allows a public repo: the README, DESIGN.md and code would be visible to anyone. Secrets are never in git, so nothing sensitive would leak.
1. https://github.com/CodeEx24/stall-watch/settings, then **Danger Zone → Change visibility → Public**.

## After fixing
Tell Claude "Actions billing fixed". Claude re-runs PR #5's CI, shows the deliberate lint failure (STW-14 AC2), reverts it, confirms green, and lets the merge gate merge.

## Done when
- [ ] Re-running the PR #5 workflow actually executes steps (`npm ci`, lint, …)
