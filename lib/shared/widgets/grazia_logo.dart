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
/// Cold-start brand reveal: the emblem appears centred, glides up while "GRAZIA" writes in letter by
/// letter underneath, then a gold rule and "STONES" finish it. Always on the dark brand backdrop so it
/// continues seamlessly from the Android system splash. ~1.9s total, tap to skip happens upstream.
class GraziaAnimatedSplashLogo extends StatefulWidget {
  final VoidCallback? onAnimationComplete;

  const GraziaAnimatedSplashLogo({super.key, this.onAnimationComplete});

  static const backdrop = Color(0xFF14110D);

  @override
  State<GraziaAnimatedSplashLogo> createState() => _GraziaAnimatedSplashLogoState();
}

class _GraziaAnimatedSplashLogoState extends State<GraziaAnimatedSplashLogo>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFD4AF37);
  static const _letters = ['G', 'R', 'A', 'Z', 'I', 'A'];
  late final AnimationController _c =
      AnimationController(duration: const Duration(milliseconds: 1900), vsync: this);

  @override
  void initState() {
    super.initState();
    _c.forward().then((_) {
      if (mounted) widget.onAnimationComplete?.call();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Progress 0..1 of [v] inside the window [from, to] with [curve] applied.
  double _seg(double v, double from, double to, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((v - from) / (to - from)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        final appear = _seg(v, 0.0, 0.26);
        final scale = 0.82 + 0.18 * _seg(v, 0.0, 0.30, Curves.easeOutBack);
        final lift = _seg(v, 0.30, 0.66, Curves.easeInOutCubic);
        final glow = 0.15 + 0.2 * math.sin(math.pi * _seg(v, 0.0, 0.7, Curves.linear));
        final shimmer = _seg(v, 0.34, 0.70, Curves.easeInOut);
        final rule = _seg(v, 0.62, 0.86);
        final stones = _seg(v, 0.68, 0.92);
        final tracking = 18.0 - 9.0 * _seg(v, 0.30, 0.78);

        return SizedBox(
          width: 320,
          height: 300,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Emblem: fades in at the exact centre, then lifts.
              Transform.translate(
                offset: Offset(0, -46 * lift),
                child: Opacity(
                  opacity: appear,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 104,
                      height: 104,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: _gold.withValues(alpha: glow), blurRadius: 40, spreadRadius: 4)],
                      ),
                      child: ClipOval(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.asset('assets/brand/grazia-emblem-gold.png', width: 88, fit: BoxFit.contain),
                            if (shimmer > 0 && shimmer < 1)
                              Transform.translate(
                                offset: Offset(-70 + 140 * shimmer, 0),
                                child: Transform.rotate(
                                  angle: math.pi / 5,
                                  child: Container(
                                    width: 22,
                                    height: 150,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: [
                                        Colors.white.withValues(alpha: 0),
                                        Colors.white.withValues(alpha: 0.35),
                                        Colors.white.withValues(alpha: 0),
                                      ]),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Wordmark: letters write in one after another, tracking tightens as they land.
              Transform.translate(
                offset: const Offset(0, 46),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < _letters.length; i++)
                          Builder(builder: (_) {
                            final t = _seg(v, 0.30 + i * 0.035, 0.52 + i * 0.035);
                            return Opacity(
                              opacity: t,
                              child: Transform.translate(
                                offset: Offset(0, 14 * (1 - t)),
                                child: Padding(
                                  padding: EdgeInsets.only(right: i == _letters.length - 1 ? 0 : tracking),
                                  child: Text(
                                    _letters[i],
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFF4E9D3),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 72 * rule,
                      height: 1.2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          _gold.withValues(alpha: 0),
                          _gold,
                          _gold.withValues(alpha: 0),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Opacity(
                      opacity: stones,
                      child: Transform.translate(
                        offset: Offset(0, 8 * (1 - stones)),
                        child: Text(
                          'STONES',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 7,
                            color: _gold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
