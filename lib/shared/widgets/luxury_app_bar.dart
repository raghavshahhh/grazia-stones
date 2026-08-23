import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/tokens.dart';
import '../theme/colors.dart';
import '../theme/borders.dart';

/// Glass-morphism app bar with blur backdrop, gold accents, and flexible layout.
class GLuxuryAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;
  final bool showBlur;
  final double height;
  final Color? backgroundColor;
  final VoidCallback? onBackPressed;

  const GLuxuryAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.showBackButton = false,
    this.showBlur = true,
    this.height = 56,
    this.backgroundColor,
    this.onBackPressed,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;

    return ClipRect(
      child: BackdropFilter(
        filter: showBlur
            ? ImageFilter.blur(sigmaX: GTokens.blurXl, sigmaY: GTokens.blurXl)
            : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
        child: Container(
          height: height + MediaQuery.of(context).padding.top,
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          color: backgroundColor ?? palette.background.withValues(alpha: 0.7),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: GTokens.space2),
              child: Row(
                children: [
                  if (showBackButton)
                    // Flexible bounds the width Row gives this Material button —
                    // without it, Row's Expanded title sibling forces an intrinsic
                    // width query that crashes IconButton's tap-target padding.
                    Flexible(
                      child: IconButton(
                        onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.arrow_back_ios_rounded,
                          size: 22,
                          color: palette.textPrimary,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: GTokens.space3),
                      ),
                    )
                  else if (leading != null)
                    leading!,
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: palette.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else if (titleWidget != null)
                    Expanded(child: titleWidget!),
                  if (actions != null)
                    ...actions!.map((a) => Flexible(child: a))
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating glass app bar for scroll-based apps.
class GLuxuryFloatingAppBar extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;

  const GLuxuryFloatingAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + GTokens.space2,
      left: GTokens.space4,
      right: GTokens.space4,
      child: ClipRRect(
        borderRadius: GLuxuryBorders.buttonRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: GTokens.blurXl, sigmaY: GTokens.blurXl),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: 0.6),
              borderRadius: GLuxuryBorders.buttonRadius,
              border: Border.all(
                color: palette.border,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                        color: palette.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (titleWidget != null)
                  Expanded(child: titleWidget!),
                if (actions != null)
                  ...actions!
                else
                  const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
