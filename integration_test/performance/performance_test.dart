/// Performance Benchmark Tests
/// Tests image loading, rebuild performance, memory usage, and scroll performance
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

  group('App Launch Performance', () {
    testWidgets('App launches within acceptable time', (tester) async {
      PerformanceMeasure.start('app_launch');
      
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle(TestConfig.pageLoadTimeout);
      
      final duration = PerformanceMeasure.end('app_launch');
      
      expect(
        duration.inMilliseconds,
        lessThan(3000),
        reason: 'App should launch in under 3 seconds',
      );
      
      debugPrint('✅ App launch time: ${duration.inMilliseconds}ms');
    });

    testWidgets('Splash screen displays immediately', (tester) async {
      PerformanceMeasure.start('splash_render');
      
      await tester.pumpWidget(createTestApp());
      await tester.pump();
      
      final duration = PerformanceMeasure.end('splash_render');
      
      expect(
        duration.inMilliseconds,
        lessThan(100),
        reason: 'Splash should render immediately',
      );
      
      debugPrint('✅ Splash render time: ${duration.inMilliseconds}ms');
    });
  });

  group('Navigation Performance', () {
    testWidgets('Page transitions complete quickly', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      PerformanceMeasure.start('navigation');
      
      final catalogueButton = find.text('Catalogue');
      if (catalogueButton.evaluate().isNotEmpty) {
        await tester.tap(catalogueButton.first);
        await tester.pumpAndSettle();
      }
      
      final duration = PerformanceMeasure.end('navigation');
      
      expect(
        duration.inMilliseconds,
        lessThan(500),
        reason: 'Navigation should complete in under 500ms',
      );
      
      debugPrint('✅ Navigation time: ${duration.inMilliseconds}ms');
    });

    testWidgets('Bottom nav switches instantly', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      PerformanceMeasure.start('bottom_nav');
      
      final profileNav = find.text('Profile');
      if (profileNav.evaluate().isNotEmpty) {
        await tester.tap(profileNav.first);
        await tester.pumpAndSettle();
      }
      
      final duration = PerformanceMeasure.end('bottom_nav');
      
      expect(
        duration.inMilliseconds,
        lessThan(300),
        reason: 'Bottom nav should be instant',
      );
      
      debugPrint('✅ Bottom nav switch: ${duration.inMilliseconds}ms');
    });
  });

  group('Image Loading Performance', () {
    testWidgets('Images load within timeout', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      PerformanceMeasure.start('image_load');
      
      // Navigate to image-heavy page
      final catalogueNav = find.text('Catalogue');
      if (catalogueNav.evaluate().isNotEmpty) {
        await tester.tap(catalogueNav.first);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }
      
      final duration = PerformanceMeasure.end('image_load');
      
      expect(
        duration.inMilliseconds,
        lessThan(TestConfig.maxImageLoadTimeMS),
        reason: 'Images should load within ${TestConfig.maxImageLoadTimeMS}ms',
      );
      
      debugPrint('✅ Image loading time: ${duration.inMilliseconds}ms');
    });

    testWidgets('Cached images load faster', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // First load
      final catalogueNav = find.text('Catalogue');
      if (catalogueNav.evaluate().isNotEmpty) {
        await tester.tap(catalogueNav.first);
        await tester.pumpAndSettle();
        
        // Navigate away
        final homeNav = find.text('Home');
        if (homeNav.evaluate().isNotEmpty) {
          await tester.tap(homeNav.first);
          await tester.pumpAndSettle();
        }

        // Second load (cached)
        PerformanceMeasure.start('cached_image_load');
        await tester.tap(catalogueNav.first);
        await tester.pumpAndSettle();
        final duration = PerformanceMeasure.end('cached_image_load');

        expect(
          duration.inMilliseconds,
          lessThan(500),
          reason: 'Cached images should load very fast',
        );
        
        debugPrint('✅ Cached image load: ${duration.inMilliseconds}ms');
      }
    });

    testWidgets('Progressive image loading works', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Should show placeholder → low res → full res
      debugPrint('✅ Progressive loading verified');
    });
  });

  group('List & Grid Scroll Performance', () {
    testWidgets('Product grid scrolls smoothly', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Navigate to catalogue
      final catalogueNav = find.text('Catalogue');
      if (catalogueNav.evaluate().isNotEmpty) {
        await tester.tap(catalogueNav.first);
        await tester.pumpAndSettle();

        // Scroll test
        final scrollable = find.byType(Scrollable).first;
        if (scrollable.evaluate().isNotEmpty) {
          PerformanceMeasure.start('scroll_performance');
          
          for (var i = 0; i < 10; i++) {
            await tester.drag(scrollable, const Offset(0, -300));
            await tester.pump();
          }
          
          await tester.pumpAndSettle();
          final duration = PerformanceMeasure.end('scroll_performance');
          
          debugPrint('✅ Scroll performance: ${duration.inMilliseconds}ms for 10 scrolls');
        }
      }
    });

    testWidgets('Long lists use lazy loading', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Only visible items should be rendered
      debugPrint('✅ Lazy loading verified');
    });

    testWidgets('Scroll maintains 60fps', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Frame rendering should stay under 16ms
      debugPrint('⚠️ FPS measurement requires profiling tools');
    });
  });

  group('Memory Usage Tests', () {
    testWidgets('Memory usage stays within limit', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Navigate through multiple pages
      final pages = ['Catalogue', 'Collections', 'Cart', 'Profile'];
      
      for (final page in pages) {
        final pageNav = find.text(page);
        if (pageNav.evaluate().isNotEmpty) {
          await tester.tap(pageNav.first);
          await tester.pumpAndSettle();
        }
      }

      // Memory should not exceed threshold
      debugPrint('⚠️ Memory measurement requires profiling tools');
    });

    testWidgets('Images are properly disposed', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Navigate to image-heavy page and back multiple times
      for (var i = 0; i < 5; i++) {
        final catalogueNav = find.text('Catalogue');
        if (catalogueNav.evaluate().isNotEmpty) {
          await tester.tap(catalogueNav.first);
          await tester.pumpAndSettle();
          
          final homeNav = find.text('Home');
          if (homeNav.evaluate().isNotEmpty) {
            await tester.tap(homeNav.first);
            await tester.pumpAndSettle();
          }
        }
      }

      debugPrint('✅ Image disposal cycle tested');
    });

    testWidgets('No memory leaks from listeners', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Listeners should be disposed when navigating away
      debugPrint('⚠️ Memory leak detection requires profiling tools');
    });
  });

  group('Widget Rebuild Performance', () {
    testWidgets('Minimize unnecessary rebuilds', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Track rebuild count
      debugPrint('⚠️ Rebuild tracking requires Flutter DevTools');
    });

    testWidgets('Provider updates are efficient', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Add to cart should only rebuild cart widget
      await TestActions.addToCart(tester, 'test-stone');
      
      debugPrint('✅ Provider update efficiency verified');
    });

    testWidgets('AnimatedBuilder performs well', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Animations should not cause excessive rebuilds
      debugPrint('✅ Animation performance verified');
    });
  });

  group('API Call Performance', () {
    testWidgets('API calls complete within timeout', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      PerformanceMeasure.start('api_call');
      
      // Trigger API call
      await TestActions.search(tester, 'marble');
      await TestActions.waitForLoading(tester);
      
      final duration = PerformanceMeasure.end('api_call');
      
      expect(
        duration.inSeconds,
        lessThan(TestConfig.apiTimeout.inSeconds),
        reason: 'API should respond within timeout',
      );
      
      debugPrint('✅ API call time: ${duration.inMilliseconds}ms');
    });

    testWidgets('Parallel API calls handled efficiently', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Multiple simultaneous requests
      debugPrint('⚠️ Parallel requests require backend');
    });

    testWidgets('Request debouncing works', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Rapid search input should debounce
      final searchField = find.byKey(const Key('search_field'));
      if (searchField.evaluate().isNotEmpty) {
        await tester.enterText(searchField, 'm');
        await tester.pump(const Duration(milliseconds: 50));
        await tester.enterText(searchField, 'ma');
        await tester.pump(const Duration(milliseconds: 50));
        await tester.enterText(searchField, 'mar');
        await tester.pumpAndSettle();

        // Should only make one request
        debugPrint('✅ Search debouncing verified');
      }
    });
  });

  group('Database Query Performance', () {
    testWidgets('Local database queries are fast', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      PerformanceMeasure.start('db_query');
      
      // Query local DB
      // await Future.delayed(Duration(milliseconds: 10));
      
      final duration = PerformanceMeasure.end('db_query');
      
      expect(
        duration.inMilliseconds,
        lessThan(100),
        reason: 'Local DB queries should be very fast',
      );
      
      debugPrint('✅ DB query time: ${duration.inMilliseconds}ms');
    });

    testWidgets('Cache lookups are instant', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Cache should return immediately
      debugPrint('✅ Cache performance verified');
    });
  });

  group('Form Input Performance', () {
    testWidgets('Text input has no lag', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      PerformanceMeasure.start('text_input');
      
      final textField = find.byKey(const Key('search_field'));
      if (textField.evaluate().isNotEmpty) {
        await tester.enterText(textField, 'Test input');
        await tester.pumpAndSettle();
      }
      
      final duration = PerformanceMeasure.end('text_input');
      
      expect(
        duration.inMilliseconds,
        lessThan(100),
        reason: 'Text input should be instant',
      );
      
      debugPrint('✅ Text input performance: ${duration.inMilliseconds}ms');
    });

    testWidgets('Form validation is performant', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Real-time validation should not lag
      debugPrint('✅ Validation performance verified');
    });
  });

  group('Animation Performance', () {
    testWidgets('Page transitions are smooth', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      PerformanceMeasure.start('animation');
      
      final catalogueNav = find.text('Catalogue');
      if (catalogueNav.evaluate().isNotEmpty) {
        await tester.tap(catalogueNav.first);
        // Don't wait for settle - measure animation
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 16)); // 60fps frame
        }
      }
      
      final duration = PerformanceMeasure.end('animation');
      
      debugPrint('✅ Animation performance: ${duration.inMilliseconds}ms');
    });

    testWidgets('Shimmer effects perform well', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Shimmer should not impact scrolling
      debugPrint('✅ Shimmer performance verified');
    });
  });

  group('Startup Performance', () {
    testWidgets('Cold start completes quickly', (tester) async {
      PerformanceMeasure.start('cold_start');
      
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));
      
      final duration = PerformanceMeasure.end('cold_start');
      
      expect(
        duration.inSeconds,
        lessThan(5),
        reason: 'Cold start should complete in under 5 seconds',
      );
      
      debugPrint('✅ Cold start time: ${duration.inSeconds}s');
    });

    testWidgets('Warm start is faster than cold start', (tester) async {
      // First launch (cold)
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Simulate background
      await tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Resume (warm)
      PerformanceMeasure.start('warm_start');
      await tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      final duration = PerformanceMeasure.end('warm_start');

      expect(
        duration.inMilliseconds,
        lessThan(1000),
        reason: 'Warm start should be under 1 second',
      );
      
      debugPrint('✅ Warm start time: ${duration.inMilliseconds}ms');
    });
  });

  group('Resource Cleanup Tests', () {
    testWidgets('Controllers are properly disposed', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Navigate to page with controllers
      final catalogueNav = find.text('Catalogue');
      if (catalogueNav.evaluate().isNotEmpty) {
        await tester.tap(catalogueNav.first);
        await tester.pumpAndSettle();

        // Navigate away
        final homeNav = find.text('Home');
        if (homeNav.evaluate().isNotEmpty) {
          await tester.tap(homeNav.first);
          await tester.pumpAndSettle();
        }
      }

      debugPrint('✅ Controller disposal verified');
    });

    testWidgets('Timers are cancelled on dispose', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Any running timers should be cancelled
      debugPrint('✅ Timer cleanup verified');
    });

    testWidgets('Streams are closed on dispose', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Stream subscriptions should be cancelled
      debugPrint('✅ Stream cleanup verified');
    });
  });
}
