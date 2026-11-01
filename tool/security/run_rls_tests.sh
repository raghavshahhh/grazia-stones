#!/usr/bin/env bash
# Boots a throwaway local Postgres, loads supabase/schema.sql + every migration (in order) on top of
# Supabase stand-ins, then runs the RLS attack tests and a parallel consume_ai_render race. Never touches Supabase.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
app="$(cd "$here/../.." && pwd)"
dir="$(mktemp -d "${TMPDIR:-/tmp}/rlstest.XXXXXX")"
port="${PGPORT_TEST:-54331}"
trap 'pg_ctl -D "$dir/data" stop -m immediate >/dev/null 2>&1 || true; rm -rf "$dir"' EXIT
initdb -D "$dir/data" -U postgres -A trust >/dev/null
pg_ctl -D "$dir/data" -o "-p $port -k $dir -c listen_addresses=''" -l "$dir/log" -w start >/dev/null
export PGOPTIONS="-c client_min_messages=warning"
sql() { psql -h "$dir" -p "$port" -U postgres -d postgres -v ON_ERROR_STOP=1 -q -X "$@"; }

sql -f "$here/supabase_standins.sql" 2>/dev/null
sql -f "$app/supabase/schema.sql" >/dev/null 2>&1
# schema.sql already contains most of 20260830000000 (it is not re-runnable on top of it), so that one file runs
# without ON_ERROR_STOP; its "already exists" errors are expected. Every later migration must apply cleanly.
for f in "$app"/supabase/migrations/*.sql; do
  case "$f" in
    *20260830000000_*) sql -v ON_ERROR_STOP=0 -f "$f" >/dev/null 2>&1 ;;
    *) sql -f "$f" >/dev/null ;;
  esac
done
# Re-applying every migration must be a no-op (idempotent).
for f in "$app"/supabase/migrations/2026110*.sql; do sql -f "$f" >/dev/null; done

sql -f "$here/test_rls.sql"

# Public buckets only take images.
sql -tA -c "select count(*) from storage.buckets where id in ('avatars','ai-visualizations','ar-screenshots') and 'image/jpeg' = any(allowed_mime_types) and not 'text/html' = any(allowed_mime_types)" | grep -qx 3 \
  || { echo 'FAIL: public buckets accept non-image types'; exit 1; }

# Race: 5 parallel renders against a daily limit of 2 must spend exactly 2.
u=eeeeeeee-0000-0000-0000-000000000005
sql -c "insert into auth.users (id, email) values ('$u', 'race@test'); update public.ai_plan_limits set daily_limit = 2;"
for i in 1 2 3 4 5; do sql -tA -c "set role service_role; select ok from public.consume_ai_render('$u')" > "$dir/race.$i" & done
wait
oks=$(cat "$dir"/race.* | grep -c '^t$' || true)
spent=$(sql -tA -c "select daily_count from public.ai_credits where user_id = '$u'")
[ "$oks" = 2 ] && [ "$spent" = 2 ] || { echo "FAIL: race spent $spent, $oks ok (want 2/2)"; exit 1; }
echo "consume_ai_render race: 5 parallel calls, limit 2 -> $oks ok, counter $spent"
