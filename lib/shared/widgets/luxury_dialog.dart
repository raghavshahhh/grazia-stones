import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/tokens.dart';
import '../theme/colors.dart';
import '../theme/shadows.dart';
import '../theme/borders.dart';
import 'luxury_button.dart';

/// Glass-morphism dialog with backdrop blur and gold accents.
class GLuxuryDialog extends StatelessWidget {
  final String? title;
  final Widget content;
  final String? primaryAction;
  final VoidCallback? onPrimaryAction;
  final String? secondaryAction;
  final VoidCallback? onSecondaryAction;
  final bool showCloseButton;

  const GLuxuryDialog({
    super.key,
    this.title,
    required this.content,
    this.primaryAction,
    this.onPrimaryAction,
    this.secondaryAction,
    this.onSecondaryAction,
    this.showCloseButton = true,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    required Widget content,
    String? primaryAction,
    VoidCallback? onPrimaryAction,
    String? secondaryAction,
    VoidCallback? onSecondaryAction,
    bool showCloseButton = true,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: GTokens.durationNormal,
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: GTokens.curveSpring,
          ),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: GLuxuryDialog(
              title: title,
              content: content,
              primaryAction: primaryAction,
              onPrimaryAction: onPrimaryAction,
              secondaryAction: secondaryAction,
              onSecondaryAction: onSecondaryAction,
              showCloseButton: showCloseButton,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: GTokens.blurLg, sigmaY: GTokens.blurLg),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.sizeOf(context).width - GTokens.space8 * 2,
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: 0.85),
              borderRadius: GLuxuryBorders.dialogRadius,
              border: Border.all(
                color: palette.primary.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: GLuxuryShadows.level5,
            ),
            child: ClipRRect(
              borderRadius: GLuxuryBorders.dialogRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: GTokens.blurMd, sigmaY: GTokens.blurMd),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.06),
                        Colors.white.withValues(alpha: 0.02),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(GTokens.space6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showCloseButton || title != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (title != null)
                                Expanded(
                                  child: Text(
                                    title!,
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: palette.textPrimary,
                                    ),
                                  ),
                                ),
                              if (showCloseButton)
                                GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 20,
                                    color: palette.textTertiary,
                                  ),
                                ),
                            ],
                          ),
                        if (title != null)
                          const SizedBox(height: GTokens.space4),
                        Flexible(child: content),
                        if (primaryAction != null || secondaryAction != null) ...[
                          const SizedBox(height: GTokens.space5),
                          Row(
                            children: [
                              if (secondaryAction != null) ...[
                                Expanded(
                                  child: GLuxuryButton(
                                    label: secondaryAction!,
                                    onPressed: () {
                                      onSecondaryAction?.call();
                                      Navigator.of(context).pop();
                                    },
                                    style: GLuxuryButtonStyle.ghost,
                                  ),
                                ),
                                const SizedBox(width: GTokens.space3),
                              ],
                              if (primaryAction != null)
                                Expanded(
                                  child: GLuxuryButton(
                                    label: primaryAction!,
                                    onPressed: () {
                                      onPrimaryAction?.call();
                                      Navigator.of(context).pop();
                                    },
                                    style: GLuxuryButtonStyle.filled,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
