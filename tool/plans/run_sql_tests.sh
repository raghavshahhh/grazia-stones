#!/usr/bin/env bash
# Boots a throwaway local Postgres, runs test_ai_plans.sql then test_ai_usage.sql against it, deletes it.
# Never touches Supabase.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
dir="$(mktemp -d "${TMPDIR:-/tmp}/aiplans.XXXXXX")"
port="${PGPORT_TEST:-54329}"
trap 'pg_ctl -D "$dir/data" stop -m immediate >/dev/null 2>&1 || true; rm -rf "$dir"' EXIT
initdb -D "$dir/data" -U postgres -A trust >/dev/null
pg_ctl -D "$dir/data" -o "-p $port -k $dir -c listen_addresses=''" -l "$dir/log" -w start >/dev/null
psql -h "$dir" -p "$port" -U postgres -d postgres -v ON_ERROR_STOP=1 -q -f "$here/test_ai_plans.sql"
psql -h "$dir" -p "$port" -U postgres -d postgres -v ON_ERROR_STOP=1 -q -f "$here/test_ai_usage.sql"
