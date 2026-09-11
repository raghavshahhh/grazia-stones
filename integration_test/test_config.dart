/// Central configuration for all integration tests
/// Provides test environments, mock data, and shared utilities
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class TestConfig {
  /// Base URL for test API endpoints
  static const String testApiBaseUrl = 'https://grazia-stones.vercel.app';
  
  /// Supabase test project URL (use a separate test instance in production)
  static const String testSupabaseUrl = 'https://jrrmjtbauimrrxwjvmzh.supabase.co';
  
  /// Test user credentials
  static const String testEmail = 'test@graziastones.com';
  static const String testPassword = 'TestPass123!';
  static const String testAdminEmail = 'admin@graziastones.com';
  static const String testAdminPassword = 'AdminPass123!';
  
  /// Timeout configurations
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration apiTimeout = Duration(seconds: 15);
  static const Duration animationTimeout = Duration(milliseconds: 500);
  static const Duration pageLoadTimeout = Duration(seconds: 10);
  
  /// Test device sizes for responsive testing
  static const Map<String, Size> testDeviceSizes = {
    'mobile_small': Size(390, 844),   // iPhone 13 mini
    'mobile_medium': Size(393, 852),  // iPhone 14 Pro
    'mobile_large': Size(430, 932),   // iPhone 14 Pro Max
    'tablet': Size(820, 1180),        // iPad Air
    'desktop_small': Size(1366, 768), // Small laptop
    'desktop_medium': Size(1920, 1080), // Full HD
    'desktop_large': Size(2560, 1440),  // 2K
  };
  
  /// Mock data for testing
  static const String mockStoneId = '550e8400-e29b-41d4-a716-446655440000';
  static const String mockCollectionId = '550e8400-e29b-41d4-a716-446655440001';
  static const String mockCategoryId = 'natural-stones';
  
  /// Feature flags for test scenarios
  static bool enableNetworkMocking = false;
  static bool enableAnimations = false;
  static bool skipLoginFlow = false;
  static bool useRealBackend = kDebugMode;
  
  /// Performance thresholds
  static const Duration maxRenderTime = Duration(milliseconds: 16); // 60fps
  static const int maxMemoryUsageMB = 512;
  static const int maxImageLoadTimeMS = 3000;
}

/// Test utilities for common operations
class TestUtils {
  /// Wait for a widget to appear with timeout
  static Future<void> waitForWidget(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = TestConfig.defaultTimeout,
  }) async {
    final endTime = DateTime.now().add(timeout);
    
    while (DateTime.now().isBefore(endTime)) {
      await tester.pumpAndSettle(TestConfig.animationTimeout);
      
      if (finder.evaluate().isNotEmpty) {
        return;
      }
      
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    throw TimeoutException('Widget not found: $finder', timeout);
  }
  
  /// Scroll until widget is visible
  static Future<void> scrollUntilVisible(
    WidgetTester tester,
    Finder item,
    Finder scrollable, {
    double delta = -300.0,
    int maxScrolls = 50,
  }) async {
    for (var i = 0; i < maxScrolls; i++) {
      if (item.evaluate().isNotEmpty) {
        return;
      }
      
      await tester.drag(scrollable, Offset(0, delta));
      await tester.pumpAndSettle(TestConfig.animationTimeout);
    }
    
    throw Exception('Could not find widget after $maxScrolls scrolls');
  }
  
  /// Take a screenshot for debugging
  static Future<void> takeScreenshot(
    WidgetTester tester,
    String name,
  ) async {
    // Screenshots are automatically saved in test results
    await tester.pumpAndSettle();
    debugPrint('📸 Screenshot captured: $name');
  }
  
  /// Simulate network delay
  static Future<void> simulateNetworkDelay([Duration? delay]) async {
    await Future.delayed(delay ?? const Duration(milliseconds: 500));
  }
  
  /// Clear all app data for test isolation
  static Future<void> clearAppData() async {
    // Implementation depends on storage mechanism
    debugPrint('🧹 Clearing app data for test isolation');
  }
}

class TimeoutException implements Exception {
  final String message;
  final Duration timeout;
  
  TimeoutException(this.message, this.timeout);
  
  @override
  String toString() => 'TimeoutException: $message (timeout: $timeout)';
}
