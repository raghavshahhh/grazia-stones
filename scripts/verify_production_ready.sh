#!/bin/bash
set -e

echo "=========================================="
echo "GRAZIA STONES - PRODUCTION READINESS CHECK"
echo "=========================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

check_pass() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
    ((PASS_COUNT++))
}

check_fail() {
    echo -e "${RED}❌ FAIL${NC}: $1"
    ((FAIL_COUNT++))
}

check_warn() {
    echo -e "${YELLOW}⚠️  WARN${NC}: $1"
    ((WARN_COUNT++))
}

echo "1. CHECKING GIT STATUS..."
if [ -z "$(git status --porcelain)" ]; then
    check_pass "No uncommitted changes"
else
    check_warn "Uncommitted changes found"
    git status --short
fi
echo ""

echo "2. CHECKING VERSION..."
VERSION=$(grep "^version:" pubspec.yaml | awk '{print $2}')
if [ -n "$VERSION" ]; then
    check_pass "Version found: $VERSION"
else
    check_fail "No version in pubspec.yaml"
fi
echo ""

echo "3. CHECKING iOS CONFIGURATION..."
if grep -q "CFBundleIdentifier" ios/Runner/Info.plist; then
    check_pass "iOS Bundle ID configured"
else
    check_fail "iOS Bundle ID missing"
fi

if grep -q "NSCameraUsageDescription" ios/Runner/Info.plist; then
    check_pass "iOS camera permission configured"
else
    check_fail "iOS camera permission missing"
fi
echo ""

echo "4. CHECKING ANDROID CONFIGURATION..."
if grep -q "applicationId" android/app/build.gradle.kts; then
    check_pass "Android applicationId configured"
else
    check_fail "Android applicationId missing"
fi

if grep -q "CAMERA" android/app/src/main/AndroidManifest.xml; then
    check_pass "Android camera permission configured"
else
    check_fail "Android camera permission missing"
fi

if grep -q 'signingConfig = signingConfigs.getByName("debug")' android/app/build.gradle.kts; then
    check_warn "Android release build uses DEBUG signing (must fix for production)"
else
    check_pass "Android release signing configured"
fi
echo ""

echo "5. CHECKING FOR LOCALHOST REFERENCES..."
LOCALHOST_COUNT=$(grep -r "localhost" lib/ --include="*.dart" 2>/dev/null | grep -v "// " | grep -v "kDebugMode" | wc -l || echo "0")
if [ "$LOCALHOST_COUNT" -eq "0" ]; then
    check_pass "No hardcoded localhost URLs in lib/"
else
    check_fail "Found $LOCALHOST_COUNT localhost references in lib/"
fi
echo ""

echo "6. CHECKING FOR HARDCODED SECRETS..."
SECRET_PATTERNS="sk_|pk_test|rzp_test_[A-Za-z0-9]{20,}|AIza[A-Za-z0-9_-]{35,}"
if grep -rE "$SECRET_PATTERNS" lib/ 2>/dev/null | grep -v "PLACEH" | head -5; then
    check_fail "Potential hardcoded secrets found"
else
    check_pass "No obvious hardcoded secrets"
fi
echo ""

echo "7. CHECKING BUILD ARTIFACTS..."
if [ -d "build/web" ]; then
    WEB_SIZE=$(du -sh build/web | awk '{print $1}')
    check_pass "Web build exists ($WEB_SIZE)"
else
    check_fail "Web build missing"
fi

if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    APK_SIZE=$(du -sh build/app/outputs/flutter-apk/app-release.apk | awk '{print $1}')
    check_pass "Android APK exists ($APK_SIZE)"
else
    check_warn "Android APK not built"
fi

if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
    AAB_SIZE=$(du -sh build/app/outputs/bundle/release/app-release.aab | awk '{print $1}')
    check_pass "Android AAB exists ($AAB_SIZE)"
else
    check_warn "Android AAB not built"
fi
echo ""

echo "8. CHECKING FLUTTER ANALYZE..."
if flutter analyze --no-pub 2>&1 | grep -q "No issues found"; then
    check_pass "Flutter analyze clean"
else
    check_warn "Flutter analyze has warnings"
fi
echo ""

echo "9. CHECKING CI/CD..."
if [ -f ".github/workflows/tests.yml" ]; then
    check_pass "CI workflow exists"
else
    check_warn "No CI workflow"
fi
echo ""

echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo -e "${GREEN}✅ PASSED: $PASS_COUNT${NC}"
echo -e "${YELLOW}⚠️  WARNINGS: $WARN_COUNT${NC}"
echo -e "${RED}❌ FAILED: $FAIL_COUNT${NC}"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    if [ $WARN_COUNT -eq 0 ]; then
        echo -e "${GREEN}🎉 PRODUCTION READY${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠️  READY WITH WARNINGS${NC}"
        exit 0
    fi
else
    echo -e "${RED}❌ NOT PRODUCTION READY${NC}"
    exit 1
fi
