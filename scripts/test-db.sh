#!/usr/bin/env bash
# Run every SQL assertion file in supabase/tests/ against a database, then every
# supabase/tests/*.sh multi-session scenario (e.g. concurrent detector runs).
# Each file raises on failure (ON_ERROR_STOP), so a non-zero exit means a failed test.
#
#   DB_URL=<postgres connection URL> npm run test:db   # any psql-reachable DB (CI); never commit a real URL
#   npm run test:db                                                                  # local stack via docker exec
set -euo pipefail

cd "$(dirname "$0")/.."
CONTAINER="${DB_CONTAINER:-supabase_db_stall-watch}"
shopt -s nullglob
files=(supabase/tests/*.sql)
if [ ${#files[@]} -eq 0 ]; then
  echo "no SQL tests found"; exit 0
fi

failed=0
for f in "${files[@]}"; do
  echo "== $f"
  status=0
  if [ -n "${DB_URL:-}" ]; then
    out=$(psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 -f "$f" 2>&1) || status=$?
  else
    out=$(docker exec -i "$CONTAINER" psql -U postgres -X -q -v ON_ERROR_STOP=1 -f - < "$f" 2>&1) || status=$?
  fi
  if [ "$status" -ne 0 ]; then
    failed=1
    echo "  exit $status; full output:"
    echo "$out" | sed 's/^/    /'
  else
    # a passing file may print no PASS lines; that is fine
    echo "$out" | grep -E "PASS|FAIL|ERROR" | sed -E 's/^psql:[^ ]+ (NOTICE|ERROR): +/  \1 /' || true
  fi
done

# multi-session scenarios that one psql transaction cannot express (same DB_URL /
# DB_CONTAINER rules; each script cleans up everything it commits)
for f in supabase/tests/*.sh; do
  echo "== $f"
  status=0
  out=$(bash "$f" 2>&1) || status=$?
  if [ "$status" -ne 0 ]; then
    failed=1
    echo "  exit $status; full output:"
    echo "$out" | sed 's/^/    /'
  else
    echo "$out" | grep -E "PASS|FAIL|ERROR|SKIP" | sed -E 's/^psql:[^ ]+ (NOTICE|ERROR): +/  \1 /; s/^PASS/  PASS/' || true
  fi
done

if [ "$failed" -ne 0 ]; then
  echo "SQL tests FAILED"; exit 1
fi
echo "SQL tests passed"
