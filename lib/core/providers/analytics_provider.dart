import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/analytics_service.dart';
import '../services/crash_reporting_service.dart';

/// Provider for AnalyticsService instance
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService.instance;
});

/// Provider for CrashReportingService instance
final crashReportingServiceProvider = Provider<CrashReportingService>((ref) {
  return CrashReportingService.instance;
});

/// Provider for analytics enabled state
final analyticsEnabledProvider = StateProvider<bool>((ref) {
  return AnalyticsService.instance.isEnabled;
});

/// Provider for crash reporting enabled state
final crashReportingEnabledProvider = StateProvider<bool>((ref) {
  return CrashReportingService.instance.isEnabled;
});

/// Provider for current user ID
final analyticsUserIdProvider = StateProvider<String?>((ref) {
  return null;
});

/// Screen tracking mixin for Riverpod ConsumerStatefulWidget
mixin ScreenTrackingMixin on ConsumerState {
  String get screenName;
  String? get screenClass => null;

  @override
  void initState() {
    super.initState();
    _trackScreen();
  }

  void _trackScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logScreenView(
            screenName,
            screenClass: screenClass,
          );
    });
  }
}
