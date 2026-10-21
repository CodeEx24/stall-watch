# Action for you: submit Stall Watch to Reverie3D (STW-44) — PENDING

**Who:** you. Every step involves your accounts or your passwords.
**When:** after STW-43 is done (secret scan clean, advisors reviewed, live walk OK) and every open PR is merged.
**Jira:** https://stratyge.atlassian.net/browse/STW-44

Acceptance criteria (from the ticket):
- Two separate one-time secret links each contain all three logins (staff, Ana, Bruno).
- Message contains the public repo link, live URL and both links; no password is in plain text.
- Supabase and Vercel stay running for 7 days after submitting.

---

## 1. Make the repo public (only after the secret scan is clean)

The STW-43 scan (`docs/tickets/STW-43.md`) covered every commit on every branch and every pull-request ref, plus PR descriptions and comments: **no keys, passwords or connection strings**. Once public, the full history and all PR text are visible to anyone, so don't skip this order: scan first, then publish. If anything was committed after STW-43 merged, ask Claude to re-run the scan first.

1. https://github.com/CodeEx24/stall-watch → **Settings** → **General** → scroll to **Danger Zone** → **Change repository visibility** → **Change to public**.
2. Read the warnings, type the repo name `CodeEx24/stall-watch` to confirm.
3. Check: open https://github.com/CodeEx24/stall-watch in a private window; the code is visible without signing in.
4. Bonus: public repos get free GitHub Actions minutes. Re-run the last `main` CI run (Actions → CI → latest run → **Re-run all jobs**) and confirm both jobs go green (see `docs/actions/STW-43-pre-submission.md` part 4).

Repo link for the message: `https://github.com/CodeEx24/stall-watch`

## 2. Create two one-time secret links

Each link holds **all three logins** (staff, Ana, Bruno), so either reviewer can open either link. Two links because a one-time link burns when opened: if one reviewer opens it, the other still has theirs.

1. Go to https://onetimesecret.com (or a similar service such as https://pwpush.com). No account needed.
2. Paste this text, filled in from your password manager (the hosted passwords you set in STW-24):
   ```
   Stall Watch — https://stall-watch.vercel.app/

   Reverie3D staff:  staff@stallwatch.test  /  <staff password>
   Builder A admin:  ana@builder-a.test     /  <ana password>
   Builder B admin:  bruno@builder-b.test   /  <bruno password>
   ```
   (Optional: add `mia@builder-a.test` (Builder A member) too, if you want reviewers to see that members get no alerts.)
3. Set the expiry to **at least 7 days** if the service offers it, otherwise the longest option, and **1 view** (one-time). Optional: a passphrase you send separately; skip it unless you want it, since the link itself is the secret.
4. Click **Create a secret link**. Copy the link. **Don't open it yourself** (that would burn it).
5. Repeat steps 2–4 for the **second** link. You now have two different URLs.
6. Clear the text from your clipboard. Don't paste either password anywhere else.

## 3. Send the message

Template (fill the `<…>`; nothing else in it is secret):

> Subject: Stall Watch — submission
>
> Hi <name>,
>
> Here is my Stall Watch submission.
>
> - Live app: https://stall-watch.vercel.app/
> - Code: https://github.com/CodeEx24/stall-watch (start with README.md; DESIGN.md has the design and trade-offs, SETUP.md rebuilds it from nothing)
> - Logins (staff, Builder A admin, Builder B admin), in two one-time links (each link holds all three and opens only once):
>   - Link 1: <one-time link 1>
>   - Link 2: <one-time link 2>
>
> Suggested walk: sign in as Ana (Builder A) and see Lot 12 stalled and its alert; as Bruno (Builder B) see Unit 4B and Unit 7C stalled and that Builder A's projects are not reachable; as staff see all nine projects and the detector's run history at /detector.
>
> The app and database stay up for at least 7 days from today.
>
> Thanks,
> <your name>

Before sending, check: the message has the repo link, the live URL and both one-time links, and **no password**.

## 4. Keep it running for 7 days

**Vercel (Hobby):** deployments don't sleep or expire. Nothing to do, except: **don't merge anything to `main` that breaks the build** for these 7 days (each merge redeploys Production).

**Supabase (Free plan):** Supabase pauses Free projects that have *low user database activity over a 7-day period* and emails the owner a warning first ([docs](https://supabase.com/docs/guides/platform/free-project-pausing)). A paused project returns errors, so the live app would show nothing.
- The nightly pg_cron detector job does run inside the database every night, but Supabase doesn't document that scheduled jobs count as "user activity". **Don't rely on it.**
- What does count, per the docs: visiting the project in the Supabase dashboard, or API requests from the app. So **every 2–3 days** for the 7 days: open https://stall-watch.vercel.app/ and sign in as one user, and open the project in the dashboard.
- Watch your email for a "project will be paused" warning; if it arrives, do the above at once.
- If it was paused anyway: Dashboard → the project → **Resume project** (data and settings are kept). Then reload the live site.
- Don't pause, delete or reset the `stall-watch` project, and don't change Vercel's environment variables, during the 7 days. Delete the STW-43 scratch rebuild project if it still exists, so you stay within the Free plan's two active projects.

**Data ages (expected):** the seed's dates are relative to when it was loaded, so a few days in, Unit 5A and then Lot 14 also become stalled and get alerts after the next nightly run. That's correct detector behaviour; nothing to fix.

## Done when
**Status checked 2026-10-21 (Claude, read-only):** **not started.** Repo is still private (no commits since the STW-43 scan except this status update, which is docs only). The secret links and the message can't be seen by Claude: tell Claude when they're sent.

- [ ] Repo is public, and the scan in `docs/tickets/STW-43.md` was clean when you published it
- [ ] Two separate one-time links, each with the staff, Ana and Bruno logins
- [ ] Message sent with repo link, live URL and both links; no password in it
- [ ] Days 1–7: site and Supabase project checked every 2–3 days; never paused (or resumed at once)
