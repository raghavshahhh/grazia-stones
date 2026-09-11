# Grazia Stones - Testing Documentation

Comprehensive automated testing suite for web, iOS, and Android platforms.

## 📋 Table of Contents

- [Overview](#overview)
- [Test Structure](#test-structure)
- [Running Tests](#running-tests)
- [Test Categories](#test-categories)
- [CI/CD Integration](#cicd-integration)
- [Writing New Tests](#writing-new-tests)
- [Troubleshooting](#troubleshooting)

## 🎯 Overview

This project includes a complete automated testing infrastructure covering:

- **60+ Route Navigation Tests** - All app routes and navigation flows
- **E2E Commerce Flows** - Cart, checkout, orders, quotes, samples
- **User Management** - Profile, addresses, dealers, settings
- **Tools & Spatial Suite** - AI Room Studio, Wall Visualizer, Measure Tool, AR
- **Authentication** - Login, register, forgot password, session management
- **Admin Portal** - All 8 admin modules with CRUD operations
- **Error Scenarios** - Network failures, data errors, edge cases
- **Responsive UI** - 7 breakpoints from 390px to 2560px
- **Performance** - Load times, scroll performance, memory usage
- **Accessibility** - WCAG compliance, screen readers, keyboard navigation
- **Platform-Specific** - iOS and Android native features

**Total Test Coverage**: 200+ test cases across all categories

## 📁 Test Structure

```
grazia-stones/
├── test/
│   ├── helpers/
│   │   ├── test_app_wrapper.dart    # Test environment setup
│   │   └── mock_data.dart            # Mock data for testing
│   ├── unit/                         # Unit tests
│   └── widget/                       # Widget tests
│
├── integration_test/
│   ├── e2e/                          # End-to-end tests
│   │   ├── 01_navigation_test.dart
│   │   ├── 02_commerce_flows_test.dart
│   │   ├── 03_user_management_test.dart
│   │   ├── 04_tools_spatial_suite_test.dart
│   │   ├── 05_authentication_test.dart
│   │   ├── 06_admin_portal_test.dart
│   │   └── 07_responsive_ui_test.dart
│   │
│   ├── error_scenarios/              # Error handling tests
│   │   └── error_handling_test.dart
│   │
│   ├── performance/                  # Performance benchmarks
│   │   └── performance_test.dart
│   │
│   ├── accessibility/                # Accessibility audits
│   │   └── accessibility_test.dart
│   │
│   ├── platform/                     # Platform-specific tests
│   │   ├── ios_specific_test.dart
│   │   └── android_specific_test.dart
│   │
│   ├── test_config.dart              # Test configuration
│   └── test_helpers.dart             # Shared test utilities
│
├── integration_test_driver/
│   └── integration_test.dart         # Test driver
│
└── scripts/
    ├── run_all_tests.sh              # Run all tests
    ├── run_ios_tests.sh              # iOS-specific tests
    └── run_android_tests.sh          # Android-specific tests
```

## 🚀 Running Tests

### Run All Tests

```bash
./scripts/run_all_tests.sh
```

### Run Specific Test Categories

**Unit Tests:**
```bash
flutter test test/unit/
```

**Widget Tests:**
```bash
flutter test test/widget/
```

**Integration Tests:**
```bash
flutter test integration_test/
```

**E2E Tests Only:**
```bash
flutter test integration_test/e2e/
```

**Performance Tests:**
```bash
flutter test integration_test/performance/
```

**Accessibility Tests:**
```bash
flutter test integration_test/accessibility/
```

### Platform-Specific Tests

**iOS (requires macOS):**
```bash
./scripts/run_ios_tests.sh
```

**Android (requires Android SDK):**
```bash
./scripts/run_android_tests.sh
```

**Web:**
```bash
flutter test integration_test/ -d chrome
```

### Run Individual Test Files

```bash
flutter test integration_test/e2e/01_navigation_test.dart
```

## 📚 Test Categories

### 1. Navigation Tests (01_navigation_test.dart)

- ✅ All 60+ routes defined and accessible
- ✅ Bottom navigation functionality
- ✅ Drawer/menu navigation
- ✅ Product detail navigation
- ✅ Deep linking
- ✅ Back navigation
- ✅ Route guards and authentication

### 2. Commerce Flows (02_commerce_flows_test.dart)

- ✅ Wishlist: Add, remove, view, add to cart
- ✅ Cart: Add, update quantity, remove, total calculation
- ✅ Checkout: Address selection, order placement
- ✅ Orders: View list, details, filter
- ✅ Quotes: Create, view, respond
- ✅ Samples: Request, view history
- ✅ Cart persistence across sessions

### 3. User Management (03_user_management_test.dart)

- ✅ Profile: Edit, picture upload, password change
- ✅ Addresses: CRUD operations, set default
- ✅ Dealers: Search, filter, view details
- ✅ Settings: Notifications, language, permissions
- ✅ Legal pages: About, Privacy, Terms
- ✅ Support: FAQ, contact form
- ✅ Saved Designs: View, delete, share

### 4. Tools & Spatial Suite (04_tools_spatial_suite_test.dart)

- ✅ AI Room Studio: Upload, generate, save, share
- ✅ Wall Visualizer: Dimensions, tile calculation
- ✅ Measure Tool: AR measurement, save results
- ✅ AR View: Place objects, rotate, scale

### 5. Authentication (05_authentication_test.dart)

- ✅ Registration: Form validation, password strength
- ✅ Login: Credentials, remember me, social login
- ✅ Forgot Password: Email submission, validation
- ✅ Session: Persistence, timeout, refresh
- ✅ Logout: Profile/settings, data clear
- ✅ Protected routes and admin access

### 6. Admin Portal (06_admin_portal_test.dart)

- ✅ Dashboard: Stats, recent activity
- ✅ Products: CRUD, search, filter, bulk operations
- ✅ Collections: CRUD, add products
- ✅ Orders: View, update status, tracking
- ✅ Quotes: Respond, pricing, convert to order
- ✅ Samples: Approve, reject, ship
- ✅ Dealers: CRUD operations
- ✅ AI Jobs: View, retry, delete

### 7. Error Scenarios (error_handling_test.dart)

- ✅ Network: Offline, timeout, 404, 500
- ✅ Data: Null values, missing fields, malformed JSON
- ✅ User Interaction: Double submission, rapid taps
- ✅ Media: Failed image loading, large files
- ✅ Session: Expired, concurrent, invalid token
- ✅ Edge Cases: Zero quantity, negative prices

### 8. Responsive UI (07_responsive_ui_test.dart)

- ✅ Mobile Small (390x844) - iPhone 13 mini
- ✅ Mobile Medium (393x852) - iPhone 14 Pro
- ✅ Mobile Large (430x932) - iPhone 14 Pro Max
- ✅ Tablet (820x1180) - iPad Air
- ✅ Desktop Small (1366x768) - Laptop
- ✅ Desktop Medium (1920x1080) - Full HD
- ✅ Desktop Large (2560x1440) - 2K
- ✅ Orientation changes
- ✅ Dynamic scaling

### 9. Performance (performance_test.dart)

- ✅ App launch time (<3s)
- ✅ Navigation speed (<500ms)
- ✅ Image loading (<3s)
- ✅ Scroll performance (60fps)
- ✅ Memory usage (<512MB)
- ✅ API call timing
- ✅ Resource cleanup

### 10. Accessibility (accessibility_test.dart)

- ✅ Semantic labels for all interactive elements
- ✅ Tap targets minimum 44x44pt
- ✅ Color contrast (WCAG AA)
- ✅ Keyboard navigation
- ✅ Text scaling up to 200%
- ✅ Screen reader support
- ✅ Form accessibility
- ✅ Time-based content

### 11. iOS-Specific (ios_specific_test.dart)

- ✅ Cupertino widgets
- ✅ iOS back gesture
- ✅ Camera/photo permissions
- ✅ Share sheet
- ✅ Apple Pay integration
- ✅ Face ID / Touch ID
- ✅ Safe area handling
- ✅ VoiceOver compatibility

### 12. Android-Specific (android_specific_test.dart)

- ✅ Material Design components
- ✅ Android back button
- ✅ Permissions handling
- ✅ Google Pay integration
- ✅ Google Sign In
- ✅ System UI styling
- ✅ Multi-window support
- ✅ TalkBack compatibility

## 🔄 CI/CD Integration

Tests run automatically on:
- Push to `main` or `develop` branches
- Pull requests
- Manual workflow dispatch

### GitHub Actions Workflow

```yaml
# .github/workflows/tests.yml
- Unit & Widget Tests (Ubuntu)
- Integration Tests - Web (Ubuntu)
- Integration Tests - iOS (macOS)
- Integration Tests - Android (macOS with emulator)
- Performance Tests (Ubuntu)
- Accessibility Tests (Ubuntu)
```

### Viewing Test Results

1. Go to GitHub Actions tab
2. Select the workflow run
3. View job logs and artifacts
4. Download test reports and coverage

## ✍️ Writing New Tests

### Test File Template

```dart
@Timeout(Duration(minutes: 5))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_config.dart';
import '../test_helpers.dart';
import '../../test/helpers/test_app_wrapper.dart';

void main() {
  late IntegrationTestWidgetsFlutterBinding binding;

  setUpAll(() async {
    binding = await initializeIntegrationTest();
    await initializeTestEnvironment();
  });

  group('Feature Tests', () {
    testWidgets('Test description', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Your test code here
      
      debugPrint('✅ Test passed');
    });
  });
}
```

### Best Practices

1. **Use descriptive test names** - Clear what is being tested
2. **One assertion per test** - Makes failures easy to identify
3. **Clean up after tests** - Reset state, dispose resources
4. **Use test helpers** - Reuse common actions
5. **Mock external dependencies** - Tests should be isolated
6. **Handle async properly** - Use `await` and `pumpAndSettle()`
7. **Add timeouts** - Prevent hanging tests
8. **Document requirements** - Note if test needs device/backend

## 🔧 Troubleshooting

### Tests Timeout

- Increase timeout: `@Timeout(Duration(minutes: 10))`
- Check for infinite loops or missing `await`
- Verify network mocks are working

### Tests Fail on CI but Pass Locally

- Check platform-specific behavior
- Verify environment variables
- Review GitHub Actions logs
- Test on clean environment

### Integration Tests Not Running

- Ensure `integration_test` package in `dev_dependencies`
- Check `integration_test_driver/integration_test.dart` exists
- Verify Flutter SDK version compatibility

### Platform Tests Require Device

Some tests marked with `⚠️` require physical device or simulator:
- AR features
- Camera/photo access
- Biometric authentication
- Payment integrations
- Native share functionality

### Performance Tests Vary

Performance results depend on:
- Hardware specs
- System load
- Network conditions
- Debug vs release mode

## 📊 Test Metrics

Current test coverage:
- **Unit Tests**: TBD (add unit tests as needed)
- **Widget Tests**: TBD (add widget tests as needed)
- **Integration Tests**: 200+ test cases
- **Total Lines**: ~15,000 lines of test code
- **Execution Time**: ~30-45 minutes (full suite)

## 🤝 Contributing

When adding new features:

1. Write tests first (TDD)
2. Ensure all existing tests pass
3. Add integration tests for user flows
4. Update this README if needed
5. Run full test suite before PR

## 📞 Support

For test-related questions:
- Review existing test files for examples
- Check Flutter testing documentation
- Ask in team chat

---

**Last Updated**: September 11, 2026
**Test Coverage**: 200+ tests across 12 categories
**Platforms**: Web, iOS, Android
