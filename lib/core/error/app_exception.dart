import 'package:dio/dio.dart';

/// Base class for all application exceptions
/// 
/// Provides:
/// - User-friendly error messages
/// - Technical error details for logging
/// - Error codes for tracking
/// - Retry capability flag
abstract class AppException implements Exception {
  final String message;
  final String? technicalMessage;
  final String? code;
  final StackTrace? stackTrace;
  final bool isRetryable;

  const AppException({
    required this.message,
    this.technicalMessage,
    this.code,
    this.stackTrace,
    this.isRetryable = false,
  });

  @override
  String toString() => message;

  String toDetailedString() {
    final buffer = StringBuffer();
    buffer.writeln('${runtimeType}: $message');
    if (code != null) buffer.writeln('Code: $code');
    if (technicalMessage != null) buffer.writeln('Technical: $technicalMessage');
    if (stackTrace != null) buffer.writeln('StackTrace: $stackTrace');
    return buffer.toString();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// NETWORK EXCEPTIONS
// ═══════════════════════════════════════════════════════════════════════════

class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.technicalMessage,
    super.code,
    super.stackTrace,
    super.isRetryable = true,
  });

  factory NetworkException.noInternet() {
    return const NetworkException(
      message: 'No internet connection. Please check your network settings.',
      code: 'NO_INTERNET',
      isRetryable: true,
    );
  }

  factory NetworkException.timeout() {
    return const NetworkException(
      message: 'Request timed out. Please try again.',
      code: 'TIMEOUT',
      isRetryable: true,
    );
  }

  factory NetworkException.serverError() {
    return const NetworkException(
      message: 'Server error. Please try again later.',
      code: 'SERVER_ERROR',
      isRetryable: true,
    );
  }

  factory NetworkException.badRequest(String details) {
    return NetworkException(
      message: 'Invalid request: $details',
      technicalMessage: details,
      code: 'BAD_REQUEST',
      isRetryable: false,
    );
  }

  factory NetworkException.fromDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException.timeout();
      
      case DioExceptionType.connectionError:
        return NetworkException.noInternet();
      
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode != null && statusCode >= 500) {
          return NetworkException.serverError();
        }
        return NetworkException(
          message: 'Request failed with status ${statusCode ?? 'unknown'}',
          technicalMessage: error.response?.data?.toString(),
          code: 'HTTP_$statusCode',
          isRetryable: false,
        );
      
      case DioExceptionType.cancel:
        return const NetworkException(
          message: 'Request was cancelled',
          code: 'CANCELLED',
          isRetryable: false,
        );
      
      case DioExceptionType.badCertificate:
        return const NetworkException(
          message: 'SSL certificate error',
          code: 'SSL_ERROR',
          isRetryable: false,
        );
      
      case DioExceptionType.unknown:
      default:
        return NetworkException(
          message: 'Network error occurred',
          technicalMessage: error.message,
          code: 'UNKNOWN',
          isRetryable: true,
        );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// AUTHENTICATION EXCEPTIONS
// ═══════════════════════════════════════════════════════════════════════════

