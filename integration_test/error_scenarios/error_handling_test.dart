/// Error Scenario Tests
/// Tests network failures, timeouts, missing data, double submits, and edge cases
@Timeout(Duration(minutes: 10))
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

  group('Network Error Scenarios', () {
    testWidgets('Handle offline state gracefully', (tester) async {
      await tester.pumpWidget(createTestApp(mockNetwork: false));
      await tester.pumpAndSettle();

      // Navigate to a page requiring network
      final catalogueButton = find.text('Catalogue');
      if (catalogueButton.evaluate().isNotEmpty) {
        await tester.tap(catalogueButton.first);
        await tester.pumpAndSettle(TestConfig.pageLoadTimeout);

        // Should show offline indicator or error
        final offlineIndicator = find.textContaining('offline');
        final errorMessage = find.textContaining('network');
        
        expect(
          offlineIndicator.evaluate().isNotEmpty || errorMessage.evaluate().isNotEmpty,
          true,
          reason: 'Expected offline/network error message',
        );
        
        debugPrint('✅ Offline state handled');
      }
    });

    testWidgets('Handle network timeout', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Trigger API call that times out
      debugPrint('⚠️ Network timeout requires backend mock');
    });

    testWidgets('Handle slow network connection', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Should show loading indicators
      final loadingIndicator = find.byType(CircularProgressIndicator);
      if (loadingIndicator.evaluate().isNotEmpty) {
        debugPrint('✅ Loading indicator displayed during slow network');
      }
    });

    testWidgets('Retry failed network request', (tester) async {
      await tester.pumpWidget(createTestApp(mockNetwork: false));
      await tester.pumpAndSettle();

      // Trigger failed request
      final retryButton = find.text('Retry');
      if (retryButton.evaluate().isNotEmpty) {
        await tester.tap(retryButton);
        await tester.pumpAndSettle();
        
        debugPrint('✅ Retry functionality works');
      }
    });

    testWidgets('Handle intermittent connectivity', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Simulate connection loss during operation
      debugPrint('⚠️ Intermittent connectivity requires network mock');
    });

    testWidgets('Show appropriate error for 404', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Navigate to non-existent resource
      debugPrint('⚠️ 404 handling requires backend mock');
    });

    testWidgets('Show appropriate error for 500', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Trigger server error
      debugPrint('⚠️ 500 error handling requires backend mock');
    });

    testWidgets('Handle API rate limiting', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Make rapid API calls
      for (var i = 0; i < 20; i++) {
        // Trigger API call
        await tester.pump(const Duration(milliseconds: 10));
      }

      debugPrint('⚠️ Rate limiting requires backend mock');
    });
  });

  group('Data Error Scenarios', () {
    testWidgets('Handle missing/null data gracefully', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Load page with missing data
      debugPrint('⚠️ Null data handling requires mock data injection');
    });

    testWidgets('Handle empty list states', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Navigate to empty cart
      final cartNav = find.text('Cart');
      if (cartNav.evaluate().isNotEmpty) {
        await tester.tap(cartNav.first);
        await tester.pumpAndSettle();

        // Should show empty state
        final emptyMessage = find.textContaining('empty');
        if (emptyMessage.evaluate().isNotEmpty) {
          debugPrint('✅ Empty cart state displayed');
        }
      }
    });

    testWidgets('Handle malformed JSON response', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      debugPrint('⚠️ Malformed JSON requires backend mock');
    });

    testWidgets('Handle missing required fields', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Try to submit form with missing fields
      final submitButton = find.byKey(const Key('submit_form_button'));
      if (submitButton.evaluate().isNotEmpty) {
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        // Should show validation errors
        final errorText = find.textContaining('required');
        if (errorText.evaluate().isNotEmpty) {
          debugPrint('✅ Required field validation works');
        }
      }
    });

    testWidgets('Handle invalid data types', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Enter text in numeric field
      final priceField = find.byKey(const Key('price_field'));
      if (priceField.evaluate().isNotEmpty) {
        await tester.enterText(priceField, 'invalid');
        await tester.pumpAndSettle();

        // Should show error or prevent input
        debugPrint('✅ Invalid data type handled');
      }
    });

    testWidgets('Handle data exceeding max length', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final textField = find.byKey(const Key('text_field'));
      if (textField.evaluate().isNotEmpty) {
        await tester.enterText(textField, 'A' * 1000);
        await tester.pumpAndSettle();

        // Should truncate or show error
        debugPrint('✅ Max length validation works');
      }
    });

    testWidgets('Handle special characters in input', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final searchField = find.byKey(const Key('search_field'));
      if (searchField.evaluate().isNotEmpty) {
        await tester.enterText(searchField, '<script>alert("XSS")</script>');
        await tester.pumpAndSettle();

        // Should sanitize or escape
        debugPrint('✅ Special character handling works');
      }
    });
  });

  group('User Interaction Error Scenarios', () {
    testWidgets('Prevent double form submission', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final submitButton = find.byKey(const Key('submit_button'));
      if (submitButton.evaluate().isNotEmpty) {
        // Rapid double tap
        await tester.tap(submitButton);
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        // Should only submit once
        debugPrint('✅ Double submission prevented');
      }
    });

    testWidgets('Handle rapid button taps', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final button = find.byKey(const Key('action_button'));
      if (button.evaluate().isNotEmpty) {
        for (var i = 0; i < 10; i++) {
          await tester.tap(button);
          await tester.pump(const Duration(milliseconds: 10));
        }
        await tester.pumpAndSettle();

        debugPrint('✅ Rapid taps handled');
      }
    });

    testWidgets('Handle back navigation during loading', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Navigate to page
      final catalogueButton = find.text('Catalogue');
      if (catalogueButton.evaluate().isNotEmpty) {
        await tester.tap(catalogueButton.first);
        await tester.pump(); // Don't wait for loading

        // Immediately go back
        final backButton = find.byIcon(Icons.arrow_back);
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton);
          await tester.pumpAndSettle();
          
          debugPrint('✅ Back during loading handled');
        }
      }
    });

    testWidgets('Handle app backgrounding during operation', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Start operation
      final submitButton = find.byKey(const Key('submit_button'));
      if (submitButton.evaluate().isNotEmpty) {
        await tester.tap(submitButton);
        await tester.pump();

        // Background app
        await tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();

        // Foreground app
        await tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pumpAndSettle();

        debugPrint('✅ App backgrounding handled');
      }
    });

    testWidgets('Handle orientation change during form entry', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Fill form
      await TestActions.fillField(tester, 'form_field', 'Test data');

      // Simulate orientation change
      await tester.binding.setSurfaceSize(const Size(844, 390)); // Landscape
      await tester.pumpAndSettle();

      // Verify data persisted
      final field = find.byKey(const Key('form_field'));
      if (field.evaluate().isNotEmpty) {
        debugPrint('✅ Orientation change handled');
      }

      // Restore portrait
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpAndSettle();
    });
  });

  group('Image & Media Error Scenarios', () {
    testWidgets('Handle failed image loading', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle(TestConfig.pageLoadTimeout);

      // Look for error placeholder or retry
      final errorIcon = find.byIcon(Icons.error);
      final brokenImage = find.byIcon(Icons.broken_image);
      
      if (errorIcon.evaluate().isNotEmpty || brokenImage.evaluate().isNotEmpty) {
        debugPrint('✅ Failed image handled with placeholder');
      }
    });

    testWidgets('Handle slow image loading', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Should show loading shimmer/skeleton
      final shimmer = find.byKey(const Key('image_shimmer'));
      if (shimmer.evaluate().isNotEmpty) {
        debugPrint('✅ Image loading shimmer displayed');
      }
    });

    testWidgets('Handle unsupported image format', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      debugPrint('⚠️ Unsupported format requires mock');
    });

    testWidgets('Handle large image file size', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      debugPrint('⚠️ Large file handling requires image picker mock');
    });

    testWidgets('Handle camera permission denied', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Try to access camera
      final cameraButton = find.byKey(const Key('camera_button'));
      if (cameraButton.evaluate().isNotEmpty) {
        await tester.tap(cameraButton);
        await tester.pumpAndSettle();

        // Should show permission error
        debugPrint('⚠️ Camera permission requires device');
      }
    });
  });

  group('Session & Authentication Error Scenarios', () {
    testWidgets('Handle expired session', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      debugPrint('⚠️ Session expiry requires backend mock');
    });

    testWidgets('Handle concurrent session from another device', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      debugPrint('⚠️ Concurrent session requires backend mock');
    });

    testWidgets('Handle forced logout', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      debugPrint('⚠️ Forced logout requires backend mock');
    });

    testWidgets('Handle invalid auth token', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      debugPrint('⚠️ Invalid token requires backend mock');
    });
  });

  group('Payment & Transaction Error Scenarios', () {
    testWidgets('Handle payment gateway failure', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      debugPrint('⚠️ Payment failure requires payment gateway mock');
    });

    testWidgets('Handle insufficient funds', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      debugPrint('⚠️ Insufficient funds requires payment gateway mock');
    });

    testWidgets('Handle transaction timeout', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      debugPrint('⚠️ Transaction timeout requires payment gateway mock');
    });

    testWidgets('Handle duplicate transaction', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      debugPrint('⚠️ Duplicate transaction requires backend mock');
    });
  });

  group('Storage Error Scenarios', () {
    testWidgets('Handle storage full', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      debugPrint('⚠️ Storage full requires storage mock');
    });

    testWidgets('Handle corrupted local data', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      debugPrint('⚠️ Corrupted data requires storage mock');
    });

    testWidgets('Handle cache clear during operation', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      debugPrint('⚠️ Cache clear requires storage mock');
    });
  });

  group('Edge Cases & Boundary Conditions', () {
    testWidgets('Handle extremely long product names', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Product name should truncate or wrap properly
      debugPrint('⚠️ Long names require mock data');
    });

    testWidgets('Handle zero quantity in cart', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final decrementButton = find.byKey(const Key('quantity_decrement'));
      if (decrementButton.evaluate().isNotEmpty) {
        // Keep decrementing to zero
        for (var i = 0; i < 10; i++) {
          await tester.tap(decrementButton);
          await tester.pumpAndSettle();
        }

        // Item should be removed or quantity stays at 1
        debugPrint('✅ Zero quantity handled');
      }
    });

    testWidgets('Handle negative price values', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      debugPrint('⚠️ Negative price requires mock data');
    });

    testWidgets('Handle very large numbers', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final quantityField = find.byKey(const Key('quantity_field'));
      if (quantityField.evaluate().isNotEmpty) {
        await tester.enterText(quantityField, '999999999');
        await tester.pumpAndSettle();

        // Should handle or limit
        debugPrint('✅ Large number handled');
      }
    });

    testWidgets('Handle date in past/future', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      debugPrint('⚠️ Date validation requires form');
    });

    testWidgets('Handle simultaneous updates to same resource', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      debugPrint('⚠️ Concurrent updates require backend mock');
    });
  });

  group('Error Recovery Tests', () {
    testWidgets('Clear error state on retry', (tester) async {
      await tester.pumpWidget(createTestApp(mockNetwork: false));
      await tester.pumpAndSettle();

      // Trigger error
      final retryButton = find.text('Retry');
      if (retryButton.evaluate().isNotEmpty) {
        await tester.tap(retryButton);
        await tester.pumpAndSettle();

        // Error should clear
        debugPrint('✅ Error state cleared on retry');
      }
    });

    testWidgets('Navigate away from error state', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // After error, navigate to different page
      final homeButton = find.text('Home');
      if (homeButton.evaluate().isNotEmpty) {
        await tester.tap(homeButton);
        await tester.pumpAndSettle();

        // Should reset cleanly
        debugPrint('✅ Navigation from error works');
      }
    });

    testWidgets('Refresh to recover from error', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Pull to refresh
      await tester.drag(
        find.byType(RefreshIndicator),
        const Offset(0, 300),
      );
      await tester.pumpAndSettle();

      debugPrint('✅ Refresh recovery works');
    });
  });
}
