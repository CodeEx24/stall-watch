#!/usr/bin/env bash
# Run the provided supabase/link-test-users.sql against the LOCAL stack (as the DB owner).
# It links the four test users to their orgs and is safe to run twice.
#   npm run db:local-link
set -euo pipefail
cd "$(dirname "$0")/.."
CONTAINER="${DB_CONTAINER:-supabase_db_stall-watch}"
docker exec -i "$CONTAINER" psql -U postgres -X -q -v ON_ERROR_STOP=1 -f - < supabase/link-test-users.sql
docker exec "$CONTAINER" psql -U postgres -X -q -tA -c "
  select u.email || ' -> ' || o.name || ' (' || m.role || ')'
  from public.memberships m
  join public.users u on u.id = m.user_id
  join public.orgs o on o.id = m.org_id
  where u.email in ('staff@stallwatch.test','ana@builder-a.test','bruno@builder-b.test','mia@builder-a.test')
  order by u.email;"