class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.technicalMessage,
    super.code,
    super.stackTrace,
    super.isRetryable = false,
  });

  factory AuthException.invalidCredentials() {
    return const AuthException(
      message: 'Invalid email or password',
      code: 'INVALID_CREDENTIALS',
    );
  }

  factory AuthException.userNotFound() {
    return const AuthException(
      message: 'User not found',
      code: 'USER_NOT_FOUND',
    );
  }

  factory AuthException.emailAlreadyInUse() {
    return const AuthException(
      message: 'Email is already registered',
      code: 'EMAIL_IN_USE',
    );
  }

  factory AuthException.weakPassword() {
    return const AuthException(
      message: 'Password is too weak. Use at least 8 characters.',
      code: 'WEAK_PASSWORD',
    );
  }

  factory AuthException.sessionExpired() {
    return const AuthException(
      message: 'Your session has expired. Please login again.',
      code: 'SESSION_EXPIRED',
    );
  }

  factory AuthException.unauthorized() {
    return const AuthException(
      message: 'You are not authorized to perform this action',
      code: 'UNAUTHORIZED',
    );
  }

  factory AuthException.phoneVerificationFailed() {
    return const AuthException(
      message: 'Phone verification failed. Please try again.',
      code: 'PHONE_VERIFICATION_FAILED',
    );
  }

  factory AuthException.invalidOtp() {
    return const AuthException(
      message: 'Invalid OTP. Please check and try again.',
      code: 'INVALID_OTP',
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// VALIDATION EXCEPTIONS
// ═══════════════════════════════════════════════════════════════════════════

class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  const ValidationException({
    required super.message,
    this.fieldErrors,
    super.technicalMessage,
    super.code,
    super.stackTrace,
    super.isRetryable = false,
  });

  factory ValidationException.required(String fieldName) {
    return ValidationException(
      message: '$fieldName is required',
      code: 'REQUIRED_FIELD',
      fieldErrors: {fieldName: 'Required'},
    );
  }

  factory ValidationException.invalidFormat(String fieldName) {
    return ValidationException(
      message: 'Invalid $fieldName format',
      code: 'INVALID_FORMAT',
      fieldErrors: {fieldName: 'Invalid format'},
    );
  }

  factory ValidationException.minLength(String fieldName, int minLength) {
    return ValidationException(
      message: '$fieldName must be at least $minLength characters',
      code: 'MIN_LENGTH',
      fieldErrors: {fieldName: 'Minimum $minLength characters'},
    );
  }

  factory ValidationException.invalidEmail() {
    return ValidationException.invalidFormat('Email');
  }

  factory ValidationException.invalidPhone() {
    return ValidationException.invalidFormat('Phone number');
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STORAGE EXCEPTIONS
// ═══════════════════════════════════════════════════════════════════════════

class StorageException extends AppException {
  const StorageException({
    required super.message,
    super.technicalMessage,
    super.code,
    super.stackTrace,
    super.isRetryable = true,
  });

  factory StorageException.uploadFailed() {
    return const StorageException(
      message: 'Failed to upload file. Please try again.',
      code: 'UPLOAD_FAILED',
    );
  }

  factory StorageException.downloadFailed() {
    return const StorageException(
      message: 'Failed to download file. Please try again.',
      code: 'DOWNLOAD_FAILED',
    );
  }

  factory StorageException.fileTooLarge(int maxSizeMB) {
    return StorageException(
      message: 'File is too large. Maximum size is ${maxSizeMB}MB.',
      code: 'FILE_TOO_LARGE',
      isRetryable: false,
    );
  }

  factory StorageException.invalidFileType(String allowedTypes) {
    return StorageException(
      message: 'Invalid file type. Allowed types: $allowedTypes',
      code: 'INVALID_FILE_TYPE',
      isRetryable: false,
    );
  }

  factory StorageException.insufficientStorage() {
    return const StorageException(
      message: 'Insufficient storage space on device',
      code: 'INSUFFICIENT_STORAGE',
      isRetryable: false,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PAYMENT EXCEPTIONS
// ═══════════════════════════════════════════════════════════════════════════

class PaymentException extends AppException {
  const PaymentException({
    required super.message,
    super.technicalMessage,
    super.code,
    super.stackTrace,
    super.isRetryable = false,
  });

  factory PaymentException.paymentFailed() {
    return const PaymentException(
      message: 'Payment failed. Please try again.',
      code: 'PAYMENT_FAILED',
      isRetryable: true,
    );
  }

  factory PaymentException.paymentCancelled() {
    return const PaymentException(
      message: 'Payment was cancelled',
      code: 'PAYMENT_CANCELLED',
    );
  }

  factory PaymentException.verificationFailed() {
    return const PaymentException(
      message: 'Payment verification failed. Please contact support.',
      code: 'VERIFICATION_FAILED',
    );
  }

  factory PaymentException.insufficientFunds() {
    return const PaymentException(
      message: 'Insufficient funds in account',
      code: 'INSUFFICIENT_FUNDS',
    );
  }

  factory PaymentException.invalidCard() {
    return const PaymentException(
      message: 'Invalid card details',
      code: 'INVALID_CARD',
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DATA EXCEPTIONS
// ═══════════════════════════════════════════════════════════════════════════

class DataException extends AppException {
  const DataException({
    required super.message,
    super.technicalMessage,
    super.code,
    super.stackTrace,
    super.isRetryable = true,
  });

  factory DataException.notFound(String entityName) {
    return DataException(
      message: '$entityName not found',
      code: 'NOT_FOUND',
      isRetryable: false,
    );
  }

  factory DataException.alreadyExists(String entityName) {
    return DataException(
      message: '$entityName already exists',
      code: 'ALREADY_EXISTS',
      isRetryable: false,
    );
  }

  factory DataException.parsingError() {
    return const DataException(
      message: 'Failed to parse data. Please try again.',
      code: 'PARSING_ERROR',
    );
  }

  factory DataException.corruptedData() {
    return const DataException(
      message: 'Data is corrupted. Please refresh.',
      code: 'CORRUPTED_DATA',
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PERMISSION EXCEPTIONS
// ═══════════════════════════════════════════════════════════════════════════

class PermissionException extends AppException {
  const PermissionException({
    required super.message,
    super.technicalMessage,
    super.code,
    super.stackTrace,
    super.isRetryable = false,
  });

  factory PermissionException.denied(String permission) {
    return PermissionException(
      message: '$permission permission is required for this feature',
      code: 'PERMISSION_DENIED',
    );
  }

  factory PermissionException.permanentlyDenied(String permission) {
    return PermissionException(
      message: '$permission permission is required. Please enable it in settings.',
      code: 'PERMISSION_PERMANENTLY_DENIED',
    );
  }

  factory PermissionException.camera() {
    return PermissionException.denied('Camera');
  }

  factory PermissionException.storage() {
    return PermissionException.denied('Storage');
  }

  factory PermissionException.location() {
    return PermissionException.denied('Location');
  }

  factory PermissionException.notifications() {
    return PermissionException.denied('Notifications');
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// AI/ML EXCEPTIONS
// ═══════════════════════════════════════════════════════════════════════════

class AIException extends AppException {
  const AIException({
    required super.message,
    super.technicalMessage,
    super.code,
    super.stackTrace,
    super.isRetryable = true,
  });

  factory AIException.processingFailed() {
    return const AIException(
      message: 'AI processing failed. Please try again.',
      code: 'PROCESSING_FAILED',
    );
  }

  factory AIException.apiNotConfigured() {
    return const AIException(
      message: 'AI service is not configured. Please contact support.',
      code: 'API_NOT_CONFIGURED',
      isRetryable: false,
    );
  }

  factory AIException.imageQualityLow() {
    return const AIException(
      message: 'Image quality is too low for processing. Please use a better image.',
      code: 'LOW_IMAGE_QUALITY',
      isRetryable: false,
    );
  }

  factory AIException.quotaExceeded() {
    return const AIException(
      message: 'AI processing quota exceeded. Please try again later.',
      code: 'QUOTA_EXCEEDED',
      isRetryable: false,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GENERAL EXCEPTIONS
// ═══════════════════════════════════════════════════════════════════════════

class UnknownException extends AppException {
  const UnknownException({
    super.message = 'An unexpected error occurred',
    super.technicalMessage,
    super.code = 'UNKNOWN',
    super.stackTrace,
    super.isRetryable = true,
  });
}

class MaintenanceException extends AppException {
  const MaintenanceException({
    super.message = 'App is under maintenance. Please try again later.',
    super.code = 'MAINTENANCE',
    super.isRetryable = false,
  });
}

class FeatureDisabledException extends AppException {
  const FeatureDisabledException({
    required super.message,
    super.code = 'FEATURE_DISABLED',
    super.isRetryable = false,
  });
}
