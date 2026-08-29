import 'package:flutter/foundation.dart';

/// Retry configuration for network operations
class RetryConfig {
  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final List<int> retryableStatusCodes;

  const RetryConfig({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 10),
    this.backoffMultiplier = 2.0,
    this.retryableStatusCodes = const [408, 429, 500, 502, 503, 504],
  });

  /// Default config for database operations
  static const RetryConfig database = RetryConfig(
    maxAttempts: 3,
    baseDelay: Duration(milliseconds: 300),
    maxDelay: Duration(seconds: 5),
    backoffMultiplier: 2.0,
  );

  /// Config for AI/API operations (longer timeout)
  static const RetryConfig aiApi = RetryConfig(
    maxAttempts: 2,
    baseDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 15),
    backoffMultiplier: 2.0,
  );

  /// Calculate delay for attempt number (0-indexed)
  Duration delayForAttempt(int attempt) {
    final delay = baseDelay * (backoffMultiplier * attempt);
    return delay > maxDelay ? maxDelay : delay;
  }

  /// Check if an exception is retryable
  bool isRetryable(Object error) {
    if (error is SupabaseException) {
      return retryableStatusCodes.contains(error.code);
    }
    // Network errors, timeouts, etc.
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('timeout') ||
        errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('socket') ||
        errorStr.contains('handshake') ||
        errorStr.contains('econnrefused') ||
        errorStr.contains('enotfound');
  }
}

/// Generic retry wrapper with exponential backoff
Future<T> withRetry<T>({
  required Future<T> Function() operation,
  RetryConfig config = RetryConfig.database,
  void Function(Object error, int attempt)? onRetry,
}) async {
  Object? lastError;
  
  for (int attempt = 0; attempt < config.maxAttempts; attempt++) {
    try {
      return await operation();
    } catch (e) {
      lastError = e;
      
      if (attempt < config.maxAttempts - 1 && config.isRetryable(e)) {
        final delay = config.delayForAttempt(attempt);
        debugPrint('[Retry] Attempt ${attempt + 1} failed: $e. Retrying in ${delay.inMilliseconds}ms...');
        onRetry?.call(e, attempt);
        await Future.delayed(delay);
        continue;
      }
      
      // Non-retryable error or last attempt
      rethrow;
    }
  }
  
  throw lastError!;
}

/// Supabase-specific exception wrapper
class SupabaseException implements Exception {
  final int code;
  final String message;
  final Map<String, dynamic>? details;

  SupabaseException(this.code, this.message, {this.details});

  @override
  String toString() => 'SupabaseException(code: $code, message: $message)';
}