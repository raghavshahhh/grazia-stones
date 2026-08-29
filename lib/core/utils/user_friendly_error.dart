import 'dart:async';
import 'dart:io';

/// Centralized mapper that converts technical exceptions, network errors,
/// Supabase failures, camera issues, and generic errors into elegant, human-readable copy.
/// Raw technical details are hidden from the user and should be routed only to debug logs.
class UserFriendlyError {
  final String title;
  final String message;
  final String? actionLabel;

  const UserFriendlyError({
    required this.title,
    required this.message,
    this.actionLabel,
  });

  /// Map any exception or dynamic error into a client-safe UserFriendlyError
  factory UserFriendlyError.from(dynamic error, {String? fallbackMessage}) {
    if (error == null) {
      return const UserFriendlyError(
        title: 'Notice',
        message: 'Everything is up to date.',
      );
    }

    final errStr = error.toString().toLowerCase();

    // 1. Network & Timeout Errors
    if (error is SocketException ||
        error is TimeoutException ||
        errStr.contains('socketexception') ||
        errStr.contains('timeout') ||
        errStr.contains('network_error') ||
        errStr.contains('failed host lookup') ||
        errStr.contains('connection refused') ||
        errStr.contains('connection closed') ||
        errStr.contains('clientexception') ||
        errStr.contains('xmlhttprequest error')) {
      return const UserFriendlyError(
        title: 'Connection Offline',
        message: 'Unable to connect right now. Please check your internet connection and try again.',
        actionLabel: 'Try Again',
      );
    }

    // 2. Camera & Sensor Permissions
    if (errStr.contains('camera') ||
        errStr.contains('permission') ||
        errStr.contains('notallowederror') ||
        errStr.contains('permissiondenied')) {
      return const UserFriendlyError(
        title: 'Camera Access Required',
        message: 'Camera access is required for Live AR spatial visualization. Please allow camera access to continue.',
        actionLabel: 'Grant Access',
      );
    }

    // 3. Authentication & Login Errors
    if (errStr.contains('invalid_credentials') ||
        errStr.contains('invalid login credentials') ||
        errStr.contains('invalid password') ||
        errStr.contains('wrong password') ||
        errStr.contains('user not found') ||
        errStr.contains('invalid_grant')) {
      return UserFriendlyError(
        title: 'Authentication Notice',
        message: fallbackMessage ?? 'We couldn\'t sign you in with those details. Please check your email and password and try again.',
        actionLabel: 'Try Again',
      );
    }

    // 4. Duplicate / Conflict Errors
    if (errStr.contains('already registered') ||
        errStr.contains('user already exists') ||
        errStr.contains('unique constraint')) {
      return const UserFriendlyError(
        title: 'Account Exists',
        message: 'An account with this email already exists. Please log in or reset your password.',
        actionLabel: 'Sign In',
      );
    }

    // 5. AI Visualization Errors
    if (errStr.contains('ai') ||
        errStr.contains('segmentation') ||
        errStr.contains('wall not detected') ||
        errStr.contains('replicate') ||
        errStr.contains('inference')) {
      return const UserFriendlyError(
        title: 'Studio Notice',
        message: 'We couldn\'t complete the room visualization. Please ensure your wall is well lit and try again.',
        actionLabel: 'Retry AI Studio',
      );
    }

    // 6. Not Found / Catalog Missing
    if (errStr.contains('not found') ||
        errStr.contains('404') ||
        errStr.contains('no rows')) {
      return const UserFriendlyError(
        title: 'Surface Not Found',
        message: 'The requested architectural stone surface could not be located in our active catalogue.',
        actionLabel: 'Browse Catalogue',
      );
    }

    // 7. General Graceful Fallback
    return UserFriendlyError(
      title: 'Something Went Wrong',
      message: fallbackMessage ?? 'Unable to complete this request right now. Please try again in a moment.',
      actionLabel: 'Try Again',
    );
  }
}
