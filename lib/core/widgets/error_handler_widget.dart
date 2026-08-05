import 'package:flutter/material.dart';
import '../../shared/theme/colors.dart';
import '../../shared/theme/typography.dart';
import '../../shared/theme/spacing.dart';
import '../network/exceptions.dart';

/// Widget to display errors with retry option
class ErrorHandlerWidget extends StatelessWidget {
  final dynamic error;
  final VoidCallback? onRetry;
  final String? customMessage;

  const ErrorHandlerWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;
    final errorInfo = _getErrorInfo(error);

    return Center(
      child: Padding(
        padding: GLuxurySpacing.paddingXl,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: errorInfo.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                errorInfo.icon,
                size: 40,
                color: errorInfo.color,
              ),
            ),
            
            GLuxurySpacing.gapXl,
            
            // Error Title
            Text(
              errorInfo.title,
              style: GLuxuryTypography.h2.copyWith(
                color: palette.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            
            GLuxurySpacing.gapSm,
            
            // Error Message
            Text(
              customMessage ?? errorInfo.message,
              style: GLuxuryTypography.bodyMedium.copyWith(
                color: palette.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            
            if (onRetry != null) ...[
              GLuxurySpacing.gapXl,
              
              // Retry Button
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: palette.background,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _ErrorInfo _getErrorInfo(dynamic error) {
    if (error is NetworkException) {
      return _ErrorInfo(
        icon: Icons.wifi_off_rounded,
        title: 'No Internet Connection',
        message: error.message,
        color: Colors.orange,
      );
    } else if (error is UnauthorizedException) {
      return _ErrorInfo(
        icon: Icons.lock_outline_rounded,
        title: 'Unauthorized',
        message: 'Please login again to continue',
        color: Colors.red,
      );
    } else if (error is ForbiddenException) {
      return _ErrorInfo(
        icon: Icons.block_rounded,
        title: 'Access Denied',
        message: error.message,
        color: Colors.red,
      );
    } else if (error is NotFoundException) {
      return _ErrorInfo(
        icon: Icons.search_off_rounded,
        title: 'Not Found',
        message: error.message,
        color: Colors.grey,
      );
    } else if (error is ValidationException) {
      return _ErrorInfo(
        icon: Icons.error_outline_rounded,
        title: 'Validation Error',
        message: error.message,
        color: Colors.orange,
      );
    } else if (error is ServerException) {
      return _ErrorInfo(
        icon: Icons.cloud_off_rounded,
        title: 'Server Error',
        message: error.message,
        color: Colors.red,
      );
    } else {
      return _ErrorInfo(
        icon: Icons.error_outline_rounded,
        title: 'Something Went Wrong',
        message: error.toString(),
        color: Colors.red,
      );
    }
  }
}

class _ErrorInfo {
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  _ErrorInfo({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });
}

/// Small inline error widget
class InlineErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const InlineErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;

    return Container(
      padding: GLuxurySpacing.paddingBase,
      decoration: BoxDecoration(
        color: palette.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: palette.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: palette.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GLuxuryTypography.bodySmall.copyWith(
                color: palette.error,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: TextStyle(color: palette.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Snackbar for errors
void showErrorSnackbar(BuildContext context, dynamic error, {VoidCallback? onRetry}) {
  final palette = GLuxuryPalettes.gold;
  
  String message;
  if (error is ApiException) {
    message = error.message;
  } else if (error is Exception) {
    message = error.toString().replaceFirst('Exception: ', '');
  } else {
    message = error.toString();
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: palette.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      action: onRetry != null
          ? SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: onRetry,
            )
          : null,
    ),
  );
}

/// Success snackbar
void showSuccessSnackbar(BuildContext context, String message) {
  final palette = GLuxuryPalettes.gold;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: palette.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// Info snackbar
void showInfoSnackbar(BuildContext context, String message) {
  final palette = GLuxuryPalettes.gold;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: palette.info,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
