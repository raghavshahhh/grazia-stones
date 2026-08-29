import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'app_exception.dart';

/// Global error handler service
/// 
/// Features:
/// - Converts raw exceptions to AppException hierarchy
/// - Retry logic with exponential backoff
/// - Error logging and reporting
/// - User-friendly error messages
class ErrorHandler {
  static ErrorHandler? _instance;
  static ErrorHandler get instance => _instance ??= ErrorHandler._();

  ErrorHandler._();

  // Callbacks for error reporting (config-ready for Sentry/Crashlytics)
  Function(AppException error, StackTrace? stackTrace)? _errorReporter;
  Function(String message, Map<String, dynamic>? data)? _analyticsLogger;

  void setErrorReporter(Function(AppException, StackTrace?) reporter) {
    _errorReporter = reporter;
  }

  void setAnalyticsLogger(Function(String, Map<String, dynamic>?) logger) {
    _analyticsLogger = logger;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ERROR CONVERSION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Convert any exception to AppException
  AppException handleError(dynamic error, [StackTrace? stackTrace]) {
    AppException appException;

    if (error is AppException) {
      appException = error;
    } else if (error is DioException) {
      appException = NetworkException.fromDioException(error);
    } else if (error is supa.AuthException) {
      appException = _handleSupabaseAuthError(error);
    } else if (error is supa.PostgrestException) {
      appException = _handleSupabasePostgrestError(error);
    } else if (error is supa.StorageException) {
      appException = _handleSupabaseStorageError(error);
    } else if (error is TimeoutException) {
      appException = NetworkException.timeout();
    } else if (error is FormatException) {
      appException = DataException.parsingError();
    } else {
      appException = UnknownException(
        technicalMessage: error.toString(),
        stackTrace: stackTrace,
      );
    }

    // Log error
    _logError(appException, stackTrace);

    // Report to external service
    _reportError(appException, stackTrace);

    return appException;
  }

  AppException _handleSupabaseAuthError(supa.AuthException error) {
    final message = error.message.toLowerCase();
    
    if (message.contains('invalid') && message.contains('credentials')) {
      return AuthException.invalidCredentials();
    } else if (message.contains('user not found')) {
      return AuthException.userNotFound();
    } else if (message.contains('email') && message.contains('already')) {
      return AuthException.emailAlreadyInUse();
    } else if (message.contains('weak password')) {
      return AuthException.weakPassword();
    } else if (message.contains('expired') || message.contains('jwt')) {
      return AuthException.sessionExpired();
    } else if (message.contains('otp')) {
      return AuthException.invalidOtp();
    } else {
      return AuthException(
        message: error.message,
        code: error.statusCode ?? 'AUTH_ERROR',
      );
    }
  }

  AppException _handleSupabasePostgrestError(supa.PostgrestException error) {
    final message = error.message.toLowerCase();
    
    if (message.contains('not found') || error.code == 'PGRST116') {
      return DataException.notFound('Data');
    } else if (message.contains('duplicate') || message.contains('unique')) {
      return DataException.alreadyExists('Record');
    } else if (message.contains('permission') || message.contains('rls')) {
      return AuthException.unauthorized();
    } else {
      return DataException(
        message: 'Database error occurred',
        technicalMessage: error.message,
        code: error.code,
      );
    }
  }

  AppException _handleSupabaseStorageError(supa.StorageException error) {
    final message = error.message.toLowerCase();
    
    if (message.contains('not found')) {
      return StorageException(
        message: 'File not found',
        code: 'FILE_NOT_FOUND',
        isRetryable: false,
      );
    } else if (message.contains('too large') || message.contains('size')) {
      return StorageException.fileTooLarge(10); // Default 10MB
    } else if (message.contains('unauthorized')) {
      return AuthException.unauthorized();
    } else {
      return StorageException(
        message: 'Storage operation failed',
        technicalMessage: error.message,
      );
    }
  }


  // ═══════════════════════════════════════════════════════════════════════════
  // RETRY LOGIC
  // ═══════════════════════════════════════════════════════════════════════════

  /// Execute operation with retry logic
  /// 
  /// Uses exponential backoff strategy:
  /// - Attempt 1: immediate
  /// - Attempt 2: 1s delay
  /// - Attempt 3: 2s delay
  /// - Attempt 4: 4s delay
  /// - etc.
  Future<T> executeWithRetry<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
    bool Function(AppException)? shouldRetry,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (true) {
      try {
        attempt++;
        return await operation();
      } catch (error, stackTrace) {
        final appException = handleError(error, stackTrace);

        // Check if we should retry
        final canRetry = attempt < maxRetries &&
            appException.isRetryable &&
            (shouldRetry == null || shouldRetry(appException));

        if (!canRetry) {
          rethrow;
        }

        // Log retry attempt
        debugPrint(
          '⚠️ Retry attempt $attempt/$maxRetries after ${delay.inSeconds}s: ${appException.message}',
        );

        // Wait before retry
        await Future.delayed(delay);

        // Increase delay for next attempt
        delay *= backoffMultiplier;
      }
    }
  }

  /// Execute operation with timeout
  Future<T> executeWithTimeout<T>({
    required Future<T> Function() operation,
    Duration timeout = const Duration(seconds: 30),
    String? timeoutMessage,
  }) async {
    try {
      return await operation().timeout(
        timeout,
        onTimeout: () {
          throw NetworkException.timeout();
        },
      );
    } catch (error, stackTrace) {
      throw handleError(error, stackTrace);
    }
  }

  /// Execute operation with both retry and timeout
  Future<T> executeSafe<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 30),
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    return executeWithRetry(
      operation: () => executeWithTimeout(
        operation: operation,
        timeout: timeout,
      ),
      maxRetries: maxRetries,
      initialDelay: initialDelay,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ERROR LOGGING & REPORTING
  // ═══════════════════════════════════════════════════════════════════════════

  void _logError(AppException error, StackTrace? stackTrace) {
    if (kDebugMode) {
      debugPrint('═══════════════════════════════════════════════');
      debugPrint('🔴 ERROR: ${error.runtimeType}');
      debugPrint('Message: ${error.message}');
      if (error.code != null) debugPrint('Code: ${error.code}');
      if (error.technicalMessage != null) {
        debugPrint('Technical: ${error.technicalMessage}');
      }
      debugPrint('Retryable: ${error.isRetryable}');
      if (stackTrace != null) {
        debugPrint('StackTrace:');
        debugPrint(stackTrace.toString());
      }
      debugPrint('═══════════════════════════════════════════════');
    }

    // Log to analytics (config-ready)
    _analyticsLogger?.call('error_occurred', {
      'error_type': error.runtimeType.toString(),
      'error_code': error.code ?? 'UNKNOWN',
      'error_message': error.message,
      'is_retryable': error.isRetryable,
    });
  }

  void _reportError(AppException error, StackTrace? stackTrace) {
    // Report to external service (config-ready for Sentry/Crashlytics)
    _errorReporter?.call(error, stackTrace);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Check if error is network-related
  bool isNetworkError(dynamic error) {
    if (error is NetworkException) return true;
    if (error is DioException) return true;
    if (error is TimeoutException) return true;
    return false;
  }

  /// Check if error is auth-related
  bool isAuthError(dynamic error) {
    return error is AuthException;
  }

  /// Get user-friendly message from any error
  String getUserMessage(dynamic error) {
    if (error is AppException) {
      return error.message;
    } else if (error is DioException) {
      return NetworkException.fromDioException(error).message;
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }
}
