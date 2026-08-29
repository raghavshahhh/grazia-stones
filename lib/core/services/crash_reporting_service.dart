import 'package:flutter/foundation.dart';

/// Crash severity levels
enum CrashSeverity {
  fatal,
  error,
  warning,
  info,
}

/// Crash reporting service (config-ready for Sentry/Crashlytics)
/// 
/// Features:
/// - Exception capturing
/// - Custom error logging
/// - User context
/// - Breadcrumbs
/// - Config-ready for external services
class CrashReportingService {
  static CrashReportingService? _instance;
  static CrashReportingService get instance => _instance ??= CrashReportingService._();

  CrashReportingService._();

  // Callbacks for external crash reporting services
  Function(dynamic exception, StackTrace? stackTrace, CrashSeverity severity)?
      _sentryReporter;
  Function(dynamic exception, StackTrace? stackTrace)? _crashlyticsReporter;
  Function(String message, Map<String, dynamic>? data)? _breadcrumbLogger;

  bool _isEnabled = true;
  String? _userId;
  final Map<String, dynamic> _userContext = {};
  final List<Breadcrumb> _breadcrumbs = [];
  static const int _maxBreadcrumbs = 100;

  // ═══════════════════════════════════════════════════════════════════════════
  // CONFIGURATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initialize crash reporting service
  void init({
    Function(dynamic, StackTrace?, CrashSeverity)? sentryCallback,
    Function(dynamic, StackTrace?)? crashlyticsCallback,
    Function(String, Map<String, dynamic>?)? breadcrumbCallback,
  }) {
    _sentryReporter = sentryCallback;
    _crashlyticsReporter = crashlyticsCallback;
    _breadcrumbLogger = breadcrumbCallback;
    
    // Set up Flutter error handler
    FlutterError.onError = (details) {
      reportFlutterError(details);
    };
    
    debugPrint('🛡️ Crash reporting service initialized');
  }

  /// Enable/disable crash reporting
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    debugPrint('🛡️ Crash reporting ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Check if crash reporting is enabled
  bool get isEnabled => _isEnabled;

  // ═══════════════════════════════════════════════════════════════════════════
  // USER CONTEXT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Set current user ID
  void setUserId(String? userId) {
    _userId = userId;
    if (userId != null) {
      _userContext['user_id'] = userId;
      debugPrint('🛡️ User ID set for crash reporting: $userId');
    } else {
      _userContext.remove('user_id');
    }
  }

  /// Set user context data
  void setUserContext(Map<String, dynamic> context) {
    _userContext.addAll(context);
  }

  /// Get current user context
  Map<String, dynamic> get userContext => Map.unmodifiable(_userContext);

  // ═══════════════════════════════════════════════════════════════════════════
  // EXCEPTION REPORTING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Report an exception
  void reportException(
    dynamic exception,
    StackTrace? stackTrace, {
    CrashSeverity severity = CrashSeverity.error,
    Map<String, dynamic>? context,
  }) {
    if (!_isEnabled) return;

    // Log to console in debug mode
    if (kDebugMode) {
      debugPrint('🛡️ Exception reported (${severity.name}):');
      debugPrint('   $exception');
      if (stackTrace != null) {
        debugPrint('   Stack trace:');
        debugPrint('   $stackTrace');
      }
      if (context != null) {
        debugPrint('   Context: $context');
      }
    }

    // Build full context
    final fullContext = {
      ..._userContext,
      if (context != null) ...context,
      'breadcrumbs': _breadcrumbs.map((b) => b.toJson()).toList(),
    };

    // Report to Sentry
    _sentryReporter?.call(exception, stackTrace, severity);

    // Report to Crashlytics (fatal and error only)
    if (severity == CrashSeverity.fatal || severity == CrashSeverity.error) {
      _crashlyticsReporter?.call(exception, stackTrace);
    }

    // Add as breadcrumb
    addBreadcrumb(
      'exception',
      data: {
        'type': exception.runtimeType.toString(),
        'message': exception.toString(),
        'severity': severity.name,
      },
    );
  }

  /// Report Flutter error
  void reportFlutterError(FlutterErrorDetails details) {
    if (!_isEnabled) return;

    reportException(
      details.exception,
      details.stack,
      severity: CrashSeverity.fatal,
      context: {
        'library': details.library ?? 'unknown',
        'context': details.context?.toString(),
      },
    );
  }

  /// Log a message (non-exception)
  void logMessage(
    String message, {
    CrashSeverity severity = CrashSeverity.info,
    Map<String, dynamic>? data,
  }) {
    if (!_isEnabled) return;

    if (kDebugMode) {
      debugPrint('🛡️ Log (${severity.name}): $message');
      if (data != null) {
        debugPrint('   Data: $data');
      }
    }

    addBreadcrumb(message, data: data);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BREADCRUMBS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Add a breadcrumb (trail of events leading to an error)
  void addBreadcrumb(
    String message, {
    String? category,
    Map<String, dynamic>? data,
    BreadcrumbLevel level = BreadcrumbLevel.info,
  }) {
    final breadcrumb = Breadcrumb(
      message: message,
      category: category,
      data: data,
      level: level,
      timestamp: DateTime.now(),
    );

    _breadcrumbs.add(breadcrumb);

    // Keep only last N breadcrumbs
    if (_breadcrumbs.length > _maxBreadcrumbs) {
      _breadcrumbs.removeAt(0);
    }

    // Log to external service
    _breadcrumbLogger?.call(message, breadcrumb.toJson());
  }

  /// Get all breadcrumbs
  List<Breadcrumb> get breadcrumbs => List.unmodifiable(_breadcrumbs);

  /// Clear all breadcrumbs
  void clearBreadcrumbs() {
    _breadcrumbs.clear();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PERFORMANCE MONITORING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Start a performance trace
  PerformanceTrace startTrace(String name) {
    return PerformanceTrace(name);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BREADCRUMB MODEL
// ═══════════════════════════════════════════════════════════════════════════

enum BreadcrumbLevel {
  debug,
  info,
  warning,
  error,
}

class Breadcrumb {
  final String message;
  final String? category;
  final Map<String, dynamic>? data;
  final BreadcrumbLevel level;
  final DateTime timestamp;

  Breadcrumb({
    required this.message,
    this.category,
    this.data,
    this.level = BreadcrumbLevel.info,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      if (category != null) 'category': category,
      if (data != null) 'data': data,
      'level': level.name,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PERFORMANCE TRACE
// ═══════════════════════════════════════════════════════════════════════════

class PerformanceTrace {
  final String name;
  final DateTime _startTime;
  final Map<String, dynamic> _metrics = {};
  bool _stopped = false;

  PerformanceTrace(this.name) : _startTime = DateTime.now() {
    debugPrint('⏱️ Performance trace started: $name');
  }

  /// Add a metric to the trace
  void setMetric(String name, num value) {
    if (!_stopped) {
      _metrics[name] = value;
    }
  }

  /// Stop the trace and record duration
  void stop() {
    if (_stopped) return;

    _stopped = true;
    final duration = DateTime.now().difference(_startTime);
    
    debugPrint('⏱️ Performance trace stopped: $name (${duration.inMilliseconds}ms)');
    if (_metrics.isNotEmpty) {
      debugPrint('   Metrics: $_metrics');
    }

    // Add as breadcrumb
    CrashReportingService.instance.addBreadcrumb(
      'Performance trace: $name',
      category: 'performance',
      data: {
        'duration_ms': duration.inMilliseconds,
        ..._metrics,
      },
    );
  }

  /// Get trace duration
  Duration get duration => DateTime.now().difference(_startTime);
}
