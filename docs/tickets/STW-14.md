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
None. Action versions are pinned to major tags (`@v4`).

## Testing notes
- A deliberate lint error was pushed to this PR once: CI failed at `npm run lint` (run link in the PR). It was then reverted, and CI is green.
- `grep -n secrets .github/workflows/ci.yml` finds nothing.

## Follow-up tasks
STW-37 database job; enable branch protection requiring this check.
