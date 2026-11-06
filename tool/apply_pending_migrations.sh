#!/usr/bin/env bash
# Backs up the prod objects the pending migrations touch, then applies each migration in its own transaction
# through the Supabase Management API and records it in schema_migrations. Run from the app folder.
#   bash tool/apply_pending_migrations.sh
set -euo pipefail
REF=jrrmjtbauimrrxwjvmzh
PENDING=(20261103000000_security_hardening_2 20261104000000_stones_storage_admin_write 20261104000001_profile_avatar_from_provider)
# Already live on prod (checked 2026-11-07) but never recorded:
RECORD_ONLY=(20261020000000_sample_requests_insert_policy 20261102000000_admin_unlimited_renders)

TOK="$(security find-generic-password -s 'Supabase CLI' -w | sed 's/^go-keyring-base64://')"
[[ "$TOK" == sbp_* ]] || TOK="$(echo "$TOK" | base64 -d)"
q() { # $1 = sql, $2 = endpoint suffix ("" or "/read-only")
  python3 -c 'import json,sys;print(json.dumps({"query":sys.stdin.read()}))' <<<"$1" |
    curl -sS -f -X POST -H @<(printf 'Authorization: Bearer %s\n' "$TOK") -H 'content-type: application/json' \
      --data @- "https://api.supabase.com/v1/projects/$REF/database/query$2"
}

BK="../backups/db-$(date +%Y%m%d-%H%M%S).json"
mkdir -p ../backups
q "select json_build_object(
  'functions', (select json_agg(json_build_object('name', p.proname, 'def', pg_get_functiondef(p.oid))) from pg_proc p
                join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public'
                and p.proname in ('handle_new_user','consume_ai_render','enforce_order_customer_fields','limit_lead_inserts')),
  'policies', (select json_agg(row_to_json(x)) from pg_policies x where (schemaname = 'public' and tablename in
                ('orders','sample_requests','admin_users','profiles','quote_requests')) or schemaname = 'storage'),
  'buckets', (select json_agg(json_build_object('id', id, 'mime', allowed_mime_types, 'size', file_size_limit)) from storage.buckets),
  'migrations', (select json_agg(version order by version) from supabase_migrations.schema_migrations)) as backup" /read-only > "$BK"
echo "backup -> $BK ($(wc -c <"$BK") bytes)"

record() { q "insert into supabase_migrations.schema_migrations(version, name) values ('${1%%_*}', '${1#*_}') on conflict (version) do nothing" "" >/dev/null; }
for m in "${RECORD_ONLY[@]}"; do record "$m"; echo "recorded $m"; done
for m in "${PENDING[@]}"; do
  q "begin;
$(cat "supabase/migrations/$m.sql")
commit;" "" >/dev/null
  record "$m"; echo "applied $m"
done
echo DONE
