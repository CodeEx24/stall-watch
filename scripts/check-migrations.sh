#!/usr/bin/env bash
# Static checks on supabase/migrations/ and MIGRATIONS.md (no database, no deps).
#   1. every file is named YYYYMMDDHHMMSS_snake_name.sql; timestamps unique and increasing
#   2. the MIGRATIONS.md ledger (table before the first "## ") has one row per file, none without a file
#   3. every file's leading comment header has WHY:, WHAT: and ROLLBACK: lines
#   4. a file that creates an extension or uses cron.* also has a NOT SELF-CONTAINED: line
# Pure bash (no external commands in the loop), so it is fast on Git Bash too.
#
#   npm run check:migrations
set -euo pipefail

cd "$(dirname "$0")/.."
DIR=supabase/migrations
LEDGER=MIGRATIONS.md
NAME_RE='^[0-9]{14}_[a-z0-9_]+\.sql$'
ROW_RE='^\| *`([0-9]{14}_[a-z0-9_]+\.sql)` *\|'
fail=0
err() { echo "  FAIL $*"; fail=1; }

# ledger rows: filename -> count. The ledger is the table above the first "## "
# heading; later sections (e.g. the audit) may mention filenames freely.
declare -A ledger=()
while IFS= read -r line || [ -n "$line" ]; do
  [[ "$line" =~ ^##\  ]] && break
  if [[ "$line" =~ $ROW_RE ]]; then
    n=${BASH_REMATCH[1]}
    ledger[$n]=$(( ${ledger[$n]:-0} + 1 ))
  fi
done < "$LEDGER"

shopt -s nullglob
files=("$DIR"/*)
[ ${#files[@]} -gt 0 ] || { echo "no migrations found"; exit 1; }

prev=""
for path in "${files[@]}"; do
  f=${path##*/}
  if ! [[ "$f" =~ $NAME_RE ]]; then
    err "$f: name must match YYYYMMDDHHMMSS_snake_name.sql"; continue
  fi
  ts=${f:0:14}
  [[ "$ts" > "$prev" ]] || err "$f: timestamp $ts is not after $prev (duplicate or out of order)"
  prev=$ts

  rows=${ledger[$f]:-0}
  [ "$rows" -eq 1 ] || err "$f: expected 1 row in $LEDGER, found $rows"

  # header = the leading run of comment / blank lines; body = the rest
  has_why=0 has_what=0 has_rollback=0 has_nsc=0 needs_nsc=0 in_header=1
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    if [ "$in_header" -eq 1 ]; then
      if [[ "$line" =~ ^[[:space:]]*(--.*)?$ ]]; then
        [[ "$line" =~ ^--\ *WHY: ]] && has_why=1
        [[ "$line" =~ ^--\ *WHAT: ]] && has_what=1
        [[ "$line" =~ ^--\ *ROLLBACK: ]] && has_rollback=1
        [[ "$line" =~ ^--\ *NOT\ SELF-CONTAINED: ]] && has_nsc=1
        continue
      fi
      in_header=0
    fi
    shopt -s nocasematch
    [[ "$line" =~ create\ extension|cron\. ]] && needs_nsc=1
    shopt -u nocasematch
  done < "$path"
  [ "$has_why" -eq 1 ] || err "$f: header has no '-- WHY:' line"
  [ "$has_what" -eq 1 ] || err "$f: header has no '-- WHAT:' line"
  [ "$has_rollback" -eq 1 ] || err "$f: header has no '-- ROLLBACK:' line"
  if [ "$needs_nsc" -eq 1 ] && [ "$has_nsc" -eq 0 ]; then
    err "$f: creates an extension / uses cron but has no '-- NOT SELF-CONTAINED:' line"
  fi
done

# ledger rows that point at no file
for n in "${!ledger[@]}"; do
  [ -f "$DIR/$n" ] || err "$LEDGER row $n: no such file in $DIR"
done

if [ "$fail" -ne 0 ]; then echo "migration checks FAILED"; exit 1; fi
echo "migration checks passed (${#files[@]} files, ${#ledger[@]} ledger rows)"
