# STW-40 — Finalize DESIGN.md

- **Jira:** https://stratyge.atlassian.net/browse/STW-40
- **Branch:** `docs/stw-40/finalize-design`

## Overview
Turns the planning-stage `DESIGN.md` (STW-10) into the final design note, now that every screen, the detector, the cron job, the Run now RPC, the late-change alert (STW-42), the CI database job (STW-37), SETUP.md (STW-39) and the migrations audit (STW-38) are merged.

Acceptance criteria:
- Detector section states where it runs, how it gets permission, what stops duplicates, and what was given up.
- 'Rules I bent' and 'What I cut' sections exist, listing any rule broken on purpose and why.
- The first two lines still read Candidate and Hours spent with an honest total; the note is 1 to 2 pages.

## Implementation details
- `DESIGN.md` rewritten (about 1,000 words, roughly 2 pages): Problem · Goals and non-goals · Data and permissions · **Stall detector** (where it runs, how it gets permission, what stops duplicates, failures, what I gave up) · Decisions and rejected alternatives · **Rules I bent** · **What I cut** · What I'd build next. The "Planned data / Planned permissions" sections became "Data and permissions", because they describe what was built. The STW-42 late-change note is kept, shortened.
- Every claim was checked against the merged code: migrations `20261020140000` (constraint names `stall_episodes_project_quiet_key`, `alerts_episode_user_key`), `160000` (definer, `search_path = ''`, `pg_advisory_xact_lock(2026032)`, revoke from public/anon/authenticated, inner exception block), `170000` (first statement `is_staff()` check, `42501`), `171000` (`stall-detector-daily`, `0 18 * * *`), `180000` (`alerts_history_user_key`); `supabase/tests/detector_scenarios.sql` (trigger disable/enable inside the rolled-back test); `src/features/*/schemas.ts` (`z.guid()`); `mark-alert-read.ts` (`new Date()`); `src/app/layout.tsx` (no nav); the Known limitations sections of `docs/tickets/STW-14…STW-42`.
- I left out claims that the code doesn't support. For example, there is no "one open episode per project" constraint; uniqueness is on `(project_id, quiet_since)`.
- **Hours spent:** line 2 now reads `Hours spent: TBD (candidate to fill in before submission)`. Only the candidate knows the honest total, so `docs/actions/STW-40-hours-spent.md` asks the owner to replace it before submitting.
- Small documentation follow-ups from earlier reviews:
  - `SETUP.md` Part C: describes both CI jobs (`ci` and the STW-37 `database` job) and drops the stale "no database job yet" sentence.
  - `scripts/create-local-test-users.sh`: the usage comment now shows the `read -rs` hidden-prompt form from SETUP A3, replacing the inline-password form. Comment only.
  - `MIGRATIONS.md`: notes that the `20261020171000` header's "SETUP.md section 2, step 3" is now SETUP **B2**. The migration itself is not edited.

## API changes
None.

## Database changes
None.

## Dependencies on other tickets
Blocked by everything it describes (STW-31…STW-39, STW-42), all merged. It feeds STW-44 (submission).

## Known limitations
- The honest hours total isn't filled in yet. That's a person action (`docs/actions/STW-40-hours-spent.md`). Until it's done, the third AC is only partly met.
- "1 to 2 pages" was measured as word count (`wc -w DESIGN.md` ≈ 1,030 including markdown), not by printing the file.

## Testing notes
- `head -2 DESIGN.md` → `Candidate: Jocarl Basco` / `Hours spent: TBD (candidate to fill in before submission)`.
- `grep -n "^## " DESIGN.md` lists Stall detector, Rules I bent and What I cut.
- `npm ci && npm run ci` (lint, typecheck, build) and `npm run check:migrations` pass. No SQL changed, so `test:db` was not re-run.
- `bash -n scripts/create-local-test-users.sh` passes (only the comment changed).

## Follow-up tasks
- Owner: fill in Hours spent (action doc above).
- When GitHub Actions is unblocked, replace "CI is run locally" in Rules I bent with a link to the first green run.
