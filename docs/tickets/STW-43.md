# STW-43 — Pre-submission verification

- **Jira:** https://stratyge.atlassian.net/browse/STW-43
- **Branch:** `chore/stw-43/pre-submission-check`
- **Status:** agent checks done; person actions pending (`docs/actions/STW-43-pre-submission.md`)

## Overview
A last check before submitting (STW-44). No app code, migrations or seed changed. This ticket produces evidence and two person-action guides.

Acceptance criteria:
1. A fresh Supabase project is rebuilt from the repo using SETUP.md only.
2. `git log -p` scan finds no keys, passwords or connection strings; no service-role key anywhere; Security and Performance Advisors reviewed.
3. CI green on main; the brief's story walked in a real browser as Ana, Mia, Bruno and Sam.

| AC | Agent-verified (this ticket) | Pending person action |
|---|---|---|
| 1 Fresh rebuild | Partial: SETUP.md Part A (local) rebuild on a scratch stack from a clean clone of `main`: 16 migrations + seed, counts match, users, all SQL tests. Hosted project is at 16/16 migrations. | Part B (hosted) on a **new** scratch Supabase project: action guide §1 |
| 2 Secrets | **Done: clean.** Full history, all refs, PR text; working tree; `src/` | — |
| 2 Advisors | Proxy: Supabase's advisor lints (`splinter.sql`) on an identical scratch DB; `db lint --linked` on hosted: no errors | Dashboard Security + Performance Advisor: action guide §2 |
| 3 CI green on main | **Done locally** on a clean clone of `main` (both `ci.yml` jobs replayed). GitHub Actions doesn't start: billing, private repo | Optional: make repo public, confirm first green run: action guide §4 |
| 3 Browser story | **Done on the local stack**: 23/23 PASS as Ana, Mia, Bruno, Sam via the real `/login`. Live site: responds, `/login` renders, wall redirects, hosted API denies anon | Signed-in walk on the live site: action guide §3 |

**Conclusion on making the repo public:** the history and PR text contain no secrets. **It is safe to make the repo public** (STW-44 step 1).

## Implementation details
Files added: `docs/tickets/STW-43.md`, `docs/actions/STW-43-pre-submission.md` (hosted rebuild, advisors, live walk, optional public-repo CI), `docs/actions/STW-44-submit.md` (make public, two one-time secret links, message template, 7-day keep-alive).

Scratch work (scripts, logs, screenshots) stayed in the session scratchpad and is not committed.

## API changes
None.

## Database changes
None. The shared local stack was only read (two read-only `select`s); no selection was set; Run now was not clicked.

## Dependencies on other tickets
Needs everything up to STW-42 and STW-40 merged (it is: verified on `main` `57a23ad`). STW-44 depends on this ticket and its person actions.

## Known limitations
- **GitHub Actions has never run green.** Every run on `main` (latest `3744a38`/`57a23ad`) is "The job was not started because recent account payments have failed or your spending limit needs to be increased". "CI green on main" is evidenced by running both jobs locally on a clean clone. Making the repo public gives free minutes.
- **Hosted rebuild and dashboard advisors** need the owner's Supabase account (an agent can't create a project or open the dashboard; the claude.ai Supabase connector can't see this project).
- **Live signed-in walk** needs the owner's hosted passwords.
- **Not-found status is 200.** Bruno opening a Builder A project id gets the not-found page with no project data, but HTTP 200 (Next.js streaming; already documented in STW-29). Not a leak.
- **Seed ages.** `seed.sql` dates are relative to its load time; a few days after loading, Unit 5A and then Lot 14 become stalled too. That is correct behaviour; noted in both guides.

## Testing notes

### AC2a — Secret scan (2026-10-21)
Source: a fresh `git clone --mirror` of `CodeEx24/stall-watch`, which includes `refs/heads/main` **and all 35 `refs/pull/*/head`** (these become public with the repo). 158 commits (re-scanned after STW-40 merged).

