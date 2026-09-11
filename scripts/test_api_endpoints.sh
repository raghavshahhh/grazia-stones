#!/bin/bash

echo "=========================================="
echo "GRAZIA STONES - API ENDPOINT VERIFICATION"
echo "=========================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0

check_pass() {
    echo "✅ PASS: $1"
    ((PASS_COUNT++))
}

check_fail() {
    echo "❌ FAIL: $1"
    ((FAIL_COUNT++))
}

check_info() {
    echo "ℹ️  INFO: $1"
}

# Test 1: Supabase REST API - Read stones
check_info "Testing Supabase REST API (public read)..."
RESPONSE=$(curl -s -w "\n%{http_code}" -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impycm1qdGJhdWltcnJ4d2p2bXpoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY4NjAyMjUsImV4cCI6MjA1MjQzNjIyNX0.UhXvLBvLqH7kH9p5gAWlvhfHlWH4OkLmUCkb5TbYzLs" -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impycm1qdGJhdWltcnJ4d2p2bXpoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY4NjAyMjUsImV4cCI6MjA1MjQzNjIyNX0.UhXvLBvLqH7kH9p5gAWlvhfHlWH4OkLmUCkb5TbYzLs" "https://jrrmjtbauimrrxwjvmzh.supabase.co/rest/v1/stones?select=id,name&limit=5")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    STONE_COUNT=$(echo "$BODY" | jq '. | length' 2>/dev/null || echo "0")
    check_pass "Read stones via Supabase REST API (HTTP $HTTP_CODE, count: $STONE_COUNT)"
else
    check_fail "Read stones via Supabase REST API (HTTP $HTTP_CODE)"
fi

# Test 2: Collections
RESPONSE=$(curl -s -w "\n%{http_code}" -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impycm1qdGJhdWltcnJ4d2p2bXpoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY4NjAyMjUsImV4cCI6MjA1MjQzNjIyNX0.UhXvLBvLqH7kH9p5gAWlvhfHlWH4OkLmUCkb5TbYzLs" "https://jrrmjtbauimrrxwjvmzh.supabase.co/rest/v1/collections?select=id,name&limit=5")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "200" ]; then
    check_pass "Read collections via Supabase REST API (HTTP $HTTP_CODE)"
else
    check_fail "Read collections via Supabase REST API (HTTP $HTTP_CODE)"
fi

# Test 3: Dealers
RESPONSE=$(curl -s -w "\n%{http_code}" -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impycm1qdGJhdWltcnJ4d2p2bXpoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY4NjAyMjUsImV4cCI6MjA1MjQzNjIyNX0.UhXvLBvLqH7kH9p5gAWlvhfHlWH4OkLmUCkb5TbYzLs" "https://jrrmjtbauimrrxwjvmzh.supabase.co/rest/v1/dealers?select=id,name&limit=3")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "200" ]; then
    check_pass "Read dealers via Supabase REST API (HTTP $HTTP_CODE)"
else
    check_fail "Read dealers via Supabase REST API (HTTP $HTTP_CODE)"
fi

# Test 4: Vercel API - wall-detect
check_info "Testing Vercel serverless functions..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X OPTIONS "https://grazia-stones.vercel.app/api/wall-detect" -H "Origin: https://grazia-stones.vercel.app" -H "Access-Control-Request-Method: POST" 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "204" ]; then
    check_pass "wall-detect CORS preflight (HTTP $HTTP_CODE)"
else
    check_fail "wall-detect CORS preflight (HTTP $HTTP_CODE)"
fi

# Test 5: generate-visualization CORS
RESPONSE=$(curl -s -w "\n%{http_code}" -X OPTIONS "https://grazia-stones.vercel.app/api/generate-visualization" -H "Origin: https://grazia-stones.vercel.app" -H "Access-Control-Request-Method: POST" 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "204" ]; then
    check_pass "generate-visualization CORS preflight (HTTP $HTTP_CODE)"
else
    check_fail "generate-visualization CORS preflight (HTTP $HTTP_CODE)"
fi

# Test 6: Invalid request to wall-detect (should return 400 with proper error)
check_info "Testing error handling..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "https://grazia-stones.vercel.app/api/wall-detect" -H "Content-Type: application/json" -d '{"invalid":"data"}' 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "400" ]; then
    check_pass "wall-detect rejects invalid input (HTTP $HTTP_CODE)"
elif [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "429" ]; then
    check_pass "wall-detect requires auth or rate limited (HTTP $HTTP_CODE)"
else
    check_fail "wall-detect error handling unexpected (HTTP $HTTP_CODE)"
fi

# Test 7: Supabase Health
check_info "Testing Supabase connection..."
RESPONSE=$(curl -s -w "\n%{http_code}" "https://jrrmjtbauimrrxwjvmzh.supabase.co/rest/v1/" -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impycm1qdGJhdWltcnJ4d2p2bXpoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY4NjAyMjUsImV4cCI6MjA1MjQzNjIyNX0.UhXvLBvLqH7kH9p5gAWlvhfHlWH4OkLmUCkb5TbYzLs" 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "200" ]; then
    check_pass "Supabase REST API health check (HTTP $HTTP_CODE)"
else
    check_fail "Supabase REST API health check (HTTP $HTTP_CODE)"
fi

# Test 8: RLS Test - Try to insert without proper auth (should fail)
check_info "Testing RLS protection..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "https://jrrmjtbauimrrxwjvmzh.supabase.co/rest/v1/stones" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impycm1qdGJhdWltcnJ4d2p2bXpoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY4NjAyMjUsImV4cCI6MjA1MjQzNjIyNX0.UhXvLBvLqH7kH9p5gAWlvhfHlWH4OkLmUCkb5TbYzLs" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impycm1qdGJhdWltcnJ4d2p2bXpoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY4NjAyMjUsImV4cCI6MjA1MjQzNjIyNX0.UhXvLBvLqH7kH9p5gAWlvhfHlWH4OkLmUCkb5TbYzLs" \
  -H "Content-Type: application/json" \
  -d '{"name":"QA_TEST","slug":"qa-test","material_type":"Marble"}' 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "403" ] || [ "$HTTP_CODE" = "401" ]; then
    check_pass "RLS correctly blocks unauthorized insert (HTTP $HTTP_CODE)"
else
    check_fail "RLS protection may be weak (HTTP $HTTP_CODE - expected 403/401)"
fi

echo ""
echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo "✅ PASSED: $PASS_COUNT"
echo "❌ FAILED: $FAIL_COUNT"
echo "=========================================="
echo ""

exit $FAIL_COUNT
