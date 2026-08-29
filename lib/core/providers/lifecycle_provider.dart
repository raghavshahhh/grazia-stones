import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_lifecycle_service.dart';
import '../services/state_restoration_service.dart';
import '../services/deep_link_service.dart';

/// Provider for AppLifecycleService instance
final appLifecycleServiceProvider = Provider<AppLifecycleService>((ref) {
  return AppLifecycleService.instance;
});

/// Stream provider for app lifecycle state
final appLifecycleStateProvider = StreamProvider<AppLifecycleState>((ref) {
  return AppLifecycleService.instance.stateStream;
});

/// Provider for current lifecycle state
final currentLifecycleStateProvider = Provider<AppLifecycleState>((ref) {
  return AppLifecycleService.instance.currentState;
});

/// Provider for StateRestorationService instance
final stateRestorationServiceProvider = Provider<StateRestorationService>((ref) {
  return StateRestorationService.instance;
});

/// Provider for DeepLinkService instance
final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  return DeepLinkService.instance;
});

/// Stream provider for deep links
final deepLinkStreamProvider = StreamProvider<DeepLinkData>((ref) {
  return DeepLinkService.instance.linkStream;
});

/// Provider for initial deep link
final initialDeepLinkProvider = Provider<DeepLinkData?>((ref) {
  return DeepLinkService.instance.getInitialLink();
});