| Scan | Scope | Result |
|---|---|---|
| gitleaks v8.18.4 (`docker run zricethezav/gitleaks:v8.18.4 detect --log-opts=--all --redact`) | all commits, all refs | `no leaks found` |
| gitleaks `--no-git` | working tree of this branch | `no leaks found` |
| Regex scan of **every blob reachable from any ref** (367 blobs, 265 paths; this also covers merge commits, which `git log -p` skips) plus every commit message | JWT `eyJ….eyJ….`, `sb_secret_…`, `sb_publishable_…`, `sbp_` tokens, `postgres(ql)://user:pass@`, `password/secret/token/api_key = <literal>`, AWS `AKIA…`, GCP `AIza…`, GitHub `ghp_`/`github_pat_`, `-----BEGIN … PRIVATE KEY` | see below |
| Same regexes over all PR descriptions, PR comments, reviews and inline review comments (`gh pr list --state all`, `gh api pulls/comments`) | 35 PRs, 105 texts, 0 inline comments, 0 issues | 1 hit: a review comment quoting the old SETUP.md placeholder (below); false positive |

Hits and classification (values never printed; only rule, path, redacted context):

| Rule | Hits (unique) | Classification |
|---|---|---|
| JWT, `sb_secret_<value>`, `sb_publishable_<value>`, `sbp_`, connection string with password, AWS, GCP, GitHub token | **0** | — |
| `sb_secret_` (bare word) | 9 | False positive: prose rules ("never add a service-role / `sb_secret_` key") in docs, `.env.example`, the reviewer agent and the secret-scanner hook's own regex |
| `service_role` / `service-role` | 44 | False positive: prose rules, and SQL/tests that **revoke** from or assert no grants for the `service_role` role (`cron_schedule.sql`, the cron migration) |
| `password = …` | 5 | False positives: `SETUP.md` "Database password: **Generate a password**"; zod field `password: z.string()…` (`schemas.ts`); `password: rawPassword` (`sign-in.ts`); and historical placeholders `LOCAL_TEST_PASSWORD='pick-a-local-password'` / `'choose-a-local-password'` (SETUP.md, `create-local-test-users.sh`; replaced by `read -rs` prompts in STW-37/38). Checked programmatically: neither equals the real local test password |
| `-----BEGIN … PRIVATE KEY` | 1 | False positive: the regex inside `.claude/hooks/secret-scanner.py` |

`.env` files: the only env-like path ever added in any commit is `.env.example`, and its two variables have empty values in every version. `.gitignore` covers `.env*` (except the example), `supabase/.temp`, `*.pem`.

Service-role key in code: `grep -rniE "service.role|sb_secret|SUPABASE_SECRET|SERVICE_KEY" src/` finds only the comment in `src/lib/env.ts` ("The service-role key is never read anywhere"). `src/` reads exactly `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`.

Information that becomes public with the repo (not secrets; for your awareness): commit author name and email, the hosted project ref `wgfxpdrlijzxkqaxlrbc` and Vercel URL in docs, the test-user emails, and the `.claude/` agent/hook configuration.

### AC2b — Advisors (agent proxy)
- `npx -y supabase@2.121.0 db lint --linked --level warning` (hosted, read-only): `No schema errors found` across `builder`, `extensions`, `private`, `public`.
- Supabase's advisor SQL (`splinter.sql` from `supabase/splinter`, inspected: SELECTs and one `set_config`, no DDL/DML) run in a `begin read only … rollback` with `pgrst.db_schemas = 'public,builder,graphql_public'` against the scratch DB built from `main`:
  - **0 ERROR.**
  - 1 WARN `authenticated_security_definer_function_executable` on `public.run_stall_detector_now()`: by design (ADR-001, STW-33: first statement raises `42501` unless `private.is_staff()`; anon gets `42501` from the grant, verified on the hosted API below).
  - 9 INFO `unindexed_foreign_keys` (`alerts` ×3, `project_slots`, `selection_history` ×2, `selections` ×2, `stall_episodes`): accepted at this data size; follow-up below.
- RLS on the scratch DB: all 10 tables in `public`/`builder` have `relrowsecurity = true` and `relforcerowsecurity = true`.
- Hosted migration history: `migration list --linked` shows 16 local = 16 remote (through `20261020180000`).

