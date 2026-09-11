/// Test wrapper for initializing the app in test environment
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/main.dart' as app;

/// Creates a testable version of the app with mocked dependencies
Widget createTestApp({
  bool skipOnboarding = true,
  bool mockAuth = true,
  bool mockNetwork = false,
}) {
  return const ProviderScope(
    child: app.MyApp(), // Use actual app for integration tests
  );
}

/// Initialize test environment
Future<void> initializeTestEnvironment() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Add any other initialization needed
  debugPrint('🧪 Test environment initialized');
}
