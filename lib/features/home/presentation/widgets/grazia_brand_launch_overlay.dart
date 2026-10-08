import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grazia_stones/shared/theme/colors.dart';

/// Ultra-luxury Apple-grade brand launch animation with cinematic motion graphics.
/// 
/// The emblem and brand wordmark are unified as ONE cohesive brand entity from frame 1:
/// 1. Cold start: Deep obsidian (#151413) matching native launch screen exactly.
/// 2. Power-on awakening (0-300ms): Unified brand unit awakens with an elastic spring
///    scale, radiant gold energy bloom, and specular shimmer sweep across emblem & typography.
/// 3. Apple fluid flight (320-1000ms): The entire brand unit glides gracefully as ONE piece
///    using Apple's signature cubic curve, scaling down from 1.95x to 1.0x and docking
///    with sub-pixel precision directly into the top-left AppBar title.
/// 4. Coordinated backdrop dissolve (400-900ms): Obsidian backdrop smoothly fades out,
///    revealing the home screen seamlessly underneath.
/// 5. Precision haptic dock (920ms): Subtle Apple-style selection click right as it docks.
class GraziaBrandLaunchOverlay extends StatefulWidget {
  final LuxuryPalette palette;
  final bool isDark;
  final VoidCallback onComplete;

  const GraziaBrandLaunchOverlay({
    super.key,
    required this.palette,
    required this.isDark,
    required this.onComplete,
  });

  @override
  State<GraziaBrandLaunchOverlay> createState() => _GraziaBrandLaunchOverlayState();
}

