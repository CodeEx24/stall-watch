#!/usr/bin/env bash
# Create the four Stall Watch test users on the LOCAL Supabase stack only.
#
#   LOCAL_TEST_PASSWORD='choose-a-local-password' npm run db:local-users
#
# - Signs each user up through the local Auth API with the publishable key, the same
#   path as the app (no service-role key). Local signup auto-confirms
#   (config.toml: enable_confirmations = false).
# - The password comes from LOCAL_TEST_PASSWORD and is never written to disk or printed.
# - Refuses to run against anything but 127.0.0.1. For the hosted project, create the
#   users in the dashboard (docs/actions/STW-24-hosted-test-users.md).
# - Safe to run twice: an existing user is reported and skipped.
# Afterwards: run supabase/link-test-users.sql (npm run db:local-link).
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -z "${LOCAL_TEST_PASSWORD:-}" ]; then
  echo "Set LOCAL_TEST_PASSWORD (local stack only; never commit it)." >&2
  exit 1
fi

status_json=$(npx -y supabase@2.121.0 status -o json 2>/dev/null)
api_url=$(printf '%s' "$status_json" | python -I -c "import json,sys; print(json.load(sys.stdin).get('API_URL',''))")
key=$(printf '%s' "$status_json" | python -I -c "import json,sys; d=json.load(sys.stdin); print(d.get('PUBLISHABLE_KEY') or d.get('ANON_KEY') or '')")

case "$api_url" in
  http://127.0.0.1:*|http://localhost:*) ;;
  *) echo "Refusing: API_URL '$api_url' is not the local stack." >&2; exit 1 ;;
esac
[ -n "$key" ] || { echo "Local stack not running (no publishable key)." >&2; exit 1; }

for email in staff@stallwatch.test ana@builder-a.test bruno@builder-b.test mia@builder-a.test; do
  body=$(python -I -c "import json,os,sys; print(json.dumps({'email': sys.argv[1], 'password': os.environ['LOCAL_TEST_PASSWORD']}))" "$email")
  # keep the response in memory (no temp files; works the same in Git Bash and Linux)
  resp=$(curl -s -w '\n%{http_code}' -X POST "$api_url/auth/v1/signup" \
    -H "apikey: $key" -H "Content-Type: application/json" --data-binary "$body")
  code=${resp##*$'\n'}
  reason=$(printf '%s' "${resp%$'\n'*}" | python -I -c "
import json,sys
try:
    d=json.load(sys.stdin); print(d.get('msg') or d.get('error_description') or d.get('error_code') or d.get('code') or '')
except Exception:
    print('')")
  case "$code" in
    200) echo "created  $email" ;;
    400|422) echo "skipped  $email ($reason)" ;;
    *) echo "failed   $email (HTTP $code: $reason)"; exit 1 ;;
  esac
done
