#!/bin/bash

# Grazia Stones - Comprehensive Test Runner
# Runs all integration tests, performance tests, and accessibility audits

set -e

echo "🧪 Grazia Stones - Running All Tests"
echo "===================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results tracking
PASSED=0
FAILED=0
SKIPPED=0

# Function to run a test file
run_test() {
    local test_file=$1
    local test_name=$(basename "$test_file")
    
    echo ""
    echo "📋 Running: $test_name"
    echo "-----------------------------------"
    
    if flutter test "$test_file"; then
        echo -e "${GREEN}✅ PASSED: $test_name${NC}"
        ((PASSED++))
    else
        echo -e "${RED}❌ FAILED: $test_name${NC}"
        ((FAILED++))
    fi
}

# Function to run integration test
run_integration_test() {
    local test_file=$1
    local test_name=$(basename "$test_file")
    
    echo ""
    echo "🔧 Running Integration Test: $test_name"
    echo "-----------------------------------"
    
    if flutter test "$test_file" --dart-define=FLUTTER_TEST_INTEGRATION=true; then
        echo -e "${GREEN}✅ PASSED: $test_name${NC}"
        ((PASSED++))
    else
        echo -e "${RED}❌ FAILED: $test_name${NC}"
        ((FAILED++))
    fi
}

echo ""
echo "Step 1: Running Unit Tests"
echo "============================"

# Run unit tests
if [ -d "test/unit" ]; then
    for test_file in test/unit/*_test.dart; do
        if [ -f "$test_file" ]; then
            run_test "$test_file"
        fi
    done
else
    echo -e "${YELLOW}⚠️  No unit tests found${NC}"
fi

echo ""
echo "Step 2: Running Widget Tests"
echo "============================"

# Run widget tests
if [ -d "test/widget" ]; then
    for test_file in test/widget/*_test.dart; do
        if [ -f "$test_file" ]; then
            run_test "$test_file"
        fi
    done
else
    echo -e "${YELLOW}⚠️  No widget tests found${NC}"
fi

echo ""
echo "Step 3: Running E2E Integration Tests"
echo "====================================="

# E2E tests
for test_file in integration_test/e2e/*_test.dart; do
    if [ -f "$test_file" ]; then
        run_integration_test "$test_file"
    fi
done

echo ""
echo "Step 4: Running Error Scenario Tests"
echo "====================================="

# Error scenario tests
if [ -d "integration_test/error_scenarios" ]; then
    for test_file in integration_test/error_scenarios/*_test.dart; do
        if [ -f "$test_file" ]; then
            run_integration_test "$test_file"
        fi
    done
fi

echo ""
echo "Step 5: Running Performance Tests"
echo "=================================="

# Performance tests
if [ -d "integration_test/performance" ]; then
    for test_file in integration_test/performance/*_test.dart; do
        if [ -f "$test_file" ]; then
            run_integration_test "$test_file"
        fi
    done
fi

echo ""
echo "Step 6: Running Accessibility Tests"
echo "===================================="

# Accessibility tests
if [ -d "integration_test/accessibility" ]; then
    for test_file in integration_test/accessibility/*_test.dart; do
        if [ -f "$test_file" ]; then
            run_integration_test "$test_file"
        fi
    done
fi

echo ""
echo "Step 7: Running Platform-Specific Tests"
echo "========================================"
echo -e "${YELLOW}⚠️  Platform tests require device/simulator${NC}"

# Generate test report
echo ""
echo "===================================="
echo "📊 Test Results Summary"
echo "===================================="
echo -e "✅ Passed:  ${GREEN}$PASSED${NC}"
echo -e "❌ Failed:  ${RED}$FAILED${NC}"
echo -e "⏭️  Skipped: ${YELLOW}$SKIPPED${NC}"
echo "===================================="

TOTAL=$((PASSED + FAILED + SKIPPED))
echo "Total tests: $TOTAL"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}💔 Some tests failed${NC}"
    exit 1
fi
