import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/theme/colors.dart';
import '../utils/user_friendly_error.dart';

/// Widget to display errors with retry option and luxury aesthetic
class ErrorHandlerWidget extends StatelessWidget {
  final dynamic error;
  final VoidCallback? onRetry;
  final String? customTitle;
  final String? customMessage;
  final LuxuryPalette? palette;

  const ErrorHandlerWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.customTitle,
    this.customMessage,
    this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final activePalette = palette ?? GLuxuryPalettes.gold;
    final friendly = UserFriendlyError.from(error, fallbackMessage: customMessage);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: activePalette.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: activePalette.border),
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 32,
                  color: activePalette.primary,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Error Title
              Text(
                customTitle ?? friendly.title,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: activePalette.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              // Error Message
              Text(
                customMessage ?? friendly.message,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: activePalette.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              
              if (onRetry != null) ...[
                const SizedBox(height: 24),
                
                // Retry Button
                ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onRetry!();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    friendly.actionLabel ?? 'Try Again',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activePalette.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small inline error widget
class InlineErrorWidget extends StatelessWidget {
  final dynamic error;
  final String? message;
  final VoidCallback? onRetry;
  final LuxuryPalette? palette;

  const InlineErrorWidget({
    super.key,
    this.error,
    this.message,
    this.onRetry,
    this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final activePalette = palette ?? GLuxuryPalettes.gold;
    final friendly = UserFriendlyError.from(error, fallbackMessage: message);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: activePalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: activePalette.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: activePalette.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message ?? friendly.message,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: activePalette.textSecondary,
                height: 1.35,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                onRetry!();
              },
              child: Text(
                'Retry',
                style: GoogleFonts.inter(
                  color: activePalette.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Global client-safe error snackbar
void showErrorSnackbar(BuildContext context, dynamic error, {VoidCallback? onRetry, String? customMessage}) {
  final friendly = UserFriendlyError.from(error, fallbackMessage: customMessage);

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              customMessage ?? friendly.message,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF2C2C2A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      action: onRetry != null
          ? SnackBarAction(
              label: 'Retry',
              textColor: const Color(0xFFD4AF37),
              onPressed: onRetry,
            )
          : null,
    ),
  );
}

/// Success snackbar
void showSuccessSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF2E7D32),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// Info snackbar
void showInfoSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.diamond_outlined, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF171717),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
