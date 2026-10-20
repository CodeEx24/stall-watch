# STW-14 — CI: lint, typecheck and build on every PR

- **Jira:** https://stratyge.atlassian.net/browse/STW-14 (blueprint US-006)
- **Branch:** `ci/stw-14/lint-typecheck-build`

## Overview
A GitHub Actions workflow runs `npm run lint`, `npm run typecheck` and `npm run build` on every pull request and on every push to `main`, so a red PR is never merged.

## Implementation details
- `.github/workflows/ci.yml`, one job `ci` ("lint, typecheck, build"): checkout without persisted credentials, Node 22 with npm cache, `npm ci`, then lint, typecheck and build in the same order as the README.
- `permissions: contents: read`; no `secrets.*` and no `env` values other than `NEXT_TELEMETRY_DISABLED`.
- `concurrency` cancels superseded runs on the same ref.
- STW-37 adds a second job (database: seed + SQL tests).

## API changes
None.

## Database changes
None.

## Dependencies on other tickets
Blocked by STW-11. Blocks STW-37 (CI database job). After merge, `main` should be protected with this check required (`docs/actions/github-branch-protection.md`).

## Known limitations
- The workflow is in place but GitHub won't run it until Actions billing allows (`docs/actions/github-actions-billing.md`); local `npm run ci` is the gate meanwhile.
- Action versions are pinned to major tags (`@v4`).

## Testing notes
- GitHub Actions does not start jobs on this free private account (billing annotation on run 39411386914). By owner decision, CI is bypassed on GitHub and the same steps run locally: `npm run ci` = lint, then typecheck, then build. The merge-gate reviewer runs `npm ci && npm run ci` in a clean worktree for every PR.
- AC2 demo: commit `6038a73` added `src/app/lint-canary.ts` with an `any`. `npm run lint` exited **1** (`@typescript-eslint/no-explicit-any`). Commit `6305217` reverted it, and `npm run ci` exits **0**.
- `grep -n secrets .github/workflows/ci.yml` finds nothing.

## Follow-up tasks
STW-37 database job; enable branch protection requiring this check.
