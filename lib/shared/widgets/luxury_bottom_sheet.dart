import 'package:flutter/material.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/theme/text_styles.dart';

/// Premium glass-effect bottom sheet with drag-to-dismiss.
class LuxuryBottomSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final bool showDragHandle;
  final double maxHeight;

  const LuxuryBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.showDragHandle = true,
    this.maxHeight = 0.85,
  });

  /// Convenience method for showModalBottomSheet.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    bool isScrollControlled = true,
    bool showDragHandle = true,
    double maxHeight = 0.85,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: isScrollControlled,
      builder: (_) => LuxuryBottomSheet(
        title: title,
        showDragHandle: showDragHandle,
        maxHeight: maxHeight,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * maxHeight,
      ),
      margin: EdgeInsets.only(bottom: bottomPadding),
      decoration: const BoxDecoration(
        color: AppColors.charcoal,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.goldWarm, width: 0.5),
          left: BorderSide(color: AppColors.borderSubtle),
          right: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          if (showDragHandle) ...[
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.slate,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],

          // Title bar
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GraziaTextStyles.titleMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.silver,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.slate),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick confirm dialog styled as bottom sheet.
class LuxuryConfirmSheet extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final bool isDestructive;

  const LuxuryConfirmSheet({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    required this.onConfirm,
    this.isDestructive = false,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => LuxuryConfirmSheet(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        onConfirm: () => Navigator.pop(context, true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final confirmColor =
        isDestructive ? AppColors.error : AppColors.goldWarm;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: GraziaTextStyles.titleMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style:
                GraziaTextStyles.bodyMedium.copyWith(color: AppColors.silver),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.slate),
                    ),
                    child: Center(
                      child: Text(
                        cancelLabel,
                        style: GraziaTextStyles.bodyMedium
                            .copyWith(color: AppColors.silver),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: onConfirm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: confirmColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        confirmLabel,
                        style: GraziaTextStyles.bodyMedium
                            .copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Options bottom sheet with icons.
class LuxuryOptionsSheet extends StatelessWidget {
  final String title;
  final List<LuxuryOption> options;

  const LuxuryOptionsSheet({
    super.key,
    required this.title,
    required this.options,
  });

  static Future<int?> show({
    required BuildContext context,
    required String title,
    required List<LuxuryOption> options,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => LuxuryOptionsSheet(title: title, options: options),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryBottomSheet(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(options.length, (i) {
          final opt = options[i];
          return GestureDetector(
            onTap: () => Navigator.pop(context, i),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.slate),
              ),
              child: Row(
                children: [
                  Icon(opt.icon, color: AppColors.goldWarm, size: 22),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(opt.label,
                            style: GraziaTextStyles.bodyLarge
                                .copyWith(color: Colors.white)),
                        if (opt.subtitle != null)
                          Text(opt.subtitle!,
                              style: GraziaTextStyles.bodySmall
                                  .copyWith(color: AppColors.slate)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppColors.slate, size: 20),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class LuxuryOption {
  final IconData icon;
  final String label;
  final String? subtitle;

  const LuxuryOption({
    required this.icon,
    required this.label,
    this.subtitle,
  });
}