### AC3a — CI on `main` (local replay)
Clean `git clone` of `main` into the scratchpad (not a worktree): first at `3744a38`, and this branch's `npm run ci` again after merging `57a23ad` (STW-40, docs + one script comment).
- `ci` job: `npm ci` then `npm run ci` (lint, typecheck, build): exit 0.
- `database` job, replayed on a scratch Supabase stack (copy's `config.toml`: `project_id = "stall-watch-v43"`, ports 55560–55569; the shared `stall-watch` stack was not touched):
  1. `npm run check:migrations`: `migration checks passed (16 files, 16 ledger rows)`
  2. `supabase start -x realtime,storage-api,imgproxy,mailpit,postgrest,postgres-meta,studio,edge-runtime,logflare,vector,supavisor` (as `ci.yml`), then `supabase db reset`: `Finished supabase db reset on branch main.`
  3. Counts: orgs 3, projects 9, slots 43, selections 22, history 26, cron jobs 1.
  4. Users with a random `openssl rand -hex 16` password: `created` ×4; link script: the 4 expected `email -> org (role)` lines; memberships 4.
  5. `DB_CONTAINER=supabase_db_stall-watch-v43 npm run test:db`: 19 `.sql` files + `detector_concurrency.sh`, 106 PASS lines, `SQL tests passed`, exit 0.
  6. `supabase stop --no-backup --project-id stall-watch-v43`: 0 containers, 0 volumes left; shared stack still 11 containers.
- GitHub: `gh run list` shows every run on `main` failed to start (billing annotation quoted above). Vercel's commit status on `3744a38`: `success`.

### AC3b — Browser story (local stack, real `/login`)
App built from this worktree (`npm run build && PORT=3043 npm start`, `.env.local` → `http://127.0.0.1:55421`, publishable key). Playwright Chromium, one fresh context per user. Read-only. **23/23 PASS**:

| User | Checked |
|---|---|
| each | signed-out `/projects` → `/login`; sign-in lands on `/projects` |
| Ana | 5 projects (Lot 12, 14, 15, 9, 3), all Builder A; only Lot 12 Stalled; opens Lot 12: 4 rooms, 8 slots; `/alerts`: one `stalled` alert for Lot 12, none for Builder B; `/detector`: "Staff only", no Run now |
| Mia | same 5 projects, Lot 12 Stalled; `/alerts`: "You have no alerts." |
| Bruno | only Unit 2A, 4B, 5A, 7C; Stalled = 4B, 7C (the 7C trap holds); Lot 12's id → not-found page, no detail or slot rows, HTML contains none of "Lot 12", "Builder A", "Kitchen" (HTTP 200, see limitations); `/alerts`: Unit 4B and 7C |
| Sam (staff) | all 9 projects, Builder column shows Builder A and Builder B; Stalled = Lot 12, 4B, 7C; `/detector`: 19 runs in history, Run now present (not clicked); `/alerts`: none |

After the walk: `stall_runs` still 19, `selections` still 22 on the shared stack. Screenshots in the scratchpad (not committed).

### AC3c — Live site, unauthenticated (https://stall-watch.vercel.app/)
| Request | Result |
|---|---|
| `/` | 307 → `/projects` |
| `/login` | 200, `<h1>Sign in</h1>`, `#email`, `#password` |
| `/projects`, `/alerts`, `/detector` | 307 → `/login` |
| hosted REST, anon (both the `sb_publishable_` key and the legacy anon key; never printed): `builder.projects`, `project_slots`, `selections`, `selection_history`, `alerts`, `stall_runs`, `stall_episodes`, `v_projects` | 401 `42501 permission denied for schema builder` |
| `public.orgs`, `memberships`, `users` | `42501` (no grant) |
| `private.*` | `PGRST106` (schema not exposed) |
| `POST rpc/run_stall_detector_now` | `42501 permission denied for function` |

Hosted table estimates (`inspect db table-stats --linked`): projects 9, slots 43, selections 22, history 26, memberships 4. `alerts` and `stall_runs` estimates were 0, but those are planner estimates; if Ana's live `/alerts` is empty, the guide says to have Sam click Run now once.

## Follow-up tasks
- Owner: `docs/actions/STW-43-pre-submission.md` §1–3 (and optional §4); then STW-44 with `docs/actions/STW-44-submit.md`.
- Record the owner's advisor results and hosted-rebuild outcome in this doc when reported; fix SETUP.md if the rebuild finds gaps.
- Optional: covering indexes for the 9 `unindexed_foreign_keys` INFO items (a migration with rollback; not needed at this data size).
