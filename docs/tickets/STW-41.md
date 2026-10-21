# STW-41 — Part 3 write-up: what I'd build next

- **Jira:** https://stratyge.atlassian.net/browse/STW-41
- **Branch:** `docs/stw-41/what-id-build-next`
- **Status:** Code Review

## Overview
A reasoned pick for the next step, so a reviewer can see product judgment. Docs only.

Acceptance criteria:
- 'What I'd build next' picks one option (or a justified own idea) and says who it helps.
- States why it is the most valuable next step, roughly how to build it, and what to leave out.
- Says plainly whether it was built.

## Implementation details
- New `docs/what-id-build-next.md`, about one page. It picks the **late-change alert** over the "due soon" warning; these are the two Part 3 cases named in the `supabase/seed.sql` header (Lot 15 / Lot 14). It covers who it helps (builder admins), why (no screen shows it today, a miss costs more, and it reuses `alerts.kind = 'late_change'` and the definer history trigger), a rough build (an AFTER INSERT trigger on `selection_history`, `alerts.history_id` with `unique (history_id, user_id)`, no new grants or policies, a `/alerts` label, a SQL test plan, the rollback), a leave-out list, and "Built: no (planned as STW-42)".
- `DESIGN.md`: a short "What I'd build next" section linking to it.
- Written in the candidate's voice as a draft for the candidate to review.

## API changes
None.

## Database changes
None. The planned schema change is only described; STW-42 would deliver it.

## Dependencies on other tickets
Builds on what has merged: STW-23 (history trigger), STW-22/31 (alerts and episodes), STW-26 (views) and STW-32 (detector). STW-42 implements the plan.

## Known limitations
- The original brief options (BRIEF.md) are not in the repo. The two candidates were inferred from the seed header comments.
- The rule ("changed/cleared while status is revision or complete") is a proposal. STW-42 should confirm it before building.

## Testing notes
Docs only: no code, no migration. Checked every claim against the merged migrations: the `alerts.kind` check allows `'late_change'`, `alerts_episode_user_key`, the `v_projects.selection_due_date` column, and the `actor_kind` computed in `private.record_selection_history()`. The DESIGN.md link resolves to the new file.

## Follow-up tasks
- STW-42: implement the late-change alert as described.
- After that, a possible "due soon" warning added to the detector loop.
