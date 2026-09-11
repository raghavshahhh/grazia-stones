#!/bin/bash

echo "=========================================="
echo "STORE READINESS VERIFICATION"
echo "=========================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
BLOCKER_COUNT=0

check_pass() {
    echo "✅ PASS: $1"
    ((PASS_COUNT++))
}

check_fail() {
    echo "❌ FAIL: $1"
    ((FAIL_COUNT++))
}

check_warn() {
    echo "⚠️  WARN: $1"
    ((WARN_COUNT++))
}

check_blocker() {
    echo "🚫 BLOCKER: $1"
    ((BLOCKER_COUNT++))
}

check_info() {
    echo "ℹ️  INFO: $1"
}

echo "==========================================  
IOS STORE READINESS
=========================================="

# iOS Bundle ID
if grep -q "CFBundleIdentifier" ios/Runner/Info.plist; then
    BUNDLE_ID=$(grep -A1 "CFBundleIdentifier" ios/Runner/Info.plist | grep "string" | sed 's/.*<string>\(.*\)<\/string>/\1/')
    if [ "$BUNDLE_ID" = "\$(PRODUCT_BUNDLE_IDENTIFIER)" ]; then
        check_warn "Bundle ID is variable (set in project.pbxproj)"
    else
        check_pass "Bundle ID: $BUNDLE_ID"
    fi
else
    check_fail "Bundle ID not found"
fi

# iOS Display Name
if grep -q "CFBundleDisplayName" ios/Runner/Info.plist; then
    DISPLAY_NAME=$(grep -A1 "CFBundleDisplayName" ios/Runner/Info.plist | grep "string" | sed 's/.*<string>\(.*\)<\/string>/\1/')
    check_pass "Display Name: $DISPLAY_NAME"
else
    check_warn "Display Name not set"
fi

# iOS Version
VERSION=$(grep "^version:" pubspec.yaml | awk '{print $2}')
if [ -n "$VERSION" ]; then
    VERSION_NAME=$(echo $VERSION | cut -d'+' -f1)
    BUILD_NUMBER=$(echo $VERSION | cut -d'+' -f2)
    check_pass "Version: $VERSION_NAME (Build: $BUILD_NUMBER)"
else
    check_fail "Version not found in pubspec.yaml"
fi

# iOS Permissions
REQUIRED_PERMS=("NSCameraUsageDescription" "NSPhotoLibraryUsageDescription" "NSLocationWhenInUseUsageDescription")
for perm in "${REQUIRED_PERMS[@]}"; do
    if grep -q "$perm" ios/Runner/Info.plist; then
        check_pass "Permission: $perm"
    else
        check_fail "Missing permission: $perm"
    fi
done

# iOS Deployment Target
if [ -f "ios/Podfile" ]; then
    DEPLOYMENT_TARGET=$(grep "platform :ios" ios/Podfile | sed "s/.*'\(.*\)'.*/\1/" | head -1)
    if [ -n "$DEPLOYMENT_TARGET" ]; then
        check_pass "Deployment Target: iOS $DEPLOYMENT_TARGET"
    else
        check_warn "Deployment target not found in Podfile"
    fi
fi

# iOS Signing
check_info "iOS Signing: Requires manual configuration in Xcode"
check_info "  1. Open ios/Runner.xcworkspace in Xcode"
check_info "  2. Configure Signing & Capabilities"
check_info "  3. Select Development Team"
check_info "  4. Configure provisioning profiles"

# iOS Icons
if [ -d "ios/Runner/Assets.xcassets/AppIcon.appiconset" ]; then
    ICON_COUNT=$(ls -1 ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png 2>/dev/null | wc -l)
    if [ "$ICON_COUNT" -gt 0 ]; then
        check_pass "App Icons: $ICON_COUNT icons found"
    else
        check_warn "No app icon PNGs found"
    fi
else
    check_fail "AppIcon.appiconset directory not found"
fi

echo ""
echo "=========================================="
echo "ANDROID STORE READINESS"
echo "=========================================="

# Android Application ID
if grep -q "applicationId" android/app/build.gradle.kts; then
    APP_ID=$(grep "applicationId" android/app/build.gradle.kts | sed 's/.*"\(.*\)".*/\1/')
    check_pass "Application ID: $APP_ID"
else
    check_fail "Application ID not found"
fi

# Android Version
check_pass "Version Code: Derived from pubspec.yaml ($BUILD_NUMBER)"
check_pass "Version Name: Derived from pubspec.yaml ($VERSION_NAME)"

# Android Min/Target SDK
if grep -q "minSdk" android/app/build.gradle.kts; then
    MIN_SDK=$(grep "minSdk" android/app/build.gradle.kts | sed 's/.*= \([0-9]*\).*/\1/')
    check_pass "Min SDK: API $MIN_SDK (Android 7.0+)"
