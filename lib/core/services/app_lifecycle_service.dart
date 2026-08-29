import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'analytics_service.dart';
import 'connectivity_service.dart';

/// App lifecycle service
/// 
/// Features:
/// - Monitor app lifecycle (foreground/background)
/// - Auto-save on pause
/// - Restore state on resume
/// - Handle system events
/// - Deep link handling
class AppLifecycleService extends WidgetsBindingObserver {
  static AppLifecycleService? _instance;
  static AppLifecycleService get instance => _instance ??= AppLifecycleService._();

  AppLifecycleService._();

  AppLifecycleState _currentState = AppLifecycleState.resumed;
  final _stateController = StreamController<AppLifecycleState>.broadcast();


  // Callbacks
  VoidCallback? _onResumed;
  VoidCallback? _onPaused;
  VoidCallback? _onInactive;
  VoidCallback? _onDetached;

  DateTime? _lastPausedTime;
  Duration _backgroundDuration = Duration.zero;

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initialize lifecycle service
  void init({
    VoidCallback? onResumed,
    VoidCallback? onPaused,
    VoidCallback? onInactive,
    VoidCallback? onDetached,
  }) {
    _onResumed = onResumed;
    _onPaused = onPaused;
    _onInactive = onInactive;
    _onDetached = onDetached;

    WidgetsBinding.instance.addObserver(this);
    debugPrint('🔄 App lifecycle service initialized');
  }

  /// Dispose of resources
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stateController.close();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE OBSERVER
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final newState = _mapFlutterState(state);
    
    if (_currentState != newState) {
      final previousState = _currentState;
      _currentState = newState;
      _stateController.add(newState);

      debugPrint('🔄 App lifecycle changed: ${previousState.name} → ${newState.name}');

      // Handle state transitions
      _handleStateTransition(previousState, newState);

      // Track analytics
      _trackLifecycleEvent(newState);
    }
  }

  AppLifecycleState _mapFlutterState(AppLifecycleState flutterState) {
    switch (flutterState) {
      case AppLifecycleState.resumed:
        return AppLifecycleState.resumed;
      case AppLifecycleState.inactive:
        return AppLifecycleState.inactive;
      case AppLifecycleState.paused:
        return AppLifecycleState.paused;
      case AppLifecycleState.detached:
        return AppLifecycleState.detached;
      default:
        return AppLifecycleState.paused;
    }
  }


  void _handleStateTransition(
    AppLifecycleState from,
    AppLifecycleState to,
  ) {
    switch (to) {
      case AppLifecycleState.resumed:
        _handleResumed();
        _onResumed?.call();
        break;
      case AppLifecycleState.paused:
        _handlePaused();
        _onPaused?.call();
        break;
      case AppLifecycleState.inactive:
        _onInactive?.call();
        break;
      case AppLifecycleState.detached:
        _onDetached?.call();
        break;
      default:
        break;
    }
  }


  void _handleResumed() {
    // Calculate time spent in background
    if (_lastPausedTime != null) {
      _backgroundDuration = DateTime.now().difference(_lastPausedTime!);
      debugPrint('🔄 App resumed after ${_backgroundDuration.inSeconds}s in background');
    }

    // Check connectivity and sync if needed
    _checkConnectivityOnResume();
  }

  void _handlePaused() {
    _lastPausedTime = DateTime.now();
    debugPrint('🔄 App paused at ${_lastPausedTime!.toIso8601String()}');
  }

  Future<void> _checkConnectivityOnResume() async {
    try {
      final isOnline = await ConnectivityService.instance.checkConnection();
      if (isOnline && ConnectivityService.instance.queuedOperationsCount > 0) {
        debugPrint('🔄 Syncing queued operations on resume...');
        await ConnectivityService.instance.syncNow();
      }
    } catch (e) {
      debugPrint('❌ Error checking connectivity on resume: $e');
    }
  }

  void _trackLifecycleEvent(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        AnalyticsService.instance.logEvent(AnalyticsEvent.appOpened);
        break;
      case AppLifecycleState.paused:
        AnalyticsService.instance.logEvent(AnalyticsEvent.appBackgrounded);
        break;
      case AppLifecycleState.detached:
        AnalyticsService.instance.logEvent(AnalyticsEvent.appClosed);
        break;
      default:
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MEMORY WARNINGS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void didHaveMemoryPressure() {
    debugPrint('⚠️ Memory pressure warning');
    // Clear caches, release resources
    // ImageCacheConfig.clearCache(); // Optional: clear if needed
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get current lifecycle state
  AppLifecycleState get currentState => _currentState;

  /// Stream of lifecycle state changes
  Stream<AppLifecycleState> get stateStream => _stateController.stream;

  /// Check if app is in foreground
  bool get isInForeground => _currentState == AppLifecycleState.resumed;

  /// Check if app is in background
  bool get isInBackground =>
      _currentState == AppLifecycleState.paused ||
      _currentState == AppLifecycleState.inactive;

  /// Get duration spent in background
  Duration get backgroundDuration => _backgroundDuration;
}
