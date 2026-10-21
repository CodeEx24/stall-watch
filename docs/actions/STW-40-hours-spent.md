# Action for you: fill in your honest Hours spent in DESIGN.md (STW-40)

**Who:** you, the candidate. Only you know how many hours you actually spent; Claude cannot.
**When:** before you submit the repository to Reverie3D (STW-44).
**Jira:** https://stratyge.atlassian.net/browse/STW-40

## Why
The STW-40 acceptance criteria require that the first two lines of `DESIGN.md` read Candidate and Hours spent **with an honest total**. STW-40 left line 2 as a placeholder:

```
Hours spent: TBD (candidate to fill in before submission)
```

Reverie3D compares this number with the estimate you sent in STW-9 (about 7 hours). A low number that isn't true is worse than a high number that is.

## Steps
1. Add up your own time on Stall Watch: reading the brief, planning, building, reviewing, setup (Supabase, Vercel, GitHub) and writing. Count the time you spent directing and checking Claude's work. Don't count time when nobody was working.
2. Edit line 2 of `DESIGN.md` so it reads, for example, `Hours spent: 9.5`. Use one number, optionally followed by a short note in parentheses (e.g. `Hours spent: 9.5 (incl. ~1 h hosted setup)`). Leave line 1 (`Candidate: Jocarl Basco`) exactly as it is.
3. Check: `head -2 DESIGN.md` shows the two lines and no `TBD`.
4. Commit it on a short branch, e.g. `docs/stw-40/hours-spent`, with `docs(design): record hours spent (STW-40)`, and open a PR (or tell Claude "hours: <n>" and Claude will do it with your number, unchanged).

## Done when
- [ ] Line 2 of `DESIGN.md` holds your honest total (no `TBD`)
- [ ] The change is merged to `main` before submission