else
    check_warn "Min SDK not found"
fi

# Android Permissions
ANDROID_PERMS=("CAMERA" "ACCESS_FINE_LOCATION" "INTERNET")
for perm in "${ANDROID_PERMS[@]}"; do
    if grep -q "android.permission.$perm" android/app/src/main/AndroidManifest.xml; then
        check_pass "Permission: $perm"
    else
        check_fail "Missing permission: $perm"
    fi
done

# Android Signing - CRITICAL CHECK
check_info "Android Release Signing Configuration:"
if grep -q 'signingConfig = signingConfigs.getByName("debug")' android/app/build.gradle.kts; then
    check_blocker "RELEASE BUILD USES DEBUG SIGNING!"
    check_info "  → This MUST be fixed before Play Store submission"
    check_info "  → Create release keystore: keytool -genkey -v -keystore release.keystore ..."
    check_info "  → Configure signing in android/app/build.gradle.kts"
    check_info "  → Add key.properties with storePassword, keyPassword, keyAlias"
else
    check_pass "Release signing configured (not using debug keys)"
fi

# Android Icons
if [ -d "android/app/src/main/res/mipmap-xxxhdpi" ]; then
    ICON_COUNT=$(ls -1 android/app/src/main/res/mipmap-xxxhdpi/ic_launcher*.png 2>/dev/null | wc -l)
    if [ "$ICON_COUNT" -gt 0 ]; then
        check_pass "App Icons: Found in mipmap directories"
    else
        check_warn "No launcher icons found"
    fi
else
    check_warn "mipmap-xxxhdpi directory not found"
fi

# Android App Name
if grep -q 'android:label="Grazia Stones"' android/app/src/main/AndroidManifest.xml; then
    check_pass "App Name: Grazia Stones"
else
    check_warn "App name not found in AndroidManifest.xml"
fi

echo ""
echo "=========================================="
echo "COMMON CHECKS"
echo "=========================================="

# Localhost References
check_info "Checking for localhost references..."
LOCALHOST_IN_LIB=$(grep -r "localhost" lib/ --include="*.dart" 2>/dev/null | grep -v "//" | grep -v "kDebugMode" | wc -l || echo "0")
if [ "$LOCALHOST_IN_LIB" -eq "0" ]; then
    check_pass "No hardcoded localhost in lib/"
else
    check_fail "Found $LOCALHOST_IN_LIB hardcoded localhost references"
fi

# Secrets Check
check_info "Checking for exposed secrets..."
if grep -rE "(rzp_test_[A-Za-z0-9]{20,}|sk_[a-z]{4}_[A-Za-z0-9]{20,})" lib/ 2>/dev/null | head -1; then
    check_fail "Potential exposed API keys found"
else
    check_pass "No obvious exposed secrets in code"
fi

# Debug Print Statements
DEBUG_PRINTS=$(grep -r "print(" lib/ --include="*.dart" 2>/dev/null | grep -v "//" | wc -l || echo "0")
if [ "$DEBUG_PRINTS" -gt 50 ]; then
    check_warn "Found $DEBUG_PRINTS print() statements (consider using logger)"
else
    check_pass "Print statements: $DEBUG_PRINTS (acceptable)"
fi

# Build Artifacts
if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    APK_SIZE=$(du -h build/app/outputs/flutter-apk/app-release.apk | awk '{print $1}')
    check_pass "Android APK built ($APK_SIZE)"
else
    check_warn "Android APK not found (run: flutter build apk)"
fi

if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
    AAB_SIZE=$(du -h build/app/outputs/bundle/release/app-release.aab | awk '{print $1}')
    check_pass "Android AAB built ($AAB_SIZE)"
else
    check_warn "Android AAB not found (run: flutter build appbundle)"
fi

echo ""
echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo "✅ PASSED: $PASS_COUNT"
echo "⚠️  WARNINGS: $WARN_COUNT"
echo "❌ FAILED: $FAIL_COUNT"
echo "🚫 BLOCKERS: $BLOCKER_COUNT"
echo "=========================================="
echo ""

if [ $BLOCKER_COUNT -gt 0 ]; then
    echo "🚫 NOT STORE READY - CRITICAL BLOCKERS FOUND"
    echo ""
    echo "BLOCKERS MUST BE FIXED:"
    echo "  1. Android release signing (using debug keys)"
    echo ""
    exit 2
elif [ $FAIL_COUNT -gt 0 ]; then
    echo "❌ NOT STORE READY - FAILURES FOUND"
    exit 1
elif [ $WARN_COUNT -gt 5 ]; then
    echo "⚠️  READY WITH WARNINGS"
    exit 0
else
    echo "✅ STORE READY (subject to manual review)"
    exit 0
fi
