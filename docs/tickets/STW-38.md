# STW-38 — MIGRATIONS.md ledger and header audit

- **Jira:** https://stratyge.atlassian.net/browse/STW-38
- **Branch:** `docs/stw-38/migrations-audit`
- **Status:** Code Review

## Overview
Audit every migration and the ledger so a reviewer can trust that the SQL in git is what ran, and keep it that way with a cheap check.

Acceptance criteria:
- MIGRATIONS.md has one row per file with filename and what it did.
- Every migration has WHY, WHAT, ROLLBACK (and NOT SELF-CONTAINED where needed) and a YYYYMMDDHHMMSS_name.sql filename.
- No applied migration was edited after the fact.

## Implementation details
- **No migration file was edited.** All 15 are applied on the hosted project and the shared local stack, so changing even a header comment would itself break AC3. The plan was to record any header gap in MIGRATIONS.md instead; the audit found none.
- `MIGRATIONS.md` gains an **Audit (STW-38)** section: results for filenames, ledger, headers and NOT SELF-CONTAINED, a per-file table of `git log --follow` commits and "hosted applied = file", a note on the one file with two commits, and a note on drift in the local stack's migration history.
- `scripts/check-migrations.sh` (pure bash, no external commands in the loop, so it runs in seconds on Git Bash) enforces:
  1. filename `^[0-9]{14}_[a-z0-9_]+\.sql$`, timestamps unique and strictly increasing;
  2. exactly one ledger row per file in the table before the first `## ` heading, and no row without a file;
  3. `-- WHY:`, `-- WHAT:`, `-- ROLLBACK:` in the leading comment block;
  4. `-- NOT SELF-CONTAINED:` in the header when the body creates an extension or uses `cron.` (heuristic for the one known outside dependency).
- `package.json`: new script `check:migrations` only. The shared `ci` script is unchanged; STW-37 (CI DB job) can call it.
- Same PR, separate commits:
  - `SETUP.md`: the local test-user command now reads `LOCAL_TEST_PASSWORD=<your-local-password>`. The old quoted sample value matched the secret scanner's hardcoded-password pattern, a false positive that blocked any commit touching the file.
  - `docs/actions/STW-24-hosted-test-users.md` marked DONE: the owner confirmed "hosted users linked", and a read-only hosted query showed 4 auth users (all confirmed), 4 memberships and 9 projects.

## API changes
None.

## Database changes
None. No migration was added or changed; nothing was applied to any database.

## Dependencies on other tickets
Covers the migrations from STW-12 to STW-34, all merged. STW-37 (CI database job) can run `npm run check:migrations`.

## Known limitations
- The NOT SELF-CONTAINED check is a heuristic (extension / `cron.`). Other outside dependencies, such as a dashboard setting or a Vault secret, still need a reviewer's eye.
- The ledger check looks only at backticked filenames in the first table. It doesn't judge whether the "What" text is accurate.
- The shared local stack's migration history wasn't repaired, because other tickets are using it (see Follow-up).

## Testing notes
- `npm run check:migrations`: `migration checks passed (15 files, 15 ledger rows)`.
- Negative test on a throwaway copy: a missing ROLLBACK, a bad name, a duplicate timestamp, an unlisted file, a ghost ledger row and a removed NOT SELF-CONTAINED note each produce a FAIL line, and the script exits 1.
- `git log --follow --format=%h -- <file>`: one commit per file, except `20261020133000_selection_history_trigger.sql` (`00b27d6`, `63e7a33`). `63e7a33` landed on the STW-23 PR branch at 20:12 -04:00, before PR #17 merged at 20:33 and before that migration was pushed to the hosted DB, which then held 8/8 migrations, through STW-21.
- Hosted (`wgfxpdrlijzxkqaxlrbc`): `supabase migration list --linked` shows 15/15 local = remote. For every version, the statements recorded in `supabase_migrations.schema_migrations` are verbatim substrings of the committed file, and concatenated they equal the whole file (ignoring whitespace and `;`). The comparison script lives in the scratchpad and isn't committed.
- Shared local stack: the 13 recorded versions match the files except `133000`, whose record matches the pre-fix `00b27d6` version (the live function body has the fix). `170000` and `171000` are applied but not recorded.
- `npm run test:db` and `npm ci && npm run ci`: see the PR description for output.

## Follow-up tasks
- When the shared local stack is free: `npx supabase migration repair --local --status applied 20261020170000 20261020171000`, or a full `db reset` followed by `db:local-users` / `db:local-link`.
- STW-37: add `npm run check:migrations` to the CI database job.
- Rule worth promoting to CLAUDE.md at epic close: once a migration has run on any shared database (local stack included), fix it with a new migration rather than amending the file.