class _GraziaBrandLaunchOverlayState extends State<GraziaBrandLaunchOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Phase 1: Center awakening, power-on bloom & shimmer sweep
  late final Animation<double> _powerOnBloom;
  late final Animation<double> _awakenScale;
  late final Animation<double> _shimmerSweep;

  // Phase 2: Apple fluid flight & Morph into top-left AppBar
  late final Animation<double> _flightCurve;
  late final Animation<double> _backdropFade;

  bool _isSkipping = false;
  bool _dockHapticPlayed = false;

  static const Color _obsidianDark = Color(0xFF151413);
  static const Color _goldRadiant = Color(0xFFD4AF37);
  static const Color _goldLuminous = Color(0xFFFFD700);

  // Exact geometry of the unscaled AppBar brand unit:
  // Emblem (22) + Gap (8) + Typography (~128) ≈ 158px width, ~31px height.
  static const double _baseUnitWidth = 158.0;
  static const double _baseUnitHeight = 31.0;
  static const double _startScale = 1.95;

  @override
  void initState() {
    super.initState();

    // Fast, responsive 1100ms total duration (energetic, silky & premium)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    // Radiant gold aura bloom expanding from center
    _powerOnBloom = Tween<double>(begin: 0.1, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.32, curve: Curves.easeOutCubic),
      ),
    );

    // Brand unit spring awakening (0.88 -> 1.04 -> 1.0)
    _awakenScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.32, curve: Curves.easeOutBack),
      ),
    );

    // Specular light sweep across metallic emblem & gold wordmark
    _shimmerSweep = Tween<double>(begin: -0.6, end: 1.8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.06, 0.38, curve: Curves.easeInOutCubic),
      ),
    );

    // Apple fluid flight curve (fast confident takeoff, ultra-soft gradual dock)
    _flightCurve = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        0.32,
        0.95,
        curve: Cubic(0.20, 0.0, 0.05, 1.0), // Signature iOS fluid motion curve
      ),
    );

    // Obsidian backdrop dissolves smoothly during flight
    _backdropFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.42, 0.90, curve: Curves.easeOut),
      ),
    );

    _controller.addListener(() {
      if (_flightCurve.value > 0.90 && !_dockHapticPlayed) {
        _dockHapticPlayed = true;
        HapticFeedback.selectionClick();
      }
    });

    _controller.forward().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _skip() {
    if (_isSkipping) return;
    _isSkipping = true;
    HapticFeedback.lightImpact();
    _controller
        .animateTo(1.0, duration: const Duration(milliseconds: 180), curve: Curves.easeOut)
        .then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topPadding = media.padding.top;
    final size = media.size;

    // Destination: exactly where HomeScreen's AppBar title is rendered:
    // In AppBar: titleSpacing = 14.0, kToolbarHeight = 56.0.
    // Center title vertically: (56.0 - 31.0) / 2 = 12.5 ≈ 13.0.
    const destX = 14.0;
    final destY = topPadding + 13.0;

    // Start: Centered horizontally and optical center vertically (0.44 height)
    final centerY = size.height * 0.44;
    final startX = (size.width - (_baseUnitWidth * _startScale)) / 2;
    final startY = centerY - ((_baseUnitHeight * _startScale) / 2);

    final targetGoldColor =
        widget.isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final flight = _flightCurve.value;
        final bgOpacity = _backdropFade.value.clamp(0.0, 1.0);
        final bloom = _powerOnBloom.value;
        final awaken = _awakenScale.value;
        final shimmerVal = _shimmerSweep.value;

        if (_controller.isCompleted) {
          return const SizedBox.shrink();
        }

        // Calculate synchronous position and scale
        final double curScale;
        final double curX;
        final double curY;

        if (flight == 0.0) {
          curScale = _startScale * awaken;
          curX = (size.width - (_baseUnitWidth * curScale)) / 2;
          curY = centerY - ((_baseUnitHeight * curScale) / 2);
        } else {
          curScale = Tween<double>(begin: _startScale, end: 1.0).transform(flight);
          curX = Tween<double>(begin: startX, end: destX).transform(flight);
          curY = Tween<double>(begin: startY, end: destY).transform(flight);
        }

        final curGoldColor =
            Color.lerp(_goldRadiant, targetGoldColor, flight) ?? _goldRadiant;
        final curSubtitleColor = Color.lerp(
              const Color(0xFFA0A0A0),
              widget.palette.textSecondary,
              flight,
            ) ??
            widget.palette.textSecondary;

        final haloAlpha = (bloom * (1.0 - flight * 1.6)).clamp(0.0, 1.0);

        return GestureDetector(
          onTap: _skip,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              // 1. Deep Obsidian Background (#151413) - 1:1 match with native launch screen
              if (bgOpacity > 0.0)
                Positioned.fill(
                  child: Opacity(
                    opacity: bgOpacity,
                    child: Container(
                      color: _obsidianDark,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Radiant ambient gold bloom behind center (powers on with energy)
                          Container(
                            width: size.width * 1.15,
                            height: size.width * 1.15,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  _goldLuminous.withValues(
                                    alpha: 0.32 * bloom * (1.0 - flight),
                                  ),
                                  _goldRadiant.withValues(
                                    alpha: 0.15 * bloom * (1.0 - flight),
                                  ),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.42, 1.0],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 2. UNIFIED BRAND UNIT (Emblem + Wordmark locked in perfect harmony)
              Positioned(
                left: curX,
                top: curY,
                child: Transform.scale(
                  scale: curScale,
                  alignment: Alignment.topLeft,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // The pristine brand lockup (1:1 structural match to AppBar title)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Gold Monogram with soft luminous halo
                          Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              // Concentric golden energy halo
                              if (haloAlpha > 0.02)
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _goldLuminous.withValues(
                                          alpha: 0.55 * haloAlpha,
                                        ),
                                        blurRadius: 20,
                                        spreadRadius: 3,
                                      ),
                                      BoxShadow(
                                        color: _goldRadiant.withValues(
                                          alpha: 0.35 * haloAlpha,
                                        ),
                                        blurRadius: 40,
                                        spreadRadius: 7,
                                      ),
                                    ],
                                  ),
                                ),
                              Image.asset(
                                'assets/brand/grazia-emblem-gold.png',
                                height: 22,
                                width: 22,
                                fit: BoxFit.contain,
                              ),
                            ],
                          ),

                          const SizedBox(width: 8),

                          // Brand Typography
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'GRAZIA',
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.8,
                                      color: curGoldColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'STONES',
                                    style: GoogleFonts.inter(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.5,
                                      color: curGoldColor,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'UNIT OF BNK STONES',
                                style: GoogleFonts.inter(
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                  color: curSubtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Metallic Specular Shimmer Beam across the entire lockup
                      if (flight < 0.25 && shimmerVal > -0.4 && shimmerVal < 1.4)
                        Positioned.fill(
                          child: ClipRect(
                            child: Transform.translate(
                              offset: Offset(shimmerVal * _baseUnitWidth, 0),
                              child: Transform.rotate(
                                angle: math.pi / 5,
                                child: Container(
                                  width: 24,
                                  height: _baseUnitHeight * 2.5,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.0),
                                        Colors.white.withValues(alpha: 0.45),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                    ),
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
            ],
          ),
        );
      },
    );
  }
}
