#!/usr/bin/env bash
# Create the four Stall Watch test users on the LOCAL Supabase stack only.
#
#   read -rs LOCAL_TEST_PASSWORD && export LOCAL_TEST_PASSWORD   # type it; nothing is echoed
#   npm run db:local-users
#
#   (Reading it at a hidden prompt keeps it out of shell history; see SETUP.md A3.)
#
# - Signs each user up through the local Auth API with the publishable key, the same
#   path as the app (no service-role key). Local signup auto-confirms
#   (config.toml: enable_confirmations = false).
# - The password comes from LOCAL_TEST_PASSWORD and is never written to disk, printed,
#   or put on a command line (the request body goes to curl on stdin).
# - Refuses to run against anything but 127.0.0.1 / localhost. For the hosted project,
#   create the users in the dashboard (docs/actions/STW-24-hosted-test-users.md).
# - Safe to run twice: an already-registered user is reported and skipped; any other
#   rejection (e.g. password too short) fails the run.
# Afterwards: run supabase/link-test-users.sql (npm run db:local-link).
set -euo pipefail
cd "$(dirname "$0")/.."

PY=""
for candidate in python3 python; do  # first interpreter that actually runs (Windows has a python3 Store stub)
  if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c "import sys" >/dev/null 2>&1; then
    PY="$candidate"; break
  fi
done
[ -n "$PY" ] || { echo "python3 (or python) is required." >&2; exit 1; }

if [ -z "${LOCAL_TEST_PASSWORD:-}" ]; then
  echo "Set LOCAL_TEST_PASSWORD (local stack only; never commit it)." >&2
  exit 1
fi

# SUPABASE_CLI lets CI use an installed, pinned binary; default is the pinned npx package
read -r -a supabase_cli <<< "${SUPABASE_CLI:-npx -y supabase@2.121.0}"
if ! status_json=$("${supabase_cli[@]}" status -o json 2>/dev/null); then
  echo "Local Supabase stack is not running (npx supabase start)." >&2
  exit 1
fi
api_url=$(printf '%s' "$status_json" | "$PY" -I -c "import json,sys; print(json.load(sys.stdin).get('API_URL',''))")
key=$(printf '%s' "$status_json" | "$PY" -I -c "import json,sys; d=json.load(sys.stdin); print(d.get('PUBLISHABLE_KEY') or d.get('ANON_KEY') or '')")

case "$api_url" in
  http://127.0.0.1:*|http://localhost:*) ;;
  *) echo "Refusing: API_URL '$api_url' is not the local stack." >&2; exit 1 ;;
esac
[ -n "$key" ] || { echo "Local stack not running (no publishable key)." >&2; exit 1; }

for email in staff@stallwatch.test ana@builder-a.test bruno@builder-b.test mia@builder-a.test; do
  # body built from env inside Python, piped to curl on stdin: the password never hits argv
  resp=$(EMAIL="$email" "$PY" -I -c "import json,os; print(json.dumps({'email': os.environ['EMAIL'], 'password': os.environ['LOCAL_TEST_PASSWORD']}))" \
    | curl -s -w '\n%{http_code}' -X POST "$api_url/auth/v1/signup" \
        -H "apikey: $key" -H "Content-Type: application/json" --data-binary @-)
  code=${resp##*$'\n'}
  reason=$(printf '%s' "${resp%$'\n'*}" | "$PY" -I -c "
import json,sys
try:
    d=json.load(sys.stdin); print(d.get('error_code') or d.get('code') or '', '|', d.get('msg') or d.get('error_description') or '')
except Exception:
    print('|')")
  case "$code" in
    200) echo "created  $email" ;;
    400|422)
      case "$reason" in
        *user_already_exists*|*"already registered"*) echo "skipped  $email (already registered)" ;;
        *) echo "failed   $email (HTTP $code: $reason)" >&2; exit 1 ;;
      esac ;;
    *) echo "failed   $email (HTTP $code: $reason)" >&2; exit 1 ;;
  esac
done
