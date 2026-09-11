#!/usr/bin/env bash
# Regression test for the profiles.role privilege-escalation fix
# (migrations 20260911000000_prevent_role_self_elevation.sql and
# 20260911000001_role_trigger_allow_service_role.sql).
#
# Creates two disposable auth users against the target Supabase project,
# exercises the real REST API exactly the way an attacker or an admin
# would, and asserts:
#   1. a normal user cannot self-promote their own role
#   2. a normal user can still update their own allowed profile fields
#   3. an admin CAN change another user's role
#   4. an admin's own normal profile edit does not affect their role
# Both test users are deleted at the end regardless of outcome.
#
# Usage: run from the `app/` directory with `.env` populated:
#   bash supabase/tests/role_immutability_test.sh

set -euo pipefail
cd "$(dirname "$0")/../.."

SUPABASE_URL=$(grep "^SUPABASE_URL=" .env | cut -d'=' -f2-)
SUPABASE_ANON_KEY=$(grep "^SUPABASE_ANON_KEY=" .env | cut -d'=' -f2-)
SUPABASE_SECRET_KEY=$(grep "^SUPABASE_SECRET_KEY=" .env | cut -d'=' -f2-)

PASS=0
FAIL=0

check() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc (expected $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

cleanup() {
  [ -n "${USER_ID:-}" ] && curl -s -o /dev/null -X DELETE "$SUPABASE_URL/auth/v1/admin/users/$USER_ID" \
    -H "apikey: $SUPABASE_SECRET_KEY" -H "Authorization: Bearer $SUPABASE_SECRET_KEY" || true
  [ -n "${ADMIN_USER_ID:-}" ] && curl -s -o /dev/null -X DELETE "$SUPABASE_URL/auth/v1/admin/users/$ADMIN_USER_ID" \
    -H "apikey: $SUPABASE_SECRET_KEY" -H "Authorization: Bearer $SUPABASE_SECRET_KEY" || true
}
trap cleanup EXIT

TS=$(date +%s)
USER_EMAIL="role-immutability-test-user-$TS@gmail.com"
USER_PASS="TestPass123!${TS}Aa"
ADMIN_EMAIL="role-immutability-test-admin-$TS@gmail.com"
ADMIN_PASS="TestPass123!${TS}Bb"

USER_ID=$(curl -s -X POST "$SUPABASE_URL/auth/v1/admin/users" \
  -H "apikey: $SUPABASE_SECRET_KEY" -H "Authorization: Bearer $SUPABASE_SECRET_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$USER_EMAIL\",\"password\":\"$USER_PASS\",\"email_confirm\":true}" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

ADMIN_USER_ID=$(curl -s -X POST "$SUPABASE_URL/auth/v1/admin/users" \
  -H "apikey: $SUPABASE_SECRET_KEY" -H "Authorization: Bearer $SUPABASE_SECRET_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\",\"email_confirm\":true}" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

# Bootstrap the admin test account via service role (trusted server context,
# not the exploit path — this is what the "allow service_role" migration
# specifically preserves).
curl -s -o /dev/null -X PATCH "$SUPABASE_URL/rest/v1/profiles?id=eq.$ADMIN_USER_ID" \
  -H "apikey: $SUPABASE_SECRET_KEY" -H "Authorization: Bearer $SUPABASE_SECRET_KEY" \
  -H "Content-Type: application/json" -d '{"role":"admin"}'

USER_TOKEN=$(curl -s -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Content-Type: application/json" \
  -d "{\"email\":\"$USER_EMAIL\",\"password\":\"$USER_PASS\"}" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['access_token'])")

ADMIN_TOKEN=$(curl -s -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Content-Type: application/json" \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\"}" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['access_token'])")

# 1. Normal user cannot self-promote.
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "$SUPABASE_URL/rest/v1/profiles?id=eq.$USER_ID" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $USER_TOKEN" \
  -H "Content-Type: application/json" -d '{"role":"admin"}')
check "normal user cannot self-promote to admin" "403" "$STATUS"

ROLE_AFTER=$(curl -s "$SUPABASE_URL/rest/v1/profiles?id=eq.$USER_ID&select=role" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $USER_TOKEN" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['role'])")
check "role unchanged after self-promotion attempt" "customer" "$ROLE_AFTER"

# 2. Normal user can still update allowed fields.
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "$SUPABASE_URL/rest/v1/profiles?id=eq.$USER_ID" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $USER_TOKEN" \
  -H "Content-Type: application/json" -d '{"full_name":"Regression Test"}')
check "normal user can update own allowed fields" "204" "$STATUS"

# 3. Admin can change another user's role.
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "$SUPABASE_URL/rest/v1/profiles?id=eq.$USER_ID" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" -d '{"role":"dealer"}')
check "admin can change another user's role" "204" "$STATUS"

# 4. Admin remains admin after their own normal profile edit.
curl -s -o /dev/null -X PATCH "$SUPABASE_URL/rest/v1/profiles?id=eq.$ADMIN_USER_ID" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" -d '{"full_name":"Admin Regression Test"}'
ADMIN_ROLE_AFTER=$(curl -s "$SUPABASE_URL/rest/v1/profiles?id=eq.$ADMIN_USER_ID&select=role" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $ADMIN_TOKEN" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['role'])")
check "admin keeps admin role after own normal profile edit" "admin" "$ADMIN_ROLE_AFTER"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
