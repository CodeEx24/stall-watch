# Stall Watch

A small multi-tenant web app where home builders pick finishes for their projects. A scheduled detector flags projects that went quiet and alerts the builder's admins, and Reverie3D staff see every builder and the detector's run history. Postgres row-level security is the security wall; the app only ever uses the Supabase publishable key.

- Design: [`DESIGN.md`](DESIGN.md) · Architecture and ADRs: [`docs/architecture.md`](docs/architecture.md)
- Engineering rules: [`CLAUDE.md`](CLAUDE.md) / [`AGENTS.md`](AGENTS.md)
- Ticket notes: [`docs/tickets/`](docs/tickets/) · Steps only a person can do: [`docs/actions/`](docs/actions/)

## Stack
Next.js 16 (App Router, TypeScript strict) on Vercel · Supabase (Postgres, Auth, `pg_cron`) · GitHub Actions.

## Run locally
Requirements: Node.js 20.9 or newer, npm.

```bash
npm ci                      # install exact dependencies from package-lock.json
cp .env.example .env.local  # then fill in the two NEXT_PUBLIC_ values (Supabase > Project Settings > API Keys)
npm run dev                 # http://localhost:3000
```

The two variables are `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`. Never add a service-role key.

## Checks (CI runs the same)
```bash
npm run lint        # ESLint (next core-web-vitals + typescript)
npm run typecheck   # next typegen, then tsc --noEmit (strict)
npm run build       # production build
```

## How work lands
Branch `<type>/stw-<nnn>/<short-title>` from `main` → Conventional Commits ending in the Jira key, e.g. `feat(stall): record every detector run (STW-32)` → PR stating what / why / how verified and the acceptance criteria → green CI → merge commit (never squash).
