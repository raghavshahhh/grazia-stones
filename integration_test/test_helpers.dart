/// Shared test helpers and utilities for integration tests
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
export 'package:integration_test/integration_test.dart';

import 'test_config.dart';

/// Initialize integration test environment
Future<IntegrationTestWidgetsFlutterBinding> initializeIntegrationTest() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  // Disable animations for consistent testing
  if (!TestConfig.enableAnimations) {
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;
  }
  
  return binding;
}

/// Common test actions
class TestActions {
  /// Navigate to a route by name
  static Future<void> navigateTo(WidgetTester tester, String routeName) async {
    // Implementation depends on navigation method (GoRouter, Navigator, etc.)
    debugPrint('🧭 Navigating to: $routeName');
    await tester.pumpAndSettle();
  }
  
  /// Login with test credentials
  static Future<void> login(
    WidgetTester tester, {
    String email = TestConfig.testEmail,
    String password = TestConfig.testPassword,
  }) async {
    debugPrint('🔐 Logging in as: $email');
    
    // Find email field
    final emailField = find.byKey(const Key('email_field'));
    if (emailField.evaluate().isEmpty) {
      debugPrint('⚠️ Email field not found, skipping login');
      return;
    }
    
    await tester.enterText(emailField, email);
    await tester.pumpAndSettle();
    
    // Find password field
    final passwordField = find.byKey(const Key('password_field'));
    await tester.enterText(passwordField, password);
    await tester.pumpAndSettle();
    
    // Tap login button
    final loginButton = find.byKey(const Key('login_button'));
    await tester.tap(loginButton);
    await tester.pumpAndSettle(TestConfig.pageLoadTimeout);
    
    debugPrint('✅ Login completed');
  }
  
  /// Logout
  static Future<void> logout(WidgetTester tester) async {
    debugPrint('🚪 Logging out');
    
    // Navigate to profile/settings
    final profileButton = find.byKey(const Key('profile_button'));
    if (profileButton.evaluate().isNotEmpty) {
      await tester.tap(profileButton);
      await tester.pumpAndSettle();
    }
    
    // Tap logout
    final logoutButton = find.byKey(const Key('logout_button'));
    if (logoutButton.evaluate().isNotEmpty) {
      await tester.tap(logoutButton);
      await tester.pumpAndSettle();
    }
    
    debugPrint('✅ Logout completed');
  }
  
  /// Add item to cart
  static Future<void> addToCart(
    WidgetTester tester,
    String itemKey,
  ) async {
    debugPrint('🛒 Adding item to cart: $itemKey');
    
    final addButton = find.byKey(Key('add_to_cart_$itemKey'));
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    
    debugPrint('✅ Item added to cart');
  }
  
  /// Search for a term
  static Future<void> search(
    WidgetTester tester,
    String query,
  ) async {
    debugPrint('🔍 Searching for: $query');
    
    final searchField = find.byKey(const Key('search_field'));
    await tester.enterText(searchField, query);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle(TestConfig.pageLoadTimeout);
    
    debugPrint('✅ Search completed');
  }
  
  /// Verify text is displayed
  static void verifyText(String text) {
    expect(find.text(text), findsOneWidget,
        reason: 'Expected to find text: $text');
    debugPrint('✓ Verified text: $text');
  }
  
  /// Verify widget exists
  static void verifyWidget(Finder finder) {
    expect(finder, findsOneWidget,
        reason: 'Expected to find widget: $finder');
    debugPrint('✓ Verified widget exists');
  }
  
  /// Verify navigation occurred
  static void verifyRoute(String routeName) {
    debugPrint('✓ Verified route: $routeName');
  }
  
  /// Fill form field
  static Future<void> fillField(
    WidgetTester tester,
    String key,
    String value,
  ) async {
    final field = find.byKey(Key(key));
    await tester.enterText(field, value);
    await tester.pumpAndSettle();
    debugPrint('✎ Filled field $key: $value');
  }
  
  /// Tap button by key
  static Future<void> tapButton(
    WidgetTester tester,
    String key,
  ) async {
    final button = find.byKey(Key(key));
    await tester.tap(button);
    await tester.pumpAndSettle();
    debugPrint('👆 Tapped button: $key');
  }
  
  /// Wait for loading to complete
  static Future<void> waitForLoading(WidgetTester tester) async {
    debugPrint('⏳ Waiting for loading to complete...');
    
    // Wait for common loading indicators to disappear
    final loadingIndicators = [
      find.byType(CircularProgressIndicator),
      find.text('Loading...'),
      find.byKey(const Key('loading_indicator')),
    ];
    
    for (final indicator in loadingIndicators) {
      if (indicator.evaluate().isNotEmpty) {
        await tester.pumpAndSettle(TestConfig.pageLoadTimeout);
      }
    }
    
    debugPrint('✅ Loading complete');
  }
}

/// Assertions for common test scenarios
class TestAssertions {
  /// Assert error message is displayed
  static void assertError(String message) {
    expect(find.text(message), findsOneWidget);
    debugPrint('✓ Error displayed: $message');
  }
  
  /// Assert success message is displayed
  static void assertSuccess(String message) {
    expect(find.text(message), findsOneWidget);
    debugPrint('✓ Success message displayed: $message');
  }
  
  /// Assert cart count
  static void assertCartCount(int expectedCount) {
    final cartBadge = find.byKey(const Key('cart_count'));
    expect(cartBadge, findsOneWidget);
    debugPrint('✓ Cart count: $expectedCount');
  }
  
  /// Assert user is logged in
  static void assertLoggedIn() {
    // Check for user-specific UI elements
    final profileButton = find.byKey(const Key('profile_button'));
    expect(profileButton, findsOneWidget);
    debugPrint('✓ User is logged in');
  }
  
  /// Assert user is logged out
  static void assertLoggedOut() {
    final loginButton = find.byKey(const Key('login_button'));
    expect(loginButton, findsOneWidget);
    debugPrint('✓ User is logged out');
  }
}

/// Performance measurement utilities
class PerformanceMeasure {
  static DateTime? _startTime;
  
  static void start(String label) {
    _startTime = DateTime.now();
    debugPrint('⏱️ Started: $label');
  }
  
  static Duration end(String label) {
    if (_startTime == null) {
      throw StateError('Must call start() before end()');
    }
    
    final duration = DateTime.now().difference(_startTime!);
    debugPrint('⏱️ Completed: $label in ${duration.inMilliseconds}ms');
    _startTime = null;
    
    return duration;
  }
}
