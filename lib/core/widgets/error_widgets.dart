import 'package:flutter/material.dart';
import '../error/app_exception.dart';

/// Error display widget for full-screen errors
/// 
/// Shows:
/// - Error icon
/// - Error message
/// - Retry button (if retryable)
/// - Secondary action button (optional)
class ErrorView extends StatelessWidget {
  final AppException? exception;
  final String? message;
  final VoidCallback? onRetry;
  final VoidCallback? onSecondaryAction;
  final String? secondaryActionLabel;
  final IconData? icon;

  const ErrorView({
    super.key,
    this.exception,
    this.message,
    this.onRetry,
    this.onSecondaryAction,
    this.secondaryActionLabel,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final errorMessage = exception?.message ?? message ?? 'An error occurred';
    final isRetryable = exception?.isRetryable ?? onRetry != null;
    final errorIcon = icon ?? _getIconForException(exception);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                errorIcon,
                size: 40,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 24),

            // Error Message
            Text(
              errorMessage,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Action Buttons
            if (isRetryable && onRetry != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (onSecondaryAction != null) const SizedBox(height: 12),
            ],

            if (onSecondaryAction != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onSecondaryAction,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(secondaryActionLabel ?? 'Go Back'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForException(AppException? exception) {
    if (exception == null) return Icons.error_outline_rounded;

    if (exception is NetworkException) {
      return Icons.wifi_off_rounded;
    } else if (exception is AuthException) {
      return Icons.lock_outline_rounded;
    } else if (exception is ValidationException) {
      return Icons.warning_amber_rounded;
    } else if (exception is StorageException) {
      return Icons.cloud_off_rounded;
    } else if (exception is PaymentException) {
      return Icons.payment_rounded;
    } else if (exception is PermissionException) {
      return Icons.block_rounded;
    } else if (exception is AIException) {
      return Icons.psychology_rounded;
    } else {
      return Icons.error_outline_rounded;
    }
  }
}

/// Compact error banner widget
/// 
/// Shows at the top or bottom of screen
class ErrorBanner extends StatelessWidget {
  final AppException? exception;
  final String? message;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final bool showAtTop;

  const ErrorBanner({
    super.key,
    this.exception,
    this.message,
    this.onRetry,
    this.onDismiss,
    this.showAtTop = false,
  });

  @override
  Widget build(BuildContext context) {
    final errorMessage = exception?.message ?? message ?? 'An error occurred';
    final isRetryable = exception?.isRetryable ?? onRetry != null;

    return Material(
      color: Colors.red[700],
      child: SafeArea(
        top: showAtTop,
        bottom: !showAtTop,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  errorMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isRetryable && onRetry != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('RETRY'),
                ),
              ],
              if (onDismiss != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.white,
                  iconSize: 20,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline error widget for forms and cards
class InlineError extends StatelessWidget {
  final AppException? exception;
  final String? message;
  final VoidCallback? onRetry;
  final bool compact;

  const InlineError({
    super.key,
    this.exception,
    this.message,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final errorMessage = exception?.message ?? message ?? 'An error occurred';
    final isRetryable = exception?.isRetryable ?? onRetry != null;

    if (compact) {
      return Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: Colors.red[700],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage,
              style: TextStyle(
                fontSize: 13,
                color: Colors.red[700],
              ),
            ),
          ),
          if (isRetryable && onRetry != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onRetry,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: Colors.red[700],
                ),
              ),
            ),
          ],
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.red[700],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              errorMessage,
              style: TextStyle(
                fontSize: 14,
                color: Colors.red[700],
              ),
            ),
          ),
          if (isRetryable && onRetry != null) ...[
            const SizedBox(width: 12),
            IconButton(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              color: Colors.red[700],
              iconSize: 20,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
            ),
          ],
        ],
      ),
    );
  }
}

/// Empty state with optional error
class EmptyStateView extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onAction;
  final String? actionLabel;
  final AppException? error;

  const EmptyStateView({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.onAction,
    this.actionLabel,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final displayIcon = icon ??
        (error != null ? Icons.error_outline_rounded : Icons.inbox_rounded);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                displayIcon,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),

            // Subtitle
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
            ],

            // Error message
            if (error != null) ...[
              const SizedBox(height: 16),
              InlineError(exception: error),
            ],

            // Action button
            if (onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel ?? 'Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error snackbar helper
class ErrorSnackbar {
  static void show(
    BuildContext context, {
    AppException? exception,
    String? message,
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 4),
  }) {
    final errorMessage = exception?.message ?? message ?? 'An error occurred';
    final isRetryable = exception?.isRetryable ?? onRetry != null;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                errorMessage,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
        duration: duration,
        action: isRetryable && onRetry != null
            ? SnackBarAction(
                label: 'RETRY',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
