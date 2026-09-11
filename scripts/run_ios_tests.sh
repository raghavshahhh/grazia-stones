#!/bin/bash

# Grazia Stones - iOS Integration Tests Runner
# Runs all tests on iOS Simulator

set -e

echo "🍎 Grazia Stones - iOS Integration Tests"
echo "========================================="

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Error: iOS tests can only run on macOS"
    exit 1
fi

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Error: Flutter is not installed"
    exit 1
fi

# List available iOS simulators
echo "📱 Available iOS Simulators:"
xcrun simctl list devices available | grep "iPhone"

# Use default simulator or specify one
SIMULATOR=${1:-"iPhone 14 Pro"}

echo ""
echo "🚀 Starting iOS Simulator: $SIMULATOR"

# Boot simulator if not running
xcrun simctl boot "$SIMULATOR" 2>/dev/null || true
sleep 5

echo ""
echo "🧪 Running iOS-specific tests..."

# Run iOS platform tests
flutter test integration_test/platform/ios_specific_test.dart \
    --dart-define=FLUTTER_TEST_INTEGRATION=true

echo ""
echo "🧪 Running all E2E tests on iOS..."

# Run all integration tests on iOS
flutter test integration_test/ \
    --dart-define=FLUTTER_TEST_INTEGRATION=true \
    -d "$SIMULATOR"

echo ""
echo "✅ iOS tests completed!"
