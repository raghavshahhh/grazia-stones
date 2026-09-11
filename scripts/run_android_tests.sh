#!/bin/bash

# Grazia Stones - Android Integration Tests Runner
# Runs all tests on Android Emulator

set -e

echo "🤖 Grazia Stones - Android Integration Tests"
echo "============================================="

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Error: Flutter is not installed"
    exit 1
fi

# Check if Android SDK is available
if [ -z "$ANDROID_HOME" ]; then
    echo "❌ Error: ANDROID_HOME is not set"
    exit 1
fi

# List available Android emulators
echo "📱 Available Android Emulators:"
$ANDROID_HOME/emulator/emulator -list-avds

# Use default emulator or specify one
EMULATOR=${1:-"Pixel_6_API_33"}

echo ""
echo "🚀 Starting Android Emulator: $EMULATOR"

# Start emulator in background
$ANDROID_HOME/emulator/emulator -avd "$EMULATOR" -no-snapshot-load &
EMULATOR_PID=$!

# Wait for emulator to boot
echo "⏳ Waiting for emulator to boot..."
adb wait-for-device
sleep 10

# Wait for boot to complete
while [ "`adb shell getprop sys.boot_completed | tr -d '\r' `" != "1" ]; do
    echo "⏳ Still waiting for emulator..."
    sleep 5
done

echo "✅ Emulator is ready!"

echo ""
echo "🧪 Running Android-specific tests..."

# Run Android platform tests
flutter test integration_test/platform/android_specific_test.dart \
    --dart-define=FLUTTER_TEST_INTEGRATION=true

echo ""
echo "🧪 Running all E2E tests on Android..."

# Run all integration tests on Android
flutter test integration_test/ \
    --dart-define=FLUTTER_TEST_INTEGRATION=true \
    -d "$EMULATOR"

echo ""
echo "✅ Android tests completed!"

# Kill emulator
kill $EMULATOR_PID 2>/dev/null || true
