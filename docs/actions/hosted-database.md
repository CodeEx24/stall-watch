# Action for you: expose `builder` and push migrations to the hosted project

**Who:** you. Pushing needs the database password, which only you should type.
**When:** now. Needed before the Vercel app (STW-13 onward) can read data.
**Project:** `wgfxpdrlijzxkqaxlrbc` (already linked; `pg_cron` enabled).
**Jira:** STW-21 (builder exposed on the hosted project), STW-24 (seed on hosted).

## 1. Expose the `builder` schema (STW-21, AC4)
1. Supabase dashboard → **Project Settings → Data API** (or **API**).
2. Under **Exposed schemas**, add **`builder`**, keeping `public` and `graphql_public`. **Do not add `private`.**
3. Save.

This only changes what the API can see. Every `builder` table has forced RLS and authenticated-only grants.

## 2. Push the migrations
In this Claude Code session, from the repo root, type:
```
! npx supabase db push
```
- It lists the migrations to apply. Confirm with `y`.
- If it asks for the database password, type it **at the prompt only**. Never pass it as `-p` / `--password`: `!` command lines land in the chat transcript.
- Expected: every file in `supabase/migrations/` applied, ending with `Finished supabase db push.`

## 3. Tell Claude
Say "db pushed, builder exposed". Claude then checks the hosted catalog through the CLI and records it for SETUP.md. The test users and seed on the hosted project come with STW-24 (`docs/actions/` will have that step).

## Done when
- [ ] `builder` listed in the hosted Exposed schemas (and `private` not)
- [ ] `npx supabase db push` finished without errors
