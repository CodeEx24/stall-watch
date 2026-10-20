# Action for you: connect the repo to Vercel and set env vars (STW-13) — DONE (2026-10-20, https://stall-watch.vercel.app/)

**Who:** you, because it uses your Vercel account and GitHub authorization.
**When:** after Claude merges the scaffold (STW-11) and you've created the Supabase project (STW-12).
**Jira:** https://stratyge.atlassian.net/browse/STW-13

## Why
Reviewers need a live URL, and every PR needs a preview deployment. The ticket's acceptance criteria:
- Live URL serves the hello page from `main`.
- The two `NEXT_PUBLIC_` variables exist in Production, Preview and Development; **no service-role key is set anywhere**.
- A PR opened against `main` produces a Vercel preview deployment.

## Steps
1. Go to https://vercel.com/new and **Import Git Repository**, then pick `CodeEx24/stall-watch`. Grant the Vercel GitHub app access to that repo if asked.
2. Framework preset: **Next.js** (auto-detected). Leave the build and output settings as they are.
3. Before clicking Deploy, open **Environment Variables** and add exactly two. Tick **Production, Preview and Development** for each:
   | Name | Value (from Supabase → Project Settings → API / API Keys) |
   |---|---|
   | `NEXT_PUBLIC_SUPABASE_URL` | Project URL, e.g. `https://<ref>.supabase.co` |
   | `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | The **publishable** key (`sb_publishable_…`). If the project only shows legacy keys, use the **anon** key. |
   Do **not** add the `service_role` / `sb_secret_` key, here or anywhere else.
4. Click **Deploy**. When it finishes, open the production URL and check that the hello page loads.
5. **Settings → Git**: confirm the Production Branch is `main` and preview deployments are on.
6. Also put the same two values in a local `.env.local` at the repo root (gitignored, and Claude is blocked from reading it):
   ```
   NEXT_PUBLIC_SUPABASE_URL=https://<ref>.supabase.co
   NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
   ```
7. Tell Claude the production URL, e.g. "Vercel is live at https://stall-watch-xxx.vercel.app".

## What Claude does after
Opens a small PR. Your confirmation shows the preview deployment works. Claude records the URL in the README and the ticket doc, then moves STW-13 to Done with a comment after merge.

## Done when
- [x] Production URL serves the hello page from `main`
- [x] Two `NEXT_PUBLIC_` vars set in all three environments; no service-role key anywhere
- [x] `.env.local` created locally
- [x] URL given to Claude, and a PR shows a Vercel preview
