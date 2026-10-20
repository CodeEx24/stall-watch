# STW-13 — Deploy hello page to Vercel with per-environment variables

- **Jira:** https://stratyge.atlassian.net/browse/STW-13 (blueprint US-005)
- **Branch:** `docs/stw-13/vercel-live-url`

## Overview
A live URL that reviewers can open, with the two public Supabase variables set per environment, and a preview deployment for every PR.

## Implementation details
- The candidate imported `CodeEx24/stall-watch` into Vercel (Next.js preset). Production branch: `main`.
- Environment variables, set in Production, Preview and Development: `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`. **No service-role / `sb_secret_` key** anywhere (candidate-confirmed checklist in `docs/actions/STW-13-vercel-project.md`).
- Production URL: **https://stall-watch.vercel.app/**, recorded in `README.md`.
- No code change was needed: the hello page is the STW-11 scaffold.

## API changes
None.

## Database changes
None.

## Dependencies on other tickets
Blocked by STW-11 and STW-12 (both Done). Every later web ticket is demonstrated on this URL and on PR previews.

## Known limitations
Values are managed in the Vercel dashboard. The repo only documents their names (`.env.example`).

## Testing notes
- `GET https://stall-watch.vercel.app/` returns **200**, with `<title>Stall Watch</title>` and `<h1>Stall Watch</h1>`; `GET /nope` returns **404**.
- Preview deployment: this ticket's PR triggers a Vercel preview build. The status and URL are recorded in the PR.

## Follow-up tasks
None.
