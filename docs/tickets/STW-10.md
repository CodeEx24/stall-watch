# STW-10 — Write and commit first DESIGN.md before any code

- **Jira:** https://stratyge.atlassian.net/browse/STW-10 (blueprint US-002)
- **Branch:** `docs/stw-10/initial-design-note`

## Overview
A short `DESIGN.md` committed before any app or migration code, so reviewers can see the decisions came first.

## Implementation details
`DESIGN.md` at the repo root: the Candidate and Hours spent lines, then Problem, Goals, Non-goals, Planned data, Planned permissions, and a decisions table with rejected alternatives. The decisions summarise ADR-001 to ADR-009 in `docs/architecture.md`.

## API changes
None.

## Database changes
None (planned schema only).

## Dependencies on other tickets
Blocks STW-11 (scaffold) and STW-41 (Part 3 write-up). STW-40 finalises DESIGN.md and fills in Hours spent.

## Known limitations
`Hours spent: 0` is a placeholder until STW-40.

## Testing notes
- First two lines checked with `head -2 DESIGN.md`.
- Ordering: `git log --reverse --format="%h %s" -- DESIGN.md` against the first app/migration commit (none exist at merge time).

## Follow-up tasks
STW-40: final DESIGN.md and real hours.
