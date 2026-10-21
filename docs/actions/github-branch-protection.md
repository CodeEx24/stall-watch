# Action for you: protect `main` on GitHub

**Who:** you, the repo owner (`CodeEx24`). This is a repository setting.
**When:** right after the CI workflow (STW-14) is merged, so the `ci` check exists and can be required.
**Jira:** supports STW-14 ("a red PR is never merged").

## Why
The local Claude hooks (no push to main, no force push) are a convenience and can be bypassed. GitHub's branch protection is enforced on the server for everyone, including Claude's merge-gate reviewer.

## Steps
1. Open https://github.com/CodeEx24/stall-watch/settings/rules and choose **New ruleset → New branch ruleset**.
2. Name: `protect-main`. Enforcement status: **Active**.
3. Target branches: **Add target → Include default branch** (`main`).
4. Turn on:
   - **Restrict deletions**
   - **Block force pushes**
   - **Require a pull request before merging**, with required approvals set to **0**. (You and Claude use the same GitHub account, and GitHub doesn't let an account approve its own PR. The merge-gate review comment stands in for the approval.)
     - Under *Allowed merge methods*, untick **Squash** (the project rule is merge commit or rebase, never squash).
   - **Require status checks to pass**: **skip this for now.** GitHub Actions can't run on the free private account (see `github-actions-billing.md`), so a required check would block every merge. Local checks (`npm run ci`, run by the merge-gate reviewer) stand in. If Actions becomes available, add the job `lint, typecheck, build` here and tick **Require branches to be up to date before merging**.
5. Leave **Bypass list** empty.
6. Click **Create**.
7. Tell Claude "main is protected". Claude will check it with `gh api repos/CodeEx24/stall-watch/rulesets`.

## Done when
**Status checked 2026-10-21 (Claude, read-only):** **not done, and not possible yet.** GitHub answers "Upgrade to GitHub Pro or make this repository public to enable this feature" (HTTP 403) for both rulesets and branch protection. Once the repo is public (STW-44 step 1) these steps work. Optional: local hooks and the merge-gate reviewer stand in.

- [ ] A direct push to `main` is rejected by GitHub
- [ ] A PR with red CI cannot be merged
- [ ] Squash merge is not offered
