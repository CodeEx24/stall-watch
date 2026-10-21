# What I'd build next

**Pick: a "late change" alert.** It tells a builder's admins, when it happens, that a selection was changed or cleared on a project whose selection set was already done (status `revision` or `complete`). The seed's Lot 15 is this case: all 6 slots filled, project in `revision`.

**Built: no.** It is planned as STW-42 (stretch). This page is the plan for it.

## Who it helps
**Builder admins.** They order materials and schedule trades against the finished set, and they get the stall alerts today. Reverie3D staff gain indirectly: they also edit selections, and once this exists a staff change on a finished project is reported to the builder instead of passing silently.

## Why this beats the "due soon" warning
- **It shows something nobody can see today.** The `/projects` list from STW-28 shows each project's due date (`v_projects.selection_due_date`) and empty-slot count, so Lot 14's deadline is visible there. A due-soon warning would repeat what that list shows. A late change appears only as a row in `selection_history`, and no screen shows that history in a way that would get noticed.
- **A miss costs more.** A late due date shows up on its own, and the stall alert already covers the quiet project that is heading for one. A late change can quietly invalidate materials ordered for the old choice, and nobody finds out until the wrong countertop arrives.
- **It reuses what exists.** `builder.alerts.kind` already allows `'late_change'`. The definer history trigger is already the one place every set/change/clear passes through, and it already computes `actor_kind`. The recipient-only alert RLS and the `/alerts` inbox need no change.
- **Main risk: noise.** Five edits during one revision create five alerts. I accept that for v1 because each alert is a real change that someone has to check. Grouping them can come later (see below).

## Rough build (one migration, one SQL test, a small UI tweak)
- **Rule:** a new `builder.selection_history` row with `action in ('change', 'clear')` whose project has `status in ('revision', 'complete')` and `archived_at is null` at that moment. A `set` filling an empty slot does not count. So clearing and then re-setting a slot on a finished project alerts only on the clear, which is the moment the finished set breaks. Using the project status, rather than "all slots filled", follows the builder's own sign-off and doesn't flicker while slots are being refilled.
- **Trigger, not the scheduled job:** an `AFTER INSERT` trigger `trg_late_change_alert` on `selection_history` calls `private.raise_late_change_alert()`. It is `security definer`, takes no arguments, uses `set search_path = ''`, and execute is revoked from `public`, `anon` and `authenticated`, the same pattern as ADR-007. A trigger sees the project status exactly when the change happens and alerts at once. The detector would need a watermark over history and would only alert at the next cron tick. The trigger only inserts rows (no network call), so it adds almost nothing to the user's write.
- **Schema:** add `builder.alerts.history_id uuid null`. Give `selection_history` a `unique (id, org_id)` and add a composite FK `(history_id, org_id)` to it (ADR-003). Add check `kind <> 'late_change' or history_id is not null`.
- **De-dup key:** `unique (history_id, user_id)` with `on conflict do nothing`, which gives one alert per admin per change. This mirrors `(episode_id, user_id)` for stalls.
- **Recipients and text:** every `admin` membership of the project's org, like the detector. Message, cut to 500 chars: `Lot 15 – Kitchen Countertop changed from "Absolute Black Granite" to "…" after the set was complete (by staff).` The old value comes from the slot's previous history row.
- **RLS and grants:** no new policies and no new grants. Alerts stay recipient-only, and only `read_at` is writable. RLS stays enabled and forced on `alerts` and `selection_history`.
- **UI:** add a kind label (Stalled / Late change) to `/alerts`, taken from `alerts.kind`. The inbox shows no kind label today. Nothing else.
- **Tests (`supabase/tests/late_change.sql`, rolled back, synthetic ids):**
  - A change or clear on a `revision` or `complete` project creates one alert per admin.
  - Members and the other org get none.
  - `set`, `selection_phase`, archived and `pending_kickoff` projects create none.
  - A staff change on a finished project does alert.
  - Re-inserting creates no duplicates.
  - Bruno can't read Builder A's late-change alerts.
- **Rollback:** drop the trigger and function, the constraints and `alerts.history_id`.

## What I'd leave out
- Email, SMS or push. The alert is in-app only, matching the DESIGN.md non-goals.
- Grouping several changes into one alert, and per-org on/off or recipient settings.
- Locking selections after completion, or an approval step for late changes. Blocking edits is a product decision, not a notification.
- Linking to material orders or showing their cost. There is no order data in this app.
- The "due soon" warning. It is the next candidate after this one, and the detector loop could produce it later.
