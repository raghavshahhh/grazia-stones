import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

enum GraziaLogoVariant {
  full,      // Emblem + Wordmark
  emblem,    // Monogram emblem only
  wordmark,  // Wordmark only
}

enum GraziaLogoColor {
  auto,      // Dark in light mode, white in dark mode
  gold,      // Champagne Gold
  white,     // Pure white
  dark,      // Dark charcoal
}

/// Official Grazia Stones Logo Component
class GraziaLogo extends ConsumerWidget {
  final double height;
  final double? width;
  final GraziaLogoVariant variant;
  final GraziaLogoColor colorStyle;
  final bool enableGlow;

  const GraziaLogo({
    super.key,
    this.height = 36,
    this.width,
    this.variant = GraziaLogoVariant.full,
    this.colorStyle = GraziaLogoColor.auto,
    this.enableGlow = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themePaletteProvider);
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;

    String assetPath;
    switch (variant) {
      case GraziaLogoVariant.emblem:
        if (colorStyle == GraziaLogoColor.gold) {
          assetPath = 'assets/brand/grazia-emblem-gold.png';
        } else if (colorStyle == GraziaLogoColor.white || (colorStyle == GraziaLogoColor.auto && isDark)) {
          assetPath = 'assets/brand/grazia-emblem-white.png';
        } else {
          assetPath = 'assets/brand/grazia-emblem-dark.png';
        }
        break;

      case GraziaLogoVariant.wordmark:
        if (colorStyle == GraziaLogoColor.gold) {
          assetPath = 'assets/brand/grazia-wordmark-gold.png';
        } else if (colorStyle == GraziaLogoColor.white || (colorStyle == GraziaLogoColor.auto && isDark)) {
          assetPath = 'assets/brand/grazia-wordmark-white.png';
        } else {
          assetPath = 'assets/brand/grazia-wordmark-dark.png';
        }
        break;

      case GraziaLogoVariant.full:
        if (colorStyle == GraziaLogoColor.gold) {
          assetPath = 'assets/brand/grazia-logo-gold.png';
        } else if (colorStyle == GraziaLogoColor.white || (colorStyle == GraziaLogoColor.auto && isDark)) {
          assetPath = 'assets/brand/grazia-logo-white.png';
        } else {
          assetPath = 'assets/brand/grazia-logo-dark.png';
        }
        break;
    }

    Widget logoWidget = Image.asset(
      assetPath,
      height: height,
      width: width,
      fit: BoxFit.contain,
    );

    if (enableGlow) {
      return Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: palette.primary.withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: logoWidget,
      );
    }

    return logoWidget;
  }
}

/// Official Grazia Stones Animated Opening Splash Sequence
class GraziaAnimatedSplashLogo extends StatefulWidget {
  final VoidCallback? onAnimationComplete;

  const GraziaAnimatedSplashLogo({
    super.key,
    this.onAnimationComplete,
  });

  @override
  State<GraziaAnimatedSplashLogo> createState() => _GraziaAnimatedSplashLogoState();
}

class _GraziaAnimatedSplashLogoState extends State<GraziaAnimatedSplashLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _emblemScaleAnimation;
  late Animation<double> _emblemFadeAnimation;
  late Animation<double> _wordmarkFadeAnimation;
  late Animation<double> _sloganFadeAnimation;
  late Animation<double> _shimmerSweepAnimation;
  late Animation<double> _lineWidthAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    );

    // 0.0 - 0.4: Emblem scales up smoothly with easeOutBack & fades in
    _emblemScaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
      ),
    );

    _emblemFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    // 0.3 - 0.65: Wordmark "GRAZIA STONES" fades & glides up
    _wordmarkFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.60, curve: Curves.easeOutCubic),
      ),
    );

    // 0.5 - 0.8: Slogan "STONES THAT INSPIRE" reveals
    _sloganFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.75, curve: Curves.easeOut),
      ),
    );

    // 0.5 - 0.9: Shimmer light sweep across the emblem
    _shimmerSweepAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.9, curve: Curves.easeInOut),
      ),
    );

    // 0.6 - 1.0: Expanding gold divider line
    _lineWidthAnimation = Tween<double>(begin: 0.0, end: 72.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.95, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward().then((_) {
      widget.onAnimationComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final palette = ref.watch(themePaletteProvider);
        final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Animated GS Monogram Emblem with Shimmer/Aura
                Transform.scale(
                  scale: _emblemScaleAnimation.value,
                  child: Opacity(
                    opacity: _emblemFadeAnimation.value,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Soft Golden Aura Glow
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: palette.primary.withValues(
                                  alpha: 0.25 * _emblemFadeAnimation.value,
                                ),
                                blurRadius: 36,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                        ),

                        // Real GS Monogram Emblem
                        Image.asset(
                          isDark
                              ? 'assets/brand/grazia-emblem-gold.png'
                              : 'assets/brand/grazia-emblem-dark.png',
                          height: 90,
                          fit: BoxFit.contain,
                        ),

                        // Shimmer sweep reflection
                        if (_shimmerSweepAnimation.value > -0.8 && _shimmerSweepAnimation.value < 1.8)
                          ClipRect(
                            child: Transform.translate(
                              offset: Offset(_shimmerSweepAnimation.value * 60, 0),
                              child: Transform.rotate(
                                angle: math.pi / 4,
                                child: Container(
                                  width: 24,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.0),
                                        Colors.white.withValues(alpha: 0.4),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // 2. Official Wordmark: "GRAZIA"
                Opacity(
                  opacity: _wordmarkFadeAnimation.value,
                  child: Column(
                    children: [
                      Text(
                        'GRAZIA',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 9.0,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'STONES',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 6.5,
                          color: palette.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 3. Expanding Gold Accent Line
                Container(
                  width: _lineWidthAnimation.value,
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: palette.primaryGradient,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),

                const SizedBox(height: 14),

                // 4. Official Slogan: "STONES THAT INSPIRE"
                Opacity(
                  opacity: _sloganFadeAnimation.value,
                  child: Text(
                    'STONES THAT INSPIRE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 3.5,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
